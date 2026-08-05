begin;
create extension if not exists pgtap;
set local role postgres;
set local search_path = extensions, public;

select plan(10);

select ok(not has_function_privilege('anon', 'public.post_transaction(jsonb)', 'EXECUTE'),
  'anonymous cannot post transactions');
select ok(not has_function_privilege('anon', 'public.post_transfer(jsonb)', 'EXECUTE'),
  'anonymous cannot post transfers');
select ok(not has_function_privilege('anon', 'public.list_transactions(integer)', 'EXECUTE'),
  'anonymous cannot list transactions');
select ok(not has_function_privilege('anon', 'public.list_categories(text)', 'EXECUTE'),
  'anonymous cannot list categories');
select ok(has_function_privilege('authenticated', 'public.post_transaction(jsonb)', 'EXECUTE'),
  'authenticated user can call transaction RPC');
select ok(has_function_privilege('authenticated', 'public.post_transfer(jsonb)', 'EXECUTE'),
  'authenticated user can call transfer RPC');
select ok(has_function_privilege('authenticated', 'public.list_transactions(integer)', 'EXECUTE'),
  'authenticated user can call masked transaction list');
select ok(exists(select 1 from pg_policies where schemaname = 'public' and tablename = 'categories'
  and policyname = 'categories_visible_read'), 'category privacy policy exists');
select ok(not exists(select 1 from pg_policies where schemaname = 'public' and tablename = 'categories'
  and policyname = 'categories_member_read'), 'over-broad category policy was removed');
select ok((select prosecdef from pg_proc join pg_namespace on pg_namespace.oid = pg_proc.pronamespace
  where nspname = 'public' and proname = 'list_transactions'),
  'masked list runs as a controlled security definer function');

select * from finish();
rollback;
