create table public.sync_changes (
  sequence bigint generated always as identity primary key,
  household_id uuid not null references public.households(id),
  entity text not null,
  entity_id uuid not null,
  operation text not null check (operation in ('UPSERT', 'TOMBSTONE')),
  changed_at timestamptz not null default now()
);

create index sync_changes_household_sequence_idx on public.sync_changes(household_id, sequence);
alter table public.sync_changes enable row level security;
create policy sync_changes_member_read on public.sync_changes for select
  using (public.is_active_household_member(household_id));
revoke insert, update, delete on public.sync_changes from anon, authenticated;

create or replace function public.capture_sync_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare operation_name text := 'UPSERT'; row_data jsonb := to_jsonb(new);
begin
  if row_data ? 'active' and coalesce((row_data->>'active')::boolean, true) = false then
    operation_name := 'TOMBSTONE';
  elsif row_data->>'status' in ('REVERSED', 'SKIPPED') then
    operation_name := 'TOMBSTONE';
  end if;
  insert into public.sync_changes(household_id, entity, entity_id, operation)
  values (new.household_id, tg_argv[0], new.id, operation_name);
  return new;
end;
$$;

create trigger sync_wallets after insert or update on public.wallets
  for each row execute function public.capture_sync_change('WALLET');
create trigger sync_categories after insert or update on public.categories
  for each row execute function public.capture_sync_change('CATEGORY');
create trigger sync_transactions after insert or update on public.transaction_aggregates
  for each row execute function public.capture_sync_change('TRANSACTION');
create trigger sync_periods after insert or update on public.financial_periods
  for each row execute function public.capture_sync_change('PERIOD');
create trigger sync_budgets after insert or update on public.budgets
  for each row execute function public.capture_sync_change('BUDGET');
create trigger sync_locked_funds after insert or update on public.locked_funds
  for each row execute function public.capture_sync_change('LOCKED_FUND');
create trigger sync_recurring after insert or update on public.recurring_obligations
  for each row execute function public.capture_sync_change('RECURRING_OBLIGATION');
create trigger sync_occurrences after insert or update on public.obligation_occurrences
  for each row execute function public.capture_sync_change('OBLIGATION_OCCURRENCE');

create or replace function public.sync_changes(cursor_value bigint default 0, result_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare household uuid := public.my_active_household_id(); result jsonb; next_cursor bigint;
begin
  if household is null then raise exception 'FORBIDDEN'; end if;
  if cursor_value < 0 or result_limit not between 1 and 200 then raise exception 'VALIDATION_ERROR'; end if;
  with visible_changes as (
    select s.* from public.sync_changes s
    where s.household_id = household and s.sequence > cursor_value
      and (
        s.entity <> 'TRANSACTION'
        or exists (select 1 from public.transaction_aggregates a where a.id = s.entity_id
          and (a.owner_id = auth.uid() or a.scope = 'HOUSEHOLD' or a.privacy = 'PRIVATE_SUMMARY'))
      )
      and (
        s.entity <> 'BUDGET'
        or exists (select 1 from public.budgets b where b.id = s.entity_id
          and (b.owner_id is null or b.owner_id = auth.uid()))
      )
      and (
        s.entity <> 'RECURRING_OBLIGATION'
        or exists (select 1 from public.recurring_obligations o where o.id = s.entity_id
          and (o.scope = 'HOUSEHOLD' or o.owner_id = auth.uid()))
      )
    order by s.sequence limit result_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'sequence', sequence, 'entity', entity, 'entityId', entity_id,
    'operation', operation, 'changedAt', changed_at
  ) order by sequence), '[]'::jsonb), coalesce(max(sequence), cursor_value)
  into result, next_cursor from visible_changes;
  return jsonb_build_object(
    'changes', result,
    'nextCursor', next_cursor,
    'hasMore', exists(select 1 from public.sync_changes s where s.household_id = household and s.sequence > next_cursor),
    'serverTime', now()
  );
end;
$$;

create or replace function public.export_my_data()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare household uuid := public.my_active_household_id(); result jsonb;
begin
  if household is null then raise exception 'FORBIDDEN'; end if;
  select jsonb_build_object(
    'schemaVersion', 2,
    'exportedAt', now(),
    'household', (select to_jsonb(h) - 'owner_id' from public.households h where h.id = household),
    'profile', (select to_jsonb(p) from public.profiles p where p.id = auth.uid()),
    'wallets', (select coalesce(jsonb_agg(to_jsonb(w)), '[]'::jsonb) from public.wallet_balances w where w.household_id = household),
    'categories', (select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) from public.categories c
      where c.household_id = household and (c.scope = 'HOUSEHOLD' or c.owner_id = auth.uid())),
    'transactions', (select coalesce(jsonb_agg(jsonb_build_object(
      'aggregate', to_jsonb(a) - 'description' || jsonb_build_object('description',
        case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then a.description else null end),
      'entries', (select jsonb_agg(to_jsonb(e)) from public.ledger_entries e where e.aggregate_id = a.id)
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
      where o.household_id = household and (o.scope = 'HOUSEHOLD' or o.owner_id = auth.uid()))
  ) into result;
  return result;
end;
$$;

revoke all on function public.capture_sync_change() from public, anon, authenticated;
revoke all on function public.sync_changes(bigint, integer), public.export_my_data() from public, anon;
grant execute on function public.sync_changes(bigint, integer), public.export_my_data() to authenticated;
