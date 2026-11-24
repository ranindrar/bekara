# API Specification Phase 3 — Credit, Import, dan Attachment

Seluruh endpoint domain diimplementasikan sebagai Supabase PostgreSQL RPC. Mutation menerima `clientReferenceId`, memvalidasi actor melalui `auth.uid()`, dan mengembalikan error code aman. Nominal dikirim sebagai string desimal dan disimpan sebagai `numeric(19,2)`.

## Credit account

| RPC | Fungsi |
|---|---|
| `list_credit_accounts()` | Akun personal milik actor dan akun household yang dapat dilihat actor |
| `credit_dashboard()` | Account, current bill, outstanding, limit, scope split, dan household reserve |
| `create_credit_account(payload)` | Membuat wallet liability dan konfigurasi PayLater/credit card secara atomik |
| `update_credit_account(account_id, expected_version, patch)` | Mengubah metadata non-finansial dengan optimistic locking |
| `archive_credit_account(account_id, expected_version)` | Menonaktifkan akun; penutupan ditolak selama outstanding belum nol |
| `reconcile_credit_account(payload)` | Membuat adjustment liability beralasan agar cocok dengan statement provider |

`PAYLATER` hanya boleh `PERSONAL`. `CREDIT_CARD` boleh `PERSONAL` atau `HOUSEHOLD`. Account household wajib memakai wallet shared, seluruh purchase-nya `HOUSEHOLD_VISIBLE`, dan anggota aktif dapat memakai atau membayar. Account personal hanya dapat dikonfigurasi dan digunakan pemilik.

Server tidak menerima atau menyimpan PAN maupun CVV. Metadata kartu terbatas pada provider, nama akun, dan `lastFour` opsional.

## Purchase, billing, dan cicilan

| RPC | Fungsi |
|---|---|
| `post_credit_purchase(payload)` | Mencatat consumption, liability, financing cost, billing item, dan installment schedule secara atomik |
| `list_credit_bills(account_id)` | Bill yang dapat dilihat actor beserta private/household split yang diizinkan |
| `list_credit_installments(account_id)` | Jadwal 1–36 bulan, due date, paid, remaining, dan status |
| `refund_credit_purchase(payload)` | Full/partial refund audited tanpa menulis ulang issued bill |

Payload purchase minimum:

```json
{
  "clientReferenceId": "uuid",
  "accountId": "uuid",
  "categoryId": "uuid",
  "principal": "1000000",
  "financingCost": "200000",
  "tenor": 6,
  "description": "Kebutuhan rumah",
  "transactionDate": "2026-08-07",
  "scope": "HOUSEHOLD",
  "privacyMode": "HOUSEHOLD_VISIBLE"
}
```

Principal dan financing cost yang sudah diketahui diakui sebagai consumption terpisah pada purchase date. Liability bertambah sebesar total keduanya. Limit berkurang berdasarkan principal. Cicilan dibagi deterministik dan selisih pembulatan masuk installment terakhir.

Cutoff inklusif. Cutoff 25 membentuk cycle 26 bulan sebelumnya sampai 25 bulan berjalan. Due date adalah occurrence pertama dari configured day setelah cutoff. Day 29–31 mengikuti akhir bulan. Issued bill immutable; backdate ke cycle lama menjadi late posting pada current bill dengan original date tersimpan.

## Payment

| RPC | Fungsi |
|---|---|
| `pay_credit_bill(payload)` | Mengurangi wallet kas dan liability secara atomik; online-only |
| `list_credit_payments(account_id)` | Riwayat payment dan allocation yang dapat dilihat actor |

Payment dialokasikan ke bill/installment tertua. Pada personal bill campuran, nilai dalam bill dialokasikan proporsional terhadap outstanding `PRIVATE` dan `HOUSEHOLD`. Overpayment ditolak. Payment tidak masuk consumption, budget, atau expense report.

## Forecast dan notification

| RPC | Fungsi |
|---|---|
| `credit_forecast()` | Personal due dan household reserve tanpa double-count atau private leakage |
| `list_credit_notifications()` | Event issued, H-7, H-3, H-1, due, dan overdue untuk actor |
| `mark_credit_notification(event_key, dismissed)` | Menandai read/dismiss secara idempotent |

Personal forecast memuat seluruh tagihan personal actor. Household forecast hanya memuat porsi household yang belum dibayar dan jatuh tempo dalam horizon. Account household sepenuhnya menjadi household reserve. Push channel ditunda; event contract tidak bergantung pada channel.

## Import CSV

| RPC | Fungsi |
|---|---|
| `commit_import_batch(payload)` | Commit seluruh row valid secara atomik dengan source hash |
| `list_import_batches()` | Riwayat batch dan ringkasan hasil milik actor |

Parsing, mapping, dan preview dilakukan lokal tanpa menulis ledger. File pertama memakai template generik maksimal 5 MB dengan kolom tanggal, nominal, debit/kredit, dan deskripsi. Wallet, category, dan scope dapat dipetakan sebelum commit. Kombinasi actor dan SHA-256 source hash unik; retry file yang sama mengembalikan hasil lama.

## Attachment

| RPC | Fungsi |
|---|---|
| `register_attachment(payload)` | Mendaftarkan metadata object yang sudah diunggah ke private bucket |
| `list_transaction_attachments(transaction_id)` | Metadata attachment yang boleh dilihat actor |
| `delete_attachment(attachment_id)` | Soft delete metadata secara audited sebelum object cleanup |

Bucket `receipts` bersifat private. Object path adalah `householdId/actorId/transactionId/random.ext`. MIME yang diterima: JPEG, PNG, WEBP, dan PDF; maksimum default 5 MB. `PRIVATE_FULL` hanya dapat diakses owner, `PRIVATE_SUMMARY` tidak pernah membuka attachment kepada pasangan, dan household attachment mengikuti membership aktif. Signed URL berumur pendek dan tidak dipersistenkan.

## Error contract

```text
UNAUTHENTICATED
FORBIDDEN
NOT_FOUND
VALIDATION_ERROR
VERSION_CONFLICT
IDEMPOTENCY_CONFLICT
PERIOD_LOCKED
CREDIT_ACCOUNT_REQUIRED
CREDIT_ACCOUNT_INACTIVE
CREDIT_ACCOUNT_NOT_EMPTY
CREDIT_OVERPAYMENT
BILL_IMMUTABLE
IMPORT_INVALID_FORMAT
IMPORT_DUPLICATE_FILE
ATTACHMENT_INVALID_TYPE
ATTACHMENT_TOO_LARGE
ATTACHMENT_METADATA_INVALID
NETWORK_OR_SERVER_ERROR
```

Unknown backend detail tidak ditampilkan kepada pengguna dan tidak disimpan dalam local diagnostics.
