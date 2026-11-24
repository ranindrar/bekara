create or replace function public.reconcile_credit_account(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '', extensions as $$
declare actor uuid := auth.uid(); account public.credit_accounts; wallet public.wallet_balances;
  aggregate public.transaction_aggregates; purchase public.credit_purchases; bill public.billing_periods;
  schedule record; actual numeric; current_liability numeric; difference numeric; remaining numeric;
  chunk numeric; fee_due numeric; fee_credit numeric; principal_credit numeric;
  reference uuid; result jsonb; stored_hash text;
  incoming_hash text := encode(digest(payload::text, 'sha256'), 'hex');
begin
  begin actual := (payload->>'actualLiability')::numeric;
    reference := (payload->>'clientReferenceId')::uuid;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if actual < 0 or char_length(btrim(payload->>'reason')) < 3 then raise exception 'VALIDATION_ERROR'; end if;
  select * into account from public.credit_accounts
    where id = (payload->>'accountId')::uuid and household_id = public.my_active_household_id() for update;
  if account.id is null then raise exception 'NOT_FOUND'; end if;
  if not public.can_manage_credit_account(account.id) then raise exception 'FORBIDDEN'; end if;
  select * into wallet from public.wallet_balances where id = account.wallet_id;
  current_liability := greatest(-wallet.balance, 0); difference := actual - current_liability;
  if difference = 0 then return jsonb_build_object('id', account.id, 'difference', '0'); end if;
  select payload_hash, response_json into stored_hash, result from public.idempotency_records
    where actor_id = actor and operation = 'RECONCILE_CREDIT_ACCOUNT' and client_reference_id = reference;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date,
    scope, privacy, description, client_reference_id, created_by)
  values (account.household_id, actor, 'ADJUSTMENT', current_date, account.scope,
    case when account.scope = 'HOUSEHOLD' then 'HOUSEHOLD_VISIBLE'::public.privacy_mode
      else 'PRIVATE_FULL'::public.privacy_mode end,
    btrim(payload->>'reason'), reference, actor) returning * into aggregate;
  insert into public.ledger_entries(aggregate_id, wallet_id, direction, amount)
  values (aggregate.id, account.wallet_id,
    case when difference > 0 then 'DEBIT'::public.entry_direction else 'CREDIT'::public.entry_direction end,
    abs(difference));
  if difference > 0 then
    bill := public.ensure_credit_billing_period(account.id, current_date);
    insert into public.credit_purchases(household_id, credit_account_id, purchase_aggregate_id,
      owner_id, source_type, original_transaction_date, posted_date, scope, privacy,
      description, principal_amount, financing_cost, tenor, client_reference_id, created_by)
    values (account.household_id, account.id, aggregate.id, actor, 'ADJUSTMENT', current_date,
      current_date, account.scope,
      case when account.scope = 'HOUSEHOLD' then 'HOUSEHOLD_VISIBLE'::public.privacy_mode
        else 'PRIVATE_FULL'::public.privacy_mode end,
      btrim(payload->>'reason'), difference, 0, 1, gen_random_uuid(), actor)
    returning * into purchase;
    insert into public.installment_schedules(household_id, credit_account_id,
      billing_period_id, purchase_id, installment_number, due_date, scope, principal_amount)
    values (account.household_id, account.id, bill.id, purchase.id, 1, bill.due_date,
      account.scope, difference);
    perform public.refresh_credit_bill(bill.id);
  else
    remaining := abs(difference);
    for schedule in select * from public.installment_schedules
      where credit_account_id = account.id and status <> 'CANCELLED'
        and (principal_amount + fee_amount) >
          (paid_principal + paid_fee + credited_principal + credited_fee)
      order by due_date, installment_number for update
    loop
      exit when remaining <= 0;
      chunk := least(remaining, (schedule.principal_amount + schedule.fee_amount) -
        (schedule.paid_principal + schedule.paid_fee + schedule.credited_principal + schedule.credited_fee));
      fee_due := schedule.fee_amount - schedule.paid_fee - schedule.credited_fee;
      fee_credit := least(chunk, greatest(fee_due, 0)); principal_credit := chunk - fee_credit;
      update public.installment_schedules set credited_fee = credited_fee + fee_credit,
        credited_principal = credited_principal + principal_credit,
        updated_at = now(), version = version + 1 where id = schedule.id;
      perform public.refresh_credit_bill(schedule.billing_period_id);
      remaining := remaining - chunk;
    end loop;
  end if;
  result := jsonb_build_object('id', account.id, 'aggregateId', aggregate.id,
    'difference', difference::text, 'actualLiability', actual::text);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'RECONCILE_CREDIT_ACCOUNT', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, reason, after_value)
  values (account.household_id, actor, 'CREDIT_ACCOUNT', account.id, 'RECONCILE',
    btrim(payload->>'reason'), result);
  return result;
end;
$$;

create or replace function public.capture_sync_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare operation_name text := 'UPSERT'; row_data jsonb := to_jsonb(new);
begin
  if row_data ? 'active' and coalesce((row_data->>'active')::boolean, true) = false then
    operation_name := 'TOMBSTONE';
  elsif row_data ? 'deleted_at' and row_data->>'deleted_at' is not null then
    operation_name := 'TOMBSTONE';
  elsif row_data->>'status' in ('REVERSED', 'SKIPPED', 'INACTIVE', 'CANCELLED') then
    operation_name := 'TOMBSTONE';
  end if;
  insert into public.sync_changes(household_id, entity, entity_id, operation)
  values (new.household_id, tg_argv[0], new.id, operation_name);
  return new;
end;
$$;

create trigger sync_credit_accounts after insert or update on public.credit_accounts
  for each row execute function public.capture_sync_change('CREDIT_ACCOUNT');
create trigger sync_billing_periods after insert or update on public.billing_periods
  for each row execute function public.capture_sync_change('BILLING_PERIOD');
create trigger sync_credit_purchases after insert or update on public.credit_purchases
  for each row execute function public.capture_sync_change('CREDIT_PURCHASE');
create trigger sync_installments after insert or update on public.installment_schedules
  for each row execute function public.capture_sync_change('INSTALLMENT');
create trigger sync_credit_payments after insert or update on public.credit_payments
  for each row execute function public.capture_sync_change('CREDIT_PAYMENT');
create trigger sync_import_batches after insert or update on public.import_batches
  for each row execute function public.capture_sync_change('IMPORT_BATCH');
create trigger sync_attachments after insert or update on public.transaction_attachments
  for each row execute function public.capture_sync_change('ATTACHMENT');

create or replace function public.sync_changes(cursor_value bigint default 0, result_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare household uuid := public.my_active_household_id(); result jsonb; next_cursor bigint;
begin
  if household is null then raise exception 'FORBIDDEN'; end if;
  if cursor_value < 0 or result_limit not between 1 and 200 then raise exception 'VALIDATION_ERROR'; end if;
  with page as (
    select s.* from public.sync_changes s
    where s.household_id = household and s.sequence > cursor_value
    order by s.sequence limit result_limit
  ), visible_changes as (
    select s.* from page s where
      (s.entity <> 'TRANSACTION' or exists (
        select 1 from public.transaction_aggregates a where a.id = s.entity_id
          and (a.owner_id = auth.uid() or a.scope = 'HOUSEHOLD' or a.privacy = 'PRIVATE_SUMMARY')
          and not (a.owner_id <> auth.uid() and a.privacy = 'PRIVATE_FULL')
      ))
      and (s.entity <> 'BUDGET' or exists (
        select 1 from public.budgets b where b.id = s.entity_id and (b.owner_id is null or b.owner_id = auth.uid())
      ))
      and (s.entity <> 'RECURRING_OBLIGATION' or exists (
        select 1 from public.recurring_obligations o where o.id = s.entity_id
          and (o.scope = 'HOUSEHOLD' or o.owner_id = auth.uid())
      ))
      and (s.entity <> 'CREDIT_ACCOUNT' or public.can_view_credit_account(s.entity_id))
      and (s.entity <> 'BILLING_PERIOD' or exists (
        select 1 from public.billing_periods b where b.id = s.entity_id
          and public.can_view_credit_account(b.credit_account_id)
      ))
      and (s.entity <> 'CREDIT_PURCHASE' or exists (
        select 1 from public.credit_purchases p where p.id = s.entity_id
          and public.can_view_credit_account(p.credit_account_id)
      ))
      and (s.entity <> 'INSTALLMENT' or exists (
        select 1 from public.installment_schedules i where i.id = s.entity_id
          and public.can_view_credit_account(i.credit_account_id)
      ))
      and (s.entity <> 'CREDIT_PAYMENT' or exists (
        select 1 from public.credit_payments p where p.id = s.entity_id
          and public.can_view_credit_account(p.credit_account_id)
      ))
      and (s.entity <> 'IMPORT_BATCH' or exists (
        select 1 from public.import_batches b where b.id = s.entity_id and b.actor_id = auth.uid()
      ))
      and (s.entity <> 'ATTACHMENT' or exists (
        select 1 from public.transaction_attachments x
        join public.transaction_aggregates a on a.id = x.transaction_id
        where x.id = s.entity_id and (a.owner_id = auth.uid() or a.scope = 'HOUSEHOLD')
      ))
  ), cursor_data as (
    select coalesce(max(sequence), cursor_value) next_cursor from page
  )
  select coalesce((select jsonb_agg(jsonb_build_object(
      'sequence', sequence, 'entity', entity, 'entityId', entity_id,
      'operation', operation, 'changedAt', changed_at) order by sequence)
    from visible_changes), '[]'::jsonb), cursor_data.next_cursor
  into result, next_cursor from cursor_data;
  return jsonb_build_object('changes', result, 'nextCursor', next_cursor,
    'hasMore', exists(select 1 from public.sync_changes s
      where s.household_id = household and s.sequence > next_cursor),
    'serverTime', now());
end;
$$;

create or replace function public.export_my_data()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare household uuid := public.my_active_household_id(); result jsonb;
begin
  if household is null then raise exception 'FORBIDDEN'; end if;
  select jsonb_build_object(
    'schemaVersion', 3,
    'exportedAt', now(),
    'household', (select to_jsonb(h) - 'owner_id' from public.households h where h.id = household),
    'profile', (select to_jsonb(p) from public.profiles p where p.id = auth.uid()),
    'wallets', (select coalesce(jsonb_agg(to_jsonb(w)), '[]'::jsonb)
      from public.wallet_balances w where w.household_id = household
        and (w.wallet_type not in ('CREDIT_CARD', 'PAYLATER') or w.owner_id = auth.uid()
          or exists (select 1 from public.credit_accounts ca where ca.wallet_id = w.id and ca.scope = 'HOUSEHOLD'))),
    'categories', (select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) from public.categories c
      where c.household_id = household and (c.scope = 'HOUSEHOLD' or c.owner_id = auth.uid())),
    'transactions', (select coalesce(jsonb_agg(jsonb_build_object(
      'aggregate', to_jsonb(a) - 'description' || jsonb_build_object('description',
        case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then a.description else null end),
      'entries', (select jsonb_agg(to_jsonb(e) - 'wallet_id' || jsonb_build_object('wallet_id',
        case when w.wallet_type in ('CREDIT_CARD', 'PAYLATER') and w.owner_id <> auth.uid()
          then null else e.wallet_id end))
        from public.ledger_entries e join public.wallets w on w.id = e.wallet_id where e.aggregate_id = a.id)
    )), '[]'::jsonb) from public.transaction_aggregates a where a.household_id = household
      and (a.owner_id = auth.uid() or a.scope = 'HOUSEHOLD' or a.privacy = 'PRIVATE_SUMMARY')
      and not (a.owner_id <> auth.uid() and a.privacy = 'PRIVATE_FULL')),
    'periods', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.financial_periods p
      left join public.household_members m on m.id = p.member_id
      where p.household_id = household and (p.period_type = 'HOUSEHOLD' or m.user_id = auth.uid())),
    'budgets', (select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb) from public.budgets b
      where b.household_id = household and (b.scope = 'HOUSEHOLD' or b.owner_id = auth.uid())),
    'lockedFunds', (select coalesce(jsonb_agg(to_jsonb(f)), '[]'::jsonb) from public.locked_funds f
      join public.wallets w on w.id = f.wallet_id where f.household_id = household and (f.owner_id = auth.uid() or w.is_shared)),
    'recurringObligations', (select coalesce(jsonb_agg(to_jsonb(o)), '[]'::jsonb) from public.recurring_obligations o
      where o.household_id = household and (o.scope = 'HOUSEHOLD' or o.owner_id = auth.uid())),
    'creditAccounts', (select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb) from public.credit_accounts a
      where a.household_id = household and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid())),
    'billingPeriods', (select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb) from public.billing_periods b
      join public.credit_accounts a on a.id = b.credit_account_id
      where a.household_id = household and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid())),
    'creditPurchases', (select coalesce(jsonb_agg(to_jsonb(p) - 'description' || jsonb_build_object('description',
        case when p.owner_id = auth.uid() or p.scope = 'HOUSEHOLD' then p.description else null end)), '[]'::jsonb)
      from public.credit_purchases p join public.credit_accounts a on a.id = p.credit_account_id
      where p.household_id = household and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid())),
    'installments', (select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb) from public.installment_schedules s
      join public.credit_accounts a on a.id = s.credit_account_id
      where s.household_id = household and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid())),
    'creditPayments', (select coalesce(jsonb_agg(to_jsonb(p)), '[]'::jsonb) from public.credit_payments p
      join public.credit_accounts a on a.id = p.credit_account_id
      where p.household_id = household and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid())),
    'attachments', (select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) from public.transaction_attachments x
      join public.transaction_aggregates a on a.id = x.transaction_id
      where x.household_id = household and x.deleted_at is null
        and (a.owner_id = auth.uid() or a.scope = 'HOUSEHOLD')),
    'importBatches', (select coalesce(jsonb_agg(to_jsonb(b)), '[]'::jsonb) from public.import_batches b
      where b.household_id = household and b.actor_id = auth.uid())
  ) into result;
  return result;
end;
$$;

grant execute on function public.can_view_credit_account(uuid),
  public.can_access_receipt_object(text) to authenticated;
revoke all on function public.reconcile_credit_account(jsonb),
  public.sync_changes(bigint, integer), public.export_my_data() from public, anon;
grant execute on function public.reconcile_credit_account(jsonb),
  public.sync_changes(bigint, integer), public.export_my_data() to authenticated;
