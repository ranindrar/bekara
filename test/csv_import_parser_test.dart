import 'dart:convert';
import 'dart:typed_data';

import 'package:bekara/features/importer/domain/csv_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses Indonesian semicolon CSV and quoted descriptions', () {
    final preview = CsvImportParser.parse(
      Uint8List.fromList(
        utf8.encode(
          'tanggal;jenis;nominal;deskripsi\r\n'
          '08/08/2026;pengeluaran;Rp 12.500;"Makan, siang"\r\n'
          '2026-08-07;pemasukan;100000;Gaji',
        ),
      ),
    );

    expect(preview.issues, isEmpty);
    expect(preview.rows, hasLength(2));
    expect(preview.rows.first.amount, '12500.00');
    expect(preview.rows.first.description, 'Makan, siang');
    expect(preview.rows.last.kind, 'INCOME');
    expect(preview.sourceHash, hasLength(64));
  });

  test('reports invalid rows without silently committing them', () {
    final preview = CsvImportParser.parse(
      Uint8List.fromList(
        utf8.encode(
          'tanggal,jenis,nominal,deskripsi\n'
          '2026-08-08,pengeluaran,-10,Tidak valid\n'
          '2026-08-08,pengeluaran,25000,Valid',
        ),
      ),
    );
    expect(preview.rows, hasLength(1));
    expect(preview.issues.single.rowNumber, 2);
  });

  test('requires canonical headers', () {
    expect(
      () => CsvImportParser.parse(
        Uint8List.fromList(utf8.encode('foo,bar\n1,2')),
      ),
      throwsFormatException,
    );
  });

  test('flags duplicate normalized rows', () {
    final preview = CsvImportParser.parse(
      Uint8List.fromList(
        utf8.encode(
          'tanggal,jenis,nominal,deskripsi\n'
          '2026-08-08,pengeluaran,25000,Makan\n'
          '2026-08-08,expense,25.000,makan',
        ),
      ),
    );
    expect(preview.rows, hasLength(1));
    expect(preview.issues.single.message, contains('duplikat'));
  });
}
