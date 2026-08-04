# Supabase Development

Migration P0 awal berada di `migrations/`. Financial tables sengaja read-only bagi mobile sampai RPC audited untuk create household, wallet, transaction, transfer, reconciliation, dan reversal ditambahkan.

Local stack (setelah Supabase CLI tersedia):

```powershell
supabase start
supabase db reset
```

Jangan menjalankan reset pada project remote yang berisi data nyata.
