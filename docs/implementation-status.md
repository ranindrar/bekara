# Implementation Status

Terakhir diverifikasi: 6 Agustus 2026.

## Foundation — 4 Agustus 2026

| Item | Status | Catatan |
|---|---|---|
| Flutter SDK stable | DONE | 3.44.8 / Dart 3.12.2 |
| Flutter Android scaffold | DONE | Package `id.bekara.app` / Dart package `bekara` |
| Git repository | DONE | Branch `main` memiliki baseline commit dan working tree diaudit |
| Riverpod dan GoRouter | DONE | Bootstrap dan route awal |
| Drift/SQLite | DONE | Wallet cache dan pending mutation queue awal |
| Supabase bootstrap | DONE | Aman dijalankan tanpa credential |
| Supabase connection | PASS | Auth health endpoint terverifikasi; config lokal diabaikan Git |
| Supabase migration P0 | DONE | Migration 001 dan privacy/auth hardening 002 diterapkan ke cloud |
| Auth UI | DONE | Register, login, reset password, session gate, logout |
| Error handling | DONE | Flutter, platform, zone, dan bootstrap error ditangkap tanpa menampilkan detail sensitif ke pengguna |
| Logging dasar | DONE | Log terstruktur berdasarkan area; payload finansial dan credential tidak dicatat |
| CI | DONE | GitHub Actions menjalankan code generation, analyzer, test coverage, dan debug APK build |
| Analyzer | PASS | Tidak ada issue |
| Automated test | PASS | 5 test: environment, bootstrap failure, bootstrap UI, dan auth validation |
| Android Studio dan SDK | DONE | Android Platform 36, Platform Tools, dan CMake tersedia |
| APK build | PASS | Debug APK berhasil dibuat |
| Supabase remote project | DONE | Auth dan REST aktif; anonymous profile read menghasilkan data kosong melalui RLS |

## Verifikasi operasional yang tertunda

Fondasi kode selesai. Item berikut memerlukan akses/tool eksternal dan harus dijalankan sebelum distribusi kepada tester:

| Item | Status | Blocker / tindakan |
|---|---|---|
| Deploy migration branding `202608050001` | DONE | Diterapkan ke remote Supabase pada 5 Agustus 2026 |
| Integration test RLS/RPC remote | PENDING OPS | RPC household belum termasuk Fase 0; audit read-policy awal sudah dilakukan, suite end-to-end dilanjutkan bersama slice household |
| Auth test pada Android nyata | PENDING OPS | Tidak ada perangkat/emulator Android aktif |
| Android toolchain health | ACTION REQUIRED | Pasang Android command-line tools dan terima SDK licenses |

Status `PENDING OPS` bukan implementasi aplikasi yang belum dibuat, tetapi gate verifikasi lingkungan sebelum rilis internal.

## Next implementation slice

1. Jalankan integration test dua akun untuk RLS dan RPC Fase 1.
2. Uji seluruh flow pada perangkat Android nyata.
3. Mulai gate Fase 2 setelah ledger dan sinkronisasi tervalidasi.

## Fase 1 — sedang dikerjakan

| Item | Status | Catatan |
|---|---|---|
| Household context RPC | DONE CODE | Mengembalikan profil, membership, dan household aktif |
| Create household | DONE CODE | RPC atomik membuat household, owner membership, dan audit log |
| Invitation pasangan | DONE CODE | Token sekali pakai, terikat email, kedaluwarsa 7 hari |
| Household onboarding UI | DONE CODE | Pengguna dapat membuat household atau memasukkan kode undangan |
| Deploy migration household | DONE | Migration `202608050002_household_onboarding.sql` diterapkan ke remote Supabase |
| Wallet dan kategori | DONE | Create/list wallet, saldo kanonis, kategori bawaan/kustom, update dan arsip RPC |
| Income dan expense | DONE | Posting ledger atomik, idempotensi transaksi, scope dan privacy |
| Transfer internal | DONE | Debit/kredit atomik dan tidak dihitung sebagai expense |
| Dashboard sederhana | DONE | Total saldo serta pemasukan/pengeluaran bulan berjalan |
| Laporan kategori | DONE | Agregasi pengeluaran bulan berjalan |
| Reversal dan rekonsiliasi | DONE | Koreksi immutable dan adjustment saldo tersedia |
| Navigation/UI Fase 1 | DONE | Beranda, transaksi, dompet, laporan, form pencatatan dan transfer |
| Migration ledger remote | DONE | Migration `003`, `004`, dan hardening permission `005` diterapkan ke remote Supabase |
| Integration test dua akun | PENDING OPS | Membutuhkan dua akun auth yang sudah dikonfirmasi |
| Android real-device test | PENDING OPS | Belum ada perangkat/emulator aktif |

## Verifikasi Fase 1 — 5 Agustus 2026

- `flutter analyze`: PASS, tanpa issue.
- `flutter test`: PASS, 7 test.
- `flutter build apk --debug`: PASS.
- Supabase migration: remote up-to-date setelah migration Fase 1.
- Implementasi kode Fase 1 selesai; gate operasional dua akun dan perangkat nyata tetap wajib sebelum rilis tester.

## Hardening Fase 1 — 6 Agustus 2026

| Area | Status | Hasil |
|---|---|---|
| Privasi transaksi | DONE | `PRIVATE_FULL` disembunyikan; `PRIVATE_SUMMARY` hanya nominal/tanggal; detail household tetap terlihat |
| Privasi kategori | DONE | Kategori pribadi hanya terlihat pemilik; policy lama yang terlalu luas dihapus |
| Otorisasi dompet | DONE | Mutation hanya pada dompet sendiri atau shared; transfer keluar tetap hanya pemilik |
| Dashboard dan laporan | DONE | Cash-flow keluarga hanya menghitung transaksi scope `HOUSEHOLD` |
| Idempotensi | DONE | Transaksi, transfer, dan reversal memvalidasi hash payload saat retry |
| Audit transfer | DONE | Transfer membuat audit log; reversal mengisi `transfers.reversed_at` |
| Validasi UI | DONE | Normalisasi nominal Indonesia, input wajib, pesan error aman, pilihan mode privasi |
| PostgreSQL regression test | PASS | 10 assertion permission/policy melalui pgTAP |
| Flutter analyzer/test | PASS | Analyzer diverifikasi; 11 test lulus setelah hardening |
| Two-account behavioral test | READY | Checklist tersedia; masih membutuhkan dua akun remote terkonfirmasi |

Migration hardening `202608060001_phase1_security_hardening.sql` sudah diterapkan ke remote Supabase.

## Fase 2 — implementasi kode selesai 6 Agustus 2026

| Area | Status | Hasil |
|---|---|---|
| Periode personal/household | DONE | Cycle 1–31, leap year, review, manual lock, dan auto-lock dua siklus |
| Koreksi setelah lock | DONE | Reversal/pengganti otomatis; laporan mempertahankan total saat tutup dan daftar koreksi |
| Budget | DONE | Personal/household/category, progress, threshold, proyeksi, dan anti-double-count |
| Dana terkunci | DONE | Soft lock per wallet, available balance, release, audit, dan mutation guard |
| Forecast | DONE | Saldo kas, dana terkunci, kebutuhan rutin, saldo bebas, batas aman harian, dan health status |
| Tagihan rutin | DONE | Weekly/monthly, month-end clamp, konfirmasi pembayaran, skip, dan reschedule |
| Backdate transaksi | DONE | Tanggal transaksi lampau dapat dipilih selama periodenya terbuka |
| Offline/sync | DONE CODE | Drift v2, pending queue, cursor, tombstone, retry, conflict, dan metrik aman |
| Backup/export | DONE CODE | Export remote, JSON checksum, restore cache idempotent, dan CSV privacy-aware |
| Migration remote | DONE | Migration `202608060002` sampai `202608060007` diterapkan dan remote up-to-date |
| Flutter verification | PASS | Analyzer tanpa issue, 20 test lulus, debug APK berhasil dibangun |
| PostgreSQL verification | PASS | Database lint bersih dan 32 assertion pgTAP lulus pada remote |
| Android emulator smoke test | PASS | APK terkonfigurasi terpasang dan layar Ringkasan/Cash Flow berhasil dimuat pada Pixel 9 API emulator |
| Two-account/two-device test | PENDING OPS | Memerlukan dua akun terkonfirmasi dan dua perangkat/emulator aktif |
| Full restore project uji | PENDING OPS | Export/checksum/restore cache teruji; restore end-to-end perlu project uji terpisah |

Implementasi Fase 2 selesai secara kode. Distribusi tester tetap menunggu behavioral test dua akun, dua perangkat, dan latihan restore pada project uji. Detail per task ada di [phase-2 tracker](phase-2-tracker.md).
