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

@DriftDatabase(tables: [LocalWallets, PendingMutations])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'bekara'));

  @override
  int get schemaVersion => 1;
}
