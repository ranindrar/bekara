create or replace function public.post_transaction(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '', extensions as $$
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
    and direction = kind::text and (requested_scope = 'PRIVATE' or scope = 'HOUSEHOLD')
    and (scope = 'HOUSEHOLD' or owner_id = actor);
  if category.id is null then raise exception 'VALIDATION_ERROR: category'; end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, client_reference_id, created_by)
  values (household, actor, kind, (payload->>'transactionDate')::date, requested_scope, requested_privacy,
    nullif(btrim(payload->>'description'), ''), reference, actor) returning * into aggregate;
  insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
  values (aggregate.id, wallet.id, category.id, case when kind = 'INCOME'
    then 'CREDIT'::public.entry_direction else 'DEBIT'::public.entry_direction end, amount);
  result := jsonb_build_object('id', aggregate.id, 'version', aggregate.version);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'POST_TRANSACTION', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'TRANSACTION', aggregate.id, 'CREATE', to_jsonb(aggregate));
  return result;
end;
$$;

create or replace function public.correct_transaction(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '', extensions as $$
declare
  actor uuid := auth.uid(); original public.transaction_aggregates; reversal public.transaction_aggregates;
  replacement public.transaction_aggregates; original_entry public.ledger_entries; selected_period public.financial_periods;
  corrected numeric := coalesce((payload->>'correctedAmount')::numeric, 0); result jsonb;
  reference uuid := (payload->>'clientReferenceId')::uuid; stored_hash text;
  incoming_hash text := encode(digest(payload::text, 'sha256'), 'hex'); reason text := btrim(payload->>'reason');
begin
  if char_length(reason) < 3 or corrected < 0 then raise exception 'VALIDATION_ERROR'; end if;
  select payload_hash, response_json into stored_hash, result from public.idempotency_records
    where actor_id = actor and operation = 'CORRECT_TRANSACTION' and client_reference_id = reference;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;
  select * into original from public.transaction_aggregates
    where id = (payload->>'transactionId')::uuid and household_id = public.my_active_household_id() for update;
  if original.id is null then raise exception 'NOT_FOUND'; end if;
  if original.owner_id <> actor and original.scope <> 'HOUSEHOLD' then raise exception 'FORBIDDEN'; end if;
  if original.status <> 'POSTED' or original.kind not in ('INCOME', 'EXPENSE', 'BILL_PAYMENT') then raise exception 'VALIDATION_ERROR'; end if;
  select * into original_entry from public.ledger_entries where aggregate_id = original.id limit 1;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, reversal_of_id, client_reference_id, created_by)
  values (original.household_id, actor, 'REVERSAL', (payload->>'correctionDate')::date, original.scope, original.privacy,
    reason, original.id, gen_random_uuid(), actor) returning * into reversal;
  insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
  values (reversal.id, original_entry.wallet_id, original_entry.category_id,
    case when original_entry.direction = 'CREDIT'
      then 'DEBIT'::public.entry_direction else 'CREDIT'::public.entry_direction end, original_entry.amount);
  update public.transaction_aggregates set status = 'REVERSED', updated_at = now(), version = version + 1 where id = original.id;
  if corrected > 0 then
    insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
      description, correction_of_id, client_reference_id, created_by)
    values (original.household_id, actor, original.kind, (payload->>'correctionDate')::date, original.scope, original.privacy,
      coalesce(nullif(btrim(payload->>'description'), ''), original.description), original.id, gen_random_uuid(), actor)
    returning * into replacement;
    insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
    values (replacement.id, coalesce(nullif(payload->>'walletId', '')::uuid, original_entry.wallet_id),
      coalesce(nullif(payload->>'categoryId', '')::uuid, original_entry.category_id), original_entry.direction, corrected);
  end if;
  selected_period := public.ensure_financial_period(original.household_id, original.owner_id, original.scope, original.transaction_date);
  result := jsonb_build_object('reversalId', reversal.id, 'replacementId', replacement.id,
    'originalPeriodLocked', selected_period.status = 'LOCKED');
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'CORRECT_TRANSACTION', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, reason, after_value)
  values (original.household_id, actor, 'TRANSACTION', original.id,
    case when selected_period.status = 'LOCKED' then 'POST_LOCK_CORRECTION' else 'CORRECT' end, reason, result);
  return result;
end;
$$;

revoke all on function public.post_transaction(jsonb), public.correct_transaction(jsonb) from public, anon;
grant execute on function public.post_transaction(jsonb), public.correct_transaction(jsonb) to authenticated;
