# API Specification v1 — Supabase

## 1. Scope

Dokumen ini adalah kontrak Release 1.0/P0. API menggunakan Supabase Auth, Data API untuk read sederhana, dan PostgreSQL RPC untuk mutation finansial. Semua timestamp ISO-8601 UTC; tanggal bisnis menggunakan `date` pada timezone household. Nominal dikirim sebagai string desimal, misalnya `"25000"`.

## 2. Konvensi

- UUID v4 untuk ID yang dibuat client.
- Bearer JWT Supabase wajib.
- `client_reference_id` wajib pada create finansial.
- `expected_version` wajib pada update.
- List memakai cursor, `limit` default 50 dan maksimum 200.
- Mutation sukses mengembalikan aggregate kanonis beserta `version`.

Error RPC:

```json
{
  "code": "PERIOD_LOCKED",
  "message": "Periode transaksi telah dikunci",
  "details": { "periodId": "uuid" },
  "requestId": "uuid"
}
```

Kode minimum: `UNAUTHENTICATED`, `FORBIDDEN`, `VALIDATION_ERROR`, `NOT_FOUND`, `VERSION_CONFLICT`, `IDEMPOTENCY_CONFLICT`, `PERIOD_LOCKED`, `WALLET_INACTIVE`, `TRANSFER_SAME_WALLET`, `CROSS_HOUSEHOLD_FORBIDDEN`, `INTERNAL_ERROR`.

## 3. Auth dan bootstrap

Auth memakai Supabase Auth: sign-up email/password, sign-in, refresh, sign-out, dan reset password. Setelah login:

| Operasi | Bentuk | Fungsi |
|---|---|---|
| `get_my_context()` | RPC | Profil, membership, household, preference, sync cursor |
| `create_household(payload)` | RPC | Membuat household dan owner membership |
| `create_invitation(email)` | RPC | Membuat undangan sekali pakai |
| `accept_invitation(token)` | RPC | Menerima undangan |
| `leave_household()` | RPC | Member keluar |
| `remove_member(member_id)` | RPC owner | Menonaktifkan member |

Transfer ownership dan pembubaran household belum termasuk sampai kebijakannya final.

## 4. Read resources

Read dapat memakai view aman berikut; RLS tetap berlaku.

| View/function | Filter utama | Hasil |
|---|---|---|
| `wallets_visible` | active | Wallet dan saldo kanonis |
| `categories_visible` | direction, active | Kategori sistem/pribadi/household |
| `transactions_visible` | cursor, period, owner, wallet, category, scope | Data yang sudah dimasking sesuai privasi |
| `periods_visible` | owner/type/status | Periode pribadi dan household |
| `dashboard_summary(period_id, mode)` | `PERSONAL`, `FAMILY`, `GLOBAL` | Saldo dan cash flow |
| `report_category(period_id, mode)` | scope/owner | Agregasi kategori |
| `sync_changes(cursor, limit)` | cursor | Perubahan incremental dan tombstone |

Mobile tidak boleh membaca tabel ledger mentah untuk menghitung hak akses.

## 5. Wallet dan kategori

| RPC | Payload penting |
|---|---|
| `create_wallet` | client_reference_id, name, wallet_type, opening_balance, is_shared |
| `update_wallet` | wallet_id, expected_version, name/icon/is_shared/active |
| `reconcile_wallet` | wallet_id, actual_balance, reason, transaction_date, client_reference_id |
| `create_category` | name, direction, necessity_type, scope |
| `update_category` | category_id, expected_version, mutable fields |
| `archive_category` | category_id, expected_version |

Perubahan opening balance setelah wallet memiliki posting dilakukan melalui reconciliation, bukan update wallet.

## 6. Transaksi

### 6.1 Create income/expense

`post_transaction(payload)`:

```json
{
  "clientReferenceId": "uuid",
  "walletId": "uuid",
  "kind": "EXPENSE",
  "amount": "25000",
  "categoryId": "uuid",
  "transactionDate": "2026-08-04",
  "scope": "PRIVATE",
  "privacyMode": "PRIVATE_SUMMARY",
  "description": "Makan siang"
}
```

Validasi kombinasi: `HOUSEHOLD` hanya menerima `HOUSEHOLD_VISIBLE`; `PRIVATE` menerima `PRIVATE_FULL`, `PRIVATE_SUMMARY`, atau `HOUSEHOLD_VISIBLE`.

### 6.2 Update

`update_transaction(transaction_id, expected_version, patch, reason)` hanya berlaku pada periode belum terkunci. Perubahan menghasilkan audit before/after.

### 6.3 Reverse

`reverse_transaction(transaction_id, transaction_date, reason, client_reference_id)` membuat aggregate reversal. Hard delete dilarang. Draft lokal yang belum pernah tersinkron boleh dihapus lokal.

### 6.4 Correction note

`add_transaction_note(transaction_id, note)` dapat digunakan pasangan untuk memberi catatan. Hak pasangan untuk mengedit langsung transaksi pribadi berstatus TBD; default API adalah tidak boleh.

## 7. Transfer

`post_transfer(payload)` membuat header dan dua posting atomik:

```json
{
  "clientReferenceId": "uuid",
  "sourceWalletId": "uuid",
  "destinationWalletId": "uuid",
  "amount": "500000",
  "feeAmount": "0",
  "transactionDate": "2026-08-04",
  "description": "Transfer pasangan"
}
```

Wallet tujuan milik pasangan hanya dapat dipilih bila `accepts_household_transfer = true`. Fee menghasilkan expense terpisah dalam transaksi database yang sama. Reverse transfer membalik kedua posting dan fee sesuai kebijakan reversal.

## 8. Periode

| RPC | Aturan |
|---|---|
| `review_period(period_id)` | Owner periode/household menandai selesai diperiksa |
| `lock_period(period_id)` | Menolak mutation selanjutnya |
| `reopen_period(period_id, reason)` | Belum diaktifkan; kebijakan TBD |
| `generate_periods()` | Membentuk periode dari konfigurasi anggota/household |

## 9. Idempotensi

Kombinasi `(actor_user_id, operation_type, client_reference_id)` unik. Server menyimpan hash payload dan hasil. Retry identik mengembalikan hasil awal; payload berbeda menghasilkan `IDEMPOTENCY_CONFLICT`.

## 10. Sinkronisasi

- Push mutation berurutan per aggregate.
- Pull menggunakan cursor server, bukan jam perangkat.
- Response mencakup `nextCursor`, `hasMore`, dan server time.
- Tombstone dikirim untuk data yang diarsipkan/reversed.
- `VERSION_CONFLICT` menyertakan versi server yang sudah dimasking sesuai izin.

## 11. P1/P2 yang belum menjadi kontrak v1

Budget/forecast, PayLater/kartu kredit, attachment, notifikasi, import CSV, dan ekspor Google Sheets akan memiliki RPC terpisah setelah aturan domainnya final.
