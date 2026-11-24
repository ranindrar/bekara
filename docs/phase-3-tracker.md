# Phase 3 Tracker — Kewajiban dan Import

## 1. Tujuan

Fase 3 menambahkan akun kredit personal/household, PayLater personal, billing period, cicilan, pembayaran kewajiban, forecast kewajiban, notifikasi in-app, import CSV, dan lampiran nota di atas ledger dan cash-flow Fase 2. Ledger tetap menjadi sumber kebenaran; pembelian kredit diakui sebagai konsumsi pada tanggal pembelian, sedangkan pembayaran kewajiban tidak boleh dihitung sebagai konsumsi kedua.

Status: `TODO`, `READY`, `IN PROGRESS`, `BLOCKED`, `REVIEW`, `DONE`.

## 2. Gate sebelum mulai

| ID | Pekerjaan | Status | Syarat selesai |
|---|---|---|---|
| G-01 | Finalisasi aturan produk kredit | DONE | Scope, ownership, billing, cicilan, pembayaran, forecast, dan privacy diputuskan |
| G-02 | Ledger dan cash-flow Fase 2 stabil | REVIEW | Automated regression lulus; authenticated mutation, two-account/two-device, physical-device, dan restore test tetap gate operasional |
| G-03 | API specification Phase 3 | DONE | RPC, payload, response, error code, dan idempotency contract terdokumentasi |
| G-04 | Threat model RLS kredit dan attachment | DONE | Matriks actor/resource/action mencakup personal, household, summary, audit, dan signed URL |
| G-05 | Strategi migration dan rollback | DONE | Migration additive, backup schema v3, rollback/forward-fix, dan data lama teruji |

## 3. Epic A — Kontrak domain dan arsitektur

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P3-A01 | Tulis API specification v3 | G-01 | Seluruh operasi kredit, import, attachment, dan notification memiliki kontrak eksplisit | DONE |
| P3-A02 | Finalisasi posting ledger kewajiban | G-01 | Purchase, fee, payment, refund, reversal, dan opening liability seimbang serta tidak double-count | DONE |
| P3-A03 | Finalisasi state machine akun/tagihan/cicilan | G-01 | Transisi valid, immutable bill, overdue, archive, dan late posting terdokumentasi | DONE |
| P3-A04 | Definisikan error dan conflict contract | A01–A03 | Error aman untuk period lock, duplicate, version, ownership, payment, file, dan import | DONE |
| P3-A05 | Perbarui architecture/database/ledger docs | A01–A04 | Dokumen utama konsisten dan TBD liability lama ditutup | DONE |

## 4. Epic B — Akun kredit dan otorisasi

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P3-B01 | Migration credit accounts | A02, G-05 | Type `PAYLATER`/`CREDIT_CARD`, scope, primary holder, limit, statement day, due day, opening liability, version, dan lifecycle tersimpan | DONE |
| P3-B02 | Constraint type dan scope | B01 | PayLater hanya personal; credit card boleh personal/household; household credit menolak transaksi private | DONE |
| P3-B03 | RLS dan permission matrix | B01, G-04 | Personal hanya pemilik; household terlihat anggota aktif; actor dan payer tervalidasi server | DONE |
| P3-B04 | RPC create/update/archive account | B01–B03 | Idempotent, optimistic locking, audited, dan akun berutang tidak dapat ditutup | DONE |
| P3-B05 | Opening liability flow | B01–B04 | Saldo awal tidak menjadi konsumsi; current bill dan due date dapat direkonsiliasi | DONE |
| P3-B06 | UI daftar/form/detail akun kredit | B04, B05 | Personal/household, limit, outstanding, last four opsional, status, dan safe error tampil jelas | DONE |
| P3-B07 | Security regression akun kredit | B01–B06 | Tidak menyimpan PAN/CVV; akses lintas owner/household dan kebocoran private ditolak | DONE |

## 5. Epic C — Billing period, pembelian, dan cicilan

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P3-C01 | Migration billing periods dan items | B01, A03 | Period, due date, principal, fee, paid, scope split, status, dan snapshot tersimpan | DONE |
| P3-C02 | Generator siklus tagihan | C01 | Cutoff inklusif; due date pertama setelah cutoff; day 29–31 clamp; timezone Jakarta | DONE |
| P3-C03 | RPC purchase kredit atomik | B03, C01 | Konsumsi bertambah, kas tidak berubah, liability bertambah, limit berkurang, bill benar | DONE |
| P3-C04 | Migration installment schedules | C01 | Tenor 1–36, first due date, principal, financing cost, dan rounding final installment deterministik | DONE |
| P3-C05 | Generator cicilan lintas akun | C04 | Berlaku pada PayLater, credit personal, dan credit household; scope mengikuti purchase asal | DONE |
| P3-C06 | Mixed-scope liability split | C03–C05 | Personal credit memisahkan outstanding private/household tanpa membuka bill pribadi | DONE |
| P3-C07 | Fee dan financing-cost posting | A02, C03 | Biaya pembiayaan yang diketahui diakui terpisah saat purchase dan masuk liability; biaya berikutnya mengikuti scope | DONE |
| P3-C08 | Late posting dan immutable bill | C02, C03 | Backdate hanya ke unbilled; transaksi terlambat masuk current bill dengan original date/reference | DONE |
| P3-C09 | Refund/reversal flow | C03, C07, C08 | Full/partial refund mengurangi consumption/liability secara audited tanpa menulis ulang issued bill | DONE |
| P3-C10 | UI purchase dan installment schedule | C03–C09 | Total biaya, tenor, cicilan, scope, limit warning, dan preview jadwal transparan | DONE |
| P3-C11 | Billing/installment test suite | C01–C10 | Cutoff, month-end, leap year, rounding, locked period, privacy, retry, dan concurrency lulus | DONE |

## 6. Epic D — Pembayaran, forecast, dan laporan

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P3-D01 | RPC pembayaran kewajiban atomik | C01, C03 | Online-only; kas dan liability berubah bersama; payment tidak menjadi consumption | DONE |
| P3-D02 | Partial payment allocation | D01, C06 | Dialokasikan ke bill/cicilan tertua lalu proporsional terhadap outstanding private/household | DONE |
| P3-D03 | Limit release dan over-limit warning | D01 | Pembayaran mengembalikan principal limit; over-limit boleh dengan warning; overpayment ditolak | DONE |
| P3-D04 | Personal/household credit forecast | C06, D02 | Personal melihat total bill; household hanya reserve agregat household; combined view tidak double-count | DONE |
| P3-D05 | Credit dashboard dan bill detail | C01–C10, D01–D04 | Current bill, nearest due, limit, remaining, scope split, payer, dan status terlihat sesuai privacy | DONE |
| P3-D06 | Credit report dan category integration | D04, D05 | Consumption pada purchase date; payment dikecualikan; personal/household aggregation konsisten | DONE |
| P3-D07 | Statement reconciliation | B05, D01 | Selisih provider diselesaikan adjustment beralasan dan audited | DONE |
| P3-D08 | Payment/forecast test suite | D01–D07 | Full/partial, proportional split, retry, overdue, payer authorization, dan anti-double-count lulus | DONE |

## 7. Epic E — Notifikasi

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P3-E01 | Notification model dan dedup key | C01 | Event issued, H-7, H-3, H-1, due, overdue unik per user/bill/event | DONE |
| P3-E02 | In-app reminder query | E01, D01 | Reminder berhenti setelah lunas; partial payment menyisakan reminder; privacy terjaga | DONE |
| P3-E03 | Notification center UI | E02 | Unread/read/dismiss, deep link ke bill yang berizin, empty/error state tersedia | DONE |
| P3-E04 | Notification test suite | E01–E03 | Timezone, retry, dedup, paid/partial/overdue, dan akses anggota lulus | DONE |

Push notification perangkat tidak termasuk MVP awal Fase 3; kontrak event harus memungkinkan penambahan channel tersebut tanpa mengubah aturan domain.

## 8. Epic F — Import CSV

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P3-F01 | Definisikan template generik dan batas file | A01 | Maksimum default 5 MB; encoding, delimiter, date, amount, debit/credit, dan required column jelas | DONE |
| P3-F02 | Parser dan column mapping | F01 | Preview tidak menulis ledger; format angka/tanggal Indonesia dan generik didukung | DONE |
| P3-F03 | Preview/validation/duplicate detection | F02 | Valid, invalid, category mapping, wallet mapping, dan suspected duplicate terlihat per row | DONE |
| P3-F04 | Import batch dan source hash | F03 | File/retry sama tidak menggandakan transaksi; status batch dan row tersimpan | DONE |
| P3-F05 | Commit batch atomik | F04, G-02 | Baris valid committed dengan idempotency; locked period, RLS, dan privacy tervalidasi server | DONE |
| P3-F06 | Import UI | F02–F05 | Pick file, map, preview, resolve row, confirm, progress, dan result summary tersedia | DONE |
| P3-F07 | Import test suite | F01–F06 | Duplicate file/row, malformed CSV, locale, partial invalid, retry, dan authorization lulus | DONE |

## 9. Epic G — Lampiran nota

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P3-G01 | Private storage bucket dan policy | G-04 | Object tidak public; path ownership tervalidasi; akses hanya melalui authenticated signed URL singkat | DONE |
| P3-G02 | Migration attachment metadata | P3-G01, G-05 | Transaction, object key, MIME, size, owner, audit, dan lifecycle tersimpan | DONE |
| P3-G03 | Upload validation | P3-G01, P3-G02 | Hanya image/PDF yang diizinkan; batas ukuran configurable; filename tidak dipercaya | DONE |
| P3-G04 | Attachment RLS/privacy | P3-G02 | PRIVATE_FULL tidak bocor; PRIVATE_SUMMARY tidak membuka attachment; household mengikuti membership aktif | DONE |
| P3-G05 | Upload/delete/download flow | P3-G01–P3-G04 | Online-only, cleanup kegagalan aman, delete audited, signed URL tidak dipersistenkan | DONE |
| P3-G06 | Attachment UI | P3-G03–P3-G05 | Pick, preview, progress, retry, download, dan delete memiliki safe error state | DONE |
| P3-G07 | Attachment security test suite | P3-G01–P3-G06 | MIME spoofing, oversized file, direct URL, cross-user, removed member, dan deleted object ditolak | DONE |

## 10. Epic H — Offline, backup, observability, dan release

| ID | Task | Dependensi | Acceptance criteria | Status |
|---|---|---|---|---|
| P3-H01 | Extend Drift schema dan sync v3 | B/C/D/E migrations | Credit cache, bill, installment, notification, cursor, tombstone, dan conflict kompatibel | DONE |
| P3-H02 | Backup/export schema v3 | H01, P3-G05 | Credit metadata dan attachment manifest terbackup; file binary memiliki strategi eksplisit | DONE |
| P3-H03 | Safe metrics dan diagnostics | Semua epic | Tidak mencatat nominal, deskripsi, PAN, object URL, atau file content | DONE |
| P3-H04 | Automated regression | Semua epic | Flutter analyzer/test/build, database lint, pgTAP, dan migration test lulus | DONE |
| P3-H05 | Two-account/two-device behavioral test | H01–H04 | Personal/household privacy, offline purchase, sync, payment, dan notification konsisten | BLOCKED |
| P3-H06 | Physical Android test | B/C/D/E/F/G UI | Purchase, cicilan, payment, CSV picker, attachment picker, dan lifecycle app lulus | BLOCKED |
| P3-H07 | Restore rehearsal project uji | H02 | Backup v3 direstore idempotent dan direkonsiliasi terhadap ledger | BLOCKED |
| P3-H08 | Release checklist Fase 3 | H04–H07 | Migration plan, rollback/forward-fix, known issues, privacy, dan recovery evidence lengkap | BLOCKED |

### Evidence otomatis — 8 Agustus 2026

- `supabase db reset`: PASS, seluruh migration diterapkan dari database kosong.
- `supabase test db`: PASS, 114 assertion dalam 5 file.
- `supabase db lint --local --level warning`: PASS, tanpa temuan.
- `flutter analyze`: PASS, tanpa issue.
- `flutter test`: PASS, 33 test.
- `flutter build apk --debug`: PASS, menghasilkan `build/app/outputs/flutter-apk/app-debug.apk`.

H05–H08 tetap `BLOCKED` karena membutuhkan identitas/perangkat/project remote yang terpisah, bukan karena pekerjaan kode tersisa. Migration Phase 3 belum diterapkan ke remote pada slice ini. Detail threat model, backup binary, forward-fix, dan langkah release terdapat pada [Phase 3 security and release plan](phase-3-security-and-release.md).

## 11. Skenario acceptance kritis

- Pembelian PayLater Rp100.000 menambah konsumsi dan liability Rp100.000, mengurangi limit, tetapi tidak mengurangi kas.
- Pembayaran tagihan mengurangi kas dan liability tanpa menambah konsumsi kedua kali.
- PayLater selalu personal, tetapi purchase dapat `PRIVATE` atau `HOUSEHOLD`.
- Purchase household melalui kredit personal memakai budget household dan membentuk reserve household tanpa membocorkan total bill pribadi.
- Bill campuran private Rp400.000 dan household Rp600.000 yang dibayar Rp500.000 menyisakan private Rp200.000 dan household Rp300.000.
- Credit card household menolak transaksi private dan terlihat penuh oleh anggota aktif.
- Purchase cicilan mengakui konsumsi penuh pada tanggal pembelian; forecast hanya mencadangkan cicilan dalam horizon.
- Cutoff tanggal 25 mencakup tanggal 26 bulan lalu sampai tanggal 25 bulan berjalan; tanggal 29–31 mengikuti akhir bulan.
- Issued bill tidak berubah karena backdate; late posting dan refund masuk current bill dengan referensi asal.
- Pembayaran offline tidak mengubah status bill; retry online dengan reference sama tidak menggandakan pembayaran.
- Import file atau row yang sama tidak menggandakan transaksi.
- PRIVATE_SUMMARY tidak pernah membuka deskripsi atau attachment.

## 12. Definition of Done Fase 3

- Seluruh task gate dan epic berstatus DONE atau memiliki pengecualian tertulis dan disetujui.
- Purchase, fee, payment, refund, reversal, dan opening liability dapat direkonsiliasi terhadap ledger.
- Consumption, cash, liability, limit, budget, dan forecast tidak double-count.
- RLS dan RPC mencegah akses lintas owner/household pada row, view, error, realtime, audit, dan attachment.
- Billing, cicilan, partial payment, proportional split, cutoff, late posting, dan rounding memiliki automated test.
- Import CSV idempotent dan tidak melewati period lock, privacy, atau authorization.
- Attachment tersimpan private dan akses langsung tanpa otorisasi ditolak.
- Dua akun dan dua perangkat kembali konsisten setelah offline/online.
- Backup v3 berhasil direstore pada project uji.
- Tidak ada high/critical security issue terbuka.

## 13. Keputusan produk final

| ID | Pertanyaan | Keputusan final |
|---|---|---|
| P3-DEC-01 | PayLater personal atau household? | PayLater selalu personal; credit card dapat personal atau household |
| P3-DEC-02 | Bolehkah kredit personal membiayai household? | Ya; purchase boleh PRIVATE/HOUSEHOLD, tetapi bill tetap personal |
| P3-DEC-03 | Dampak household purchase dari kredit personal? | Masuk budget/report household dan reserve agregat household tanpa membuka bill/limit pribadi |
| P3-DEC-04 | Credit card household boleh dipakai private? | Tidak; seluruh purchase wajib HOUSEHOLD dan HOUSEHOLD_VISIBLE |
| P3-DEC-05 | Siapa memakai/membayar household credit? | Semua anggota aktif; actor/payer tercatat; konfigurasi oleh primary holder atau household owner |
| P3-DEC-06 | Pembayaran mixed-scope dialokasikan bagaimana? | Bill/cicilan tertua dahulu, lalu proporsional terhadap outstanding private/household |
| P3-DEC-07 | Bagaimana siklus billing? | Cutoff inklusif; due date adalah occurrence pertama setelah cutoff; day 29–31 clamp; Asia/Jakarta |
| P3-DEC-08 | Apakah issued bill dapat berubah? | Tidak; late posting/refund/koreksi masuk current bill dengan referensi asal dan audit |
| P3-DEC-09 | Cicilan masuk MVP? | Ya, tenor 1–36 untuk PayLater, credit personal, dan credit household |
| P3-DEC-10 | Kapan konsumsi dan biaya diakui? | Principal dan financing cost yang diketahui diakui terpisah pada purchase date serta masuk total liability; payment bukan consumption |
| P3-DEC-11 | Over-limit dan overpayment? | Over-limit boleh dengan warning dan remaining limit negatif; overpayment ditolak pada MVP |
| P3-DEC-12 | Perilaku offline? | Purchase boleh queued; payment dan attachment online-only; status final menunggu server |
| P3-DEC-13 | Minimum payment/revolving? | Tidak dimodelkan pada MVP; sisa setelah due menjadi OVERDUE |
| P3-DEC-14 | Early payoff/restructure? | Ditunda; sementara menggunakan correction flow yang audited |
| P3-DEC-15 | Notifikasi awal? | In-app issued, H-7, H-3, H-1, due, overdue; push ditunda |
| P3-DEC-16 | Data kartu apa yang disimpan? | Tidak menyimpan PAN/CVV; last four opsional dan metadata non-sensitif saja |
| P3-DEC-17 | Import pertama? | Template generik dengan mapping, preview, validation, source hash, dan atomic commit |
