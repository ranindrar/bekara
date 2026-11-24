drop policy if exists wallets_member_read on public.wallets;
create policy wallets_member_read on public.wallets for select using (
  public.is_active_household_member(household_id)
  and (
    wallet_type not in ('CREDIT_CARD', 'PAYLATER')
    or owner_id = auth.uid()
    or exists (select 1 from public.credit_accounts a where a.wallet_id = wallets.id and a.scope = 'HOUSEHOLD')
  )
);

create or replace function public.create_wallet(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id(); created public.wallets;
  requested_type public.wallet_type;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if household is null then raise exception 'FORBIDDEN'; end if;
  begin requested_type := (payload->>'walletType')::public.wallet_type;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if requested_type in ('CREDIT_CARD', 'PAYLATER') then raise exception 'CREDIT_ACCOUNT_REQUIRED'; end if;
  if char_length(btrim(payload->>'name')) not between 1 and 80 then raise exception 'VALIDATION_ERROR: wallet name'; end if;
  insert into public.wallets(household_id, owner_id, name, wallet_type, opening_balance,
    is_shared, accepts_household_transfer, created_by)
  values (household, actor, btrim(payload->>'name'), requested_type,
    coalesce((payload->>'openingBalance')::numeric, 0), coalesce((payload->>'isShared')::boolean, false),
    coalesce((payload->>'acceptsHouseholdTransfer')::boolean, false), actor)
  returning * into created;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'WALLET', created.id, 'CREATE', to_jsonb(created));
  return jsonb_build_object('id', created.id, 'name', created.name, 'version', created.version);
end;
$$;

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
  if wallet.wallet_type in ('CREDIT_CARD', 'PAYLATER') then raise exception 'CREDIT_ACCOUNT_REQUIRED'; end if;
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

create or replace function public.list_wallets()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', w.id, 'name', w.name, 'walletType', w.wallet_type,
    'balance', w.balance::text, 'lockedAmount', coalesce(f.locked, 0)::text,
    'availableBalance', (w.balance - coalesce(f.locked, 0))::text,
    'isShared', w.is_shared, 'acceptsHouseholdTransfer', w.accepts_household_transfer,
    'active', w.active, 'ownerId', w.owner_id, 'version', w.version
  ) order by w.active desc, w.name), '[]'::jsonb)
  from public.wallet_balances w
  left join lateral (select sum(amount) locked from public.locked_funds where wallet_id = w.id and active) f on true
  where w.household_id = public.my_active_household_id()
    and w.wallet_type not in ('CREDIT_CARD', 'PAYLATER');
$$;

create or replace function public.list_transactions(result_limit integer default 50)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_data order by transaction_date desc, id desc), '[]'::jsonb)
  from (
    select a.id, a.transaction_date, a.kind::text, a.scope::text, a.status::text,
      case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then a.description else null end description,
      e.amount::text amount,
      case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then e.direction::text else null end direction,
      case
        when w.wallet_type in ('CREDIT_CARD', 'PAYLATER') and w.owner_id <> auth.uid() then 'Kredit pribadi'
        when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then w.name else null end wallet_name,
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
      and (a.kind <> 'BILL_PAYMENT' or e.direction = 'DEBIT')
    order by a.transaction_date desc, a.id desc limit least(greatest(result_limit, 1), 200)
  ) row_data;
$$;

create or replace function public.dashboard_summary()
returns jsonb language sql stable security definer set search_path = '' as $$
  with balances as (
    select coalesce(sum(balance), 0) total from public.wallet_balances
    where household_id = public.my_active_household_id() and active
      and wallet_type not in ('CREDIT_CARD', 'PAYLATER')
  ), flow as (
    select
      coalesce(sum(case when a.kind = 'INCOME' and e.direction = 'CREDIT' then e.amount
        when a.kind = 'REVERSAL' and e.direction = 'DEBIT' and c.direction = 'INCOME' then -e.amount else 0 end), 0) income,
      coalesce(sum(case when a.kind = 'EXPENSE' and e.direction = 'DEBIT' then e.amount
        when a.kind = 'REVERSAL' and e.direction = 'CREDIT' and c.direction = 'EXPENSE' then -e.amount else 0 end), 0) expense
    from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
    left join public.categories c on c.id = e.category_id
    where a.household_id = public.my_active_household_id() and a.scope = 'HOUSEHOLD'
      and date_trunc('month', a.transaction_date) = date_trunc('month', current_date)
  ) select jsonb_build_object('totalBalance', balances.total::text,
    'monthlyIncome', greatest(flow.income, 0)::text,
    'monthlyExpense', greatest(flow.expense, 0)::text)
  from balances cross join flow;
$$;

create or replace function public.report_category()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('category', name, 'amount', amount::text)
    order by amount desc) filter (where amount <> 0), '[]'::jsonb)
  from (
    select coalesce(c.name, 'Tanpa kategori') name,
      sum(case when a.kind = 'EXPENSE' and e.direction = 'DEBIT' then e.amount
        when a.kind = 'REVERSAL' and e.direction = 'CREDIT' then -e.amount else 0 end) amount
    from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
    left join public.categories c on c.id = e.category_id
    where a.household_id = public.my_active_household_id() and a.scope = 'HOUSEHOLD'
      and a.kind in ('EXPENSE', 'REVERSAL')
      and date_trunc('month', a.transaction_date) = date_trunc('month', current_date)
    group by c.name
  ) data;
$$;

create or replace function public.period_financial_summary(target_period public.financial_periods)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'income', greatest(coalesce(sum(case when a.kind = 'INCOME' and e.direction = 'CREDIT' then e.amount
      when a.kind = 'REVERSAL' and e.direction = 'DEBIT' and c.direction = 'INCOME' then -e.amount else 0 end), 0), 0)::text,
    'expense', greatest(coalesce(sum(case when a.kind = 'EXPENSE' and e.direction = 'DEBIT' then e.amount
      when a.kind = 'REVERSAL' and e.direction = 'CREDIT' and c.direction = 'EXPENSE' then -e.amount else 0 end), 0), 0)::text,
    'transactionCount', count(distinct a.id) filter (where a.kind in ('INCOME', 'EXPENSE'))
  )
  from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
  left join public.categories c on c.id = e.category_id
  where a.household_id = target_period.household_id
    and a.transaction_date between target_period.start_date and target_period.end_date
    and (
      (target_period.period_type = 'HOUSEHOLD' and a.scope = 'HOUSEHOLD')
      or (target_period.period_type = 'PERSONAL' and a.scope = 'PRIVATE' and a.owner_id = (
        select m.user_id from public.household_members m where m.id = target_period.member_id
      ))
    );
$$;

create or replace function public.list_budgets(period_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id, 'periodId', b.period_id, 'categoryId', b.category_id,
    'category', c.name, 'scope', b.scope, 'amount', b.amount::text,
    'spent', greatest(coalesce(spending.spent, 0), 0)::text,
    'remaining', greatest(b.amount - greatest(coalesce(spending.spent, 0), 0), 0)::text,
    'percentage', case when b.amount = 0 then 0 else round(greatest(coalesce(spending.spent, 0), 0) * 100 / b.amount, 1) end,
    'status', public.budget_health(greatest(coalesce(spending.spent, 0), 0), b.amount),
    'projected', case when current_date between p.start_date and p.end_date then
      round(greatest(coalesce(spending.spent, 0), 0) * (p.end_date - p.start_date + 1)::numeric /
        greatest(current_date - p.start_date + 1, 1), 2) else greatest(coalesce(spending.spent, 0), 0) end,
    'version', b.version
  ) order by c.name), '[]'::jsonb)
  from public.budgets b join public.financial_periods p on p.id = b.period_id
  join public.categories c on c.id = b.category_id
  left join lateral (
    select sum(case when a.kind = 'EXPENSE' and e.direction = 'DEBIT' then e.amount
      when a.kind = 'REVERSAL' and e.direction = 'CREDIT' then -e.amount else 0 end) spent
    from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
    where a.household_id = b.household_id and a.kind in ('EXPENSE', 'REVERSAL')
      and e.category_id = b.category_id and a.transaction_date between p.start_date and p.end_date
      and a.scope = b.scope and (b.owner_id is null or a.owner_id = b.owner_id)
  ) spending on true
  where b.period_id = list_budgets.period_id and b.active
    and b.household_id = public.my_active_household_id()
    and (b.scope = 'HOUSEHOLD' or b.owner_id = auth.uid());
$$;

create or replace function public.forecast_summary()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare household uuid := public.my_active_household_id(); current_period public.financial_periods;
  cash_balance numeric; locked numeric; routine numeric; available numeric; daily numeric;
  days_remaining integer; health text; budget_need numeric; obligation_need numeric; credit_need numeric;
begin
  current_period := public.ensure_financial_period(household, auth.uid(), 'HOUSEHOLD', current_date);
  perform public.generate_obligation_occurrences(greatest(current_period.end_date - current_date, 1));
  select coalesce(sum(balance), 0) into cash_balance from public.wallet_balances
    where household_id = household and active and wallet_type in ('BANK_ACCOUNT', 'CASH', 'E_WALLET', 'SAVING', 'OTHER');
  select coalesce(sum(f.amount), 0) into locked from public.locked_funds f
    join public.wallets w on w.id = f.wallet_id
    where f.household_id = household and f.active and w.active
      and w.wallet_type in ('BANK_ACCOUNT', 'CASH', 'E_WALLET', 'SAVING', 'OTHER');
  select coalesce(sum(greatest((b.amount - greatest(coalesce(spent.amount, 0), 0)), 0)), 0) into budget_need
  from public.budgets b join public.categories c on c.id = b.category_id
  left join lateral (
    select sum(case when a.kind = 'EXPENSE' and e.direction = 'DEBIT' then e.amount
      when a.kind = 'REVERSAL' and e.direction = 'CREDIT' then -e.amount else 0 end) amount
    from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
    where a.kind in ('EXPENSE', 'REVERSAL') and e.category_id = b.category_id
      and a.transaction_date between current_period.start_date and current_period.end_date and a.scope = b.scope
  ) spent on true
  where b.period_id = current_period.id and b.active and c.necessity_type = 'REQUIRED';
  select coalesce(sum(x.estimated_amount), 0) into obligation_need
  from public.obligation_occurrences x join public.recurring_obligations o on o.id = x.obligation_id
  where x.household_id = household and x.status = 'PENDING'
    and x.due_date between current_date and current_period.end_date
    and not exists (select 1 from public.budgets b where b.period_id = current_period.id
      and b.category_id = o.category_id and b.active);
  credit_need := coalesce((public.credit_forecast()->>'householdReserve')::numeric, 0);
  routine := budget_need + obligation_need + credit_need;
  available := cash_balance - locked - routine;
  days_remaining := greatest(current_period.end_date - current_date + 1, 1);
  daily := greatest(available, 0) / days_remaining;
  health := case when available < 0 then 'DEFICIT_RISK'
    when cash_balance > 0 and available < cash_balance * 0.20 then 'CONTROL_NEEDED' else 'SAFE' end;
  return jsonb_build_object('periodId', current_period.id, 'periodEnd', current_period.end_date,
    'cashBalance', cash_balance::text, 'lockedFunds', locked::text,
    'routineNeeds', routine::text, 'requiredBudgetRemaining', budget_need::text,
    'unbudgetedObligations', obligation_need::text, 'creditHouseholdReserve', credit_need::text,
    'availableCash', available::text, 'remainingDays', days_remaining,
    'safeDailyLimit', daily::text, 'health', health);
end;
$$;

revoke all on function public.create_wallet(jsonb), public.post_transaction(jsonb),
  public.list_wallets(), public.list_transactions(integer), public.dashboard_summary(),
  public.report_category(), public.list_budgets(uuid), public.forecast_summary() from public, anon;
grant execute on function public.create_wallet(jsonb), public.post_transaction(jsonb),
  public.list_wallets(), public.list_transactions(integer), public.dashboard_summary(),
  public.report_category(), public.list_budgets(uuid), public.forecast_summary() to authenticated;
