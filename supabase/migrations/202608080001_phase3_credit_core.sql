create type public.credit_account_status as enum ('ACTIVE', 'INACTIVE');
create type public.billing_period_status as enum (
  'UNBILLED', 'OPEN', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'CANCELLED'
);
create type public.credit_purchase_status as enum ('POSTED', 'PARTIALLY_REFUNDED', 'REFUNDED');
create type public.installment_status as enum ('SCHEDULED', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'CANCELLED');

create table public.credit_accounts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  wallet_id uuid not null unique references public.wallets(id),
  primary_holder_id uuid not null references public.profiles(id),
  account_type public.wallet_type not null,
  scope public.transaction_scope not null,
  provider_name text not null check (char_length(provider_name) between 2 and 80),
  account_name text not null check (char_length(account_name) between 2 and 80),
  last_four text check (last_four is null or last_four ~ '^[0-9]{4}$'),
  credit_limit numeric(19,2) not null check (credit_limit > 0),
  statement_day smallint not null check (statement_day between 1 and 31),
  due_day smallint not null check (due_day between 1 and 31),
  opening_liability numeric(19,2) not null default 0 check (opening_liability >= 0),
  status public.credit_account_status not null default 'ACTIVE',
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  check (account_type in ('CREDIT_CARD', 'PAYLATER')),
  check (account_type <> 'PAYLATER' or scope = 'PRIVATE')
);

create table public.billing_periods (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  credit_account_id uuid not null references public.credit_accounts(id),
  period_start date not null,
  period_end date not null,
  due_date date not null,
  principal_amount numeric(19,2) not null default 0 check (principal_amount >= 0),
  fee_amount numeric(19,2) not null default 0 check (fee_amount >= 0),
  paid_amount numeric(19,2) not null default 0 check (paid_amount >= 0),
  private_outstanding numeric(19,2) not null default 0 check (private_outstanding >= 0),
  household_outstanding numeric(19,2) not null default 0 check (household_outstanding >= 0),
  status public.billing_period_status not null default 'UNBILLED',
  issued_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  unique (credit_account_id, period_start, period_end),
  check (period_start <= period_end and due_date > period_end)
);

create table public.credit_purchases (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  credit_account_id uuid not null references public.credit_accounts(id),
  purchase_aggregate_id uuid unique references public.transaction_aggregates(id),
  fee_aggregate_id uuid unique references public.transaction_aggregates(id),
  owner_id uuid not null references public.profiles(id),
  category_id uuid references public.categories(id),
  source_type text not null default 'PURCHASE' check (source_type in ('PURCHASE', 'OPENING', 'ADJUSTMENT')),
  original_transaction_date date not null,
  posted_date date not null,
  scope public.transaction_scope not null,
  privacy public.privacy_mode not null,
  description text,
  principal_amount numeric(19,2) not null check (principal_amount >= 0),
  financing_cost numeric(19,2) not null default 0 check (financing_cost >= 0),
  refunded_amount numeric(19,2) not null default 0 check (refunded_amount >= 0),
  tenor smallint not null default 1 check (tenor between 1 and 36),
  status public.credit_purchase_status not null default 'POSTED',
  client_reference_id uuid not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  unique (created_by, client_reference_id),
  check ((scope = 'HOUSEHOLD' and privacy = 'HOUSEHOLD_VISIBLE') or scope = 'PRIVATE'),
  check (principal_amount + financing_cost > 0),
  check (refunded_amount <= principal_amount + financing_cost)
);

create table public.installment_schedules (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  credit_account_id uuid not null references public.credit_accounts(id),
  billing_period_id uuid not null references public.billing_periods(id),
  purchase_id uuid not null references public.credit_purchases(id),
  installment_number smallint not null check (installment_number > 0),
  due_date date not null,
  scope public.transaction_scope not null,
  principal_amount numeric(19,2) not null check (principal_amount >= 0),
  fee_amount numeric(19,2) not null default 0 check (fee_amount >= 0),
  paid_principal numeric(19,2) not null default 0 check (paid_principal >= 0),
  paid_fee numeric(19,2) not null default 0 check (paid_fee >= 0),
  credited_principal numeric(19,2) not null default 0 check (credited_principal >= 0),
  credited_fee numeric(19,2) not null default 0 check (credited_fee >= 0),
  status public.installment_status not null default 'SCHEDULED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  unique (purchase_id, installment_number),
  check (principal_amount + fee_amount > 0),
  check (paid_principal + credited_principal <= principal_amount
    and paid_fee + credited_fee <= fee_amount)
);

create table public.credit_payments (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  credit_account_id uuid not null references public.credit_accounts(id),
  aggregate_id uuid not null unique references public.transaction_aggregates(id),
  source_wallet_id uuid not null references public.wallets(id),
  paid_by uuid not null references public.profiles(id),
  amount numeric(19,2) not null check (amount > 0),
  payment_date date not null,
  client_reference_id uuid not null,
  created_at timestamptz not null default now(),
  unique (paid_by, client_reference_id)
);

create table public.credit_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.credit_payments(id),
  billing_period_id uuid not null references public.billing_periods(id),
  installment_id uuid not null references public.installment_schedules(id),
  scope public.transaction_scope not null,
  principal_amount numeric(19,2) not null default 0 check (principal_amount >= 0),
  fee_amount numeric(19,2) not null default 0 check (fee_amount >= 0),
  created_at timestamptz not null default now(),
  check (principal_amount + fee_amount > 0)
);

create index credit_accounts_household_scope_idx
  on public.credit_accounts(household_id, scope, status);
create index billing_periods_account_due_idx
  on public.billing_periods(credit_account_id, due_date, status);
create index credit_purchases_account_date_idx
  on public.credit_purchases(credit_account_id, original_transaction_date desc);
create index installment_schedules_account_due_idx
  on public.installment_schedules(credit_account_id, due_date, status);
create index credit_payments_account_date_idx
  on public.credit_payments(credit_account_id, payment_date desc);

alter table public.credit_accounts enable row level security;
alter table public.billing_periods enable row level security;
alter table public.credit_purchases enable row level security;
alter table public.installment_schedules enable row level security;
alter table public.credit_payments enable row level security;
alter table public.credit_payment_allocations enable row level security;

create or replace function public.can_view_credit_account(target_account_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.credit_accounts a
    where a.id = target_account_id
      and public.is_active_household_member(a.household_id)
      and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid())
  );
$$;

create or replace function public.can_manage_credit_account(target_account_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.credit_accounts a
    where a.id = target_account_id
      and public.is_active_household_member(a.household_id)
      and (
        a.primary_holder_id = auth.uid()
        or (a.scope = 'HOUSEHOLD' and exists (
          select 1 from public.household_members m
          where m.household_id = a.household_id and m.user_id = auth.uid()
            and m.status = 'ACTIVE' and m.role = 'OWNER'
        ))
      )
  );
$$;

create policy credit_accounts_visible_read on public.credit_accounts for select
  using (public.can_view_credit_account(id));
create policy billing_periods_visible_read on public.billing_periods for select
  using (public.can_view_credit_account(credit_account_id));
create policy credit_purchases_visible_read on public.credit_purchases for select
  using (public.can_view_credit_account(credit_account_id));
create policy installments_visible_read on public.installment_schedules for select
  using (public.can_view_credit_account(credit_account_id));
create policy credit_payments_visible_read on public.credit_payments for select
  using (public.can_view_credit_account(credit_account_id));
create policy credit_allocations_visible_read on public.credit_payment_allocations for select
  using (exists (
    select 1 from public.credit_payments p
    where p.id = payment_id and public.can_view_credit_account(p.credit_account_id)
  ));

revoke insert, update, delete on public.credit_accounts, public.billing_periods,
  public.credit_purchases, public.installment_schedules, public.credit_payments,
  public.credit_payment_allocations from anon, authenticated;

create or replace function public.credit_cycle_bounds(target_date date, requested_day integer)
returns table(cycle_start date, cycle_end date)
language plpgsql stable set search_path = '' as $$
declare candidate date;
begin
  if requested_day not between 1 and 31 then raise exception 'VALIDATION_ERROR'; end if;
  candidate := public.clamped_month_date(date_trunc('month', target_date)::date, requested_day);
  if target_date > candidate then
    cycle_end := public.clamped_month_date((date_trunc('month', target_date) + interval '1 month')::date, requested_day);
  else
    cycle_end := candidate;
  end if;
  cycle_start := public.clamped_month_date((date_trunc('month', cycle_end) - interval '1 month')::date, requested_day) + 1;
  return next;
end;
$$;

create or replace function public.credit_due_date(cutoff_date date, requested_day integer)
returns date language plpgsql stable set search_path = '' as $$
declare candidate date;
begin
  if requested_day not between 1 and 31 then raise exception 'VALIDATION_ERROR'; end if;
  candidate := public.clamped_month_date(date_trunc('month', cutoff_date)::date, requested_day);
  if candidate <= cutoff_date then
    candidate := public.clamped_month_date((date_trunc('month', cutoff_date) + interval '1 month')::date, requested_day);
  end if;
  return candidate;
end;
$$;

create or replace function public.ensure_credit_billing_period(
  target_account_id uuid, target_date date
)
returns public.billing_periods language plpgsql security definer set search_path = '' as $$
declare account public.credit_accounts; bounds record; selected public.billing_periods;
begin
  select * into account from public.credit_accounts where id = target_account_id;
  if account.id is null then raise exception 'NOT_FOUND'; end if;
  select * into bounds from public.credit_cycle_bounds(target_date, account.statement_day);
  select * into selected from public.billing_periods
    where credit_account_id = account.id
      and period_start = bounds.cycle_start and period_end = bounds.cycle_end;
  if selected.id is null then
    insert into public.billing_periods(
      household_id, credit_account_id, period_start, period_end, due_date, status, issued_at
    ) values (
      account.household_id, account.id, bounds.cycle_start, bounds.cycle_end,
      public.credit_due_date(bounds.cycle_end, account.due_day),
      case when bounds.cycle_end < current_date then 'OPEN'::public.billing_period_status
        else 'UNBILLED'::public.billing_period_status end,
      case when bounds.cycle_end < current_date then now() else null end
    ) returning * into selected;
  elsif selected.status = 'UNBILLED' and selected.period_end < current_date then
    update public.billing_periods set status = 'OPEN', issued_at = coalesce(issued_at, now()),
      updated_at = now(), version = version + 1 where id = selected.id returning * into selected;
  end if;
  return selected;
end;
$$;

create or replace function public.refresh_credit_bill(target_bill_id uuid)
returns public.billing_periods language plpgsql security definer set search_path = '' as $$
declare selected public.billing_periods; principal numeric; fee numeric; paid numeric;
  private_due numeric; household_due numeric; next_status public.billing_period_status;
begin
  select * into selected from public.billing_periods where id = target_bill_id for update;
  if selected.id is null then raise exception 'NOT_FOUND'; end if;
  select coalesce(sum(s.principal_amount), 0), coalesce(sum(s.fee_amount), 0),
    coalesce(sum(s.paid_principal + s.paid_fee), 0),
    coalesce(sum((s.principal_amount + s.fee_amount) -
      (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee))
      filter (where s.scope = 'PRIVATE'), 0),
    coalesce(sum((s.principal_amount + s.fee_amount) -
      (s.paid_principal + s.paid_fee + s.credited_principal + s.credited_fee))
      filter (where s.scope = 'HOUSEHOLD'), 0)
  into principal, fee, paid, private_due, household_due
  from public.installment_schedules s where s.billing_period_id = selected.id;
  next_status := case
    when selected.status = 'CANCELLED' then 'CANCELLED'::public.billing_period_status
    when principal + fee > 0 and private_due + household_due = 0 then 'PAID'::public.billing_period_status
    when selected.due_date < current_date and private_due + household_due > 0 then 'OVERDUE'::public.billing_period_status
    when paid > 0 then 'PARTIALLY_PAID'::public.billing_period_status
    when selected.period_end < current_date then 'OPEN'::public.billing_period_status
    else 'UNBILLED'::public.billing_period_status end;
  update public.billing_periods set principal_amount = principal, fee_amount = fee,
    paid_amount = paid, private_outstanding = private_due,
    household_outstanding = household_due, status = next_status,
    issued_at = case when next_status <> 'UNBILLED' then coalesce(issued_at, now()) else issued_at end,
    updated_at = now(), version = version + 1
  where id = selected.id returning * into selected;
  update public.installment_schedules set status = case
      when paid_principal + paid_fee + credited_principal + credited_fee >= principal_amount + fee_amount
        then 'PAID'::public.installment_status
      when due_date < current_date then 'OVERDUE'::public.installment_status
      when paid_principal + paid_fee + credited_principal + credited_fee > 0
        then 'PARTIALLY_PAID'::public.installment_status
      else 'SCHEDULED'::public.installment_status end,
    updated_at = now()
  where billing_period_id = selected.id and status <> 'CANCELLED';
  return selected;
end;
$$;

create or replace function public.credit_finance_category(
  target_household uuid, target_owner uuid, target_scope public.transaction_scope
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare selected uuid;
begin
  select id into selected from public.categories
  where household_id = target_household and name = 'Biaya kredit' and direction = 'EXPENSE'
    and scope = target_scope and active
    and (target_scope = 'HOUSEHOLD' or owner_id = target_owner)
  order by created_at limit 1;
  if selected is null then
    insert into public.categories(household_id, owner_id, name, direction, scope,
      necessity_type, system_category, active, created_by)
    values (target_household, case when target_scope = 'PRIVATE' then target_owner else null end,
      'Biaya kredit', 'EXPENSE', target_scope, 'FINANCIAL', false, true, target_owner)
    returning id into selected;
  end if;
  return selected;
end;
$$;

create or replace function public.create_credit_account(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '', extensions as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id();
  requested_type public.wallet_type; requested_scope public.transaction_scope;
  requested_limit numeric; opening numeric; statement integer; due integer; reference uuid;
  wallet public.wallets; account public.credit_accounts; bill public.billing_periods;
  purchase public.credit_purchases; result jsonb; stored_hash text;
  incoming_hash text := encode(digest(payload::text, 'sha256'), 'hex');
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if household is null then raise exception 'FORBIDDEN'; end if;
  begin
    requested_type := (payload->>'accountType')::public.wallet_type;
    requested_scope := (payload->>'scope')::public.transaction_scope;
    requested_limit := (payload->>'creditLimit')::numeric;
    opening := coalesce(nullif(payload->>'openingLiability', '')::numeric, 0);
    statement := (payload->>'statementDay')::integer;
    due := (payload->>'dueDay')::integer;
    reference := (payload->>'clientReferenceId')::uuid;
  exception when others then raise exception 'VALIDATION_ERROR'; end;
  if requested_type not in ('CREDIT_CARD', 'PAYLATER') or requested_limit <= 0 or opening < 0
      or statement not between 1 and 31 or due not between 1 and 31
      or char_length(btrim(payload->>'providerName')) not between 2 and 80
      or char_length(btrim(payload->>'accountName')) not between 2 and 80 then
    raise exception 'VALIDATION_ERROR';
  end if;
  if requested_type = 'PAYLATER' and requested_scope <> 'PRIVATE' then
    raise exception 'VALIDATION_ERROR: paylater scope';
  end if;
  if nullif(payload->>'lastFour', '') is not null and (payload->>'lastFour') !~ '^[0-9]{4}$' then
    raise exception 'VALIDATION_ERROR: last four';
  end if;
  select payload_hash, response_json into stored_hash, result from public.idempotency_records
    where actor_id = actor and operation = 'CREATE_CREDIT_ACCOUNT' and client_reference_id = reference;
  if result is not null then
    if stored_hash <> incoming_hash then raise exception 'IDEMPOTENCY_CONFLICT'; end if;
    return result;
  end if;
  insert into public.wallets(household_id, owner_id, name, wallet_type, opening_balance,
    is_shared, accepts_household_transfer, active, created_by)
  values (household, actor, btrim(payload->>'accountName'), requested_type, -opening,
    requested_scope = 'HOUSEHOLD', false, true, actor) returning * into wallet;
  insert into public.credit_accounts(household_id, wallet_id, primary_holder_id, account_type,
    scope, provider_name, account_name, last_four, credit_limit, statement_day, due_day,
    opening_liability, created_by)
  values (household, wallet.id, actor, requested_type, requested_scope,
    btrim(payload->>'providerName'), btrim(payload->>'accountName'), nullif(payload->>'lastFour', ''),
    requested_limit, statement, due, opening, actor) returning * into account;
  if opening > 0 then
    bill := public.ensure_credit_billing_period(account.id, current_date);
    insert into public.credit_purchases(household_id, credit_account_id, owner_id, source_type,
      original_transaction_date, posted_date, scope, privacy, description, principal_amount,
      financing_cost, tenor, client_reference_id, created_by)
    values (household, account.id, actor, 'OPENING', current_date, current_date, requested_scope,
      case when requested_scope = 'HOUSEHOLD' then 'HOUSEHOLD_VISIBLE'::public.privacy_mode
        else 'PRIVATE_FULL'::public.privacy_mode end,
      'Saldo kewajiban awal', opening, 0, 1, gen_random_uuid(), actor) returning * into purchase;
    insert into public.installment_schedules(household_id, credit_account_id, billing_period_id,
      purchase_id, installment_number, due_date, scope, principal_amount)
    values (household, account.id, bill.id, purchase.id, 1, bill.due_date, requested_scope, opening);
    perform public.refresh_credit_bill(bill.id);
  end if;
  result := jsonb_build_object('id', account.id, 'walletId', wallet.id, 'version', account.version);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'CREATE_CREDIT_ACCOUNT', reference, incoming_hash, result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'CREDIT_ACCOUNT', account.id, 'CREATE', to_jsonb(account));
  return result;
end;
$$;

create or replace function public.update_credit_account(
  account_id uuid, expected_version integer, patch jsonb
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare old_record public.credit_accounts; changed public.credit_accounts; outstanding numeric;
begin
  if not public.can_manage_credit_account(account_id) then raise exception 'FORBIDDEN'; end if;
  select * into old_record from public.credit_accounts where id = account_id for update;
  if old_record.id is null then raise exception 'NOT_FOUND'; end if;
  if old_record.version <> expected_version then raise exception 'VERSION_CONFLICT'; end if;
  if nullif(patch->>'lastFour', '') is not null and (patch->>'lastFour') !~ '^[0-9]{4}$' then
    raise exception 'VALIDATION_ERROR: last four';
  end if;
  if nullif(patch->>'creditLimit', '') is not null and (patch->>'creditLimit')::numeric <= 0 then
    raise exception 'VALIDATION_ERROR: limit';
  end if;
  if nullif(patch->>'statementDay', '') is not null and (patch->>'statementDay')::integer not between 1 and 31 then
    raise exception 'VALIDATION_ERROR: statement day';
  end if;
  if nullif(patch->>'dueDay', '') is not null and (patch->>'dueDay')::integer not between 1 and 31 then
    raise exception 'VALIDATION_ERROR: due day';
  end if;
  select greatest(-balance, 0) into outstanding from public.wallet_balances where id = old_record.wallet_id;
  update public.credit_accounts set
    provider_name = coalesce(nullif(btrim(patch->>'providerName'), ''), provider_name),
    account_name = coalesce(nullif(btrim(patch->>'accountName'), ''), account_name),
    last_four = case when patch ? 'lastFour' then nullif(patch->>'lastFour', '') else last_four end,
    credit_limit = coalesce(nullif(patch->>'creditLimit', '')::numeric, credit_limit),
    statement_day = coalesce(nullif(patch->>'statementDay', '')::integer, statement_day),
    due_day = coalesce(nullif(patch->>'dueDay', '')::integer, due_day),
    updated_at = now(), version = version + 1
  where id = account_id returning * into changed;
  update public.wallets set name = changed.account_name, updated_at = now(), version = version + 1
    where id = changed.wallet_id;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, before_value, after_value)
  values (changed.household_id, auth.uid(), 'CREDIT_ACCOUNT', changed.id, 'UPDATE', to_jsonb(old_record), to_jsonb(changed));
  return jsonb_build_object('id', changed.id, 'version', changed.version,
    'outstanding', outstanding::text);
end;
$$;

create or replace function public.archive_credit_account(account_id uuid, expected_version integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare selected public.credit_accounts; outstanding numeric;
begin
  if not public.can_manage_credit_account(account_id) then raise exception 'FORBIDDEN'; end if;
  select * into selected from public.credit_accounts where id = account_id for update;
  if selected.id is null then raise exception 'NOT_FOUND'; end if;
  if selected.version <> expected_version then raise exception 'VERSION_CONFLICT'; end if;
  select greatest(-balance, 0) into outstanding from public.wallet_balances where id = selected.wallet_id;
  if outstanding > 0 then raise exception 'CREDIT_ACCOUNT_NOT_EMPTY'; end if;
  update public.credit_accounts set status = 'INACTIVE', updated_at = now(), version = version + 1
    where id = selected.id returning * into selected;
  update public.wallets set active = false, updated_at = now(), version = version + 1
    where id = selected.wallet_id;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, before_value, after_value)
  values (selected.household_id, auth.uid(), 'CREDIT_ACCOUNT', selected.id, 'ARCHIVE', null, to_jsonb(selected));
  return jsonb_build_object('id', selected.id, 'version', selected.version, 'status', selected.status);
end;
$$;

create or replace function public.list_credit_accounts()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'walletId', a.wallet_id, 'accountType', a.account_type,
    'scope', a.scope, 'providerName', a.provider_name, 'accountName', a.account_name,
    'lastFour', a.last_four, 'creditLimit', a.credit_limit::text,
    'outstanding', greatest(-w.balance, 0)::text,
    'principalOutstanding', coalesce(s.principal_outstanding, 0)::text,
    'remainingLimit', (a.credit_limit - coalesce(s.principal_outstanding, 0))::text,
    'statementDay', a.statement_day, 'dueDay', a.due_day, 'status', a.status,
    'primaryHolderId', a.primary_holder_id, 'isPrimaryHolder', a.primary_holder_id = auth.uid(),
    'version', a.version
  ) order by a.status, a.account_name), '[]'::jsonb)
  from public.credit_accounts a
  join public.wallet_balances w on w.id = a.wallet_id
  left join lateral (
    select sum(principal_amount - paid_principal - credited_principal) principal_outstanding
    from public.installment_schedules x where x.credit_account_id = a.id and x.status <> 'CANCELLED'
  ) s on true
  where a.household_id = public.my_active_household_id()
    and (a.scope = 'HOUSEHOLD' or a.primary_holder_id = auth.uid());
$$;

revoke all on function public.can_view_credit_account(uuid), public.can_manage_credit_account(uuid),
  public.ensure_credit_billing_period(uuid, date), public.refresh_credit_bill(uuid),
  public.credit_finance_category(uuid, uuid, public.transaction_scope) from public, anon, authenticated;
revoke all on function public.credit_cycle_bounds(date, integer), public.credit_due_date(date, integer),
  public.create_credit_account(jsonb), public.update_credit_account(uuid, integer, jsonb),
  public.archive_credit_account(uuid, integer), public.list_credit_accounts() from public, anon;
grant execute on function public.credit_cycle_bounds(date, integer), public.credit_due_date(date, integer),
  public.create_credit_account(jsonb), public.update_credit_account(uuid, integer, jsonb),
  public.archive_credit_account(uuid, integer), public.list_credit_accounts() to authenticated;
