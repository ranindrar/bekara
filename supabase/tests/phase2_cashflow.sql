begin;
create extension if not exists pgtap;
set local role postgres;
set local search_path = extensions, public;

select plan(22);

select has_table('public', 'member_period_settings', 'personal period settings exist');
select has_table('public', 'financial_periods', 'financial periods exist');
select has_table('public', 'budgets', 'budgets exist');
select has_table('public', 'locked_funds', 'soft locked funds exist');
select has_table('public', 'recurring_obligations', 'recurring obligations exist');
select has_table('public', 'obligation_occurrences', 'obligation occurrences exist');
select has_table('public', 'sync_changes', 'monotonic sync feed exists');
select has_type('public', 'period_type', 'period type enum exists');
select has_type('public', 'period_status', 'period status enum exists');
select has_type('public', 'recurrence_frequency', 'MVP recurrence enum exists');
select is(public.clamped_month_date('2028-02-01'::date, 31), '2028-02-29'::date,
  'day 31 clamps to leap-year month end');
select is((select start_date from public.period_bounds('2026-08-03'::date, 25)),
  '2026-07-25'::date, '25-24 period maps to previous month');
select is(public.next_recurrence_date('2028-01-31'::date, 'MONTHLY', 31),
  '2028-02-29'::date, 'monthly recurrence clamps to month end');
select is(public.budget_health(749, 1000), 'SAFE', 'budget below 75 percent is safe');
select is(public.budget_health(1001, 1000), 'EXCEEDED', 'budget above plan is exceeded');
select ok(not has_function_privilege('anon', 'public.sync_changes(bigint,integer)', 'EXECUTE'),
  'anonymous cannot access sync feed');
select ok(has_function_privilege('authenticated', 'public.sync_changes(bigint,integer)', 'EXECUTE'),
  'authenticated user can access sync feed');
select ok(not has_function_privilege('anon', 'public.export_my_data()', 'EXECUTE'),
  'anonymous cannot export financial data');
select ok(exists(select 1 from pg_trigger where tgname = 'transaction_period_guard' and not tgisinternal),
  'transaction period guard is installed');
select ok(exists(select 1 from pg_indexes where schemaname = 'public'
  and indexname = 'sync_changes_household_sequence_idx'), 'sync cursor index exists');
select ok(exists(select 1 from pg_trigger where tgname = 'budget_target_guard' and not tgisinternal),
  'budget scope guard is installed');
select ok(exists(select 1 from pg_trigger where tgname = 'ledger_soft_lock_guard' and not tgisinternal),
  'soft locked fund guard is installed');

select * from finish();
rollback;
