create or replace function public.seed_household_categories()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.categories(household_id, name, direction, scope, necessity_type, system_category, created_by)
  values
    (new.id, 'Gaji', 'INCOME', 'HOUSEHOLD', null, true, new.owner_id),
    (new.id, 'Pendapatan lain', 'INCOME', 'HOUSEHOLD', null, true, new.owner_id),
    (new.id, 'Makanan', 'EXPENSE', 'HOUSEHOLD', 'REQUIRED', true, new.owner_id),
    (new.id, 'Transportasi', 'EXPENSE', 'HOUSEHOLD', 'REQUIRED', true, new.owner_id),
    (new.id, 'Tagihan', 'EXPENSE', 'HOUSEHOLD', 'REQUIRED', true, new.owner_id),
    (new.id, 'Belanja', 'EXPENSE', 'HOUSEHOLD', 'FLEXIBLE', true, new.owner_id),
    (new.id, 'Hiburan', 'EXPENSE', 'HOUSEHOLD', 'FLEXIBLE', true, new.owner_id),
    (new.id, 'Tabungan', 'EXPENSE', 'HOUSEHOLD', 'FINANCIAL', true, new.owner_id);
  return new;
end;
$$;

drop trigger if exists seed_categories_after_household on public.households;
create trigger seed_categories_after_household
after insert on public.households for each row execute function public.seed_household_categories();

insert into public.categories(household_id, name, direction, scope, necessity_type, system_category, created_by)
select h.id, defaults.name, defaults.direction, 'HOUSEHOLD'::public.transaction_scope,
       defaults.necessity_type, true, h.owner_id
from public.households h
cross join (values
  ('Gaji', 'INCOME', null), ('Pendapatan lain', 'INCOME', null),
  ('Makanan', 'EXPENSE', 'REQUIRED'), ('Transportasi', 'EXPENSE', 'REQUIRED'),
  ('Tagihan', 'EXPENSE', 'REQUIRED'), ('Belanja', 'EXPENSE', 'FLEXIBLE'),
  ('Hiburan', 'EXPENSE', 'FLEXIBLE'), ('Tabungan', 'EXPENSE', 'FINANCIAL')
) defaults(name, direction, necessity_type)
where not exists (
  select 1 from public.categories c where c.household_id = h.id and c.name = defaults.name
);

create or replace function public.my_active_household_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select household_id from public.household_members
  where user_id = auth.uid() and status = 'ACTIVE' limit 1;
$$;

create or replace function public.list_wallets()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', w.id, 'name', w.name, 'walletType', w.wallet_type,
    'balance', w.balance::text, 'isShared', w.is_shared,
    'acceptsHouseholdTransfer', w.accepts_household_transfer,
    'active', w.active, 'ownerId', w.owner_id, 'version', w.version
  ) order by w.active desc, w.name), '[]'::jsonb)
  from public.wallet_balances w
  where w.household_id = public.my_active_household_id();
$$;

create or replace function public.create_wallet(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id(); created public.wallets;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if household is null then raise exception 'FORBIDDEN'; end if;
  if char_length(btrim(payload->>'name')) not between 1 and 80 then raise exception 'VALIDATION_ERROR: wallet name'; end if;
  insert into public.wallets(household_id, owner_id, name, wallet_type, opening_balance,
    is_shared, accepts_household_transfer, created_by)
  values (household, actor, btrim(payload->>'name'), (payload->>'walletType')::public.wallet_type,
    coalesce((payload->>'openingBalance')::numeric, 0), coalesce((payload->>'isShared')::boolean, false),
    coalesce((payload->>'acceptsHouseholdTransfer')::boolean, false), actor)
  returning * into created;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'WALLET', created.id, 'CREATE', to_jsonb(created));
  return jsonb_build_object('id', created.id, 'name', created.name, 'version', created.version);
end;
$$;

create or replace function public.update_wallet(wallet_id uuid, expected_version integer, patch jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); old_record public.wallets; changed public.wallets;
begin
  select * into old_record from public.wallets where id = wallet_id and household_id = public.my_active_household_id() for update;
  if old_record.id is null then raise exception 'NOT_FOUND'; end if;
  if old_record.owner_id <> actor then raise exception 'FORBIDDEN'; end if;
  if old_record.version <> expected_version then raise exception 'VERSION_CONFLICT'; end if;
  update public.wallets set
    name = coalesce(nullif(btrim(patch->>'name'), ''), name),
    is_shared = coalesce((patch->>'isShared')::boolean, is_shared),
    accepts_household_transfer = coalesce((patch->>'acceptsHouseholdTransfer')::boolean, accepts_household_transfer),
    active = coalesce((patch->>'active')::boolean, active), updated_at = now(), version = version + 1
  where id = wallet_id returning * into changed;
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, before_value, after_value)
  values (changed.household_id, actor, 'WALLET', changed.id, 'UPDATE', to_jsonb(old_record), to_jsonb(changed));
  return jsonb_build_object('id', changed.id, 'name', changed.name, 'version', changed.version);
end;
$$;

create or replace function public.list_categories(category_direction text default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'name', c.name, 'direction', c.direction, 'scope', c.scope,
    'necessityType', c.necessity_type, 'systemCategory', c.system_category,
    'active', c.active, 'version', c.version
  ) order by c.direction, c.name), '[]'::jsonb)
  from public.categories c
  where c.household_id = public.my_active_household_id() and c.active
    and (category_direction is null or c.direction = category_direction);
$$;

create or replace function public.create_category(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id(); created public.categories;
begin
  if household is null then raise exception 'FORBIDDEN'; end if;
  if char_length(btrim(payload->>'name')) not between 1 and 80 then raise exception 'VALIDATION_ERROR'; end if;
  insert into public.categories(household_id, owner_id, name, direction, scope, necessity_type, created_by)
  values (household, actor, btrim(payload->>'name'), payload->>'direction',
    (payload->>'scope')::public.transaction_scope, nullif(payload->>'necessityType', ''), actor)
  returning * into created;
  return jsonb_build_object('id', created.id, 'name', created.name, 'version', created.version);
end;
$$;

create or replace function public.post_transaction(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id(); wallet public.wallets;
  category public.categories; aggregate public.transaction_aggregates; amount numeric; kind public.transaction_kind;
  reference uuid; result jsonb;
begin
  if household is null then raise exception 'FORBIDDEN'; end if;
  amount := (payload->>'amount')::numeric; kind := (payload->>'kind')::public.transaction_kind;
  reference := (payload->>'clientReferenceId')::uuid;
  if amount <= 0 or kind not in ('INCOME', 'EXPENSE') then raise exception 'VALIDATION_ERROR'; end if;
  select * into wallet from public.wallets where id = (payload->>'walletId')::uuid and household_id = household;
  if wallet.id is null then raise exception 'NOT_FOUND: wallet'; end if;
  if not wallet.active then raise exception 'WALLET_INACTIVE'; end if;
  select * into category from public.categories where id = (payload->>'categoryId')::uuid and household_id = household and active;
  if category.id is null or category.direction <> kind::text then raise exception 'VALIDATION_ERROR: category'; end if;
  select response_json into result from public.idempotency_records
    where actor_id = actor and operation = 'POST_TRANSACTION' and client_reference_id = reference;
  if result is not null then return result; end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, client_reference_id, created_by)
  values (household, actor, kind, (payload->>'transactionDate')::date,
    (payload->>'scope')::public.transaction_scope, (payload->>'privacyMode')::public.privacy_mode,
    nullif(btrim(payload->>'description'), ''), reference, actor) returning * into aggregate;
  insert into public.ledger_entries(aggregate_id, wallet_id, category_id, direction, amount)
  values (aggregate.id, wallet.id, category.id, case when kind = 'INCOME' then 'CREDIT' else 'DEBIT' end, amount);
  result := jsonb_build_object('id', aggregate.id, 'version', aggregate.version);
  insert into public.idempotency_records(actor_id, operation, client_reference_id, payload_hash, response_json)
  values (actor, 'POST_TRANSACTION', reference, encode(digest(payload::text, 'sha256'), 'hex'), result);
  insert into public.audit_logs(household_id, actor_id, entity_type, entity_id, action, after_value)
  values (household, actor, 'TRANSACTION', aggregate.id, 'CREATE', to_jsonb(aggregate));
  return result;
end;
$$;

create or replace function public.post_transfer(payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); household uuid := public.my_active_household_id(); source public.wallets;
  destination public.wallets; aggregate public.transaction_aggregates; transfer_record public.transfers;
  amount numeric := (payload->>'amount')::numeric; reference uuid := (payload->>'clientReferenceId')::uuid;
begin
  if amount <= 0 then raise exception 'VALIDATION_ERROR'; end if;
  select * into source from public.wallets where id = (payload->>'sourceWalletId')::uuid and household_id = household and active;
  select * into destination from public.wallets where id = (payload->>'destinationWalletId')::uuid and household_id = household and active;
  if source.id is null or destination.id is null then raise exception 'NOT_FOUND: wallet'; end if;
  if source.id = destination.id then raise exception 'TRANSFER_SAME_WALLET'; end if;
  if source.owner_id <> actor then raise exception 'FORBIDDEN'; end if;
  if destination.owner_id <> actor and not destination.accepts_household_transfer then raise exception 'FORBIDDEN'; end if;
  insert into public.transaction_aggregates(household_id, owner_id, kind, transaction_date, scope, privacy,
    description, client_reference_id, created_by)
  values (household, actor, 'TRANSFER', (payload->>'transactionDate')::date, 'HOUSEHOLD', 'HOUSEHOLD_VISIBLE',
    nullif(btrim(payload->>'description'), ''), reference, actor) returning * into aggregate;
  insert into public.transfers(aggregate_id, source_wallet_id, destination_wallet_id, amount)
  values (aggregate.id, source.id, destination.id, amount) returning * into transfer_record;
  insert into public.ledger_entries(aggregate_id, wallet_id, direction, amount)
  values (aggregate.id, source.id, 'DEBIT', amount), (aggregate.id, destination.id, 'CREDIT', amount);
  return jsonb_build_object('id', aggregate.id, 'transferId', transfer_record.id, 'version', aggregate.version);
end;
$$;

create or replace function public.list_transactions(result_limit integer default 50)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row_data order by transaction_date desc, id desc), '[]'::jsonb)
  from (
    select a.id, a.transaction_date, a.kind::text, a.scope::text, a.status::text,
      case when a.owner_id = auth.uid() or a.privacy = 'HOUSEHOLD_VISIBLE' then a.description else null end description,
      e.amount::text amount, e.direction::text direction, w.name wallet_name, c.name category_name,
      a.owner_id = auth.uid() is_owner
    from public.transaction_aggregates a
    join public.ledger_entries e on e.aggregate_id = a.id
    join public.wallets w on w.id = e.wallet_id
    left join public.categories c on c.id = e.category_id
    where a.household_id = public.my_active_household_id()
      and (a.kind <> 'TRANSFER' or e.direction = 'DEBIT')
    order by a.transaction_date desc, a.id desc limit least(result_limit, 200)
  ) row_data;
$$;

create or replace function public.dashboard_summary()
returns jsonb language sql stable security definer set search_path = '' as $$
  with balances as (
    select coalesce(sum(balance), 0) total from public.wallet_balances
    where household_id = public.my_active_household_id() and active
  ), flow as (
    select
      coalesce(sum(e.amount) filter (where a.kind = 'INCOME'), 0) income,
      coalesce(sum(e.amount) filter (where a.kind = 'EXPENSE'), 0) expense
    from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
    where a.household_id = public.my_active_household_id() and a.status = 'POSTED'
      and date_trunc('month', a.transaction_date) = date_trunc('month', current_date)
  ) select jsonb_build_object('totalBalance', balances.total::text,
    'monthlyIncome', flow.income::text, 'monthlyExpense', flow.expense::text)
  from balances cross join flow;
$$;

create or replace function public.report_category()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('category', name, 'amount', amount::text) order by amount desc), '[]'::jsonb)
  from (
    select coalesce(c.name, 'Tanpa kategori') name, sum(e.amount) amount
    from public.transaction_aggregates a join public.ledger_entries e on e.aggregate_id = a.id
    left join public.categories c on c.id = e.category_id
    where a.household_id = public.my_active_household_id() and a.kind = 'EXPENSE' and a.status = 'POSTED'
      and date_trunc('month', a.transaction_date) = date_trunc('month', current_date)
    group by c.name
  ) data;
$$;

revoke all on function public.my_active_household_id() from public;
grant execute on function public.my_active_household_id() to authenticated;
grant execute on function public.list_wallets(), public.create_wallet(jsonb), public.update_wallet(uuid, integer, jsonb),
  public.list_categories(text), public.create_category(jsonb), public.post_transaction(jsonb), public.post_transfer(jsonb),
  public.list_transactions(integer), public.dashboard_summary(), public.report_category() to authenticated;
