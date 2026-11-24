class FinanceValidation {
  const FinanceValidation._();

  static String normalizeAmount(String value, {bool allowZero = false}) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    final amount = num.tryParse(normalized);
    if (amount == null || amount.isNaN || amount.isInfinite) {
      throw const FormatException('Masukkan nominal yang valid.');
    }
    if (allowZero ? amount < 0 : amount <= 0) {
      throw FormatException(
        allowZero
            ? 'Nominal tidak boleh negatif.'
            : 'Nominal harus lebih dari nol.',
      );
    }
    return amount.toString();
  }

  static String normalizeSignedAmount(String value) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    final amount = num.tryParse(normalized);
    if (amount == null || amount.isNaN || amount.isInfinite) {
      throw const FormatException('Masukkan nominal yang valid.');
    }
    return amount.toString();
  }

  static String requiredText(String value, String label, {int minLength = 1}) {
    final normalized = value.trim();
    if (normalized.length < minLength) {
      throw FormatException('$label minimal $minLength karakter.');
    }
    return normalized;
  }

  static String friendlyError(Object error) {
    final message = error.toString().toUpperCase();
    if (error is FormatException) {
      return error.message.toString();
    }
    if (message.contains('WALLET_INACTIVE')) return 'Dompet sudah tidak aktif.';
    if (message.contains('TRANSFER_SAME_WALLET')) {
      return 'Dompet asal dan tujuan harus berbeda.';
    }
    if (message.contains('VERSION_CONFLICT')) {
      return 'Data sudah berubah. Muat ulang lalu coba lagi.';
    }
    if (message.contains('IDEMPOTENCY_CONFLICT')) {
      return 'Permintaan duplikat memiliki data berbeda.';
    }
    if (message.contains('PERIOD_LOCKED')) {
      return 'Periode transaksi sudah dikunci. Gunakan menu koreksi.';
    }
    if (message.contains('LOCKED_FUNDS_IN_USE')) {
      return 'Saldo ini dialokasikan sebagai dana terkunci. Lepaskan alokasinya sebelum digunakan.';
    }
    if (message.contains('CREDIT_OVERPAYMENT')) {
      return 'Pembayaran melebihi sisa tagihan.';
    }
    if (message.contains('CREDIT_ACCOUNT_NOT_EMPTY')) {
      return 'Akun kredit masih memiliki kewajiban.';
    }
    if (message.contains('CREDIT_ACCOUNT_INACTIVE')) {
      return 'Akun kredit sudah tidak aktif.';
    }
    if (message.contains('CREDIT_ACCOUNT_REQUIRED')) {
      return 'Buat akun kredit dari menu Kredit.';
    }
    if (message.contains('IMPORT_INVALID_FORMAT')) {
      return 'Format atau isi CSV belum valid.';
    }
    if (message.contains('ATTACHMENT_TOO_LARGE')) {
      return 'Lampiran maksimum 5 MB.';
    }
    if (message.contains('ATTACHMENT_INVALID_TYPE')) {
      return 'Lampiran harus berupa JPEG, PNG, WEBP, atau PDF.';
    }
    if (message.contains('ATTACHMENT_METADATA_INVALID')) {
      return 'Metadata lampiran tidak cocok dengan berkas yang diunggah.';
    }
    if (message.contains('UNAUTHENTICATED')) {
      return 'Sesi Anda sudah berakhir. Silakan masuk kembali.';
    }
    if (message.contains('NOT_FOUND: WALLET')) {
      return 'Dompet tidak ditemukan atau sudah tidak tersedia.';
    }
    if (message.contains('VALIDATION_ERROR: CATEGORY')) {
      return 'Kategori tidak sesuai dengan jenis atau cakupan transaksi.';
    }
    if (message.contains('FORBIDDEN')) {
      return 'Anda tidak memiliki izin untuk aksi ini.';
    }
    if (message.contains('VALIDATION_ERROR')) {
      return 'Data belum valid. Periksa kembali input Anda.';
    }
    return 'Data gagal disimpan. Muat ulang lalu coba lagi.';
  }
}
