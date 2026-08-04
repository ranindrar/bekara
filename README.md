# Bekara

Riwayat perubahan yang dikerjakan Codex dicatat di [CHANGELOG-AI.md](CHANGELOG-AI.md).

Aplikasi Flutter offline-capable untuk pencatatan keuangan suami–istri. Drift/SQLite menyimpan cache dan antrean lokal; Supabase PostgreSQL menjadi sumber kebenaran bersama.

## Status

Fondasi project selesai: Flutter scaffold, Riverpod, GoRouter, Drift, bootstrap Supabase opsional, migration P0 awal, analyzer, dan smoke test.

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
