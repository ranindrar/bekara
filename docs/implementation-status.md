# Implementation Status

Terakhir diverifikasi: 5 Agustus 2026.

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
| Deploy migration branding `202608050001` | PENDING OPS | Supabase CLI/session atau database credential tidak tersedia di workstation |
| Integration test RLS/RPC remote | PENDING OPS | RPC household belum termasuk Fase 0; audit read-policy awal sudah dilakukan, suite end-to-end dilanjutkan bersama slice household |
| Auth test pada Android nyata | PENDING OPS | Tidak ada perangkat/emulator Android aktif |
| Android toolchain health | ACTION REQUIRED | Pasang Android command-line tools dan terima SDK licenses |

Status `PENDING OPS` bukan implementasi aplikasi yang belum dibuat, tetapi gate verifikasi lingkungan sebelum rilis internal.

## Next implementation slice

1. Tambahkan RPC create household dan invitation.
2. Implementasikan onboarding household.
3. Tambahkan integration test RLS dan RPC.
4. Uji registrasi/login pada perangkat nyata.
5. Implementasikan dompet, kategori, dan transaksi setelah onboarding tervalidasi.
