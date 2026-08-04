# Database Schema — Supabase PostgreSQL

## 1. Standar

Semua tabel domain memakai UUID PK, `created_at`, `updated_at`, `created_by`, dan `version`. Tabel finansial menggunakan soft-state/reversal, bukan hard delete. Semua tabel mengaktifkan RLS.

## 2. Tabel P0

| Tabel | Kolom domain utama | Constraint penting |
|---|---|---|
| `profiles` | id=auth.users.id, name, timezone | satu per auth user |
| `households` | name, currency, timezone, reporting_start_day, owner_id | currency IDR P0 |
| `household_members` | household_id, user_id, role, status | satu membership aktif/user |
| `household_invitations` | token_hash, email, expires_at, used_at | token sekali pakai |
| `member_period_settings` | member_id, start_day, salary_day, frequency | unique member |
| `financial_periods` | household_id, member_id nullable, type, start/end, status | rentang valid, unique scope/range |
| `wallets` | owner_id, household_id, type, opening_balance, is_shared, accepts_transfer, active | owner anggota household |
| `categories` | household_id, owner_id nullable, direction, scope, necessity_type | nama unik dalam scope aktif |
| `transaction_aggregates` | kind, owner_id, household_id, date, scope, privacy_mode, status, version | valid privacy combination |
| `ledger_entries` | aggregate_id, wallet_id, direction, amount, category_id, transfer_id nullable | amount > 0 |
| `transfers` | source_wallet_id, destination_wallet_id, amount, fee_aggregate_id, status | source != destination |
| `transaction_notes` | transaction_id, author_id, note | author anggota household |
| `audit_logs` | actor_id, action, entity, before/after, reason, request_id | append-only |
| `idempotency_records` | actor_id, operation, client_reference_id, payload_hash, response | unique actor/operation/reference |
| `sync_changes` | sequence bigint identity, household_id, entity, entity_id, operation | cursor monotonic |

## 3. Enum/check values

```text
member_role       OWNER, MEMBER
member_status     INVITED, ACTIVE, LEFT, REMOVED
wallet_type       BANK_ACCOUNT, CASH, E_WALLET, SAVING, CREDIT_CARD, PAYLATER, OTHER
transaction_kind  INCOME, EXPENSE, TRANSFER, ADJUSTMENT, REVERSAL, BILL_PAYMENT
direction         DEBIT, CREDIT
transaction_scope PRIVATE, HOUSEHOLD
privacy_mode      PRIVATE_FULL, PRIVATE_SUMMARY, HOUSEHOLD_VISIBLE
period_type       PERSONAL, HOUSEHOLD
period_status     OPEN, REVIEWED, LOCKED
aggregate_status  POSTED, REVERSED
```

## 4. Indeks minimum

- Ledger: `(wallet_id, created_at)`, `(aggregate_id)`, `(transfer_id)`.
- Transactions: `(household_id, transaction_date desc, id)`, `(owner_id, transaction_date desc)`.
- Period: `(household_id, type, start_date, end_date)`.
- Sync: `(household_id, sequence)`.
- Audit: `(household_id, entity_type, entity_id, created_at desc)`.
- Partial indexes untuk membership, wallet, dan category aktif.

## 5. RLS minimum

- User membaca profil sendiri dan profil anggota household seperlunya.
- User hanya membaca data household aktifnya.
- Wallet balance terlihat semua anggota aktif; detail privat dimasking melalui secure view/RPC.
- Direct insert/update ledger ditolak untuk role mobile.
- Ledger mutation hanya melalui function yang tervalidasi.
- Audit privat tidak boleh membocorkan before/after kepada pasangan.

## 6. Views/functions

`wallet_balances`, `transactions_visible`, `dashboard_balances`, `household_spending`, `personal_spending`, `sync_changes_for_user`; serta RPC yang didefinisikan pada API spec.

## 7. Migration order

1. Extensions, enums, helper timestamp/version.
2. Profile dan household.
3. Membership dan invitation.
4. Period settings dan periods.
5. Wallet dan category.
6. Aggregate, ledger, transfer, notes.
7. Idempotency, audit, sync change.
8. Functions dan views.
9. RLS policies.
10. Seed kategori dan integration tests.

## 8. TBD sebelum migration final

- Representasi liability PayLater: wallet khusus atau account terpisah.
- Kebijakan transaksi privat pada shared wallet saat personal/household period berbeda status lock.
- Apakah nominal IDR tetap `numeric(19,2)` atau menjadi integer rupiah.
- Retensi audit dan tombstone.
- Batas tepat dua anggota ditegakkan di function atau hanya UI.
