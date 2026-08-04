# Ledger Technical Specification

## 1. Prinsip

- Ledger adalah sumber kebenaran saldo.
- `amount` selalu positif; `direction` adalah `DEBIT` atau `CREDIT` dari perspektif wallet.
- Aggregate finansial posted tidak dihapus fisik.
- Transfer, reconciliation, reversal, dan pembayaran kewajiban atomik.
- Nilai disimpan `numeric(19,2)`; mobile tidak memakai floating point.

## 2. Aggregate dan posting

| Aggregate | Posting minimum |
|---|---|
| Income kas | CREDIT wallet |
| Expense kas | DEBIT wallet |
| Transfer | DEBIT source + CREDIT destination |
| Reconciliation naik | CREDIT wallet |
| Reconciliation turun | DEBIT wallet |
| Reversal | Posting lawan yang mereferensikan posting asal |
| Purchase PayLater (R1.2) | EXPENSE consumption + CREDIT liability account |
| Bill payment (R1.2) | DEBIT cash wallet + DEBIT/reduction liability |

Catatan PayLater masih konseptual sampai chart-of-accounts/liability representation diputuskan.

## 3. Rumus saldo

```text
wallet_balance = opening_balance
               + sum(CREDIT active postings)
               - sum(DEBIT active postings)
```

Reversal tidak menonaktifkan posting asal; ia menambahkan posting lawan. Status aggregate mencegah reversal ganda.

## 4. Scope versus dampak saldo

Scope mengatur pelaporan, bukan apakah posting mengubah saldo.

- Semua posting wallet mengubah saldo wallet.
- `HOUSEHOLD` masuk household spending.
- `PRIVATE` masuk personal spending pemilik.
- `PRIVATE` pada shared wallet tetap mengubah shared family balance.
- Internal transfer tidak masuk income/expense household.

## 5. State machine

```text
DRAFT (lokal saja) -> POSTED -> REVERSED
```

Database pusat tidak menyimpan draft finansial sebagai ledger. Edit `POSTED` diperbolehkan hanya pada periode yang belum terkunci dan selalu diaudit. Setelah terkunci, gunakan reversal/adjustment pada periode aktif.

## 6. Periode dan locking

Transaksi dipetakan ke personal period pemilik dan household period berdasarkan tanggal. Penguncian household period mencegah perubahan transaksi `HOUSEHOLD`; penguncian personal period mencegah perubahan transaksi `PRIVATE` pemilik. Aturan transaksi privat pada shared wallet ketika salah satu period terkunci masih **TBD** dan harus diputuskan sebelum implementasi locking.

## 7. Concurrency dan idempotensi

- RPC menggunakan database transaction.
- Wallet rows dapat dikunci konsisten menurut UUID untuk mencegah deadlock transfer silang.
- Mutation update memeriksa `version`.
- Idempotency record dibuat dalam transaksi yang sama.
- Tidak ada validasi saldo cukup pada P0; saldo negatif diizinkan dengan warning.

## 8. Audit

Audit mencatat actor, action, aggregate, before/after JSON, reason, request ID, client reference, waktu, dan versi. Audit berlaku pada create, update, reverse, reconciliation, perubahan privacy, perubahan periode, dan CRUD konfigurasi penting.

## 9. Invariant wajib diuji

- Retry tidak menggandakan posting.
- Transfer posted selalu memiliki dua posting utama seimbang.
- Reverse hanya sekali.
- Internal transfer tidak mengubah global household balance.
- Locked period menolak edit/reverse bertanggal lama.
- RLS mencegah akses lintas household.
- Pasangan tidak memperoleh detail privat melalui view, RPC error, realtime, atau audit.
