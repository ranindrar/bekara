begin;
create extension if not exists pgtap;
set local role postgres;
set local search_path = extensions, public;

select plan(23);

insert into auth.users(id, email, raw_user_meta_data, is_sso_user, is_anonymous, created_at, updated_at)
values
  ('30000000-0000-0000-0000-000000000001', 'phase3-owner@example.test',
    '{"display_name":"Pemilik"}', false, false, now(), now()),
  ('30000000-0000-0000-0000-000000000002', 'phase3-member@example.test',
    '{"display_name":"Anggota"}', false, false, now(), now());

insert into public.households(id, name, owner_id, reporting_start_day)
values ('30000000-0000-0000-0000-000000000010', 'Rumah Uji Fase 3',
  '30000000-0000-0000-0000-000000000001', 25);
insert into public.household_members(household_id, user_id, role, status)
values
  ('30000000-0000-0000-0000-000000000010', '30000000-0000-0000-0000-000000000001', 'OWNER', 'ACTIVE'),
  ('30000000-0000-0000-0000-000000000010', '30000000-0000-0000-0000-000000000002', 'MEMBER', 'ACTIVE');
insert into public.wallets(id, household_id, owner_id, name, wallet_type, opening_balance,
  is_shared, accepts_household_transfer, created_by)
values ('30000000-0000-0000-0000-000000000020', '30000000-0000-0000-0000-000000000010',
  '30000000-0000-0000-0000-000000000001', 'Kas uji', 'BANK_ACCOUNT', 2000,
  true, true, '30000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000001', true);

select lives_ok($test$
  select public.create_credit_account(jsonb_build_object(
    'clientReferenceId', '31000000-0000-0000-0000-000000000001',
    'accountType', 'PAYLATER', 'scope', 'PRIVATE', 'providerName', 'PayFast',
    'accountName', 'PayLater pribadi', 'creditLimit', '5000',
    'openingLiability', '0', 'statementDay', '8', 'dueDay', '20'))
$test$, 'owner can create personal PayLater');

select is((select scope::text from public.credit_accounts where provider_name = 'PayFast'),
  'PRIVATE', 'PayLater remains personal');

select lives_ok($test$
  select public.post_credit_purchase(jsonb_build_object(
    'clientReferenceId', '31000000-0000-0000-0000-000000000002',
    'accountId', (select id from public.credit_accounts where provider_name = 'PayFast'),
    'categoryId', (select id from public.categories where household_id = '30000000-0000-0000-0000-000000000010'
      and name = 'Makanan' and scope = 'HOUSEHOLD' limit 1),
    'principal', '1000', 'financingCost', '200', 'tenor', 6,
    'description', 'Cicilan kebutuhan rumah', 'transactionDate', current_date,
    'scope', 'HOUSEHOLD', 'privacyMode', 'HOUSEHOLD_VISIBLE'))
$test$, 'personal PayLater can fund household installment purchase');

select is((select balance from public.wallet_balances where id = (
    select wallet_id from public.credit_accounts where provider_name = 'PayFast')),
  '-1200.00'::numeric, 'credit purchase increases liability without touching cash');
select is((select count(*)::integer from public.installment_schedules where credit_account_id = (
    select id from public.credit_accounts where provider_name = 'PayFast')),
  6, 'six-month purchase creates six installments');
select is((select sum(principal_amount + fee_amount) from public.installment_schedules where credit_account_id = (
    select id from public.credit_accounts where provider_name = 'PayFast')),
  '1200.00'::numeric, 'installment rounding preserves total liability');
select is((select principal_amount + fee_amount from public.installment_schedules where credit_account_id = (
    select id from public.credit_accounts where provider_name = 'PayFast') order by installment_number limit 1),
  '199.99'::numeric, 'rounding is deterministic before final installment');

select lives_ok($test$
  select public.create_credit_account(jsonb_build_object(
    'clientReferenceId', '31000000-0000-0000-0000-000000000003',
    'accountType', 'CREDIT_CARD', 'scope', 'PRIVATE', 'providerName', 'CardMix',
    'accountName', 'Kartu campuran', 'creditLimit', '5000',
    'openingLiability', '0', 'statementDay', '8', 'dueDay', '20'))
$test$, 'owner can create personal credit card');

select lives_ok($test$
  select public.post_credit_purchase(jsonb_build_object(
    'clientReferenceId', '31000000-0000-0000-0000-000000000004',
    'accountId', (select id from public.credit_accounts where provider_name = 'CardMix'),
    'categoryId', (select id from public.categories where household_id = '30000000-0000-0000-0000-000000000010'
      and name = 'Belanja' and scope = 'HOUSEHOLD' limit 1),
    'principal', '600', 'financingCost', '0', 'tenor', 1,
    'description', 'Belanja household', 'transactionDate', current_date,
    'scope', 'HOUSEHOLD', 'privacyMode', 'HOUSEHOLD_VISIBLE'))
$test$, 'personal credit records household purchase');

insert into public.categories(id, household_id, owner_id, name, direction, scope,
  necessity_type, system_category, active, created_by)
values ('30000000-0000-0000-0000-000000000030', '30000000-0000-0000-0000-000000000010',
  '30000000-0000-0000-0000-000000000001', 'Pribadi uji', 'EXPENSE', 'PRIVATE',
  'FLEXIBLE', false, true, '30000000-0000-0000-0000-000000000001');

select lives_ok($test$
  select public.post_credit_purchase(jsonb_build_object(
    'clientReferenceId', '31000000-0000-0000-0000-000000000005',
    'accountId', (select id from public.credit_accounts where provider_name = 'CardMix'),
    'categoryId', '30000000-0000-0000-0000-000000000030',
    'principal', '400', 'financingCost', '0', 'tenor', 1,
    'description', 'Belanja private', 'transactionDate', current_date,
    'scope', 'PRIVATE', 'privacyMode', 'PRIVATE_FULL'))
$test$, 'personal credit records private purchase');

select is((select balance from public.wallet_balances where id = '30000000-0000-0000-0000-000000000020'),
  '2000.00'::numeric, 'credit purchases do not reduce cash');

select lives_ok($test$
  select public.pay_credit_bill(jsonb_build_object(
    'clientReferenceId', '31000000-0000-0000-0000-000000000006',
    'accountId', (select id from public.credit_accounts where provider_name = 'CardMix'),
    'sourceWalletId', '30000000-0000-0000-0000-000000000020',
    'amount', '500', 'paymentDate', current_date, 'description', 'Bayar sebagian'))
$test$, 'partial payment posts atomically');

select is((select balance from public.wallet_balances where id = '30000000-0000-0000-0000-000000000020'),
  '1500.00'::numeric, 'payment reduces cash once');
select is((select balance from public.wallet_balances where id = (
    select wallet_id from public.credit_accounts where provider_name = 'CardMix')),
  '-500.00'::numeric, 'payment reduces liability');
select is((select sum((principal_amount + fee_amount) -
    (paid_principal + paid_fee + credited_principal + credited_fee))
    from public.installment_schedules where credit_account_id = (
      select id from public.credit_accounts where provider_name = 'CardMix') and scope = 'HOUSEHOLD'),
  '300.00'::numeric, 'partial payment leaves proportional household outstanding');
select is((select sum((principal_amount + fee_amount) -
    (paid_principal + paid_fee + credited_principal + credited_fee))
    from public.installment_schedules where credit_account_id = (
      select id from public.credit_accounts where provider_name = 'CardMix') and scope = 'PRIVATE'),
  '200.00'::numeric, 'partial payment leaves proportional private outstanding');
select is((public.dashboard_summary()->>'monthlyExpense')::numeric,
  '1800.00'::numeric, 'household dashboard counts purchases and fee but not bill payment');
select is((public.credit_forecast()->>'personalDue')::numeric,
  '699.99'::numeric, 'owner forecast sees full personal due in horizon');
select is((public.credit_forecast()->>'householdReserve')::numeric,
  '499.99'::numeric, 'household forecast sees only household-scoped reserve');

select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000002', true);
select is(jsonb_array_length(public.list_credit_accounts()), 0,
  'partner cannot list personal credit accounts');
select is((public.credit_forecast()->>'personalDue')::numeric, '0'::numeric,
  'partner personal forecast excludes owner bill');
select is((public.credit_forecast()->>'householdReserve')::numeric,
  '499.99'::numeric, 'partner receives same aggregate household reserve');
select ok(not (public.export_my_data()->'creditAccounts' @> '[{"provider_name":"PayFast"}]'::jsonb),
  'partner export does not expose personal credit account');

select * from finish();
rollback;
