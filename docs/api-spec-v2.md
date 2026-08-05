# API Specification Phase 2 — Cash Flow

## Periode

| RPC | Fungsi |
|---|---|
| `list_periods()` | Membentuk dan membaca periode personal/household yang dapat dilihat actor |
| `set_my_period_start_day(day)` | Mengatur tanggal awal cycle pribadi 1–31 |
| `review_period(period_id)` | Menyimpan snapshot review dan audit |
| `lock_period(period_id)` | Mengunci periode yang sudah direview |
| `auto_lock_due_periods()` | Mengunci periode pada awal cycle kedua setelah periode berakhir |
| `period_report(period_id)` | Total saat tutup, kondisi sekarang, dan koreksi setelah tutup |

Mutation ke tanggal pada periode terkunci ditolak dengan `PERIOD_LOCKED`. Backdate diizinkan pada periode `OPEN`/`REVIEWED`. Koreksi tidak membuka periode; `correct_transaction(payload)` membuat reversal dan pengganti pada periode aktif.

## Budget dan forecast

| RPC | Fungsi |
|---|---|
| `upsert_budget(payload)` | Create/update budget personal atau household dengan version check |
| `list_budgets(period_id)` | Planned, spent, remaining, percentage, threshold, dan projection |
| `upsert_locked_fund(payload)` | Mengalokasikan soft locked fund pada wallet |
| `release_locked_fund(id, version)` | Melepas alokasi sebelum dananya digunakan |
| `list_locked_funds()` | Daftar alokasi yang terlihat actor |
| `forecast_summary()` | Breakdown saldo kas, locked, routine need, available, daily limit, dan health |

Status budget: `SAFE` di bawah 75%, `WARNING` mulai 75%, `CRITICAL` mulai 90%, dan `EXCEEDED` di atas 100%. Kebutuhan rutin memakai sisa budget kategori `REQUIRED`; tagihan yang tidak memiliki budget ditambahkan agar tidak terjadi double count.

## Tagihan rutin

| RPC | Fungsi |
|---|---|
| `upsert_recurring_obligation(payload)` | Membuat series `WEEKLY` atau `MONTHLY` |
| `list_recurring_obligations()` | Membentuk occurrence dan menampilkan reminder in-app |
| `confirm_obligation_payment(payload)` | Membuat expense aktual setelah konfirmasi |
| `resolve_obligation_occurrence(id, action, date)` | `SKIP` atau `RESCHEDULE` occurrence |

Tanggal bulanan 29–31 mengikuti hari terakhir bulan yang lebih pendek. Selisih estimasi dan aktual langsung dilepas menjadi saldo bebas.

## Sinkronisasi dan backup

`sync_changes(cursor_value, result_limit)` mengembalikan cursor monotonic, tombstone, `hasMore`, dan server time tanpa membocorkan transaksi private. Mutation lokal memakai status `PENDING_SYNC`, `SYNCING`, `SYNC_FAILED`, atau `CONFLICT`; `PERIOD_LOCKED`, `VERSION_CONFLICT`, dan `IDEMPOTENCY_CONFLICT` menjadi conflict yang harus diselesaikan pengguna.

`export_my_data()` mengembalikan snapshot privacy-aware. Aplikasi membungkus snapshot dan cache lokal dalam JSON schema v2 dengan SHA-256 checksum. Restore cache bersifat idempotent. CSV tidak mengekspor deskripsi transaksi private secara default.
