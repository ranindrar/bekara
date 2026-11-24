import 'package:bekara/core/backup/backup_service.dart';
import 'package:bekara/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('backup checksum and restore are idempotent', () async {
    await database
        .into(database.pendingMutations)
        .insert(
          PendingMutationsCompanion.insert(
            clientReferenceId: 'ref-1',
            operation: 'post_transaction',
            payloadJson: '{"params":{}}',
          ),
        );
    await database
        .into(database.cachedSyncChanges)
        .insert(
          CachedSyncChangesCompanion.insert(
            entityType: 'TRANSACTION',
            entityId: 'transaction-1',
            householdId: 'household-1',
            operation: 'UPSERT',
            serverSequence: BigInt.one,
            changedAt: DateTime.utc(2026, 8, 6),
          ),
        );
    await database
        .into(database.syncCursors)
        .insert(
          SyncCursorsCompanion.insert(
            householdId: 'household-1',
            cursor: Value(BigInt.one),
          ),
        );
    await database
        .into(database.localCreditAccounts)
        .insert(
          LocalCreditAccountsCompanion.insert(
            id: 'credit-1',
            householdId: 'household-1',
            payloadJson: '{"id":"credit-1"}',
            updatedAt: DateTime.utc(2026, 8, 8),
          ),
        );
    await database
        .into(database.localCreditInstallments)
        .insert(
          LocalCreditInstallmentsCompanion.insert(
            id: 'installment-1',
            creditAccountId: 'credit-1',
            householdId: 'household-1',
            payloadJson: '{"id":"installment-1"}',
            dueDate: DateTime.utc(2026, 9, 10),
            status: 'SCHEDULED',
            updatedAt: DateTime.utc(2026, 8, 8),
          ),
        );

    final service = BackupService(database);
    final backup = await service.createBackup({'transactions': <Object>[]});
    await database.delete(database.pendingMutations).go();
    await database.delete(database.cachedSyncChanges).go();
    await database.delete(database.syncCursors).go();
    await database.delete(database.localCreditAccounts).go();
    await database.delete(database.localCreditInstallments).go();

    await service.restoreLocalBackup(backup);
    await service.restoreLocalBackup(backup);

    expect(
      await database.select(database.pendingMutations).get(),
      hasLength(1),
    );
    expect(
      await database.select(database.cachedSyncChanges).get(),
      hasLength(1),
    );
    expect(await database.select(database.syncCursors).get(), hasLength(1));
    expect(
      await database.select(database.localCreditAccounts).get(),
      hasLength(1),
    );
    expect(
      await database.select(database.localCreditInstallments).get(),
      hasLength(1),
    );
  });

  test('CSV excludes private descriptions by default', () {
    final csv = BackupService(database).transactionsCsv({
      'transactions': [
        {
          'aggregate': {
            'transaction_date': '2026-08-06',
            'kind': 'EXPENSE',
            'scope': 'PRIVATE',
            'description': 'rahasia',
          },
          'entries': [
            {'amount': '50000'},
          ],
        },
      ],
    });

    expect(csv, isNot(contains('rahasia')));
    expect(csv, contains('50000'));
  });
}
