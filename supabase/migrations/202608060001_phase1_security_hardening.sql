drop policy if exists categories_member_read on public.categories;
create policy categories_visible_read on public.categories for select using (
  public.is_active_household_member(household_id)
  and (scope = 'HOUSEHOLD' or owner_id = auth.uid())
);

create or replace function public.list_categories(category_direction text default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'name', c.name, 'direction', c.direction, 'scope', c.scope,
    'necessityType', c.necessity_type, 'systemCategory', c.system_category,
    'active', c.active, 'version', c.version
  ) order by c.direction, c.name), '[]'::jsonb)
  from public.categories c
  where c.household_id = public.my_active_household_id() and c.active
    and (c.scope = 'HOUSEHOLD' or c.owner_id = auth.uid())
    and (category_direction is null or c.direction = category_direction);
$$;

create or replace function public.post_transaction(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id(); wallet public.wallets;
  category public.categories; aggregate public.transaction_aggregates; amount numeric; kind public.transaction_kind;
  requested_scope public.transaction_scope; requested_privacy public.privacy_mode;
  reference uuid; result jsonb; stored_hash text; incoming_hash text := encode(digest(payload::text, 'sha256'), 'hex');
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if household is null then raise exception 'FORBIDDEN'; end if;
  begin
    amount := (payload->>'amount')::numeric;
    kind := (payload->>'kind')::public.transaction_kind;
    reference := (payload->>'clientReferenceId')::uuid;
    requested_scope := (payload->>'scope')::public.transaction_scope;
    requested_privacy := (payload->>'privacyMode')::public.privacy_mode;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if amount <= 0 or kind not in ('INCOME', 'EXPENSE') then raise exception 'VALIDATION_ERROR'; end if;
  if requested_scope = 'HOUSEHOLD' and requested_privacy <> 'HOUSEHOLD_VISIBLE' then raise exception 'VALIDATION_ERROR: privacy'; end if;

  select payload_hash, response_json into stored_hash, result from public.idempotency_records
  where actor_id = actor and operation = 'POST_TRANSACTION' and client_reference_id = reference;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;

  select * into wallet from public.wallets
  where id = (payload->>'walletId')::uuid and household_id = household;
  if wallet.id is null then raise exception 'NOT_FOUND: wallet'; end if;
  if not wallet.active then raise exception 'WALLET_INACTIVE'; end if;
  if wallet.owner_id <> actor and not wallet.is_shared then raise exception 'FORBIDDEN: wallet'; end if;

  select * into category from public.categories
  where id = (payload->>'categoryId')::uuid and household_id = household and active
    and direction = kind::text
    and (requested_scope = 'PRIVATE' or scope = 'HOUSEHOLD')
    and (scope = 'HOUSEHOLD' or owner_id = actor);
  if category.id is null then raise exception 'VALIDATION_ERROR: category'; end if;

  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, client_reference_id, created_by)
  values (household, actor, kind, (payload->>'transactionDate')::date, requested_scope, requested_privacy,
    nullif(btrim(payload->>'description'), ''), reference, actor) returning * into aggregate;
  insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
  values (aggregate.id, wallet.id, category.id, case when kind = 'INCOME' then 'CREDIT' else 'DEBIT' end, amount);
  result := jsonb_build_object('id', aggregate.id, 'version', aggregate.version);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'POST_TRANSACTION', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'TRANSACTION', aggregate.id, 'CREATE', to_jsonb(aggregate));
  return result;
end;
$$;

create or replace function public.post_transfer(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id(); source public.wallets;
  destination public.wallets; aggregate public.transaction_aggregates; transfer_record public.transfers;
  amount numeric; reference uuid; result jsonb; stored_hash text;
  incoming_hash text := encode(digest(payload::text, 'sha256'), 'hex');
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if household is null then raise exception 'FORBIDDEN'; end if;
  begin amount := (payload->>'amount')::numeric; reference := (payload->>'clientReferenceId')::uuid;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if amount <= 0 then raise exception 'VALIDATION_ERROR'; end if;
  select payload_hash, response_json into stored_hash, result from public.idempotency_records
  where actor_id = actor and operation = 'POST_TRANSFER' and client_reference_id = reference;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;
  select * into source from public.wallets where id = (payload->>'sourceWalletId')::uuid and household_id = household and active;
  select * into destination from public.wallets where id = (payload->>'destinationWalletId')::uuid and household_id = household and active;
  if source.id is null or destination.id is null then raise exception 'NOT_FOUND: wallet'; end if;
  if source.id = destination.id then raise exception 'TRANSFER_SAME_WALLET'; end if;
  if source.owner_id <> actor then raise exception 'FORBIDDEN'; end if;
  if destination.owner_id <> actor and not destination.accepts_household_transfer then raise exception 'FORBIDDEN'; end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, client_reference_id, created_by)
  values (household, actor, 'TRANSFER', (payload->>'transactionDate')::date, 'HOUSEHOLD', 'HOUSEHOLD_VISIBLE',
    nullif(btrim(payload->>'description'), ''), reference, actor) returning * into aggregate;
  insert into public.transfers(aggregate_id, source_wallet_id, destination_wallet_id, amount)
  values (aggregate.id, source.id, destination.id, amount) returning * into transfer_record;
  insert into public.ledger_entries(aggregate_id, wallet_id, direction, amount)
  values (aggregate.id, source.id, 'DEBIT', amount), (aggregate.id, destination.id, 'CREDIT', amount);
  result := jsonb_build_object('id', aggregate.id, 'transferId', transfer_record.id, 'version', aggregate.version);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'POST_TRANSFER', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'TRANSFER', transfer_record.id, 'CREATE', to_jsonb(transfer_record));
  return result;
end;
$$;

create or replace function public.list_transactions(result_limit integer default 50)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_data order by transaction_date desc, id desc), '[]'::jsonb)
  from (
    select a.id, a.transaction_date, a.kind::text, a.scope::text, a.status::text,
      case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then a.description else null end description,
      e.amount::text amount,
      case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then e.direction::text else null end direction,
      case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then w.name else null end wallet_name,
      case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then c.name else null end category_name,
      a.owner_id = auth.uid() is_owner
    from public.transaction_aggregates a
    join public.ledger_entries e on e.aggregate_id = a.id
    join public.wallets w on w.id = e.wallet_id
    left join public.categories c on c.id = e.category_id
    where a.household_id = public.my_active_household_id()
      and (a.owner_id = auth.uid() or a.scope = 'HOUSEHOLD' or a.privacy = 'PRIVATE_SUMMARY')
      and not (a.owner_id <> auth.uid() and a.privacy = 'PRIVATE_FULL')
      and (a.kind <> 'TRANSFER' or e.direction = 'DEBIT')
    order by a.transaction_date desc, a.id desc limit least(greatest(result_limit, 1), 200)
  ) row_data;
$$;

create or replace function public.dashboard_summary()
returns jsonb language sql stable security definer set search_path = '' as $$
  with balances as (
    select coalesce(sum(balance), 0) total from public.wallet_balances
    where household_id = public.my_active_household_id() and active
  ), flow as (
    select coalesce(sum(e.amount) filter (where a.kind = 'INCOME'), 0) income,
      coalesce(sum(e.amount) filter (where a.kind = 'EXPENSE'), 0) expense
    from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
    where a.household_id = public.my_active_household_id() and a.status = 'POSTED' and a.scope = 'HOUSEHOLD'
      and date_trunc('month', a.transaction_date) = date_trunc('month', current_date)
  ) select jsonb_build_object('totalBalance', balances.total::text,
    'monthlyIncome', flow.income::text, 'monthlyExpense', flow.expense::text)
  from balances cross join flow;
$$;

create or replace function public.report_category()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('category', name, 'amount', amount::text) order by amount desc), '[]'::jsonb)
  from (
    select coalesce(c.name, 'Tanpa kategori') name, sum(e.amount) amount
    from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
    left join public.categories c on c.id = e.category_id
    where a.household_id = public.my_active_household_id() and a.kind = 'EXPENSE'
      and a.status = 'POSTED' and a.scope = 'HOUSEHOLD'
      and date_trunc('month', a.transaction_date) = date_trunc('month', current_date)
    group by c.name
  ) data;
$$;

create or replace function public.reverse_transaction(
  transaction_id uuid, transaction_date date, reason text, client_reference_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); original public.transaction_aggregates; reversal public.transaction_aggregates;
  entry record; transfer_record public.transfers; result jsonb; stored_hash text;
  incoming_hash text := encode(digest(concat_ws('|', transaction_id, transaction_date, reason), 'sha256'), 'hex');
begin
  if char_length(btrim(reason)) < 3 then raise exception 'VALIDATION_ERROR: reason'; end if;
  select payload_hash, response_json into stored_hash, result from public.idempotency_records
  where actor_id = actor and operation = 'REVERSE_TRANSACTION' and idempotency_records.client_reference_id = $4;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;
  select * into original from public.transaction_aggregates
  where id = transaction_id and household_id = public.my_active_household_id() for update;
  if original.id is null then raise exception 'NOT_FOUND'; end if;
  if original.owner_id <> actor then raise exception 'FORBIDDEN'; end if;
  if original.status <> 'POSTED' then raise exception 'VALIDATION_ERROR: already reversed'; end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, status, reversal_of_id, client_reference_id, created_by)
  values (original.household_id, actor, 'REVERSAL', transaction_date, original.scope, original.privacy,
    btrim(reason), 'POSTED', original.id, client_reference_id, actor) returning * into reversal;
  for entry in select * from public.ledger_entries where aggregate_id = original.id loop
    insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
    values (reversal.id, entry.wallet_id, entry.category_id,
      case when entry.direction = 'CREDIT' then 'DEBIT'::public.entry_direction else 'CREDIT'::public.entry_direction end,
      entry.amount);
  end loop;
  update public.transaction_aggregates set status = 'REVERSED', updated_at = now(), version = version + 1 where id = original.id;
  select * into transfer_record from public.transfers where aggregate_id = original.id;
  if transfer_record.id is not null then update public.transfers set reversed_at = now() where id = transfer_record.id; end if;
  result := jsonb_build_object('id', reversal.id, 'reversalOfId', original.id, 'version', reversal.version);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'REVERSE_TRANSACTION', client_reference_id, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, reason, after_value)
  values (original.household_id, actor, 'TRANSACTION', original.id, 'REVERSE', reason, to_jsonb(reversal));
  return result;
end;
$$;
