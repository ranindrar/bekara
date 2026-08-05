create type public.period_type as enum ('PERSONAL', 'HOUSEHOLD');
create type public.period_status as enum ('OPEN', 'REVIEWED', 'LOCKED');

create table public.member_period_settings (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  member_id uuid not null unique references public.household_members(id),
  start_day smallint not null check (start_day between 1 and 31),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);

create table public.financial_periods (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  member_id uuid references public.household_members(id),
  period_type public.period_type not null,
  start_date date not null,
  end_date date not null,
  status public.period_status not null default 'OPEN',
  auto_lock_on date not null,
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  locked_at timestamptz,
  locked_by uuid references public.profiles(id),
  review_summary jsonb,
  lock_summary jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  check (start_date <= end_date),
  check ((period_type = 'HOUSEHOLD' and member_id is null) or
         (period_type = 'PERSONAL' and member_id is not null)),
  unique nulls not distinct (household_id, member_id, period_type, start_date)
);

create index financial_periods_lookup_idx
  on public.financial_periods(household_id, period_type, start_date, end_date);

alter table public.member_period_settings enable row level security;
alter table public.financial_periods enable row level security;

create policy period_settings_member_read on public.member_period_settings for select
  using (public.is_active_household_member(household_id));
create policy financial_periods_member_read on public.financial_periods for select
  using (
    public.is_active_household_member(household_id)
    and (
      period_type = 'HOUSEHOLD'
      or exists (
        select 1 from public.household_members m
        where m.id = financial_periods.member_id and m.user_id = auth.uid()
      )
    )
  );

revoke insert, update, delete on public.member_period_settings from anon, authenticated;
revoke insert, update, delete on public.financial_periods from anon, authenticated;

create or replace function public.clamped_month_date(base_date date, requested_day integer)
returns date language sql immutable set search_path = '' as $$
  select (
    date_trunc('month', base_date)::date
    + (least(
        greatest(requested_day, 1),
        extract(day from (date_trunc('month', base_date) + interval '1 month - 1 day'))::integer
      ) - 1)
  )::date;
$$;

create or replace function public.period_bounds(target_date date, requested_day integer)
returns table(start_date date, end_date date)
language plpgsql immutable set search_path = '' as $$
declare candidate date;
begin
  candidate := public.clamped_month_date(target_date, requested_day);
  if target_date < candidate then
    candidate := public.clamped_month_date((target_date - interval '1 month')::date, requested_day);
  end if;
  start_date := candidate;
  end_date := public.clamped_month_date((candidate + interval '1 month')::date, requested_day) - 1;
  return next;
end;
$$;

create or replace function public.period_financial_summary(target_period public.financial_periods)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'income', coalesce(sum(e.amount) filter (where a.kind = 'INCOME'), 0)::text,
    'expense', coalesce(sum(e.amount) filter (where a.kind in ('EXPENSE', 'BILL_PAYMENT')), 0)::text,
    'transactionCount', count(distinct a.id) filter (where a.kind in ('INCOME', 'EXPENSE', 'BILL_PAYMENT'))
  )
  from public.transaction_aggregates a
  join public.ledger_entries e on e.aggregate_id = a.id
  where a.household_id = target_period.household_id
    and a.transaction_date between target_period.start_date and target_period.end_date
    and a.status = 'POSTED'
    and (
      (target_period.period_type = 'HOUSEHOLD' and a.scope = 'HOUSEHOLD')
      or (target_period.period_type = 'PERSONAL' and a.scope = 'PRIVATE' and a.owner_id = (
        select m.user_id from public.household_members m where m.id = target_period.member_id
      ))
    );
$$;

create or replace function public.ensure_financial_period(
  target_household uuid,
  target_owner uuid,
  target_scope public.transaction_scope,
  target_date date
)
returns public.financial_periods language plpgsql security definer set search_path = '' as $$
declare
  selected_member public.household_members;
  requested_day integer;
  bounds record;
  selected_type public.period_type;
  result public.financial_periods;
begin
  if target_scope = 'HOUSEHOLD' then
    selected_type := 'HOUSEHOLD';
    select h.reporting_start_day into requested_day from public.households h where h.id = target_household;
  else
    selected_type := 'PERSONAL';
    select * into selected_member from public.household_members m
      where m.household_id = target_household and m.user_id = target_owner and m.status = 'ACTIVE';
    if selected_member.id is null then raise exception 'FORBIDDEN'; end if;
    select coalesce(s.start_day, h.reporting_start_day) into requested_day
    from public.households h left join public.member_period_settings s on s.member_id = selected_member.id
    where h.id = target_household;
  end if;

  select * into bounds from public.period_bounds(target_date, requested_day);
  insert into public.financial_periods(
    household_id, member_id, period_type, start_date, end_date, auto_lock_on
  ) values (
    target_household,
    case when selected_type = 'PERSONAL' then selected_member.id else null end,
    selected_type,
    bounds.start_date,
    bounds.end_date,
    (bounds.end_date + 1 + interval '2 months')::date
  ) on conflict (household_id, member_id, period_type, start_date) do nothing;

  select * into result from public.financial_periods p
  where p.household_id = target_household and p.period_type = selected_type
    and p.member_id is not distinct from case when selected_type = 'PERSONAL' then selected_member.id else null end
    and p.start_date = bounds.start_date;
  return result;
end;
$$;

create or replace function public.auto_lock_due_periods()
returns integer language plpgsql security definer set search_path = '' as $$
declare actor_household uuid := public.my_active_household_id(); affected integer;
begin
  if actor_household is null then raise exception 'FORBIDDEN'; end if;
  update public.financial_periods p set
    status = 'LOCKED', locked_at = now(), locked_by = null,
    lock_summary = public.period_financial_summary(p),
    updated_at = now(), version = version + 1
  where p.household_id = actor_household and p.status <> 'LOCKED' and p.auto_lock_on <= current_date;
  get diagnostics affected = row_count;
  return affected;
end;
$$;

create or replace function public.generate_periods(months_back integer default 12, months_forward integer default 3)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  actor_household uuid := public.my_active_household_id();
  actor uuid := auth.uid();
  cursor_date date;
  member_record record;
  affected integer := 0;
begin
  if actor_household is null then raise exception 'FORBIDDEN'; end if;
  if months_back not between 0 and 60 or months_forward not between 0 and 24 then
    raise exception 'VALIDATION_ERROR: period range';
  end if;
  for cursor_date in select (date_trunc('month', current_date) + (n || ' months')::interval)::date
    from generate_series(-months_back, months_forward) n loop
    perform public.ensure_financial_period(actor_household, actor, 'HOUSEHOLD', cursor_date);
    for member_record in select user_id from public.household_members
      where household_id = actor_household and status = 'ACTIVE' loop
      perform public.ensure_financial_period(actor_household, member_record.user_id, 'PRIVATE', cursor_date);
    end loop;
  end loop;
  select count(*) into affected from public.financial_periods where household_id = actor_household;
  perform public.auto_lock_due_periods();
  return affected;
end;
$$;

create or replace function public.set_my_period_start_day(requested_day integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare member_record public.household_members; result public.member_period_settings;
begin
  if requested_day not between 1 and 31 then raise exception 'VALIDATION_ERROR: start day'; end if;
  select * into member_record from public.household_members
    where user_id = auth.uid() and status = 'ACTIVE';
  if member_record.id is null then raise exception 'FORBIDDEN'; end if;
  insert into public.member_period_settings(household_id, member_id, start_day, created_by)
  values (member_record.household_id, member_record.id, requested_day, auth.uid())
  on conflict (member_id) do update set start_day = excluded.start_day,
    updated_at = now(), version = public.member_period_settings.version + 1
  returning * into result;
  return jsonb_build_object('startDay', result.start_day, 'version', result.version);
end;
$$;

create or replace function public.list_periods()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb;
begin
  perform public.generate_periods();
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'type', p.period_type, 'startDate', p.start_date,
    'endDate', p.end_date, 'status', p.status, 'autoLockOn', p.auto_lock_on,
    'reviewedAt', p.reviewed_at, 'lockedAt', p.locked_at,
    'summary', coalesce(p.lock_summary, public.period_financial_summary(p))
  ) order by p.start_date desc, p.period_type), '[]'::jsonb) into result
  from public.financial_periods p
  left join public.household_members m on m.id = p.member_id
  where p.household_id = public.my_active_household_id()
    and (p.period_type = 'HOUSEHOLD' or m.user_id = auth.uid());
  return result;
end;
$$;

create or replace function public.can_manage_period(target_period public.financial_periods, require_owner boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when target_period.period_type = 'PERSONAL' then exists (
      select 1 from public.household_members m where m.id = target_period.member_id and m.user_id = auth.uid()
    )
    when require_owner then exists (
      select 1 from public.household_members m where m.household_id = target_period.household_id
        and m.user_id = auth.uid() and m.role = 'OWNER' and m.status = 'ACTIVE'
    )
    else public.is_active_household_member(target_period.household_id)
  end;
$$;

create or replace function public.review_period(period_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare selected public.financial_periods; summary jsonb;
begin
  select * into selected from public.financial_periods where id = period_id for update;
  if selected.id is null then raise exception 'NOT_FOUND'; end if;
  if not public.can_manage_period(selected, false) then raise exception 'FORBIDDEN'; end if;
  if selected.status = 'LOCKED' then raise exception 'PERIOD_LOCKED'; end if;
  summary := public.period_financial_summary(selected);
  update public.financial_periods set status = 'REVIEWED', reviewed_at = now(), reviewed_by = auth.uid(),
    review_summary = summary, updated_at = now(), version = version + 1 where id = selected.id;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (selected.household_id, auth.uid(), 'PERIOD', selected.id, 'REVIEW', summary);
  return jsonb_build_object('id', selected.id, 'status', 'REVIEWED', 'summary', summary);
end;
$$;

create or replace function public.lock_period(period_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare selected public.financial_periods; summary jsonb;
begin
  select * into selected from public.financial_periods where id = period_id for update;
  if selected.id is null then raise exception 'NOT_FOUND'; end if;
  if not public.can_manage_period(selected, selected.period_type = 'HOUSEHOLD') then raise exception 'FORBIDDEN'; end if;
  if selected.status = 'LOCKED' then return jsonb_build_object('id', selected.id, 'status', 'LOCKED'); end if;
  if selected.status <> 'REVIEWED' then raise exception 'VALIDATION_ERROR: review required'; end if;
  summary := public.period_financial_summary(selected);
  update public.financial_periods set status = 'LOCKED', locked_at = now(), locked_by = auth.uid(),
    lock_summary = summary, updated_at = now(), version = version + 1 where id = selected.id;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (selected.household_id, auth.uid(), 'PERIOD', selected.id, 'LOCK', summary);
  return jsonb_build_object('id', selected.id, 'status', 'LOCKED', 'summary', summary);
end;
$$;

create or replace function public.assert_period_open()
returns trigger language plpgsql security definer set search_path = '' as $$
declare selected public.financial_periods;
begin
  selected := public.ensure_financial_period(new.household_id, new.owner_id, new.scope, new.transaction_date);
  if selected.auto_lock_on <= current_date and selected.status <> 'LOCKED' then
    update public.financial_periods p set status = 'LOCKED', locked_at = now(), locked_by = null,
      lock_summary = public.period_financial_summary(p), updated_at = now(), version = version + 1
    where p.id = selected.id;
    selected.status := 'LOCKED';
  end if;
  if selected.status = 'LOCKED' then raise exception 'PERIOD_LOCKED'; end if;
  return new;
end;
$$;

create trigger transaction_period_guard
before insert or update of transaction_date, scope, owner_id on public.transaction_aggregates
for each row execute function public.assert_period_open();

create or replace function public.period_report(period_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare selected public.financial_periods; result jsonb;
begin
  select * into selected from public.financial_periods where id = period_id;
  if selected.id is null or not public.can_manage_period(selected, false) then raise exception 'NOT_FOUND'; end if;
  select jsonb_build_object(
    'periodId', selected.id, 'status', selected.status,
    'closedSummary', selected.lock_summary,
    'currentSummary', public.period_financial_summary(selected),
    'corrections', coalesce(jsonb_agg(jsonb_build_object(
      'id', correction.id, 'date', correction.transaction_date,
      'description', correction.description, 'originalId', correction.reversal_of_id,
      'createdAt', correction.created_at
    ) order by correction.created_at) filter (where correction.id is not null), '[]'::jsonb)
  ) into result
  from public.transaction_aggregates correction
  join public.transaction_aggregates original on original.id = correction.reversal_of_id
  where original.household_id = selected.household_id
    and original.transaction_date between selected.start_date and selected.end_date
    and correction.created_at >= coalesce(selected.locked_at, 'infinity'::timestamptz);
  return result;
end;
$$;

revoke all on function public.clamped_month_date(date, integer), public.period_bounds(date, integer),
  public.period_financial_summary(public.financial_periods),
  public.ensure_financial_period(uuid, uuid, public.transaction_scope, date),
  public.can_manage_period(public.financial_periods, boolean) from public, anon, authenticated;
revoke all on function public.auto_lock_due_periods(), public.generate_periods(integer, integer),
  public.set_my_period_start_day(integer), public.list_periods(), public.review_period(uuid),
  public.lock_period(uuid), public.period_report(uuid) from public, anon;
grant execute on function public.auto_lock_due_periods(), public.generate_periods(integer, integer),
  public.set_my_period_start_day(integer), public.list_periods(), public.review_period(uuid),
  public.lock_period(uuid), public.period_report(uuid) to authenticated;
