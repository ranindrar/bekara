# Bekara

Bekara is a family financial companion that empowers everyday families to manage money wisely and prepare for a better future.

Riwayat perubahan yang dikerjakan Codex dicatat di [CHANGELOG-AI.md](CHANGELOG-AI.md).

Aplikasi Flutter offline-capable untuk pencatatan keuangan suami–istri. Drift/SQLite menyimpan cache dan antrean lokal; Supabase PostgreSQL menjadi sumber kebenaran bersama.

## Status

Fase 2 cash-flow selesai secara kode: periode dan locking, koreksi ter-audit, budget, soft locked funds, batas aman harian, tagihan rutin, sinkronisasi, backup JSON, dan export CSV. Verifikasi operasional dua akun/perangkat dan restore project uji dicatat di [implementation status](docs/implementation-status.md).

## Menjalankan

```powershell
C:\Development\flutter\bin\flutter.bat pub get
C:\Development\flutter\bin\dart.bat run build_runner build
C:\Development\flutter\bin\flutter.bat run `
  --dart-define-from-file=config/dev.json
```

Tanpa konfigurasi Supabase, aplikasi tetap dapat dibuka dan menampilkan status local-only.
File `config/dev.json` bersifat lokal dan diabaikan Git.

## Quality checks

```powershell
C:\Development\flutter\bin\flutter.bat analyze
C:\Development\flutter\bin\flutter.bat test
```

Dokumentasi lengkap tersedia di [docs/README.md](docs/README.md).
