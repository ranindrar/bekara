import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';

class BackupService {
  BackupService(this.database);

  final AppDatabase database;

  Future<String> createBackup(Map<String, dynamic> remoteData) async {
    final pending = await database.select(database.pendingMutations).get();
    final changes = await database.select(database.cachedSyncChanges).get();
    final cursors = await database.select(database.syncCursors).get();
    final payload = <String, dynamic>{
      'schemaVersion': 2,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'remote': remoteData,
      'local': {
        'pendingMutations': pending.map((row) => row.toJson()).toList(),
        'syncChanges': changes.map((row) => row.toJson()).toList(),
        'syncCursors': cursors.map((row) => row.toJson()).toList(),
      },
    };
    final canonical = _encode(payload);
    return _encode({
      'checksum': sha256.convert(utf8.encode(canonical)).toString(),
      'payload': payload,
    });
  }

  Future<void> restoreLocalBackup(String source) async {
    final document = jsonDecode(source) as Map<String, dynamic>;
    final payload = Map<String, dynamic>.from(document['payload'] as Map);
    final canonical = _encode(payload);
    final checksum = sha256.convert(utf8.encode(canonical)).toString();
    if (checksum != document['checksum']) {
      throw const FormatException('Checksum backup tidak cocok.');
    }
    if (payload['schemaVersion'] != 2) {
      throw const FormatException('Versi backup belum didukung.');
    }
    final local = Map<String, dynamic>.from(payload['local'] as Map);
    await database.transaction(() async {
      for (final raw in local['pendingMutations'] as List? ?? const []) {
        final row = Map<String, dynamic>.from(raw as Map);
        await database
            .into(database.pendingMutations)
            .insertOnConflictUpdate(
              PendingMutationsCompanion.insert(
                clientReferenceId: row['clientReferenceId'] as String,
                operation: row['operation'] as String,
                aggregateId: Value(row['aggregateId'] as String?),
                payloadJson: row['payloadJson'] as String,
                syncStatus: Value(row['syncStatus'] as String),
                attemptCount: Value(row['attemptCount'] as int),
                lastError: Value(row['lastError'] as String?),
                createdAt: Value(_parseDate(row['createdAt'])!),
                updatedAt: Value(_parseDate(row['updatedAt'])!),
              ),
            );
      }
      for (final raw in local['syncChanges'] as List? ?? const []) {
        final row = Map<String, dynamic>.from(raw as Map);
        await database
            .into(database.cachedSyncChanges)
            .insertOnConflictUpdate(
              CachedSyncChangesCompanion.insert(
                entityType: row['entityType'] as String,
                entityId: row['entityId'] as String,
                householdId: row['householdId'] as String,
                operation: row['operation'] as String,
                serverSequence: BigInt.parse(row['serverSequence'].toString()),
                tombstone: Value(row['tombstone'] as bool),
                changedAt: _parseDate(row['changedAt'])!,
              ),
            );
      }
      for (final raw in local['syncCursors'] as List? ?? const []) {
        final row = Map<String, dynamic>.from(raw as Map);
        await database
            .into(database.syncCursors)
            .insertOnConflictUpdate(
              SyncCursorsCompanion.insert(
                householdId: row['householdId'] as String,
                cursor: Value(BigInt.parse(row['cursor'].toString())),
                lastSuccessAt: Value(_parseDate(row['lastSuccessAt'])),
              ),
            );
      }
    });
  }

  String transactionsCsv(
    Map<String, dynamic> remoteData, {
    bool includePrivateDescriptions = false,
  }) {
    final rows = <List<String>>[
      ['tanggal', 'jenis', 'scope', 'nominal', 'deskripsi'],
    ];
    for (final raw in remoteData['transactions'] as List? ?? const []) {
      final item = Map<String, dynamic>.from(raw as Map);
      final aggregate = Map<String, dynamic>.from(item['aggregate'] as Map);
      final entries = item['entries'] as List? ?? const [];
      final first = entries.isEmpty
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(entries.first as Map);
      final private = aggregate['scope'] == 'PRIVATE';
      rows.add([
        aggregate['transaction_date']?.toString() ?? '',
        aggregate['kind']?.toString() ?? '',
        aggregate['scope']?.toString() ?? '',
        first['amount']?.toString() ?? '',
        private && !includePrivateDescriptions
            ? ''
            : aggregate['description']?.toString() ?? '',
      ]);
    }
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  static String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return DateTime.parse(value.toString());
  }

  static String _encode(Object? value) => jsonEncode(
    value,
    toEncodable: (object) {
      if (object is BigInt) return object.toString();
      if (object is DateTime) return object.toUtc().toIso8601String();
      throw UnsupportedError('Nilai backup tidak didukung.');
    },
  );
}
