import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';

class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.conflicts,
  });

  final int pushed;
  final int pulled;
  final int conflicts;
}

class SyncService {
  SyncService(this.client, this.database);

  final SupabaseClient client;
  final AppDatabase database;

  Future<SyncResult> synchronize(String householdId) async {
    var pushed = 0;
    var conflicts = 0;
    final pending =
        await (database.select(database.pendingMutations)
              ..where(
                (row) =>
                    row.syncStatus.isIn(['PENDING_SYNC', 'SYNC_FAILED']) &
                    row.attemptCount.isSmallerThanValue(5),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();

    for (final mutation in pending) {
      await (database.update(database.pendingMutations)..where(
            (row) => row.clientReferenceId.equals(mutation.clientReferenceId),
          ))
          .write(
            PendingMutationsCompanion(
              syncStatus: const Value('SYNCING'),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      try {
        final decoded =
            jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
        final params = decoded['params'] is Map
            ? Map<String, dynamic>.from(decoded['params'] as Map)
            : decoded;
        await client.rpc(mutation.operation, params: params);
        await (database.delete(database.pendingMutations)..where(
              (row) => row.clientReferenceId.equals(mutation.clientReferenceId),
            ))
            .go();
        pushed++;
      } catch (error) {
        final safeCode = _safeErrorCode(error);
        final conflict =
            safeCode == 'VERSION_CONFLICT' ||
            safeCode == 'PERIOD_LOCKED' ||
            safeCode == 'IDEMPOTENCY_CONFLICT';
        await (database.update(database.pendingMutations)..where(
              (row) => row.clientReferenceId.equals(mutation.clientReferenceId),
            ))
            .write(
              PendingMutationsCompanion(
                syncStatus: Value(conflict ? 'CONFLICT' : 'SYNC_FAILED'),
                attemptCount: Value(mutation.attemptCount + 1),
                lastError: Value(safeCode),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
        if (conflict) conflicts++;
        await _metric('PUSH_FAILURE', mutation.operation, safeCode);
      }
    }

    final pulled = await _pull(householdId);
    await _metric('SYNC_SUCCESS', null, null);
    return SyncResult(pushed: pushed, pulled: pulled, conflicts: conflicts);
  }

  Future<int> _pull(String householdId) async {
    final stored = await (database.select(
      database.syncCursors,
    )..where((row) => row.householdId.equals(householdId))).getSingleOrNull();
    var cursor = stored?.cursor ?? BigInt.zero;
    var pulled = 0;
    var hasMore = true;

    while (hasMore) {
      final response = Map<String, dynamic>.from(
        await client.rpc(
              'sync_changes',
              params: {'cursor_value': cursor.toInt(), 'result_limit': 100},
            )
            as Map,
      );
      final changes = (response['changes'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      );
      await database.batch((batch) {
        for (final change in changes) {
          final sequence = BigInt.from(change['sequence'] as num);
          batch.insert(
            database.cachedSyncChanges,
            CachedSyncChangesCompanion.insert(
              entityType: change['entity'] as String,
              entityId: change['entityId'] as String,
              householdId: householdId,
              operation: change['operation'] as String,
              serverSequence: sequence,
              tombstone: Value(change['operation'] == 'TOMBSTONE'),
              changedAt: DateTime.parse(change['changedAt'] as String),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      pulled += changes.length;
      cursor = BigInt.from(response['nextCursor'] as num);
      hasMore = response['hasMore'] as bool? ?? false;
    }

    await database
        .into(database.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            householdId: householdId,
            cursor: Value(cursor),
            lastSuccessAt: Value(DateTime.now().toUtc()),
          ),
        );
    return pulled;
  }

  Future<void> _metric(
    String eventType,
    String? operation,
    String? errorCode,
  ) => database
      .into(database.syncEvents)
      .insert(
        SyncEventsCompanion.insert(
          eventType: eventType,
          operation: Value(operation),
          errorCode: Value(errorCode),
        ),
      );

  static String _safeErrorCode(Object error) {
    final value = error.toString().toUpperCase();
    for (final code in const [
      'VERSION_CONFLICT',
      'PERIOD_LOCKED',
      'IDEMPOTENCY_CONFLICT',
      'UNAUTHENTICATED',
      'FORBIDDEN',
      'VALIDATION_ERROR',
      'NOT_FOUND',
    ]) {
      if (value.contains(code)) return code;
    }
    return 'NETWORK_OR_SERVER_ERROR';
  }
}
