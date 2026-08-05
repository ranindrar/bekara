# AI Development Changelog

Catatan ini merekam perubahan yang dikerjakan oleh Codex untuk Bekara. Rahasia seperti access token, password, dan credential lokal tidak boleh dicantumkan.

## 2026-08-06

### Hardening keamanan Fase 1

- Memperbaiki potensi kebocoran transaksi `PRIVATE_FULL` dari RPC security-definer.
- Memasking dompet, kategori, arah, dan deskripsi transaksi `PRIVATE_SUMMARY` milik pasangan.
- Membatasi kategori privat dan mutation pada dompet milik pasangan.
- Mengubah dashboard dan laporan kategori agar cash-flow keluarga hanya memakai scope `HOUSEHOLD`.
- Menambahkan idempotensi payload untuk transaksi, transfer, dan reversal serta audit log transfer.
- Reversal transfer sekarang mengisi `transfers.reversed_at`.
- Menambahkan pilihan mode privasi, normalisasi nominal Indonesia, dan pesan error pengguna yang aman.
- Menambahkan 10 regression assertion PostgreSQL dan 6 test validasi finance; total Flutter test menjadi 11.
- Migration `202608060001_phase1_security_hardening.sql` diterapkan ke remote Supabase.

## 2026-08-05

### Fase 1 — household onboarding

- Menambahkan migration household invitation serta RPC `get_my_context`, `create_household`, `create_invitation`, dan `accept_invitation`.
- Menambahkan gate konteks keluarga setelah autentikasi dan UI untuk membuat atau bergabung ke household.
- Owner dapat membuat kode undangan pasangan yang terikat email dan berlaku tujuh hari.
- Menambahkan unit test parsing household context.
- Migration branding dan `202608050002_household_onboarding.sql` telah diterapkan ke remote Supabase; dry-run setelah deployment menyatakan database up-to-date.

### Fase 1 — pencatatan dasar selesai

- Menambahkan migration ledger Fase 1 untuk kategori bawaan, wallet, income, expense, transfer internal, dashboard, dan laporan kategori.
- Menambahkan RPC lifecycle untuk update wallet, arsip kategori, reversal transaksi, dan rekonsiliasi saldo.
- Menambahkan UI utama dengan navigasi beranda, transaksi, dompet, dan laporan.
- Menambahkan form dompet, kategori, income/expense, transfer internal, reversal, dan rekonsiliasi.
- Migration `202608050003_phase1_ledger.sql`, `202608050004_phase1_lifecycle.sql`, dan hardening permission `202608050005_phase1_function_hardening.sql` diterapkan ke remote Supabase.
- Verifikasi: analyzer tanpa issue, 7 automated test lulus, dan debug APK berhasil dibangun.
- Integration test RLS dengan dua akun dan real-device test tetap menjadi gate operasional sebelum distribusi.

### Penyelesaian fondasi Fase 0

- Menambahkan logging dasar yang tidak mencatat credential atau payload finansial.
- Menangkap error Flutter, platform, zone, dan kegagalan bootstrap; kegagalan startup menampilkan pesan aman kepada pengguna.
- Menambahkan GitHub Actions untuk code generation Drift, analyzer, test coverage, dan debug APK build.
- Menambahkan test konfigurasi environment dan tampilan kegagalan bootstrap.
- Memperbarui status implementasi agar membedakan fondasi kode yang selesai dari verifikasi operasional.
- Supabase CLI dan perangkat Android tidak tersedia pada sesi ini. Deployment migration branding, test RLS/RPC remote, dan auth test pada perangkat nyata tetap `PENDING OPS` dan tidak diklaim selesai.
- `flutter doctor` menemukan Android command-line tools belum terpasang dan status license belum diketahui.
- Verifikasi akhir: `flutter analyze` tanpa issue, 5 automated test lulus, dan debug APK berhasil dibuat.

### Branding — Dompet Keluarga menjadi Bekara

- Mengadopsi nama produk **Bekara** berdasarkan `Bekara_Brand_Identity.md`.
- Mengubah nama aplikasi Android menjadi `Bekara`.
- Mengubah Dart package dari `dompet_keluarga` menjadi `bekara`.
- Mengubah Android namespace dan application ID menjadi `id.bekara.app`.
- Mengganti root widget menjadi `BekaraApp` dan file menjadi `lib/app/bekara_app.dart`.
- Mengubah nama database Drift lokal menjadi `bekara`.
- Mengganti product specification menjadi `bekara-spec.md` dan memperbarui referensi dokumentasi.
- Menambahkan migration komentar schema `202608050001_bekara_branding.sql`; belum dicatat sebagai deployed pada tanggal ini.
- Menjalankan `flutter analyze` tanpa issue dan `flutter test` dengan 2 test lulus.
- Membuat ulang debug APK Bekara dari build bersih.
- Menambahkan baseline Git dan mengecualikan metadata lokal Supabase dari version control.

### Catatan kompatibilitas

- Android menganggap `id.bekara.app` sebagai aplikasi berbeda dari application ID sebelumnya.
- Database lokal memakai nama baru. Karena aplikasi belum dirilis dan belum memiliki data produksi, tidak dibuat migrasi data dari instalasi lama.
- Nama folder workspace masih `D:\Project\Dompek Keluarga`; rename folder dilakukan terpisah setelah sesi/tool yang memakai path lama ditutup.

## 2026-08-04

### Fondasi aplikasi

- Membuat Flutter Android scaffold dengan Riverpod dan GoRouter.
- Menambahkan Drift/SQLite untuk cache wallet dan antrean mutation offline awal.
- Menghubungkan konfigurasi aplikasi ke Supabase melalui file lokal yang diabaikan Git.
- Mengimplementasikan register, login, reset password, session gate, dan logout.
- Menambahkan widget test untuk bootstrap dan validasi autentikasi.
- Menyiapkan dokumentasi arsitektur, API v1, ledger, database, fase 2, pembelajaran, serta workflow tester.

### Supabase

- Menerapkan migration `202608040001_initial_p0.sql` ke project Supabase.
- Menerapkan migration `202608040002_auth_profile_and_privacy_hardening.sql`.
- Menambahkan tabel inti P0, ledger, audit trail, idempotency, view saldo, RLS, dan profile trigger.
- Memperketat akses transaksi dan ledger privat agar tidak bocor kepada anggota household lain.
- Memverifikasi akses anonim tidak dapat membaca profil yang dilindungi RLS.

### Keamanan

- Menyimpan publishable configuration hanya pada file lokal yang diabaikan Git.
- Memastikan personal access token tidak tersimpan di workspace.
- Logout Supabase CLI setelah deployment.

## Aturan pemeliharaan

Setiap perubahan material oleh Codex harus menambahkan entri yang mencakup:

- tanggal perubahan;
- fitur atau area yang berubah;
- migration dan status deployment;
- hasil test/build;
- breaking change atau dampak kompatibilitas;
- keputusan produk baru;
- masalah yang masih terbuka.
