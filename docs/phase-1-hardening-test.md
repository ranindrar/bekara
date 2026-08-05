# Fase 1 Hardening Test

## Automated gates

```powershell
npx --yes supabase@latest test db
C:\Development\flutter\bin\flutter.bat analyze
C:\Development\flutter\bin\flutter.bat test
```

## Two-account privacy test

Gunakan dua akun terkonfirmasi A dan B dalam household yang sama.

1. A membuat dompet privat, dompet shared, kategori privat, dan kategori household.
2. A mencatat `PRIVATE_FULL`; B tidak boleh menerima baris transaksi tersebut.
3. A mencatat `PRIVATE_SUMMARY`; B hanya menerima tanggal, jenis, dan nominal. Nama dompet, kategori, serta deskripsi harus `null`.
4. A mencatat `HOUSEHOLD`; B dapat melihat seluruh detail.
5. B mencoba posting ke dompet privat A dan harus mendapat `FORBIDDEN`.
6. B mencoba memakai kategori privat A dan harus mendapat validation/authorization error.
7. B boleh posting ke dompet shared dengan kategori household.
8. Retry transaksi dan transfer dengan reference serta payload identik mengembalikan response awal tanpa ledger tambahan.
9. Retry reference sama dengan payload berbeda menghasilkan `IDEMPOTENCY_CONFLICT`.
10. Reversal transfer membuat dua posting lawan dan mengisi `transfers.reversed_at`.

Jangan menjalankan test dengan service-role client karena service role melewati RLS.
