create extension if not exists pgcrypto;

create type public.member_role as enum ('OWNER', 'MEMBER');
create type public.member_status as enum ('ACTIVE', 'LEFT', 'REMOVED');
create type public.wallet_type as enum ('BANK_ACCOUNT', 'CASH', 'E_WALLET', 'SAVING', 'CREDIT_CARD', 'PAYLATER', 'OTHER');
create type public.transaction_kind as enum ('INCOME', 'EXPENSE', 'TRANSFER', 'ADJUSTMENT', 'REVERSAL', 'BILL_PAYMENT');
create type public.entry_direction as enum ('DEBIT', 'CREDIT');
create type public.transaction_scope as enum ('PRIVATE', 'HOUSEHOLD');
create type public.privacy_mode as enum ('PRIVATE_FULL', 'PRIVATE_SUMMARY', 'HOUSEHOLD_VISIBLE');
create type public.aggregate_status as enum ('POSTED', 'REVERSED');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  timezone text not null default 'Asia/Jakarta',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 100),
  currency text not null default 'IDR' check (currency = 'IDR'),
  timezone text not null default 'Asia/Jakarta',
  reporting_start_day smallint not null default 25 check (reporting_start_day between 1 and 31),
  owner_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  user_id uuid not null references public.profiles(id),
  role public.member_role not null,
  status public.member_status not null default 'ACTIVE',
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  unique (household_id, user_id)
);

create unique index one_active_household_per_user
  on public.household_members(user_id) where status = 'ACTIVE';

create table public.wallets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  owner_id uuid not null references public.profiles(id),
  name text not null check (char_length(name) between 1 and 80),
  wallet_type public.wallet_type not null,
  opening_balance numeric(19,2) not null default 0,
  is_shared boolean not null default false,
  accepts_household_transfer boolean not null default false,
  active boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households(id),
  owner_id uuid references public.profiles(id),
  name text not null check (char_length(name) between 1 and 80),
  direction text not null check (direction in ('INCOME', 'EXPENSE')),
  scope public.transaction_scope not null,
  necessity_type text check (necessity_type in ('REQUIRED', 'FLEXIBLE', 'FINANCIAL')),
  system_category boolean not null default false,
  active boolean not null default true,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  check (household_id is not null or system_category)
);

create table public.transaction_aggregates (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  owner_id uuid not null references public.profiles(id),
  kind public.transaction_kind not null,
  transaction_date date not null,
  scope public.transaction_scope not null,
  privacy public.privacy_mode not null,
  description text,
  status public.aggregate_status not null default 'POSTED',
  reversal_of_id uuid references public.transaction_aggregates(id),
  client_reference_id uuid not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  unique (created_by, client_reference_id),
  check ((scope = 'HOUSEHOLD' and privacy = 'HOUSEHOLD_VISIBLE') or scope = 'PRIVATE')
);

create table public.transfers (
  id uuid primary key default gen_random_uuid(),
  aggregate_id uuid not null unique references public.transaction_aggregates(id),
  source_wallet_id uuid not null references public.wallets(id),
  destination_wallet_id uuid not null references public.wallets(id),
  amount numeric(19,2) not null check (amount > 0),
  fee_amount numeric(19,2) not null default 0 check (fee_amount >= 0),
  reversed_at timestamptz,
  check (source_wallet_id <> destination_wallet_id)
);

create table public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  aggregate_id uuid not null references public.transaction_aggregates(id),
  wallet_id uuid not null references public.wallets(id),
  category_id uuid references public.categories(id),
  direction public.entry_direction not null,
  amount numeric(19,2) not null check (amount > 0),
  created_at timestamptz not null default now()
);

create table public.idempotency_records (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id),
  operation text not null,
  client_reference_id uuid not null,
  payload_hash text not null,
  response_json jsonb,
  created_at timestamptz not null default now(),
  unique (actor_id, operation, client_reference_id)
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id),
  actor_id uuid not null references public.profiles(id),
  entity_type text not null,
  entity_id uuid not null,
  action text not null,
  before_value jsonb,
  after_value jsonb,
  reason text,
  request_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create index ledger_entries_wallet_created_idx on public.ledger_entries(wallet_id, created_at);
create index transactions_household_date_idx on public.transaction_aggregates(household_id, transaction_date desc, id);
create index audit_entity_idx on public.audit_logs(household_id, entity_type, entity_id, created_at desc);

create or replace function public.is_active_household_member(target_household_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.household_members m
    where m.household_id = target_household_id
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
  );
$$;

create or replace view public.wallet_balances with (security_invoker = true) as
select w.*,
  w.opening_balance + coalesce(sum(case e.direction when 'CREDIT' then e.amount else -e.amount end), 0) as balance
from public.wallets w
left join public.ledger_entries e on e.wallet_id = w.id
group by w.id;

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.wallets enable row level security;
alter table public.categories enable row level security;
alter table public.transaction_aggregates enable row level security;
alter table public.transfers enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.idempotency_records enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_self_read on public.profiles for select using (id = auth.uid());
create policy profiles_self_update on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
create policy households_member_read on public.households for select using (public.is_active_household_member(id));
create policy members_member_read on public.household_members for select using (public.is_active_household_member(household_id));
create policy wallets_member_read on public.wallets for select using (public.is_active_household_member(household_id));
create policy categories_member_read on public.categories for select using (system_category or public.is_active_household_member(household_id));
create policy transactions_member_read on public.transaction_aggregates for select using (public.is_active_household_member(household_id));
create policy transfers_member_read on public.transfers for select using (
  exists (select 1 from public.transaction_aggregates a where a.id = aggregate_id and public.is_active_household_member(a.household_id))
);
create policy ledger_member_read on public.ledger_entries for select using (
  exists (select 1 from public.transaction_aggregates a where a.id = aggregate_id and public.is_active_household_member(a.household_id))
);

revoke insert, update, delete on public.ledger_entries from anon, authenticated;
revoke insert, update, delete on public.transaction_aggregates from anon, authenticated;
revoke all on public.idempotency_records from anon, authenticated;
revoke all on public.audit_logs from anon, authenticated;

comment on schema public is 'Dompet Keluarga P0. Financial writes are added through audited RPC migrations.';
