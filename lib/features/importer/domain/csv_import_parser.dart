import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

class CsvImportRow {
  const CsvImportRow({
    required this.rowNumber,
    required this.date,
    required this.kind,
    required this.amount,
    required this.description,
  });

  final int rowNumber;
  final DateTime date;
  final String kind;
  final String amount;
  final String description;
}

class CsvImportIssue {
  const CsvImportIssue(this.rowNumber, this.message);
  final int rowNumber;
  final String message;
}

class CsvImportPreview {
  const CsvImportPreview({
    required this.sourceHash,
    required this.rows,
    required this.issues,
  });
  final String sourceHash;
  final List<CsvImportRow> rows;
  final List<CsvImportIssue> issues;
}

abstract final class CsvImportParser {
  static const maxBytes = 5 * 1024 * 1024;

  static CsvImportPreview parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('CSV harus berukuran 1 byte–5 MB.');
    }
    final source = utf8
        .decode(bytes, allowMalformed: false)
        .replaceFirst('\ufeff', '');
    final lines = _records(source);
    if (lines.length < 2 || lines.length > 1001) {
      throw const FormatException('CSV harus memiliki 1–1000 baris data.');
    }
    final delimiter = _delimiter(lines.first);
    final header = _cells(
      lines.first,
      delimiter,
    ).map((value) => value.trim().toLowerCase().replaceAll(' ', '_')).toList();
    final dateIndex = _index(header, const [
      'tanggal',
      'date',
      'transaction_date',
    ]);
    final amountIndex = _index(header, const ['nominal', 'amount', 'jumlah']);
    final typeIndex = _index(header, const ['jenis', 'type', 'kind']);
    final descriptionIndex = _index(header, const [
      'deskripsi',
      'description',
      'keterangan',
    ]);
    if ([dateIndex, amountIndex, typeIndex, descriptionIndex].contains(-1)) {
      throw const FormatException(
        'Header wajib: tanggal, nominal, jenis, dan deskripsi.',
      );
    }
    final rows = <CsvImportRow>[];
    final issues = <CsvImportIssue>[];
    final signatures = <String>{};
    for (var index = 1; index < lines.length; index++) {
      final rowNumber = index + 1;
      final cells = _cells(lines[index], delimiter);
      try {
        final date = _date(_cell(cells, dateIndex));
        final amount = _amount(_cell(cells, amountIndex));
        final kind = _kind(_cell(cells, typeIndex));
        final description = _cell(cells, descriptionIndex).trim();
        if (description.isEmpty) {
          throw const FormatException('Deskripsi kosong.');
        }
        final signature =
            '${date.toIso8601String()}|$kind|$amount|${description.toLowerCase()}';
        if (!signatures.add(signature)) {
          issues.add(CsvImportIssue(rowNumber, 'Baris terindikasi duplikat.'));
        } else {
          rows.add(
            CsvImportRow(
              rowNumber: rowNumber,
              date: date,
              kind: kind,
              amount: amount,
              description: description,
            ),
          );
        }
      } on FormatException catch (error) {
        issues.add(CsvImportIssue(rowNumber, error.message));
      }
    }
    return CsvImportPreview(
      sourceHash: sha256.convert(bytes).toString(),
      rows: rows,
      issues: issues,
    );
  }

  static List<String> _records(String source) {
    final result = <String>[];
    var current = StringBuffer();
    var quoted = false;
    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == '"') {
        quoted = !quoted;
        current.write(char);
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
          i++;
        }
        if (current.toString().trim().isNotEmpty) {
          result.add(current.toString());
        }
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (quoted) {
      throw const FormatException('Tanda kutip CSV tidak berpasangan.');
    }
    if (current.toString().trim().isNotEmpty) {
      result.add(current.toString());
    }
    return result;
  }

  static String _delimiter(String header) {
    final commas = header.split(',').length;
    final semicolons = header.split(';').length;
    return semicolons > commas ? ';' : ',';
  }

  static List<String> _cells(String line, String delimiter) {
    final result = <String>[];
    var current = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == delimiter && !quoted) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (quoted) {
      throw const FormatException('Tanda kutip CSV tidak berpasangan.');
    }
    result.add(current.toString());
    return result;
  }

  static int _index(List<String> header, List<String> aliases) =>
      header.indexWhere(aliases.contains);

  static String _cell(List<String> cells, int index) {
    if (index >= cells.length) {
      throw const FormatException('Kolom tidak lengkap.');
    }
    return cells[index];
  }

  static DateTime _date(String raw) {
    for (final format in const ['yyyy-MM-dd', 'dd/MM/yyyy', 'dd-MM-yyyy']) {
      try {
        return DateFormat(format).parseStrict(raw.trim());
      } on FormatException {
        // Try the next supported format.
      }
    }
    throw const FormatException('Tanggal tidak valid.');
  }

  static String _amount(String raw) {
    var value = raw.trim().replaceAll(
      RegExp(r'\s|Rp', caseSensitive: false),
      '',
    );
    if (value.contains(',') && value.contains('.')) {
      value = value.lastIndexOf(',') > value.lastIndexOf('.')
          ? value.replaceAll('.', '').replaceAll(',', '.')
          : value.replaceAll(',', '');
    } else if (value.contains(',')) {
      final decimalDigits = value.length - value.lastIndexOf(',') - 1;
      value = decimalDigits <= 2
          ? value.replaceAll(',', '.')
          : value.replaceAll(',', '');
    } else if (value.contains('.')) {
      final groups = value.split('.');
      final groupedThousands =
          groups.length > 1 &&
          groups.skip(1).every((group) => group.length == 3);
      if (groupedThousands) value = value.replaceAll('.', '');
    }
    final parsed = num.tryParse(value);
    if (parsed == null || parsed <= 0) {
      throw const FormatException('Nominal tidak valid.');
    }
    return parsed.toStringAsFixed(2);
  }

  static String _kind(String raw) {
    return switch (raw.trim().toUpperCase()) {
      'EXPENSE' || 'PENGELUARAN' || 'DEBIT' => 'EXPENSE',
      'INCOME' || 'PEMASUKAN' || 'CREDIT' => 'INCOME',
      _ => throw const FormatException(
        'Jenis harus pemasukan atau pengeluaran.',
      ),
    };
  }
}
