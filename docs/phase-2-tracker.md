# Phase 2 Tracker — Cash Flow

## 1. Tujuan

Fase 2 menambahkan periode pribadi/household, review dan locking, anggaran, dana terkunci, batas aman harian, tagihan rutin, serta proyeksi saldo di atas fondasi Release 1.0. Tracker ini tidak menganggap PayLater/kartu kredit lengkap sebagai bagian Fase 2; fitur tersebut tetap Release 1.2/Fase 3.

Status: `TODO`, `READY`, `IN PROGRESS`, `BLOCKED`, `REVIEW`, `DONE`.

## 2. Gate sebelum mulai

| ID | Pekerjaan | Status | Syarat selesai |
|---|---|---|---|
| G-01 | Ledger P0 stabil | DONE | Transfer, reversal, reconciliation, dan idempotensi lulus regression test |
| G-02 | RLS P0 diaudit | REVIEW | Policy dan permission lulus pgTAP; behavioral test dua akun tetap gate operasional |
| G-03 | Sinkronisasi dasar stabil | REVIEW | Cursor, tombstone, retry, conflict, dan restore cache selesai; two-device test tertunda |
| G-04 | Putuskan aturan lock lintas periode | DONE | Manual setelah review; auto-lock dua siklus setelah periode berakhir |
| G-05 | Putuskan formula kebutuhan rutin | DONE | Sisa budget REQUIRED + tagihan tanpa budget, tanpa double count |

## 3. Epic A — Periode keuangan

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P2-A01 | Migration period settings | G-01 | Personal dan household cycle tersimpan, day 1–31 valid | DONE |
| P2-A02 | Generator rentang periode | A01 | Termasuk Februari/leap year dan day 29–31 | DONE |
| P2-A03 | Mapping transaksi ke periode | A02 | PRIVATE dan HOUSEHOLD masuk cycle yang benar | DONE |
| P2-A04 | RPC review period | A03 | Hanya actor berizin; audit terbentuk | DONE |
| P2-A05 | RPC lock period | A04 | Mutation finansial relevan ditolak `PERIOD_LOCKED` | DONE |
| P2-A06 | Auto-lock scheduler/trigger strategy | A05, TBD-01 | Idempotent dan tidak mengunci periode aktif | DONE |
| P2-A07 | UI personal/household period selector | A03 | Range dan status terlihat jelas | DONE |
| P2-A08 | UI review checklist dan lock confirmation | A04 | Dampak irreversible dijelaskan; alasan tercatat | DONE |
| P2-A09 | Offline behavior untuk lock | A05 | Lock online-only; pending mutation mendapat conflict jelas | DONE |
| P2-A10 | Period test suite | A01–A09 | Boundary, timezone, leap year, concurrency lulus | REVIEW |

## 4. Epic B — Anggaran

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P2-B01 | Finalisasi scope budget | G-05 | Personal/household/category dan anti-double-count jelas | DONE |
| P2-B02 | Migration budgets | B01, A01 | Unique active budget per target/period | DONE |
| P2-B03 | RPC CRUD budget + RLS | B02 | Version conflict dan audit bekerja | DONE |
| P2-B04 | Query progress | B03 | Used, remaining, percentage konsisten dengan report | DONE |
| P2-B05 | Status threshold | B04 | SAFE/WARNING/CRITICAL/EXCEEDED teruji | DONE |
| P2-B06 | UI budget list/form/detail | B03 | Empty/error/offline state tersedia | DONE |
| P2-B07 | Budget projection | B04, C03 | Proyeksi transparan dan dapat dijelaskan | DONE |
| P2-B08 | Budget test suite | B01–B07 | Scope, privacy, locked period, boundary lulus | REVIEW |

## 5. Epic C — Dana terkunci dan forecast

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P2-C01 | Definisikan locked fund | TBD-03 | Soft lock per wallet; pemasukan tetap boleh, penggunaan perlu release | DONE |
| P2-C02 | Migration + RPC locked funds | C01 | Tidak melebihi aturan yang disepakati; audited | DONE |
| P2-C03 | Cash available query | C02, A03 | Hanya cash wallet; shared/personal mode benar | DONE |
| P2-C04 | Remaining-day calculator | A02 | Semua hari kalender dihitung | DONE |
| P2-C05 | Safe daily limit RPC | C03, C04, D03 | Breakdown setiap komponen tersedia | DONE |
| P2-C06 | Cash-flow health status | C05 | SAFE/CONTROL_NEEDED/DEFICIT_RISK deterministik | DONE |
| P2-C07 | Forecast dashboard UI | C05 | Menampilkan sumber angka, bukan angka hitam-box | DONE |
| P2-C08 | Forecast test suite | C01–C07 | Zero/negative balance, last day, timezone lulus | REVIEW |

## 6. Epic D — Tagihan rutin

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P2-D01 | Finalisasi recurrence model | TBD-04 | Weekly/monthly; tanggal 29–31 mengikuti akhir bulan | DONE |
| P2-D02 | Migration recurring obligations | D01 | Due date, amount estimate, owner/scope valid | DONE |
| P2-D03 | Upcoming obligations query | D02, A02 | Hanya kewajiban sebelum akhir forecast | DONE |
| P2-D04 | Confirmation flow | D02 | Reminder tidak otomatis menjadi expense | DONE |
| P2-D05 | UI list/form/confirm | D02–D04 | Paid/skipped/rescheduled tercatat | DONE |
| P2-D06 | Reminder integration boundary | D03 | Reminder in-app; push ditunda | DONE |
| P2-D07 | Recurring test suite | D01–D06 | Month-end, edit series, timezone lulus | REVIEW |

## 7. Epic E — Offline, observability, dan release

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P2-E01 | Extend local Drift schema | A/B/C/D migrations | Migration lokal tidak menghapus cache lama | DONE |
| P2-E02 | Extend sync protocol | E01 | Cursor, tombstone, retry, conflict bekerja | DONE |
| P2-E03 | Metrics lokal non-sensitif | E02 | Sync failure dapat didiagnosis tanpa nominal/deskripsi | DONE |
| P2-E04 | Full JSON backup/restore | G-01 | Remote export + local schema/checksum/restore idempotent selesai; restore project uji menunggu OPS | REVIEW |
| P2-E05 | CSV/Sheets export design | E04 | Export satu arah dan privacy-aware | DONE |
| P2-E06 | End-to-end two-device test | Semua epic | Suami/istri offline-online konsisten | BLOCKED |
| P2-E07 | Regression and security test | Semua epic | Ledger P0 dan RLS tidak regresi | DONE |
| P2-E08 | Release checklist | E06,E07 | Backup diuji, migration rollback plan, known issues | REVIEW |

## 8. Skenario acceptance kritis

- Suami cycle 25–24, istri 10–9, household 25–24 menghasilkan tiga konteks periode benar.
- Tanggal 31 beralih ke hari terakhir pada bulan yang lebih pendek.
- Lock household period menolak edit HOUSEHOLD tetapi tidak membocorkan detail PRIVATE.
- Pending offline edit terhadap transaksi yang kemudian terkunci menjadi `CONFLICT`.
- Transfer internal tidak mengonsumsi budget expense.
- Private expense pada shared wallet mengurangi family balance tetapi tidak household spending/budget.
- Safe daily limit nol bila available cash negatif.
- Tagihan rutin hanya menjadi transaksi setelah konfirmasi.
- Retry seluruh RPC tidak menggandakan record.

## 9. Definition of Done Fase 2

- Seluruh task gate dan epic berstatus DONE atau memiliki pengecualian tertulis.
- Formula dashboard dapat direkonsiliasi terhadap ledger.
- Semua angka memiliki layar breakdown.
- Dua perangkat dapat bekerja offline dan kembali konsisten.
- RLS, idempotensi, locking, dan privacy test lulus.
- Backup penuh berhasil direstore pada project uji.
- Tidak ada high/critical security issue terbuka.

## 10. Keputusan produk final

| ID | Pertanyaan | Keputusan final |
|---|---|---|
| TBD-01 | Auto-lock atau manual? | Manual setelah review; otomatis dua siklus setelah akhir periode (25 Jul–24 Agu → 25 Okt) |
| TBD-02 | Kebutuhan rutin berasal dari mana? | Sisa budget REQUIRED; tagihan tanpa budget ditambah tanpa double count, selisih aktual kembali bebas |
| TBD-03 | Dana terkunci per wallet atau global? | Soft lock per wallet; dana harus dilepas sebelum digunakan di aplikasi |
| TBD-04 | Recurrence apa di MVP? | Weekly dan monthly; day 29–31 menjadi last day; expense hanya setelah konfirmasi |
| TBD-05 | Pasangan boleh edit transaksi PRIVATE? | Transaksi HOUSEHOLD boleh dikoreksi pasangan; PRIVATE tetap hanya pemilik |
| TBD-06 | Reopen locked period? | Tidak; UI otomatis membuat reversal/koreksi dan laporan menampilkan total tutup + koreksi |
| TBD-07 | Hari aktif | Semua hari kalender; backdate boleh selama periode masih terbuka |
