create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      split_part(coalesce(new.email, 'Pengguna'), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

insert into public.profiles (id, display_name)
select
  u.id,
  coalesce(
    nullif(trim(u.raw_user_meta_data ->> 'display_name'), ''),
    split_part(coalesce(u.email, 'Pengguna'), '@', 1)
  )
from auth.users u
on conflict (id) do nothing;

drop policy if exists transactions_member_read on public.transaction_aggregates;
create policy transactions_visible_read
on public.transaction_aggregates
for select
using (
  public.is_active_household_member(household_id)
  and (owner_id = auth.uid() or scope = 'HOUSEHOLD')
);

drop policy if exists ledger_member_read on public.ledger_entries;
create policy ledger_visible_read
on public.ledger_entries
for select
using (
  exists (
    select 1
    from public.transaction_aggregates a
    where a.id = aggregate_id
      and public.is_active_household_member(a.household_id)
      and (a.owner_id = auth.uid() or a.scope = 'HOUSEHOLD')
  )
);

comment on policy transactions_visible_read on public.transaction_aggregates is
  'Raw transaction rows are visible to the owner or to all members for HOUSEHOLD scope. Private summaries require a masked RPC/view added separately.';
