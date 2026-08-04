# Supabase Development

Migration P0 awal berada di `migrations/`. Financial tables sengaja read-only bagi mobile sampai RPC audited untuk create household, wallet, transaction, transfer, reconciliation, dan reversal ditambahkan.

Local stack (setelah Supabase CLI tersedia):

```powershell
supabase start
supabase db reset
```

Jangan menjalankan reset pada project remote yang berisi data nyata.

## Verifikasi sebelum release internal

1. Terapkan seluruh migration berurutan pada local stack atau project uji.
2. Pastikan daftar migration remote mencakup `202608050001_bekara_branding.sql`.
3. Jalankan pengujian sebagai anonymous, user household A, dan user household B.
4. Pastikan anonymous tidak dapat membaca profile dan data finansial.
5. Pastikan anggota tidak dapat membaca detail transaksi `PRIVATE` milik anggota lain.
6. Jangan gunakan service-role key di aplikasi Flutter atau file yang masuk Git.

Migration finansial tetap read-only dari mobile sampai RPC audited Fase 1 tersedia.
