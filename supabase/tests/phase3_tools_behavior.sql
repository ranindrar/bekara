begin;
create extension if not exists pgtap;
set local role postgres;
set local search_path = extensions, public;

select plan(23);

insert into auth.users(id, email, raw_user_meta_data, is_sso_user, is_anonymous, created_at, updated_at)
values
  ('40000000-0000-0000-0000-000000000001', 'phase3-tools-owner@example.test',
    '{"display_name":"Pemilik Tools"}', false, false, now(), now()),
  ('40000000-0000-0000-0000-000000000002', 'phase3-tools-member@example.test',
    '{"display_name":"Anggota Tools"}', false, false, now(), now());

insert into public.households(id, name, owner_id, reporting_start_day)
values ('40000000-0000-0000-0000-000000000010', 'Rumah Tools',
  '40000000-0000-0000-0000-000000000001', 25);
insert into public.household_members(household_id, user_id, role, status)
values
  ('40000000-0000-0000-0000-000000000010', '40000000-0000-0000-0000-000000000001', 'OWNER', 'ACTIVE'),
  ('40000000-0000-0000-0000-000000000010', '40000000-0000-0000-0000-000000000002', 'MEMBER', 'ACTIVE');
insert into public.wallets(id, household_id, owner_id, name, wallet_type, opening_balance,
  is_shared, accepts_household_transfer, created_by)
values ('40000000-0000-0000-0000-000000000020', '40000000-0000-0000-0000-000000000010',
  '40000000-0000-0000-0000-000000000001', 'Kas household', 'BANK_ACCOUNT', 1000,
  true, true, '40000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);

select throws_ok($test$
  select public.create_credit_account(jsonb_build_object(
    'clientReferenceId', '41000000-0000-0000-0000-000000000001',
    'accountType', 'PAYLATER', 'scope', 'HOUSEHOLD', 'providerName', 'Invalid Pay',
    'accountName', 'PayLater household', 'creditLimit', '1000',
    'openingLiability', '0', 'statementDay', '8', 'dueDay', '20'))
$test$, 'P0001', 'VALIDATION_ERROR: paylater scope', 'PayLater household is rejected');

select lives_ok($test$
  select public.create_credit_account(jsonb_build_object(
    'clientReferenceId', '41000000-0000-0000-0000-000000000002',
    'accountType', 'CREDIT_CARD', 'scope', 'HOUSEHOLD', 'providerName', 'Family Card',
    'accountName', 'Kartu keluarga', 'creditLimit', '5000',
    'openingLiability', '0', 'statementDay', '8', 'dueDay', '20'))
$test$, 'owner creates household credit card');
select is((select scope::text from public.credit_accounts where provider_name = 'Family Card'),
  'HOUSEHOLD', 'household card keeps household scope');

select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000002', true);
select is(jsonb_array_length(public.list_credit_accounts()), 1,
  'active household member sees household card');
select lives_ok($test$
  select public.post_credit_purchase(jsonb_build_object(
    'clientReferenceId', '41000000-0000-0000-0000-000000000003',
    'accountId', (select id from public.credit_accounts where provider_name = 'Family Card'),
    'categoryId', (select id from public.categories where household_id = '40000000-0000-0000-0000-000000000010'
      and name = 'Makanan' and scope = 'HOUSEHOLD' limit 1),
    'principal', '300', 'financingCost', '0', 'tenor', 1,
    'description', 'Belanja keluarga', 'transactionDate', current_date,
    'scope', 'PRIVATE', 'privacyMode', 'PRIVATE_FULL'))
$test$, 'member can use household card');
select is((select scope::text from public.credit_purchases where description = 'Belanja keluarga'),
  'HOUSEHOLD', 'household card forces household purchase scope');
select is((select privacy::text from public.credit_purchases where description = 'Belanja keluarga'),
  'HOUSEHOLD_VISIBLE', 'household card forces visible privacy');
select lives_ok($test$
  select public.pay_credit_bill(jsonb_build_object(
    'clientReferenceId', '41000000-0000-0000-0000-000000000004',
    'accountId', (select id from public.credit_accounts where provider_name = 'Family Card'),
    'sourceWalletId', '40000000-0000-0000-0000-000000000020',
    'amount', '100', 'paymentDate', current_date, 'description', 'Bayar anggota'))
$test$, 'member can pay household card from shared cash');
select is((select paid_by::text from public.credit_payments limit 1),
  '40000000-0000-0000-0000-000000000002', 'payer identity is retained');

update public.billing_periods set due_date = current_date + 7, status = 'OPEN', issued_at = now() - interval '1 day'
where credit_account_id = (select id from public.credit_accounts where provider_name = 'Family Card');
select is((public.list_credit_notifications()->0->>'eventType'), 'H-7',
  'H-7 notification is generated for outstanding bill');
select lives_ok($test$
  select public.mark_credit_notification(
    (public.list_credit_notifications()->0->>'eventKey'), true)
$test$, 'notification can be dismissed');
select is(jsonb_array_length(public.list_credit_notifications()), 0,
  'dismissed notification is deduplicated');

select lives_ok($test$
  select public.commit_import_batch(jsonb_build_object(
    'sourceHash', repeat('a', 64), 'fileName', 'mutasi.csv',
    'rows', jsonb_build_array(
      jsonb_build_object('clientReferenceId', '41000000-0000-0000-0000-000000000005',
        'walletId', '40000000-0000-0000-0000-000000000020',
        'categoryId', (select id from public.categories where household_id = '40000000-0000-0000-0000-000000000010'
          and name = 'Makanan' and scope = 'HOUSEHOLD' limit 1),
        'kind', 'EXPENSE', 'amount', '10', 'description', 'Import makan',
        'transactionDate', current_date, 'scope', 'HOUSEHOLD', 'privacyMode', 'HOUSEHOLD_VISIBLE'),
      jsonb_build_object('clientReferenceId', '41000000-0000-0000-0000-000000000006',
        'walletId', '40000000-0000-0000-0000-000000000020',
        'categoryId', (select id from public.categories where household_id = '40000000-0000-0000-0000-000000000010'
          and name = 'Gaji' and scope = 'HOUSEHOLD' limit 1),
        'kind', 'INCOME', 'amount', '20', 'description', 'Import gaji',
        'transactionDate', current_date, 'scope', 'HOUSEHOLD', 'privacyMode', 'HOUSEHOLD_VISIBLE'))))
$test$, 'valid import batch commits atomically');
select is((select count(*)::integer from public.import_batches), 1,
  'one import batch is recorded');
select is((select count(*)::integer from public.import_batch_rows), 2,
  'all import rows are linked');
select is((public.commit_import_batch(jsonb_build_object(
    'sourceHash', repeat('a', 64), 'fileName', 'mutasi.csv',
    'rows', jsonb_build_array(jsonb_build_object('ignored', true))))->>'duplicate')::boolean,
  true, 'same source hash is idempotent');
select is((select count(*)::integer from public.import_batches), 1,
  'retry does not duplicate import batch');

insert into storage.objects(bucket_id, name, owner, owner_id, metadata)
select 'receipts',
  '40000000-0000-0000-0000-000000000010/40000000-0000-0000-0000-000000000002/' ||
    r.transaction_id || '/receipt.pdf',
  '40000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000002',
  '{"mimetype":"application/pdf","size":42}'::jsonb
from public.import_batch_rows r order by row_number limit 1;
select lives_ok($test$
  select public.register_attachment(jsonb_build_object(
    'transactionId', (select transaction_id from public.import_batch_rows order by row_number limit 1),
    'objectKey', (select name from storage.objects where name like '%/receipt.pdf'),
    'originalName', 'receipt.pdf', 'contentType', 'application/pdf', 'fileSize', 42))
$test$, 'matching private object metadata can be registered');
select is(jsonb_array_length(public.list_transaction_attachments(
    (select transaction_id from public.import_batch_rows order by row_number limit 1))), 1,
  'attachment owner can list receipt metadata');

select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select is(jsonb_array_length(public.list_transaction_attachments(
    (select transaction_id from public.import_batch_rows order by row_number limit 1))), 1,
  'household member can list household receipt');
insert into storage.objects(bucket_id, name, owner, owner_id, metadata)
select 'receipts',
  '40000000-0000-0000-0000-000000000010/40000000-0000-0000-0000-000000000001/' ||
    r.transaction_id || '/spoof.pdf',
  '40000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001',
  '{"mimetype":"image/png","size":42}'::jsonb
from public.import_batch_rows r order by row_number limit 1;
select throws_ok($test$
  select public.register_attachment(jsonb_build_object(
    'transactionId', (select transaction_id from public.import_batch_rows order by row_number limit 1),
    'objectKey', (select name from storage.objects where name like '%/spoof.pdf'),
    'originalName', 'spoof.pdf', 'contentType', 'application/pdf', 'fileSize', 42))
$test$, 'P0001', 'ATTACHMENT_METADATA_INVALID', 'MIME spoofing is rejected');
select lives_ok($test$
  select public.delete_attachment((select id from public.transaction_attachments limit 1))
$test$, 'household attachment deletion is audited');
select is(jsonb_array_length(public.list_transaction_attachments(
    (select transaction_id from public.import_batch_rows order by row_number limit 1))), 0,
  'deleted attachment is not listed');

select * from finish();
rollback;
