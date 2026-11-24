create or replace function public.post_credit_purchase(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '', extensions as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id();
  account public.credit_accounts; wallet public.wallets; category public.categories;
  requested_scope public.transaction_scope; requested_privacy public.privacy_mode;
  principal numeric; fee numeric; tenor_count integer; original_date date; posted_date date;
  reference uuid; purchase_aggregate public.transaction_aggregates; fee_aggregate public.transaction_aggregates;
  purchase public.credit_purchases; bill public.billing_periods; financial_period public.financial_periods;
  fee_category uuid; installment_principal numeric; installment_fee numeric;
  principal_assigned numeric := 0; fee_assigned numeric := 0; bill_target date;
  result jsonb; stored_hash text; principal_outstanding numeric;
  incoming_hash text := encode(digest(payload::text, 'sha256'), 'hex');
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if household is null then raise exception 'FORBIDDEN'; end if;
  begin
    principal := (payload->>'principal')::numeric;
    fee := coalesce(nullif(payload->>'financingCost', '')::numeric, 0);
    tenor_count := coalesce(nullif(payload->>'tenor', '')::integer, 1);
    original_date := (payload->>'transactionDate')::date;
    requested_scope := (payload->>'scope')::public.transaction_scope;
    requested_privacy := (payload->>'privacyMode')::public.privacy_mode;
    reference := (payload->>'clientReferenceId')::uuid;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if principal <= 0 or fee < 0 or tenor_count not between 1 and 36
      or original_date > current_date then raise exception 'VALIDATION_ERROR'; end if;
  if requested_scope = 'HOUSEHOLD' and requested_privacy <> 'HOUSEHOLD_VISIBLE' then
    raise exception 'VALIDATION_ERROR: privacy';
  end if;
  select * into account from public.credit_accounts
    where id = (payload->>'accountId')::uuid and household_id = household for update;
  if account.id is null then raise exception 'NOT_FOUND: credit account'; end if;
  if account.status <> 'ACTIVE' then raise exception 'CREDIT_ACCOUNT_INACTIVE'; end if;
  if account.scope = 'PRIVATE' and account.primary_holder_id <> actor then raise exception 'FORBIDDEN'; end if;
  if account.scope = 'HOUSEHOLD' then
    requested_scope := 'HOUSEHOLD'; requested_privacy := 'HOUSEHOLD_VISIBLE';
  end if;
  select * into wallet from public.wallets where id = account.wallet_id and active for update;
  if wallet.id is null then raise exception 'CREDIT_ACCOUNT_INACTIVE'; end if;
  select * into category from public.categories
    where id = (payload->>'categoryId')::uuid and household_id = household and active
      and direction = 'EXPENSE'
      and (requested_scope = 'PRIVATE' or scope = 'HOUSEHOLD')
      and (scope = 'HOUSEHOLD' or owner_id = actor);
  if category.id is null then raise exception 'VALIDATION_ERROR: category'; end if;
  if requested_scope = 'HOUSEHOLD' and category.scope <> 'HOUSEHOLD' then
    raise exception 'VALIDATION_ERROR: category scope';
  end if;
  select payload_hash, response_json into stored_hash, result from public.idempotency_records
    where actor_id = actor and operation = 'POST_CREDIT_PURCHASE' and client_reference_id = reference;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;

  financial_period := public.ensure_financial_period(household, actor, requested_scope, original_date);
  posted_date := case when financial_period.status = 'LOCKED' then current_date else original_date end;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date,
    scope, privacy, description, client_reference_id, created_by)
  values (household, actor, 'EXPENSE', posted_date, requested_scope, requested_privacy,
    nullif(btrim(payload->>'description'), ''), reference, actor)
  returning * into purchase_aggregate;
  insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
  values (purchase_aggregate.id, account.wallet_id, category.id, 'DEBIT', principal);

  if fee > 0 then
    fee_category := public.credit_finance_category(household, actor, requested_scope);
    insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date,
      scope, privacy, description, client_reference_id, created_by)
    values (household, actor, 'EXPENSE', posted_date, requested_scope, requested_privacy,
      'Biaya kredit: ' || coalesce(nullif(btrim(payload->>'description'), ''), account.account_name),
      gen_random_uuid(), actor) returning * into fee_aggregate;
    insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
    values (fee_aggregate.id, account.wallet_id, fee_category, 'DEBIT', fee);
  end if;

  insert into public.credit_purchases(household_id, credit_account_id, purchase_aggregate_id,
    fee_aggregate_id, owner_id, category_id, source_type, original_transaction_date, posted_date,
    scope, privacy, description, principal_amount, financing_cost, tenor,
    client_reference_id, created_by)
  values (household, account.id, purchase_aggregate.id, fee_aggregate.id, actor, category.id,
    'PURCHASE', original_date, posted_date, requested_scope, requested_privacy,
    nullif(btrim(payload->>'description'), ''), principal, fee, tenor_count, reference, actor)
  returning * into purchase;

  select cycle_end into bill_target from public.credit_cycle_bounds(original_date, account.statement_day);
  if bill_target < current_date then bill_target := current_date; else bill_target := original_date; end if;
  for index_no in 1..tenor_count loop
    installment_principal := case when index_no = tenor_count then principal - principal_assigned
      else trunc(principal / tenor_count, 2) end;
    installment_fee := case when index_no = tenor_count then fee - fee_assigned
      else trunc(fee / tenor_count, 2) end;
    bill := public.ensure_credit_billing_period(account.id,
      (bill_target + make_interval(months => index_no - 1))::date);
    insert into public.installment_schedules(household_id, credit_account_id,
      billing_period_id, purchase_id, installment_number, due_date, scope,
      principal_amount, fee_amount)
    values (household, account.id, bill.id, purchase.id, index_no, bill.due_date,
      requested_scope, installment_principal, installment_fee);
    principal_assigned := principal_assigned + installment_principal;
    fee_assigned := fee_assigned + installment_fee;
    perform public.refresh_credit_bill(bill.id);
  end loop;

  select coalesce(sum(principal_amount - paid_principal - credited_principal), 0)
    into principal_outstanding from public.installment_schedules
    where credit_account_id = account.id and status <> 'CANCELLED';
  result := jsonb_build_object(
    'id', purchase.id, 'aggregateId', purchase_aggregate.id,
    'feeAggregateId', fee_aggregate.id, 'tenor', tenor_count,
    'postedDate', posted_date, 'originalDate', original_date,
    'latePosting', posted_date <> original_date,
    'overLimit', principal_outstanding > account.credit_limit,
    'remainingLimit', (account.credit_limit - principal_outstanding)::text
  );
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'POST_CREDIT_PURCHASE', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'CREDIT_PURCHASE', purchase.id, 'CREATE',
    jsonb_build_object('accountId', account.id, 'scope', requested_scope,
      'principal', principal, 'financingCost', fee, 'tenor', tenor_count));
  return result;
end;
$$;

create or replace function public.list_credit_bills(account_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.can_view_credit_account(account_id) then raise exception 'FORBIDDEN'; end if;
  perform public.refresh_credit_bill(id) from public.billing_periods where credit_account_id = account_id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id, 'periodStart', b.period_start, 'periodEnd', b.period_end,
    'dueDate', b.due_date, 'principalAmount', b.principal_amount::text,
    'feeAmount', b.fee_amount::text, 'totalAmount', (b.principal_amount + b.fee_amount)::text,
    'paidAmount', b.paid_amount::text,
    'outstanding', (b.private_outstanding + b.household_outstanding)::text,
    'privateOutstanding', b.private_outstanding::text,
    'householdOutstanding', b.household_outstanding::text,
    'status', b.status, 'issuedAt', b.issued_at, 'version', b.version
  ) order by b.period_end desc), '[]'::jsonb) into result
  from public.billing_periods b where b.credit_account_id = account_id;
  return result;
end;
$$;

create or replace function public.list_credit_installments(account_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.can_view_credit_account(account_id) then raise exception 'FORBIDDEN'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id, 'purchaseId', s.purchase_id, 'billingPeriodId', s.billing_period_id,
    'installmentNumber', s.installment_number, 'dueDate', s.due_date, 'scope', s.scope,
    'principalAmount', s.principal_amount::text, 'feeAmount', s.fee_amount::text,
    'paidAmount', (s.paid_principal + s.paid_fee)::text,
    'creditedAmount', (s.credited_principal + s.credited_fee)::text,
    'remaining', ((s.principal_amount + s.fee_amount) -
      (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee))::text,
    'status', s.status, 'description', p.description
  ) order by s.due_date, s.installment_number), '[]'::jsonb) into result
  from public.installment_schedules s join public.credit_purchases p on p.id = s.purchase_id
  where s.credit_account_id = account_id;
  return result;
end;
$$;

create or replace function public.pay_credit_bill(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '', extensions as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id();
  account public.credit_accounts; source_wallet public.wallets; aggregate public.transaction_aggregates;
  payment public.credit_payments; bill_row record; installment_row record;
  amount numeric; remaining numeric; outstanding numeric; bill_outstanding numeric; bill_payment numeric;
  household_due numeric; private_due numeric; household_payment numeric; private_payment numeric;
  scope_payment numeric; chunk numeric; fee_due numeric; fee_paid numeric; principal_paid numeric;
  allocation_scope public.transaction_scope; reference uuid; result jsonb; stored_hash text;
  incoming_hash text := encode(digest(payload::text, 'sha256'), 'hex');
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  begin amount := (payload->>'amount')::numeric; reference := (payload->>'clientReferenceId')::uuid;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if amount <= 0 then raise exception 'VALIDATION_ERROR'; end if;
  select * into account from public.credit_accounts
    where id = (payload->>'accountId')::uuid and household_id = household for update;
  if account.id is null then raise exception 'NOT_FOUND'; end if;
  if account.status <> 'ACTIVE' then raise exception 'CREDIT_ACCOUNT_INACTIVE'; end if;
  if account.scope = 'PRIVATE' and account.primary_holder_id <> actor then raise exception 'FORBIDDEN'; end if;
  select * into source_wallet from public.wallets
    where id = (payload->>'sourceWalletId')::uuid and household_id = household and active for update;
  if source_wallet.id is null or source_wallet.wallet_type in ('CREDIT_CARD', 'PAYLATER') then
    raise exception 'VALIDATION_ERROR: cash wallet';
  end if;
  if source_wallet.owner_id <> actor and not source_wallet.is_shared then raise exception 'FORBIDDEN'; end if;
  select coalesce(sum((principal_amount + fee_amount) -
    (paid_principal + paid_fee + credited_principal + credited_fee)), 0)
  into outstanding from public.installment_schedules
  where credit_account_id = account.id and status <> 'CANCELLED';
  if amount > outstanding then raise exception 'CREDIT_OVERPAYMENT'; end if;
  select payload_hash, response_json into stored_hash, result from public.idempotency_records
    where actor_id = actor and operation = 'PAY_CREDIT_BILL' and client_reference_id = reference;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date,
    scope, privacy, description, client_reference_id, created_by)
  values (household, actor, 'BILL_PAYMENT', (payload->>'paymentDate')::date,
    account.scope, case when account.scope = 'HOUSEHOLD' then 'HOUSEHOLD_VISIBLE'::public.privacy_mode
      else 'PRIVATE_FULL'::public.privacy_mode end,
    nullif(btrim(payload->>'description'), ''), reference, actor) returning * into aggregate;
  insert into public.ledger_entries(aggregate_id, wallet_id, direction, amount)
  values (aggregate.id, source_wallet.id, 'DEBIT', amount),
    (aggregate.id, account.wallet_id, 'CREDIT', amount);
  insert into public.credit_payments(household_id, credit_account_id, aggregate_id,
    source_wallet_id, paid_by, amount, payment_date, client_reference_id)
  values (household, account.id, aggregate.id, source_wallet.id, actor, amount,
    (payload->>'paymentDate')::date, reference) returning * into payment;

  remaining := amount;
  for bill_row in
    select b.id,
      coalesce(sum((s.principal_amount + s.fee_amount) -
        (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee)), 0) total_due,
      coalesce(sum((s.principal_amount + s.fee_amount) -
        (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee))
        filter (where s.scope = 'HOUSEHOLD'), 0) household_due,
      coalesce(sum((s.principal_amount + s.fee_amount) -
        (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee))
        filter (where s.scope = 'PRIVATE'), 0) private_due,
      b.due_date
    from public.billing_periods b join public.installment_schedules s on s.billing_period_id = b.id
    where b.credit_account_id = account.id and s.status <> 'CANCELLED'
    group by b.id, b.due_date
    having coalesce(sum((s.principal_amount + s.fee_amount) -
      (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee)), 0) > 0
    order by b.due_date, b.id
  loop
    exit when remaining <= 0;
    bill_outstanding := bill_row.total_due;
    bill_payment := least(remaining, bill_outstanding);
    household_due := bill_row.household_due; private_due := bill_row.private_due;
    if household_due > 0 and private_due > 0 then
      household_payment := least(household_due, round(bill_payment * household_due / bill_outstanding, 2));
      private_payment := bill_payment - household_payment;
      if private_payment > private_due then
        private_payment := private_due; household_payment := bill_payment - private_payment;
      end if;
    elsif household_due > 0 then household_payment := bill_payment; private_payment := 0;
    else household_payment := 0; private_payment := bill_payment; end if;

    foreach allocation_scope in array array['HOUSEHOLD'::public.transaction_scope, 'PRIVATE'::public.transaction_scope]
    loop
      scope_payment := case when allocation_scope = 'HOUSEHOLD' then household_payment else private_payment end;
      for installment_row in
        select * from public.installment_schedules
        where billing_period_id = bill_row.id and scope = allocation_scope and status <> 'CANCELLED'
          and (principal_amount + fee_amount) >
            (paid_principal + paid_fee + credited_principal + credited_fee)
        order by due_date, installment_number, id for update
      loop
        exit when scope_payment <= 0;
        chunk := least(scope_payment,
          (installment_row.principal_amount + installment_row.fee_amount) -
          (installment_row.paid_principal + installment_row.paid_fee +
            installment_row.credited_principal + installment_row.credited_fee));
        fee_due := installment_row.fee_amount - installment_row.paid_fee - installment_row.credited_fee;
        fee_paid := least(chunk, greatest(fee_due, 0));
        principal_paid := chunk - fee_paid;
        update public.installment_schedules set paid_fee = paid_fee + fee_paid,
          paid_principal = paid_principal + principal_paid, updated_at = now(), version = version + 1
        where id = installment_row.id;
        insert into public.credit_payment_allocations(payment_id, billing_period_id,
          installment_id, scope, principal_amount, fee_amount)
        values (payment.id, bill_row.id, installment_row.id, allocation_scope, principal_paid, fee_paid);
        scope_payment := scope_payment - chunk;
      end loop;
    end loop;
    remaining := remaining - bill_payment;
    perform public.refresh_credit_bill(bill_row.id);
  end loop;

  result := jsonb_build_object('id', payment.id, 'aggregateId', aggregate.id,
    'amount', amount::text, 'remainingOutstanding', (outstanding - amount)::text);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'PAY_CREDIT_BILL', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'CREDIT_PAYMENT', payment.id, 'CREATE',
    jsonb_build_object('accountId', account.id, 'sourceWalletId', source_wallet.id, 'amount', amount));
  return result;
end;
$$;

create or replace function public.refund_credit_purchase(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '', extensions as $$
declare actor uuid := auth.uid(); purchase public.credit_purchases; account public.credit_accounts;
  aggregate public.transaction_aggregates; schedule record;
  amount numeric; remaining numeric; chunk numeric; fee_due numeric; fee_credit numeric; principal_credit numeric;
  reference uuid; result jsonb; stored_hash text;
  incoming_hash text := encode(digest(payload::text, 'sha256'), 'hex');
begin
  begin amount := (payload->>'amount')::numeric; reference := (payload->>'clientReferenceId')::uuid;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if amount <= 0 then raise exception 'VALIDATION_ERROR'; end if;
  select * into purchase from public.credit_purchases
    where id = (payload->>'purchaseId')::uuid and household_id = public.my_active_household_id() for update;
  if purchase.id is null or purchase.source_type <> 'PURCHASE' then raise exception 'NOT_FOUND'; end if;
  select * into account from public.credit_accounts where id = purchase.credit_account_id;
  if account.scope = 'PRIVATE' and account.primary_holder_id <> actor then raise exception 'FORBIDDEN'; end if;
  if amount > purchase.principal_amount + purchase.financing_cost - purchase.refunded_amount then
    raise exception 'VALIDATION_ERROR: refund amount';
  end if;
  select payload_hash, response_json into stored_hash, result from public.idempotency_records
    where actor_id = actor and operation = 'REFUND_CREDIT_PURCHASE' and client_reference_id = reference;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date,
    scope, privacy, description, reversal_of_id, client_reference_id, created_by)
  values (purchase.household_id, actor, 'REVERSAL', (payload->>'refundDate')::date,
    purchase.scope, purchase.privacy, nullif(btrim(payload->>'reason'), ''),
    purchase.purchase_aggregate_id, reference, actor) returning * into aggregate;
  insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
  values (aggregate.id, account.wallet_id, purchase.category_id, 'CREDIT', amount);
  remaining := amount;
  for schedule in select * from public.installment_schedules
    where purchase_id = purchase.id and status <> 'CANCELLED'
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
  update public.credit_purchases set refunded_amount = refunded_amount + amount,
    status = case when refunded_amount + amount >= principal_amount + financing_cost
      then 'REFUNDED'::public.credit_purchase_status
      else 'PARTIALLY_REFUNDED'::public.credit_purchase_status end,
    updated_at = now(), version = version + 1 where id = purchase.id returning * into purchase;
  result := jsonb_build_object('id', purchase.id, 'refundAggregateId', aggregate.id,
    'refundedAmount', purchase.refunded_amount::text, 'status', purchase.status);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'REFUND_CREDIT_PURCHASE', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, reason, after_value)
  values (purchase.household_id, actor, 'CREDIT_PURCHASE', purchase.id, 'REFUND',
    nullif(btrim(payload->>'reason'), ''), result);
  return result;
end;
$$;

create or replace function public.list_credit_payments(account_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if not public.can_view_credit_account(account_id) then raise exception 'FORBIDDEN'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'sourceWalletId', p.source_wallet_id, 'sourceWallet', w.name,
    'paidBy', p.paid_by, 'amount', p.amount::text, 'paymentDate', p.payment_date,
    'createdAt', p.created_at
  ) order by p.payment_date desc, p.created_at desc), '[]'::jsonb) into result
  from public.credit_payments p join public.wallets w on w.id = p.source_wallet_id
  where p.credit_account_id = account_id;
  return result;
end;
$$;

create or replace function public.credit_forecast()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare household uuid := public.my_active_household_id(); personal_period public.financial_periods;
  household_period public.financial_periods; personal_due numeric; household_due numeric;
begin
  if household is null then raise exception 'FORBIDDEN'; end if;
  personal_period := public.ensure_financial_period(household, auth.uid(), 'PRIVATE', current_date);
  household_period := public.ensure_financial_period(household, auth.uid(), 'HOUSEHOLD', current_date);
  select coalesce(sum((s.principal_amount + s.fee_amount) -
    (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee)), 0)
  into personal_due from public.installment_schedules s
  join public.credit_accounts a on a.id = s.credit_account_id
  where a.household_id = household and a.scope = 'PRIVATE' and a.primary_holder_id = auth.uid()
    and s.due_date between current_date and personal_period.end_date and s.status <> 'CANCELLED';
  select coalesce(sum((s.principal_amount + s.fee_amount) -
    (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee)), 0)
  into household_due from public.installment_schedules s
  join public.credit_accounts a on a.id = s.credit_account_id
  where a.household_id = household and s.scope = 'HOUSEHOLD'
    and s.due_date between current_date and household_period.end_date and s.status <> 'CANCELLED';
  return jsonb_build_object('personalPeriodEnd', personal_period.end_date,
    'householdPeriodEnd', household_period.end_date,
    'personalDue', personal_due::text, 'householdReserve', household_due::text);
end;
$$;

create or replace function public.credit_dashboard()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  select jsonb_build_object(
    'accounts', public.list_credit_accounts(),
    'forecast', public.credit_forecast(),
    'nearestDue', (
      select min(s.due_date) from public.installment_schedules s
      join public.credit_accounts a on a.id = s.credit_account_id
      where a.household_id = public.my_active_household_id()
        and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid())
        and s.status not in ('PAID', 'CANCELLED')
    )
  ) into result;
  return result;
end;
$$;

revoke all on function public.post_credit_purchase(jsonb), public.list_credit_bills(uuid),
  public.list_credit_installments(uuid), public.pay_credit_bill(jsonb),
  public.refund_credit_purchase(jsonb), public.list_credit_payments(uuid),
  public.credit_forecast(), public.credit_dashboard() from public, anon;
grant execute on function public.post_credit_purchase(jsonb), public.list_credit_bills(uuid),
  public.list_credit_installments(uuid), public.pay_credit_bill(jsonb),
  public.refund_credit_purchase(jsonb), public.list_credit_payments(uuid),
  public.credit_forecast(), public.credit_dashboard() to authenticated;
