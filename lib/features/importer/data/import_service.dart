import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/csv_import_parser.dart';

class ImportService {
  ImportService(this.client);
  final SupabaseClient client;
  static const _uuid = Uuid();

  Future<Map<String, dynamic>> commit({
    required String fileName,
    required CsvImportPreview preview,
    required String walletId,
    required String expenseCategoryId,
    required String incomeCategoryId,
    required String scope,
    required String privacyMode,
  }) async => Map<String, dynamic>.from(
    await client.rpc(
          'commit_import_batch',
          params: {
            'payload': {
              'fileName': fileName,
              'sourceHash': preview.sourceHash,
              'rows': [
                for (final row in preview.rows)
                  {
                    'clientReferenceId': _uuid.v4(),
                    'walletId': walletId,
                    'categoryId': row.kind == 'EXPENSE'
                        ? expenseCategoryId
                        : incomeCategoryId,
                    'kind': row.kind,
                    'amount': row.amount,
                    'description': row.description,
                    'transactionDate': DateFormat(
                      'yyyy-MM-dd',
                    ).format(row.date),
                    'scope': scope,
                    'privacyMode': scope == 'HOUSEHOLD'
                        ? 'HOUSEHOLD_VISIBLE'
                        : privacyMode,
                  },
              ],
            },
          },
        )
        as Map,
  );

  Future<List<Map<String, dynamic>>> batches() async =>
      (await client.rpc('list_import_batches') as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
}
