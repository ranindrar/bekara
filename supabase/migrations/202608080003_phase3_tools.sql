create type public.import_batch_status as enum ('PENDING', 'COMMITTED', 'FAILED');

create table public.notification_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  event_key text not null check (char_length(event_key) between 3 and 180),
  read_at timestamptz not null default now(),
  dismissed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, event_key)
);

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  actor_id uuid not null references public.profiles(id),
  source_hash text not null check (source_hash ~ '^[a-f0-9]{64}$'),
  file_name text not null check (char_length(file_name) between 1 and 200),
  total_rows integer not null check (total_rows between 1 and 1000),
  committed_rows integer not null default 0 check (committed_rows >= 0),
  status public.import_batch_status not null default 'PENDING',
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (actor_id, source_hash)
);

create table public.import_batch_rows (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.import_batches(id),
  row_number integer not null check (row_number > 0),
  transaction_id uuid not null references public.transaction_aggregates(id),
  client_reference_id uuid not null,
  created_at timestamptz not null default now(),
  unique (batch_id, row_number),
  unique (batch_id, client_reference_id)
);

create table public.transaction_attachments (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  transaction_id uuid not null references public.transaction_aggregates(id),
  object_key text not null unique check (char_length(object_key) between 20 and 500),
  original_name text not null check (char_length(original_name) between 1 and 200),
  content_type text not null,
  file_size bigint not null check (file_size > 0 and file_size <= 5242880),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.profiles(id),
  version integer not null default 1,
  check (content_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf'))
);

create index import_batches_household_actor_idx
  on public.import_batches(household_id, actor_id, created_at desc);
create index transaction_attachments_transaction_idx
  on public.transaction_attachments(transaction_id) where deleted_at is null;

alter table public.notification_receipts enable row level security;
alter table public.import_batches enable row level security;
alter table public.import_batch_rows enable row level security;
alter table public.transaction_attachments enable row level security;

create policy notification_receipts_self_read on public.notification_receipts for select
  using (user_id = auth.uid());
create policy import_batches_owner_read on public.import_batches for select
  using (actor_id = auth.uid() and public.is_active_household_member(household_id));
create policy import_rows_owner_read on public.import_batch_rows for select
  using (exists (select 1 from public.import_batches b where b.id = batch_id and b.actor_id = auth.uid()));
create policy transaction_attachments_visible_read on public.transaction_attachments for select
  using (exists (
    select 1 from public.transaction_aggregates a
    where a.id = transaction_id and a.household_id = public.my_active_household_id()
      and (a.owner_id = auth.uid() or (a.scope = 'HOUSEHOLD' and a.privacy = 'HOUSEHOLD_VISIBLE'))
  ));

revoke insert, update, delete on public.notification_receipts, public.import_batches,
  public.import_batch_rows, public.transaction_attachments from anon, authenticated;

create or replace function public.list_credit_notifications()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  perform public.refresh_credit_bill(b.id) from public.billing_periods b
    join public.credit_accounts a on a.id = b.credit_account_id
    where a.household_id = public.my_active_household_id()
      and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid());
  with visible_bills as (
    select b.*, a.account_name, a.provider_name,
      b.private_outstanding + b.household_outstanding outstanding
    from public.billing_periods b join public.credit_accounts a on a.id = b.credit_account_id
    where a.household_id = public.my_active_household_id()
      and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid())
      and b.private_outstanding + b.household_outstanding > 0
  ), events as (
    select *, 'ISSUED' event_type from visible_bills where issued_at::date = current_date
    union all select *, 'H-7' from visible_bills where due_date - current_date = 7
    union all select *, 'H-3' from visible_bills where due_date - current_date = 3
    union all select *, 'H-1' from visible_bills where due_date - current_date = 1
    union all select *, 'DUE' from visible_bills where due_date = current_date
    union all select *, 'OVERDUE' from visible_bills where due_date < current_date
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'eventKey', e.id::text || ':' || e.event_type,
    'eventType', e.event_type, 'billId', e.id, 'accountId', e.credit_account_id,
    'accountName', e.account_name, 'providerName', e.provider_name,
    'dueDate', e.due_date, 'outstanding', e.outstanding::text,
    'read', r.id is not null, 'dismissed', coalesce(r.dismissed, false)
  ) order by e.due_date, e.event_type), '[]'::jsonb) into result
  from events e left join public.notification_receipts r
    on r.user_id = auth.uid() and r.event_key = e.id::text || ':' || e.event_type
  where not coalesce(r.dismissed, false);
  return result;
end;
$$;

create or replace function public.mark_credit_notification(target_event_key text, target_dismissed boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare bill_id uuid; account_id uuid;
begin
  begin bill_id := split_part(target_event_key, ':', 1)::uuid;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  select credit_account_id into account_id from public.billing_periods where id = bill_id;
  if account_id is null then raise exception 'NOT_FOUND'; end if;
  if not public.can_view_credit_account(account_id) then raise exception 'FORBIDDEN'; end if;
  insert into public.notification_receipts(user_id, event_key, dismissed)
  values (auth.uid(), target_event_key, target_dismissed)
  on conflict (user_id, event_key) do update set read_at = now(),
    dismissed = excluded.dismissed, updated_at = now();
  return jsonb_build_object('eventKey', target_event_key, 'read', true, 'dismissed', target_dismissed);
end;
$$;

create or replace function public.commit_import_batch(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id();
  source text := lower(payload->>'sourceHash'); rows jsonb := payload->'rows';
  batch public.import_batches; row_data jsonb; row_result jsonb; row_index integer := 0; result jsonb;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if household is null then raise exception 'FORBIDDEN'; end if;
  if source !~ '^[a-f0-9]{64}$' or jsonb_typeof(rows) <> 'array'
      or jsonb_array_length(rows) not between 1 and 1000
      or char_length(btrim(payload->>'fileName')) not between 1 and 200 then
    raise exception 'IMPORT_INVALID_FORMAT';
  end if;
  select * into batch from public.import_batches
    where actor_id = actor and source_hash = source;
  if batch.id is not null then
    return jsonb_build_object('id', batch.id, 'status', batch.status,
      'committedRows', batch.committed_rows, 'duplicate', true);
  end if;
  insert into public.import_batches(household_id, actor_id, source_hash, file_name, total_rows)
  values (household, actor, source, btrim(payload->>'fileName'), jsonb_array_length(rows))
  returning * into batch;
  for row_data in select value from jsonb_array_elements(rows) loop
    row_index := row_index + 1;
    if row_data->>'clientReferenceId' is null then raise exception 'IMPORT_INVALID_FORMAT'; end if;
    row_result := public.post_transaction(row_data);
    insert into public.import_batch_rows(batch_id, row_number, transaction_id, client_reference_id)
    values (batch.id, row_index, (row_result->>'id')::uuid,
      (row_data->>'clientReferenceId')::uuid);
  end loop;
  update public.import_batches set status = 'COMMITTED', committed_rows = row_index,
    completed_at = now() where id = batch.id returning * into batch;
  result := jsonb_build_object('id', batch.id, 'status', batch.status,
    'committedRows', batch.committed_rows, 'duplicate', false);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'IMPORT_BATCH', batch.id, 'COMMIT',
    jsonb_build_object('sourceHash', source, 'rowCount', row_index));
  return result;
exception when others then
  if sqlerrm like '%IMPORT_%' or sqlerrm like '%VALIDATION_ERROR%'
      or sqlerrm like '%FORBIDDEN%' or sqlerrm like '%NOT_FOUND%'
      or sqlerrm like '%PERIOD_LOCKED%' or sqlerrm like '%IDEMPOTENCY_CONFLICT%' then raise;
  end if;
  raise exception 'IMPORT_INVALID_FORMAT';
end;
$$;

create or replace function public.list_import_batches()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id, 'fileName', b.file_name, 'totalRows', b.total_rows,
    'committedRows', b.committed_rows, 'status', b.status,
    'createdAt', b.created_at, 'completedAt', b.completed_at
  ) order by b.created_at desc), '[]'::jsonb)
  from public.import_batches b
  where b.household_id = public.my_active_household_id() and b.actor_id = auth.uid();
$$;

create or replace function public.register_attachment(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id();
  transaction_record public.transaction_aggregates; attachment public.transaction_attachments;
  object_name text := payload->>'objectKey'; mime text := payload->>'contentType'; size_value bigint;
  object_metadata jsonb; stored_mime text; stored_size bigint;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  begin size_value := (payload->>'fileSize')::bigint;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if mime not in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf') then
    raise exception 'ATTACHMENT_INVALID_TYPE';
  end if;
  if size_value <= 0 or size_value > 5242880 then raise exception 'ATTACHMENT_TOO_LARGE'; end if;
  if char_length(btrim(payload->>'originalName')) not between 1 and 200 then
    raise exception 'VALIDATION_ERROR: original name';
  end if;
  select * into transaction_record from public.transaction_aggregates
    where id = (payload->>'transactionId')::uuid and household_id = household;
  if transaction_record.id is null then raise exception 'NOT_FOUND'; end if;
  if transaction_record.owner_id <> actor and transaction_record.scope <> 'HOUSEHOLD' then
    raise exception 'FORBIDDEN';
  end if;
  if object_name not like household::text || '/' || actor::text || '/' || transaction_record.id::text || '/%' then
    raise exception 'VALIDATION_ERROR: object key';
  end if;
  select o.metadata into object_metadata from storage.objects o
    where o.bucket_id = 'receipts' and o.name = object_name;
  if object_metadata is null then
    raise exception 'NOT_FOUND: object';
  end if;
  begin
    stored_mime := lower(object_metadata->>'mimetype');
    stored_size := (object_metadata->>'size')::bigint;
  exception when others then raise exception 'ATTACHMENT_METADATA_INVALID'; end;
  if stored_mime is distinct from lower(mime) or stored_size is distinct from size_value then
    raise exception 'ATTACHMENT_METADATA_INVALID';
  end if;
  insert into public.transaction_attachments(household_id, transaction_id, object_key,
    original_name, content_type, file_size, created_by)
  values (household, transaction_record.id, object_name, btrim(payload->>'originalName'),
    mime, size_value, actor) returning * into attachment;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'ATTACHMENT', attachment.id, 'CREATE',
    jsonb_build_object('transactionId', transaction_record.id, 'contentType', mime, 'fileSize', size_value));
  return jsonb_build_object('id', attachment.id, 'transactionId', attachment.transaction_id,
    'objectKey', attachment.object_key, 'version', attachment.version);
end;
$$;

create or replace function public.list_transaction_attachments(target_transaction_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare transaction_record public.transaction_aggregates; result jsonb;
begin
  select * into transaction_record from public.transaction_aggregates
    where id = target_transaction_id and household_id = public.my_active_household_id();
  if transaction_record.id is null then raise exception 'NOT_FOUND'; end if;
  if transaction_record.owner_id <> auth.uid() and transaction_record.scope <> 'HOUSEHOLD' then
    raise exception 'FORBIDDEN';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'transactionId', a.transaction_id, 'objectKey', a.object_key,
    'originalName', a.original_name, 'contentType', a.content_type,
    'fileSize', a.file_size, 'createdBy', a.created_by, 'createdAt', a.created_at,
    'version', a.version
  ) order by a.created_at desc), '[]'::jsonb) into result
  from public.transaction_attachments a
  where a.transaction_id = target_transaction_id and a.deleted_at is null;
  return result;
end;
$$;

create or replace function public.delete_attachment(attachment_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare attachment public.transaction_attachments; transaction_record public.transaction_aggregates;
begin
  select * into attachment from public.transaction_attachments
    where id = attachment_id and household_id = public.my_active_household_id() for update;
  if attachment.id is null or attachment.deleted_at is not null then raise exception 'NOT_FOUND'; end if;
  select * into transaction_record from public.transaction_aggregates where id = attachment.transaction_id;
  if transaction_record.owner_id <> auth.uid() and transaction_record.scope <> 'HOUSEHOLD' then
    raise exception 'FORBIDDEN';
  end if;
  update public.transaction_attachments set deleted_at = now(), deleted_by = auth.uid(),
    version = version + 1 where id = attachment.id returning * into attachment;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, before_value, after_value)
  values (attachment.household_id, auth.uid(), 'ATTACHMENT', attachment.id, 'DELETE',
    jsonb_build_object('objectKey', attachment.object_key), jsonb_build_object('deletedAt', attachment.deleted_at));
  return jsonb_build_object('id', attachment.id, 'objectKey', attachment.object_key,
    'deleted', true, 'version', attachment.version);
end;
$$;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.can_access_receipt_object(object_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.transaction_attachments x
    join public.transaction_aggregates a on a.id = x.transaction_id
    where x.object_key = object_name and x.deleted_at is null
      and a.household_id = public.my_active_household_id()
      and (a.owner_id = auth.uid() or (a.scope = 'HOUSEHOLD' and a.privacy = 'HOUSEHOLD_VISIBLE'))
  );
$$;

create policy receipts_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts'
    and (storage.foldername(name))[1] = public.my_active_household_id()::text
    and (storage.foldername(name))[2] = auth.uid()::text);
create policy receipts_select on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and public.can_access_receipt_object(name));
create policy receipts_delete on storage.objects for delete to authenticated
  using (bucket_id = 'receipts' and (
    (storage.foldername(name))[2] = auth.uid()::text or public.can_access_receipt_object(name)
  ));

revoke all on function public.can_access_receipt_object(text) from public, anon, authenticated;
revoke all on function public.list_credit_notifications(), public.mark_credit_notification(text, boolean),
  public.commit_import_batch(jsonb), public.list_import_batches(), public.register_attachment(jsonb),
  public.list_transaction_attachments(uuid), public.delete_attachment(uuid) from public, anon;
grant execute on function public.list_credit_notifications(), public.mark_credit_notification(text, boolean),
  public.commit_import_batch(jsonb), public.list_import_batches(), public.register_attachment(jsonb),
  public.list_transaction_attachments(uuid), public.delete_attachment(uuid) to authenticated;
