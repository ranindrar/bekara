create type public.recurrence_frequency as enum ('WEEKLY', 'MONTHLY');
create type public.obligation_occurrence_status as enum ('PENDING', 'PAID', 'SKIPPED', 'RESCHEDULED');

alter table public.transaction_aggregates
  add column correction_of_id uuid references public.transaction_aggregates(id);

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  owner_id uuid references public.profiles(id),
  period_id uuid not null references public.financial_periods(id),
  category_id uuid not null references public.categories(id),
  scope public.transaction_scope not null,
  amount numeric(19,2) not null check (amount > 0),
  active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  check ((scope = 'HOUSEHOLD' and owner_id is null) or (scope = 'PRIVATE' and owner_id is not null))
);

create unique index one_active_budget_per_target
  on public.budgets(period_id, category_id, scope, coalesce(owner_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where active;

create table public.locked_funds (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  wallet_id uuid not null references public.wallets(id),
  owner_id uuid not null references public.profiles(id),
  label text not null check (char_length(label) between 2 and 100),
  amount numeric(19,2) not null check (amount > 0),
  active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);

create index locked_funds_wallet_active_idx on public.locked_funds(wallet_id) where active;

create table public.recurring_obligations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  owner_id uuid not null references public.profiles(id),
  name text not null check (char_length(name) between 2 and 100),
  wallet_id uuid not null references public.wallets(id),
  category_id uuid not null references public.categories(id),
  scope public.transaction_scope not null,
  privacy public.privacy_mode not null,
  frequency public.recurrence_frequency not null,
  day_of_month smallint check (day_of_month between 1 and 31),
  day_of_week smallint check (day_of_week between 1 and 7),
  estimated_amount numeric(19,2) not null check (estimated_amount > 0),
  next_due_date date not null,
  active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  check ((frequency = 'MONTHLY' and day_of_month is not null and day_of_week is null)
    or (frequency = 'WEEKLY' and day_of_week is not null and day_of_month is null)),
  check ((scope = 'HOUSEHOLD' and privacy = 'HOUSEHOLD_VISIBLE') or scope = 'PRIVATE')
);

create table public.obligation_occurrences (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  obligation_id uuid not null references public.recurring_obligations(id),
  due_date date not null,
  estimated_amount numeric(19,2) not null check (estimated_amount > 0),
  actual_amount numeric(19,2) check (actual_amount > 0),
  status public.obligation_occurrence_status not null default 'PENDING',
  transaction_id uuid references public.transaction_aggregates(id),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  unique (obligation_id, due_date)
);

create index obligation_occurrences_due_idx
  on public.obligation_occurrences(household_id, status, due_date);

alter table public.budgets enable row level security;
alter table public.locked_funds enable row level security;
alter table public.recurring_obligations enable row level security;
alter table public.obligation_occurrences enable row level security;

create policy budgets_visible_read on public.budgets for select using (
  public.is_active_household_member(household_id) and (scope = 'HOUSEHOLD' or owner_id = auth.uid())
);
create policy locked_funds_visible_read on public.locked_funds for select using (
  public.is_active_household_member(household_id)
  and (owner_id = auth.uid() or exists (
    select 1 from public.wallets w where w.id = locked_funds.wallet_id and w.is_shared
  ))
);
create policy recurring_visible_read on public.recurring_obligations for select using (
  public.is_active_household_member(household_id) and (scope = 'HOUSEHOLD' or owner_id = auth.uid())
);
create policy occurrences_visible_read on public.obligation_occurrences for select using (
  exists (select 1 from public.recurring_obligations o where o.id = obligation_id
    and public.is_active_household_member(o.household_id) and (o.scope = 'HOUSEHOLD' or o.owner_id = auth.uid()))
);

revoke insert, update, delete on public.budgets, public.locked_funds,
  public.recurring_obligations, public.obligation_occurrences from anon, authenticated;

create or replace function public.budget_health(spent numeric, planned numeric)
returns text language sql immutable set search_path = '' as $$
  select case
    when spent > planned then 'EXCEEDED'
    when spent >= planned * 0.90 then 'CRITICAL'
    when spent >= planned * 0.75 then 'WARNING'
    else 'SAFE'
  end;
$$;

create or replace function public.upsert_budget(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid(); household uuid := public.my_active_household_id();
  selected_period public.financial_periods; selected_category public.categories;
  selected public.budgets; requested_scope public.transaction_scope;
  requested_amount numeric; requested_id uuid; expected integer;
begin
  requested_scope := (payload->>'scope')::public.transaction_scope;
  requested_amount := (payload->>'amount')::numeric;
  requested_id := nullif(payload->>'id', '')::uuid;
  expected := nullif(payload->>'expectedVersion', '')::integer;
  if requested_amount <= 0 then raise exception 'VALIDATION_ERROR: amount'; end if;
  select * into selected_period from public.financial_periods
    where id = (payload->>'periodId')::uuid and household_id = household;
  if selected_period.id is null or selected_period.status = 'LOCKED' then raise exception 'PERIOD_LOCKED'; end if;
  select * into selected_category from public.categories
    where id = (payload->>'categoryId')::uuid and household_id = household and active;
  if selected_category.id is null or selected_category.direction <> 'EXPENSE' then raise exception 'VALIDATION_ERROR: category'; end if;
  if requested_scope = 'PRIVATE' and selected_period.period_type <> 'PERSONAL' then raise exception 'VALIDATION_ERROR: period scope'; end if;
  if requested_scope = 'HOUSEHOLD' and selected_period.period_type <> 'HOUSEHOLD' then raise exception 'VALIDATION_ERROR: period scope'; end if;
  if requested_id is null then
    insert into public.budgets(household_id, owner_id, period_id, category_id, scope, amount, created_by)
    values (household, case when requested_scope = 'PRIVATE' then actor else null end,
      selected_period.id, selected_category.id, requested_scope, requested_amount, actor)
    returning * into selected;
  else
    select * into selected from public.budgets where id = requested_id and household_id = household for update;
    if selected.id is null then raise exception 'NOT_FOUND'; end if;
    if selected.scope = 'PRIVATE' and selected.owner_id <> actor then raise exception 'FORBIDDEN'; end if;
    if selected.version <> expected then raise exception 'VERSION_CONFLICT'; end if;
    update public.budgets set amount = requested_amount, updated_at = now(), version = version + 1
      where id = selected.id returning * into selected;
  end if;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'BUDGET', selected.id, case when requested_id is null then 'CREATE' else 'UPDATE' end, to_jsonb(selected));
  return jsonb_build_object('id', selected.id, 'version', selected.version);
end;
$$;

create or replace function public.list_budgets(period_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', b.id, 'periodId', b.period_id, 'categoryId', b.category_id,
    'category', c.name, 'scope', b.scope, 'amount', b.amount::text,
    'spent', coalesce(spending.spent, 0)::text,
    'remaining', greatest(b.amount - coalesce(spending.spent, 0), 0)::text,
    'percentage', case when b.amount = 0 then 0 else round(coalesce(spending.spent, 0) * 100 / b.amount, 1) end,
    'status', public.budget_health(coalesce(spending.spent, 0), b.amount),
    'projected', case when current_date between p.start_date and p.end_date then
      round(coalesce(spending.spent, 0) * (p.end_date - p.start_date + 1)::numeric /
        greatest(current_date - p.start_date + 1, 1), 2) else coalesce(spending.spent, 0) end,
    'version', b.version
  ) order by c.name), '[]'::jsonb)
  from public.budgets b
  join public.financial_periods p on p.id = b.period_id
  join public.categories c on c.id = b.category_id
  left join lateral (
    select sum(e.amount) spent from public.transaction_aggregates a
    join public.ledger_entries e on e.aggregate_id = a.id
    where a.household_id = b.household_id and a.kind in ('EXPENSE', 'BILL_PAYMENT')
      and a.status = 'POSTED' and e.category_id = b.category_id
      and a.transaction_date between p.start_date and p.end_date
      and a.scope = b.scope and (b.owner_id is null or a.owner_id = b.owner_id)
  ) spending on true
  where b.period_id = list_budgets.period_id and b.active
    and b.household_id = public.my_active_household_id()
    and (b.scope = 'HOUSEHOLD' or b.owner_id = auth.uid());
$$;

create or replace function public.upsert_locked_fund(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid(); household uuid := public.my_active_household_id();
  selected_wallet public.wallets; selected public.locked_funds; requested_id uuid;
  requested_amount numeric := (payload->>'amount')::numeric; expected integer;
  balance numeric; other_locked numeric;
begin
  requested_id := nullif(payload->>'id', '')::uuid;
  expected := nullif(payload->>'expectedVersion', '')::integer;
  select * into selected_wallet from public.wallets
    where id = (payload->>'walletId')::uuid and household_id = household and active;
  if selected_wallet.id is null then raise exception 'NOT_FOUND: wallet'; end if;
  if selected_wallet.owner_id <> actor and not selected_wallet.is_shared then raise exception 'FORBIDDEN'; end if;
  if requested_amount <= 0 or char_length(btrim(payload->>'label')) < 2 then raise exception 'VALIDATION_ERROR'; end if;
  select w.balance into balance from public.wallet_balances w where w.id = selected_wallet.id;
  select coalesce(sum(amount), 0) into other_locked from public.locked_funds
    where wallet_id = selected_wallet.id and active and id is distinct from requested_id;
  if requested_amount + other_locked > greatest(balance, 0) then raise exception 'VALIDATION_ERROR: locked amount exceeds balance'; end if;
  if requested_id is null then
    insert into public.locked_funds(household_id, wallet_id, owner_id, label, amount, created_by)
    values (household, selected_wallet.id, actor, btrim(payload->>'label'), requested_amount, actor)
    returning * into selected;
  else
    select * into selected from public.locked_funds where id = requested_id and household_id = household for update;
    if selected.id is null then raise exception 'NOT_FOUND'; end if;
    if selected.owner_id <> actor then raise exception 'FORBIDDEN'; end if;
    if selected.version <> expected then raise exception 'VERSION_CONFLICT'; end if;
    update public.locked_funds set label = btrim(payload->>'label'), amount = requested_amount,
      updated_at = now(), version = version + 1 where id = selected.id returning * into selected;
  end if;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'LOCKED_FUND', selected.id, case when requested_id is null then 'CREATE' else 'UPDATE' end, to_jsonb(selected));
  return jsonb_build_object('id', selected.id, 'version', selected.version);
end;
$$;

create or replace function public.release_locked_fund(fund_id uuid, expected_version integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare selected public.locked_funds;
begin
  select * into selected from public.locked_funds where id = fund_id and household_id = public.my_active_household_id() for update;
  if selected.id is null then raise exception 'NOT_FOUND'; end if;
  if selected.owner_id <> auth.uid() then raise exception 'FORBIDDEN'; end if;
  if selected.version <> expected_version then raise exception 'VERSION_CONFLICT'; end if;
  update public.locked_funds set active = false, updated_at = now(), version = version + 1 where id = selected.id;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, before_value)
  values (selected.household_id, auth.uid(), 'LOCKED_FUND', selected.id, 'RELEASE', to_jsonb(selected));
  return jsonb_build_object('id', selected.id, 'active', false, 'version', selected.version + 1);
end;
$$;

create or replace function public.list_locked_funds()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', f.id, 'walletId', f.wallet_id, 'wallet', w.name, 'label', f.label,
    'amount', f.amount::text, 'ownerId', f.owner_id, 'version', f.version
  ) order by w.name, f.label), '[]'::jsonb)
  from public.locked_funds f join public.wallets w on w.id = f.wallet_id
  where f.household_id = public.my_active_household_id() and f.active
    and (f.owner_id = auth.uid() or w.is_shared);
$$;

create or replace function public.next_recurrence_date(
  from_date date, frequency public.recurrence_frequency, requested_day integer
)
returns date language sql immutable set search_path = '' as $$
  select case when frequency = 'WEEKLY' then from_date + 7
    else public.clamped_month_date((from_date + interval '1 month')::date, requested_day) end;
$$;

create or replace function public.upsert_recurring_obligation(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid(); household uuid := public.my_active_household_id(); selected public.recurring_obligations;
  requested_id uuid := nullif(payload->>'id', '')::uuid; expected integer := nullif(payload->>'expectedVersion', '')::integer;
  requested_scope public.transaction_scope := (payload->>'scope')::public.transaction_scope;
  requested_frequency public.recurrence_frequency := (payload->>'frequency')::public.recurrence_frequency;
  due date := (payload->>'nextDueDate')::date; requested_day integer;
begin
  if char_length(btrim(payload->>'name')) < 2 or (payload->>'estimatedAmount')::numeric <= 0 then raise exception 'VALIDATION_ERROR'; end if;
  if not exists (select 1 from public.wallets where id = (payload->>'walletId')::uuid and household_id = household and active) then raise exception 'NOT_FOUND: wallet'; end if;
  if not exists (select 1 from public.categories where id = (payload->>'categoryId')::uuid and household_id = household and direction = 'EXPENSE' and active) then raise exception 'NOT_FOUND: category'; end if;
  requested_day := case when requested_frequency = 'MONTHLY' then extract(day from due)::integer else extract(isodow from due)::integer end;
  if requested_id is null then
    insert into public.recurring_obligations(household_id, owner_id, name, wallet_id, category_id,
      scope, privacy, frequency, day_of_month, day_of_week, estimated_amount, next_due_date, created_by)
    values (household, actor, btrim(payload->>'name'), (payload->>'walletId')::uuid, (payload->>'categoryId')::uuid,
      requested_scope, case when requested_scope = 'HOUSEHOLD' then 'HOUSEHOLD_VISIBLE' else coalesce(nullif(payload->>'privacyMode', '')::public.privacy_mode, 'PRIVATE_FULL') end,
      requested_frequency, case when requested_frequency = 'MONTHLY' then requested_day end,
      case when requested_frequency = 'WEEKLY' then requested_day end,
      (payload->>'estimatedAmount')::numeric, due, actor) returning * into selected;
  else
    select * into selected from public.recurring_obligations where id = requested_id and household_id = household for update;
    if selected.id is null then raise exception 'NOT_FOUND'; end if;
    if selected.owner_id <> actor and selected.scope <> 'HOUSEHOLD' then raise exception 'FORBIDDEN'; end if;
    if selected.version <> expected then raise exception 'VERSION_CONFLICT'; end if;
    update public.recurring_obligations set name = btrim(payload->>'name'), wallet_id = (payload->>'walletId')::uuid,
      category_id = (payload->>'categoryId')::uuid, estimated_amount = (payload->>'estimatedAmount')::numeric,
      frequency = requested_frequency, day_of_month = case when requested_frequency = 'MONTHLY' then requested_day end,
      day_of_week = case when requested_frequency = 'WEEKLY' then requested_day end,
      next_due_date = due, updated_at = now(), version = version + 1
    where id = selected.id returning * into selected;
  end if;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'RECURRING_OBLIGATION', selected.id, case when requested_id is null then 'CREATE' else 'UPDATE' end, to_jsonb(selected));
  return jsonb_build_object('id', selected.id, 'version', selected.version);
end;
$$;

create or replace function public.generate_obligation_occurrences(horizon_days integer default 90)
returns integer language plpgsql security definer set search_path = '' as $$
declare household uuid := public.my_active_household_id(); obligation public.recurring_obligations; due date; generated integer := 0;
begin
  if household is null then raise exception 'FORBIDDEN'; end if;
  if horizon_days not between 1 and 366 then raise exception 'VALIDATION_ERROR: horizon'; end if;
  for obligation in select * from public.recurring_obligations where household_id = household and active loop
    due := obligation.next_due_date;
    while due <= current_date + horizon_days loop
      insert into public.obligation_occurrences(household_id, obligation_id, due_date, estimated_amount)
      values (household, obligation.id, due, obligation.estimated_amount) on conflict do nothing;
      generated := generated + 1;
      due := public.next_recurrence_date(due, obligation.frequency,
        coalesce(obligation.day_of_month, obligation.day_of_week));
    end loop;
    update public.recurring_obligations set next_due_date = due, updated_at = now() where id = obligation.id;
  end loop;
  return generated;
end;
$$;

create or replace function public.list_recurring_obligations()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  perform public.generate_obligation_occurrences();
  select coalesce(jsonb_agg(jsonb_build_object(
    'occurrenceId', x.id, 'obligationId', o.id, 'name', o.name,
    'walletId', o.wallet_id, 'wallet', w.name, 'categoryId', o.category_id, 'category', c.name,
    'scope', o.scope, 'frequency', o.frequency, 'estimatedAmount', x.estimated_amount::text,
    'actualAmount', x.actual_amount::text, 'dueDate', x.due_date, 'status', x.status,
    'version', x.version
  ) order by x.due_date), '[]'::jsonb) into result
  from public.obligation_occurrences x
  join public.recurring_obligations o on o.id = x.obligation_id
  join public.wallets w on w.id = o.wallet_id join public.categories c on c.id = o.category_id
  where x.household_id = public.my_active_household_id()
    and (o.scope = 'HOUSEHOLD' or o.owner_id = auth.uid())
    and x.due_date >= current_date - 31;
  return result;
end;
$$;

create or replace function public.confirm_obligation_payment(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare occurrence public.obligation_occurrences; obligation public.recurring_obligations; transaction_result jsonb;
begin
  select * into occurrence from public.obligation_occurrences
    where id = (payload->>'occurrenceId')::uuid and household_id = public.my_active_household_id() for update;
  if occurrence.id is null then raise exception 'NOT_FOUND'; end if;
  if occurrence.status <> 'PENDING' then raise exception 'VALIDATION_ERROR: occurrence resolved'; end if;
  select * into obligation from public.recurring_obligations where id = occurrence.obligation_id;
  if obligation.owner_id <> auth.uid() and obligation.scope <> 'HOUSEHOLD' then raise exception 'FORBIDDEN'; end if;
  transaction_result := public.post_transaction(jsonb_build_object(
    'clientReferenceId', payload->>'clientReferenceId', 'walletId', obligation.wallet_id,
    'categoryId', obligation.category_id, 'kind', 'EXPENSE', 'amount', payload->>'actualAmount',
    'transactionDate', payload->>'transactionDate', 'scope', obligation.scope,
    'privacyMode', obligation.privacy, 'description', obligation.name
  ));
  update public.obligation_occurrences set status = 'PAID', actual_amount = (payload->>'actualAmount')::numeric,
    transaction_id = (transaction_result->>'id')::uuid, resolved_at = now(), resolved_by = auth.uid(),
    updated_at = now(), version = version + 1 where id = occurrence.id;
  return transaction_result || jsonb_build_object('occurrenceId', occurrence.id, 'releasedAmount',
    greatest(occurrence.estimated_amount - (payload->>'actualAmount')::numeric, 0)::text);
end;
$$;

create or replace function public.resolve_obligation_occurrence(
  occurrence_id uuid, action text, rescheduled_date date default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare occurrence public.obligation_occurrences; obligation public.recurring_obligations; replacement public.obligation_occurrences;
begin
  if action not in ('SKIP', 'RESCHEDULE') then raise exception 'VALIDATION_ERROR'; end if;
  select * into occurrence from public.obligation_occurrences
    where id = occurrence_id and household_id = public.my_active_household_id() for update;
  if occurrence.id is null or occurrence.status <> 'PENDING' then raise exception 'NOT_FOUND'; end if;
  select * into obligation from public.recurring_obligations where id = occurrence.obligation_id;
  if obligation.owner_id <> auth.uid() and obligation.scope <> 'HOUSEHOLD' then raise exception 'FORBIDDEN'; end if;
  update public.obligation_occurrences set status = case when action = 'SKIP'
      then 'SKIPPED'::public.obligation_occurrence_status
      else 'RESCHEDULED'::public.obligation_occurrence_status end,
    resolved_at = now(), resolved_by = auth.uid(), updated_at = now(), version = version + 1 where id = occurrence.id;
  if action = 'RESCHEDULE' then
    if rescheduled_date is null or rescheduled_date < current_date then raise exception 'VALIDATION_ERROR: reschedule date'; end if;
    insert into public.obligation_occurrences(household_id, obligation_id, due_date, estimated_amount)
    values (occurrence.household_id, occurrence.obligation_id, rescheduled_date, occurrence.estimated_amount)
    returning * into replacement;
  end if;
  return jsonb_build_object('id', occurrence.id, 'status', case when action = 'SKIP' then 'SKIPPED' else 'RESCHEDULED' end,
    'replacementId', replacement.id);
end;
$$;

create or replace function public.forecast_summary()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  household uuid := public.my_active_household_id(); current_period public.financial_periods;
  cash_balance numeric; locked numeric; routine numeric; available numeric; daily numeric;
  days_remaining integer; health text; budget_need numeric; obligation_need numeric;
begin
  current_period := public.ensure_financial_period(household, auth.uid(), 'HOUSEHOLD', current_date);
  perform public.generate_obligation_occurrences(greatest(current_period.end_date - current_date, 1));
  select coalesce(sum(balance), 0) into cash_balance from public.wallet_balances
    where household_id = household and active and wallet_type in ('BANK_ACCOUNT', 'CASH', 'E_WALLET', 'SAVING', 'OTHER');
  select coalesce(sum(f.amount), 0) into locked from public.locked_funds f
    join public.wallets w on w.id = f.wallet_id
    where f.household_id = household and f.active and w.active
      and w.wallet_type in ('BANK_ACCOUNT', 'CASH', 'E_WALLET', 'SAVING', 'OTHER');
  select coalesce(sum(greatest((b.amount - coalesce(spent.amount, 0)), 0)), 0) into budget_need
  from public.budgets b join public.categories c on c.id = b.category_id
  left join lateral (
    select sum(e.amount) amount from public.transaction_aggregates a
    join public.ledger_entries e on e.aggregate_id = a.id
    where a.kind in ('EXPENSE', 'BILL_PAYMENT') and a.status = 'POSTED' and e.category_id = b.category_id
      and a.transaction_date between current_period.start_date and current_period.end_date and a.scope = b.scope
  ) spent on true
  where b.period_id = current_period.id and b.active and c.necessity_type = 'REQUIRED';
  select coalesce(sum(x.estimated_amount), 0) into obligation_need
  from public.obligation_occurrences x join public.recurring_obligations o on o.id = x.obligation_id
  where x.household_id = household and x.status = 'PENDING'
    and x.due_date between current_date and current_period.end_date
    and not exists (select 1 from public.budgets b where b.period_id = current_period.id
      and b.category_id = o.category_id and b.active);
  routine := budget_need + obligation_need;
  available := cash_balance - locked - routine;
  days_remaining := greatest(current_period.end_date - current_date + 1, 1);
  daily := greatest(available, 0) / days_remaining;
  health := case when available < 0 then 'DEFICIT_RISK'
    when cash_balance > 0 and available < cash_balance * 0.20 then 'CONTROL_NEEDED' else 'SAFE' end;
  return jsonb_build_object(
    'periodId', current_period.id, 'periodEnd', current_period.end_date,
    'cashBalance', cash_balance::text, 'lockedFunds', locked::text,
    'routineNeeds', routine::text, 'requiredBudgetRemaining', budget_need::text,
    'unbudgetedObligations', obligation_need::text, 'availableCash', available::text,
    'remainingDays', days_remaining, 'safeDailyLimit', daily::text, 'health', health
  );
end;
$$;

create or replace function public.correct_transaction(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
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
  where w.household_id = public.my_active_household_id();
$$;

drop function if exists public.period_report(uuid);
create function public.period_report(period_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare selected public.financial_periods; result jsonb;
begin
  select * into selected from public.financial_periods where id = period_id;
  if selected.id is null or not public.can_manage_period(selected, false) then raise exception 'NOT_FOUND'; end if;
  select jsonb_build_object(
    'periodId', selected.id, 'status', selected.status, 'closedSummary', selected.lock_summary,
    'currentSummary', public.period_financial_summary(selected),
    'corrections', coalesce(jsonb_agg(jsonb_build_object(
      'id', correction.id, 'kind', correction.kind, 'date', correction.transaction_date,
      'description', correction.description, 'originalId', coalesce(correction.reversal_of_id, correction.correction_of_id),
      'createdAt', correction.created_at
    ) order by correction.created_at) filter (where correction.id is not null), '[]'::jsonb)
  ) into result
  from public.transaction_aggregates correction
  join public.transaction_aggregates original
    on original.id = coalesce(correction.reversal_of_id, correction.correction_of_id)
  where original.household_id = selected.household_id
    and original.transaction_date between selected.start_date and selected.end_date
    and correction.created_at >= coalesce(selected.locked_at, 'infinity'::timestamptz);
  return result;
end;
$$;

revoke all on function public.budget_health(numeric, numeric),
  public.next_recurrence_date(date, public.recurrence_frequency, integer) from public, anon, authenticated;
revoke all on function public.upsert_budget(jsonb), public.list_budgets(uuid),
  public.upsert_locked_fund(jsonb), public.release_locked_fund(uuid, integer), public.list_locked_funds(),
  public.upsert_recurring_obligation(jsonb), public.generate_obligation_occurrences(integer),
  public.list_recurring_obligations(), public.confirm_obligation_payment(jsonb),
  public.resolve_obligation_occurrence(uuid, text, date), public.forecast_summary(),
  public.correct_transaction(jsonb), public.period_report(uuid) from public, anon;
grant execute on function public.upsert_budget(jsonb), public.list_budgets(uuid),
  public.upsert_locked_fund(jsonb), public.release_locked_fund(uuid, integer), public.list_locked_funds(),
  public.upsert_recurring_obligation(jsonb), public.generate_obligation_occurrences(integer),
  public.list_recurring_obligations(), public.confirm_obligation_payment(jsonb),
  public.resolve_obligation_occurrence(uuid, text, date), public.forecast_summary(),
  public.correct_transaction(jsonb), public.period_report(uuid) to authenticated;
