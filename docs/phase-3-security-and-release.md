# Phase 3 Security and Release Plan

## Threat model

| Resource | Owner/primary holder | Anggota household aktif | Non-member / anon | Enforcement |
|---|---|---|---|---|
| Personal PayLater/credit account | Detail penuh, kelola, beli, bayar | Tidak dapat melihat account/bill/limit | Ditolak | `can_view_credit_account`, `can_manage_credit_account`, RPC check |
| Household credit card | Detail penuh; primary holder/household owner mengelola | Lihat, beli, dan bayar; actor/payer direkam | Ditolak | Account RLS dan server-side scope coercion |
| Household purchase pada personal credit | Detail penuh sebagai bagian bill personal | Hanya reserve agregat household | Ditolak | `credit_forecast`; account, bill, dan installment tetap tersembunyi |
| PRIVATE_FULL / PRIVATE_SUMMARY | Owner dapat melihat | Tidak dapat melihat attachment; summary tidak membuka deskripsi | Ditolak | Transaction visibility RPC dan attachment RPC/RLS |
| Notification | Hanya user yang berhak melihat bill | Hanya untuk household card yang terlihat | Ditolak | Query dari visible bill dan receipt unik per user/event |
| CSV batch | Actor pengimpor | Tidak dapat melihat batch actor lain | Ditolak | Batch RLS, RPC auth, source hash per actor |
| Receipt object | Owner; household-visible receipt juga anggota aktif | Sesuai visibility transaksi | Ditolak | Bucket private, validated path, metadata match, signed URL 5 menit |

Mobile roles tidak memperoleh direct write ke tabel kredit, import, attachment metadata, ledger, atau audit. Seluruh mutation melalui RPC `security definer` yang menetapkan `search_path`, memeriksa actor/household, menggunakan idempotency key, dan menulis audit. PAN dan CVV tidak memiliki kolom penyimpanan; hanya empat digit terakhir opsional.

## Attachment controls

- Ukuran 1 byte–5 MB dan MIME hanya JPEG, PNG, WEBP, atau PDF.
- Path wajib `householdId/actorId/transactionId/random.ext`.
- Metadata MIME dan ukuran pada Storage harus sama dengan payload registrasi; mismatch ditolak sebagai `ATTACHMENT_METADATA_INVALID`.
- Upload yang gagal diregistrasi dibersihkan oleh aplikasi. Delete metadata diaudit sebelum object cleanup.
- Object URL tidak disimpan. Aplikasi hanya membuat signed URL berdurasi 300 detik.

## Migration and recovery

Migration Phase 3 bersifat additive dan berurutan:

1. `202608080001_phase3_credit_core.sql`
2. `202608080002_phase3_credit_operations.sql`
3. `202608080003_phase3_tools.sql`
4. `202608080004_phase3_finance_hardening.sql`
5. `202608080005_phase3_sync_backup.sql`

Migration diuji dari database kosong dengan `supabase db reset`. Karena data finansial append-only dan migration membuat enum/table/policy/function baru, rollback produksi menggunakan forward-fix; migration yang sudah diterapkan tidak diubah atau dihapus. Sebelum deployment, ambil backup database dan verifikasi project target. Setelah deployment, jalankan lint, pgTAP, dan smoke test dua akun.

Backup aplikasi schema v3 mencakup cache account, bill, installment, notification, pending mutation, cursor, dan remote export manifest attachment. Binary receipt tidak dimasukkan ke JSON; restore mengembalikan manifest lalu object diambil ulang dari private Storage setelah otorisasi. Reader v3 tetap menerima backup cache v2.

## Release gates

Automated gate lokal harus lulus: migration reset, database lint, pgTAP, Flutter analyzer, Flutter tests, dan debug APK build. Deployment remote, behavioral test dua akun/dua perangkat, physical-device picker/lifecycle test, dan full restore pada project uji merupakan gate operasional terpisah dan tidak boleh diklaim lulus tanpa evidence lingkungan tersebut.

Known toolchain note: project saat ini mempertahankan `android.builtInKotlin=false`, sehingga `file_picker` dipin ke 10.3.10. Debug APK lulus, tetapi Flutter memberi peringatan kompatibilitas KGP untuk versi toolchain mendatang. Upgrade ke built-in Kotlin dan `file_picker` 11+ harus dilakukan bersama sebagai maintenance terpisah, lalu seluruh Android gate diulang.
