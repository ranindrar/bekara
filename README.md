# Bekara

Bekara is a family financial companion that empowers everyday families to manage money wisely and prepare for a better future.

Riwayat perubahan yang dikerjakan Codex dicatat di [CHANGELOG-AI.md](CHANGELOG-AI.md).

Aplikasi Flutter offline-capable untuk pencatatan keuangan suami–istri. Drift/SQLite menyimpan cache dan antrean lokal; Supabase PostgreSQL menjadi sumber kebenaran bersama.

## Status

Fase 3 kewajiban dan import selesai secara kode: akun PayLater/kartu kredit, billing period, cicilan, pembayaran kewajiban, notifikasi in-app, import CSV, dan lampiran nota, di atas fondasi cash-flow Fase 2. Migration Fase 3 belum diterapkan ke Supabase remote. Verifikasi operasional dua akun/perangkat, perangkat fisik, dan restore project uji dicatat di [implementation status](docs/implementation-status.md).

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
