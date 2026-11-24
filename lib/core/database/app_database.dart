import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class LocalWallets extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get householdId => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get walletType => text()();
  Int64Column get balanceMinor =>
      int64().withDefault(const CustomExpression<BigInt>('0'))();
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get serverVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PendingMutations extends Table {
  TextColumn get clientReferenceId => text()();
  TextColumn get operation => text()();
  TextColumn get aggregateId => text().nullable()();
  TextColumn get payloadJson => text()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('PENDING_SYNC'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {clientReferenceId};
}

class CachedSyncChanges extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get householdId => text()();
  TextColumn get operation => text()();
  Int64Column get serverSequence => int64()();
  BoolColumn get tombstone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get changedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entityType, entityId};
}

class SyncCursors extends Table {
  TextColumn get householdId => text()();
  Int64Column get cursor =>
      int64().withDefault(const CustomExpression<BigInt>('0'))();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {householdId};
}

class SyncEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get eventType => text()();
  TextColumn get operation => text().nullable()();
  TextColumn get errorCode => text().nullable()();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();
}

class LocalCreditAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get householdId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get serverVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalCreditBills extends Table {
  TextColumn get id => text()();
  TextColumn get creditAccountId => text()();
  TextColumn get householdId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text()();
  IntColumn get serverVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalCreditNotifications extends Table {
  TextColumn get eventKey => text()();
  TextColumn get creditAccountId => text().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {eventKey};
}

class LocalCreditInstallments extends Table {
  TextColumn get id => text()();
  TextColumn get creditAccountId => text()();
  TextColumn get householdId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get status => text()();
  IntColumn get serverVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    LocalWallets,
    PendingMutations,
    CachedSyncChanges,
    SyncCursors,
    SyncEvents,
    LocalCreditAccounts,
    LocalCreditBills,
    LocalCreditNotifications,
    LocalCreditInstallments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'bekara'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(cachedSyncChanges);
        await migrator.createTable(syncCursors);
        await migrator.createTable(syncEvents);
      }
      if (from < 3) {
        await migrator.createTable(localCreditAccounts);
        await migrator.createTable(localCreditBills);
        await migrator.createTable(localCreditNotifications);
        await migrator.createTable(localCreditInstallments);
      }
    },
  );
}
