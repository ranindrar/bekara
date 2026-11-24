begin;
create extension if not exists pgtap;
set local role postgres;
set local search_path = extensions, public;

select plan(36);

select has_type('public', 'credit_account_status', 'credit account status exists');
select has_type('public', 'billing_period_status', 'billing status exists');
select has_type('public', 'installment_status', 'installment status exists');
select has_type('public', 'import_batch_status', 'import batch status exists');

select has_table('public', 'credit_accounts', 'credit accounts exist');
select has_table('public', 'billing_periods', 'billing periods exist');
select has_table('public', 'credit_purchases', 'credit purchases exist');
select has_table('public', 'installment_schedules', 'installment schedules exist');
select has_table('public', 'credit_payments', 'credit payments exist');
select has_table('public', 'credit_payment_allocations', 'payment allocations exist');
select has_table('public', 'notification_receipts', 'notification receipts exist');
select has_table('public', 'import_batches', 'import batches exist');
select has_table('public', 'transaction_attachments', 'transaction attachments exist');

select is((select cycle_start from public.credit_cycle_bounds('2026-08-25', 25)),
  '2026-07-26'::date, 'cutoff day belongs to ending cycle');
select is((select cycle_end from public.credit_cycle_bounds('2026-08-25', 25)),
  '2026-08-25'::date, 'cutoff is inclusive');
select is((select cycle_end from public.credit_cycle_bounds('2026-08-26', 25)),
  '2026-09-25'::date, 'day after cutoff enters next cycle');
select is(public.credit_due_date('2026-08-25', 10), '2026-09-10'::date,
  'due day before cutoff moves to next month');
select is(public.credit_due_date('2026-08-25', 30), '2026-08-30'::date,
  'due day after cutoff stays in month');
select is(public.credit_due_date('2027-01-31', 30), '2027-02-28'::date,
  'due day clamps to month end');

select ok((select relrowsecurity from pg_class where oid = 'public.credit_accounts'::regclass),
  'credit accounts have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.billing_periods'::regclass),
  'billing periods have RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.transaction_attachments'::regclass),
  'attachments have RLS');
select ok(exists(select 1 from pg_policies where schemaname = 'public'
  and tablename = 'credit_accounts' and policyname = 'credit_accounts_visible_read'),
  'credit account visibility policy exists');
select ok(exists(select 1 from pg_policies where schemaname = 'storage'
  and tablename = 'objects' and policyname = 'receipts_select'),
  'private receipt read policy exists');
select ok(exists(select 1 from storage.buckets where id = 'receipts' and not public),
  'receipt bucket is private');

select ok(not has_function_privilege('anon', 'public.create_credit_account(jsonb)', 'EXECUTE'),
  'anonymous cannot create credit account');
select ok(has_function_privilege('authenticated', 'public.create_credit_account(jsonb)', 'EXECUTE'),
  'authenticated can create credit account');
select ok(not has_function_privilege('anon', 'public.post_credit_purchase(jsonb)', 'EXECUTE'),
  'anonymous cannot post credit purchase');
select ok(has_function_privilege('authenticated', 'public.post_credit_purchase(jsonb)', 'EXECUTE'),
  'authenticated can post credit purchase');
select ok(not has_function_privilege('anon', 'public.pay_credit_bill(jsonb)', 'EXECUTE'),
  'anonymous cannot pay bill');
select ok(has_function_privilege('authenticated', 'public.pay_credit_bill(jsonb)', 'EXECUTE'),
  'authenticated can pay bill');
select ok(not has_function_privilege('authenticated',
  'public.ensure_credit_billing_period(uuid,date)', 'EXECUTE'),
  'client cannot call internal billing generator directly');
select ok(not has_function_privilege('anon', 'public.commit_import_batch(jsonb)', 'EXECUTE'),
  'anonymous cannot commit import');
select ok(has_function_privilege('authenticated', 'public.commit_import_batch(jsonb)', 'EXECUTE'),
  'authenticated can commit import');
select ok(not has_function_privilege('anon', 'public.register_attachment(jsonb)', 'EXECUTE'),
  'anonymous cannot register attachment');
select ok(has_function_privilege('authenticated', 'public.register_attachment(jsonb)', 'EXECUTE'),
  'authenticated can register attachment');

select * from finish();
rollback;
