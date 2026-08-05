// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalWalletsTable extends LocalWallets
    with TableInfo<$LocalWalletsTable, LocalWallet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalWalletsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _walletTypeMeta = const VerificationMeta(
    'walletType',
  );
  @override
  late final GeneratedColumn<String> walletType = GeneratedColumn<String>(
    'wallet_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceMinorMeta = const VerificationMeta(
    'balanceMinor',
  );
  @override
  late final GeneratedColumn<BigInt> balanceMinor = GeneratedColumn<BigInt>(
    'balance_minor',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression<BigInt>('0'),
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    householdId,
    name,
    walletType,
    balanceMinor,
    isShared,
    active,
    serverVersion,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_wallets';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalWallet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('wallet_type')) {
      context.handle(
        _walletTypeMeta,
        walletType.isAcceptableOrUnknown(data['wallet_type']!, _walletTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_walletTypeMeta);
    }
    if (data.containsKey('balance_minor')) {
      context.handle(
        _balanceMinorMeta,
        balanceMinor.isAcceptableOrUnknown(
          data['balance_minor']!,
          _balanceMinorMeta,
        ),
      );
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalWallet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalWallet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      walletType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wallet_type'],
      )!,
      balanceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}balance_minor'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalWalletsTable createAlias(String alias) {
    return $LocalWalletsTable(attachedDatabase, alias);
  }
}

class LocalWallet extends DataClass implements Insertable<LocalWallet> {
  final String id;
  final String ownerId;
  final String householdId;
  final String name;
  final String walletType;
  final BigInt balanceMinor;
  final bool isShared;
  final bool active;
  final int serverVersion;
  final DateTime updatedAt;
  const LocalWallet({
    required this.id,
    required this.ownerId,
    required this.householdId,
    required this.name,
    required this.walletType,
    required this.balanceMinor,
    required this.isShared,
    required this.active,
    required this.serverVersion,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['household_id'] = Variable<String>(householdId);
    map['name'] = Variable<String>(name);
    map['wallet_type'] = Variable<String>(walletType);
    map['balance_minor'] = Variable<BigInt>(balanceMinor);
    map['is_shared'] = Variable<bool>(isShared);
    map['active'] = Variable<bool>(active);
    map['server_version'] = Variable<int>(serverVersion);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalWalletsCompanion toCompanion(bool nullToAbsent) {
    return LocalWalletsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      householdId: Value(householdId),
      name: Value(name),
      walletType: Value(walletType),
      balanceMinor: Value(balanceMinor),
      isShared: Value(isShared),
      active: Value(active),
      serverVersion: Value(serverVersion),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalWallet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalWallet(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      householdId: serializer.fromJson<String>(json['householdId']),
      name: serializer.fromJson<String>(json['name']),
      walletType: serializer.fromJson<String>(json['walletType']),
      balanceMinor: serializer.fromJson<BigInt>(json['balanceMinor']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      active: serializer.fromJson<bool>(json['active']),
      serverVersion: serializer.fromJson<int>(json['serverVersion']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'householdId': serializer.toJson<String>(householdId),
      'name': serializer.toJson<String>(name),
      'walletType': serializer.toJson<String>(walletType),
      'balanceMinor': serializer.toJson<BigInt>(balanceMinor),
      'isShared': serializer.toJson<bool>(isShared),
      'active': serializer.toJson<bool>(active),
      'serverVersion': serializer.toJson<int>(serverVersion),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalWallet copyWith({
    String? id,
    String? ownerId,
    String? householdId,
    String? name,
    String? walletType,
    BigInt? balanceMinor,
    bool? isShared,
    bool? active,
    int? serverVersion,
    DateTime? updatedAt,
  }) => LocalWallet(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    householdId: householdId ?? this.householdId,
    name: name ?? this.name,
    walletType: walletType ?? this.walletType,
    balanceMinor: balanceMinor ?? this.balanceMinor,
    isShared: isShared ?? this.isShared,
    active: active ?? this.active,
    serverVersion: serverVersion ?? this.serverVersion,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalWallet copyWithCompanion(LocalWalletsCompanion data) {
    return LocalWallet(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      name: data.name.present ? data.name.value : this.name,
      walletType: data.walletType.present
          ? data.walletType.value
          : this.walletType,
      balanceMinor: data.balanceMinor.present
          ? data.balanceMinor.value
          : this.balanceMinor,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      active: data.active.present ? data.active.value : this.active,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalWallet(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('householdId: $householdId, ')
          ..write('name: $name, ')
          ..write('walletType: $walletType, ')
          ..write('balanceMinor: $balanceMinor, ')
          ..write('isShared: $isShared, ')
          ..write('active: $active, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    householdId,
    name,
    walletType,
    balanceMinor,
    isShared,
    active,
    serverVersion,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalWallet &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.householdId == this.householdId &&
          other.name == this.name &&
          other.walletType == this.walletType &&
          other.balanceMinor == this.balanceMinor &&
          other.isShared == this.isShared &&
          other.active == this.active &&
          other.serverVersion == this.serverVersion &&
          other.updatedAt == this.updatedAt);
}

class LocalWalletsCompanion extends UpdateCompanion<LocalWallet> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> householdId;
  final Value<String> name;
  final Value<String> walletType;
  final Value<BigInt> balanceMinor;
  final Value<bool> isShared;
  final Value<bool> active;
  final Value<int> serverVersion;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalWalletsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.householdId = const Value.absent(),
    this.name = const Value.absent(),
    this.walletType = const Value.absent(),
    this.balanceMinor = const Value.absent(),
    this.isShared = const Value.absent(),
    this.active = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalWalletsCompanion.insert({
    required String id,
    required String ownerId,
    required String householdId,
    required String name,
    required String walletType,
    this.balanceMinor = const Value.absent(),
    this.isShared = const Value.absent(),
    this.active = const Value.absent(),
    this.serverVersion = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       householdId = Value(householdId),
       name = Value(name),
       walletType = Value(walletType),
       updatedAt = Value(updatedAt);
  static Insertable<LocalWallet> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? householdId,
    Expression<String>? name,
    Expression<String>? walletType,
    Expression<BigInt>? balanceMinor,
    Expression<bool>? isShared,
    Expression<bool>? active,
    Expression<int>? serverVersion,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (householdId != null) 'household_id': householdId,
      if (name != null) 'name': name,
      if (walletType != null) 'wallet_type': walletType,
      if (balanceMinor != null) 'balance_minor': balanceMinor,
      if (isShared != null) 'is_shared': isShared,
      if (active != null) 'active': active,
      if (serverVersion != null) 'server_version': serverVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalWalletsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? householdId,
    Value<String>? name,
    Value<String>? walletType,
    Value<BigInt>? balanceMinor,
    Value<bool>? isShared,
    Value<bool>? active,
    Value<int>? serverVersion,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalWalletsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      walletType: walletType ?? this.walletType,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      isShared: isShared ?? this.isShared,
      active: active ?? this.active,
      serverVersion: serverVersion ?? this.serverVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (walletType.present) {
      map['wallet_type'] = Variable<String>(walletType.value);
    }
    if (balanceMinor.present) {
      map['balance_minor'] = Variable<BigInt>(balanceMinor.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalWalletsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('householdId: $householdId, ')
          ..write('name: $name, ')
          ..write('walletType: $walletType, ')
          ..write('balanceMinor: $balanceMinor, ')
          ..write('isShared: $isShared, ')
          ..write('active: $active, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingMutationsTable extends PendingMutations
    with TableInfo<$PendingMutationsTable, PendingMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientReferenceIdMeta = const VerificationMeta(
    'clientReferenceId',
  );
  @override
  late final GeneratedColumn<String> clientReferenceId =
      GeneratedColumn<String>(
        'client_reference_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aggregateIdMeta = const VerificationMeta(
    'aggregateId',
  );
  @override
  late final GeneratedColumn<String> aggregateId = GeneratedColumn<String>(
    'aggregate_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING_SYNC'),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientReferenceId,
    operation,
    aggregateId,
    payloadJson,
    syncStatus,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingMutation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_reference_id')) {
      context.handle(
        _clientReferenceIdMeta,
        clientReferenceId.isAcceptableOrUnknown(
          data['client_reference_id']!,
          _clientReferenceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientReferenceIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('aggregate_id')) {
      context.handle(
        _aggregateIdMeta,
        aggregateId.isAcceptableOrUnknown(
          data['aggregate_id']!,
          _aggregateIdMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientReferenceId};
  @override
  PendingMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMutation(
      clientReferenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_reference_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      aggregateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_id'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingMutationsTable createAlias(String alias) {
    return $PendingMutationsTable(attachedDatabase, alias);
  }
}

class PendingMutation extends DataClass implements Insertable<PendingMutation> {
  final String clientReferenceId;
  final String operation;
  final String? aggregateId;
  final String payloadJson;
  final String syncStatus;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PendingMutation({
    required this.clientReferenceId,
    required this.operation,
    this.aggregateId,
    required this.payloadJson,
    required this.syncStatus,
    required this.attemptCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_reference_id'] = Variable<String>(clientReferenceId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || aggregateId != null) {
      map['aggregate_id'] = Variable<String>(aggregateId);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['sync_status'] = Variable<String>(syncStatus);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PendingMutationsCompanion toCompanion(bool nullToAbsent) {
    return PendingMutationsCompanion(
      clientReferenceId: Value(clientReferenceId),
      operation: Value(operation),
      aggregateId: aggregateId == null && nullToAbsent
          ? const Value.absent()
          : Value(aggregateId),
      payloadJson: Value(payloadJson),
      syncStatus: Value(syncStatus),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingMutation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMutation(
      clientReferenceId: serializer.fromJson<String>(json['clientReferenceId']),
      operation: serializer.fromJson<String>(json['operation']),
      aggregateId: serializer.fromJson<String?>(json['aggregateId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientReferenceId': serializer.toJson<String>(clientReferenceId),
      'operation': serializer.toJson<String>(operation),
      'aggregateId': serializer.toJson<String?>(aggregateId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PendingMutation copyWith({
    String? clientReferenceId,
    String? operation,
    Value<String?> aggregateId = const Value.absent(),
    String? payloadJson,
    String? syncStatus,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PendingMutation(
    clientReferenceId: clientReferenceId ?? this.clientReferenceId,
    operation: operation ?? this.operation,
    aggregateId: aggregateId.present ? aggregateId.value : this.aggregateId,
    payloadJson: payloadJson ?? this.payloadJson,
    syncStatus: syncStatus ?? this.syncStatus,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingMutation copyWithCompanion(PendingMutationsCompanion data) {
    return PendingMutation(
      clientReferenceId: data.clientReferenceId.present
          ? data.clientReferenceId.value
          : this.clientReferenceId,
      operation: data.operation.present ? data.operation.value : this.operation,
      aggregateId: data.aggregateId.present
          ? data.aggregateId.value
          : this.aggregateId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutation(')
          ..write('clientReferenceId: $clientReferenceId, ')
          ..write('operation: $operation, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    clientReferenceId,
    operation,
    aggregateId,
    payloadJson,
    syncStatus,
    attemptCount,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMutation &&
          other.clientReferenceId == this.clientReferenceId &&
          other.operation == this.operation &&
          other.aggregateId == this.aggregateId &&
          other.payloadJson == this.payloadJson &&
          other.syncStatus == this.syncStatus &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PendingMutationsCompanion extends UpdateCompanion<PendingMutation> {
  final Value<String> clientReferenceId;
  final Value<String> operation;
  final Value<String?> aggregateId;
  final Value<String> payloadJson;
  final Value<String> syncStatus;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PendingMutationsCompanion({
    this.clientReferenceId = const Value.absent(),
    this.operation = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingMutationsCompanion.insert({
    required String clientReferenceId,
    required String operation,
    this.aggregateId = const Value.absent(),
    required String payloadJson,
    this.syncStatus = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientReferenceId = Value(clientReferenceId),
       operation = Value(operation),
       payloadJson = Value(payloadJson);
  static Insertable<PendingMutation> custom({
    Expression<String>? clientReferenceId,
    Expression<String>? operation,
    Expression<String>? aggregateId,
    Expression<String>? payloadJson,
    Expression<String>? syncStatus,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientReferenceId != null) 'client_reference_id': clientReferenceId,
      if (operation != null) 'operation': operation,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingMutationsCompanion copyWith({
    Value<String>? clientReferenceId,
    Value<String>? operation,
    Value<String?>? aggregateId,
    Value<String>? payloadJson,
    Value<String>? syncStatus,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingMutationsCompanion(
      clientReferenceId: clientReferenceId ?? this.clientReferenceId,
      operation: operation ?? this.operation,
      aggregateId: aggregateId ?? this.aggregateId,
      payloadJson: payloadJson ?? this.payloadJson,
      syncStatus: syncStatus ?? this.syncStatus,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientReferenceId.present) {
      map['client_reference_id'] = Variable<String>(clientReferenceId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsCompanion(')
          ..write('clientReferenceId: $clientReferenceId, ')
          ..write('operation: $operation, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedSyncChangesTable extends CachedSyncChanges
    with TableInfo<$CachedSyncChangesTable, CachedSyncChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSyncChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSequenceMeta = const VerificationMeta(
    'serverSequence',
  );
  @override
  late final GeneratedColumn<BigInt> serverSequence = GeneratedColumn<BigInt>(
    'server_sequence',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tombstoneMeta = const VerificationMeta(
    'tombstone',
  );
  @override
  late final GeneratedColumn<bool> tombstone = GeneratedColumn<bool>(
    'tombstone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tombstone" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entityType,
    entityId,
    householdId,
    operation,
    serverSequence,
    tombstone,
    changedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_sync_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSyncChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('server_sequence')) {
      context.handle(
        _serverSequenceMeta,
        serverSequence.isAcceptableOrUnknown(
          data['server_sequence']!,
          _serverSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverSequenceMeta);
    }
    if (data.containsKey('tombstone')) {
      context.handle(
        _tombstoneMeta,
        tombstone.isAcceptableOrUnknown(data['tombstone']!, _tombstoneMeta),
      );
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityType, entityId};
  @override
  CachedSyncChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSyncChange(
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      serverSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}server_sequence'],
      )!,
      tombstone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tombstone'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  $CachedSyncChangesTable createAlias(String alias) {
    return $CachedSyncChangesTable(attachedDatabase, alias);
  }
}

class CachedSyncChange extends DataClass
    implements Insertable<CachedSyncChange> {
  final String entityType;
  final String entityId;
  final String householdId;
  final String operation;
  final BigInt serverSequence;
  final bool tombstone;
  final DateTime changedAt;
  const CachedSyncChange({
    required this.entityType,
    required this.entityId,
    required this.householdId,
    required this.operation,
    required this.serverSequence,
    required this.tombstone,
    required this.changedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['household_id'] = Variable<String>(householdId);
    map['operation'] = Variable<String>(operation);
    map['server_sequence'] = Variable<BigInt>(serverSequence);
    map['tombstone'] = Variable<bool>(tombstone);
    map['changed_at'] = Variable<DateTime>(changedAt);
    return map;
  }

  CachedSyncChangesCompanion toCompanion(bool nullToAbsent) {
    return CachedSyncChangesCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      householdId: Value(householdId),
      operation: Value(operation),
      serverSequence: Value(serverSequence),
      tombstone: Value(tombstone),
      changedAt: Value(changedAt),
    );
  }

  factory CachedSyncChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSyncChange(
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      householdId: serializer.fromJson<String>(json['householdId']),
      operation: serializer.fromJson<String>(json['operation']),
      serverSequence: serializer.fromJson<BigInt>(json['serverSequence']),
      tombstone: serializer.fromJson<bool>(json['tombstone']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'householdId': serializer.toJson<String>(householdId),
      'operation': serializer.toJson<String>(operation),
      'serverSequence': serializer.toJson<BigInt>(serverSequence),
      'tombstone': serializer.toJson<bool>(tombstone),
      'changedAt': serializer.toJson<DateTime>(changedAt),
    };
  }

  CachedSyncChange copyWith({
    String? entityType,
    String? entityId,
    String? householdId,
    String? operation,
    BigInt? serverSequence,
    bool? tombstone,
    DateTime? changedAt,
  }) => CachedSyncChange(
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    householdId: householdId ?? this.householdId,
    operation: operation ?? this.operation,
    serverSequence: serverSequence ?? this.serverSequence,
    tombstone: tombstone ?? this.tombstone,
    changedAt: changedAt ?? this.changedAt,
  );
  CachedSyncChange copyWithCompanion(CachedSyncChangesCompanion data) {
    return CachedSyncChange(
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      operation: data.operation.present ? data.operation.value : this.operation,
      serverSequence: data.serverSequence.present
          ? data.serverSequence.value
          : this.serverSequence,
      tombstone: data.tombstone.present ? data.tombstone.value : this.tombstone,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSyncChange(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('householdId: $householdId, ')
          ..write('operation: $operation, ')
          ..write('serverSequence: $serverSequence, ')
          ..write('tombstone: $tombstone, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entityType,
    entityId,
    householdId,
    operation,
    serverSequence,
    tombstone,
    changedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSyncChange &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.householdId == this.householdId &&
          other.operation == this.operation &&
          other.serverSequence == this.serverSequence &&
          other.tombstone == this.tombstone &&
          other.changedAt == this.changedAt);
}

class CachedSyncChangesCompanion extends UpdateCompanion<CachedSyncChange> {
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> householdId;
  final Value<String> operation;
  final Value<BigInt> serverSequence;
  final Value<bool> tombstone;
  final Value<DateTime> changedAt;
  final Value<int> rowid;
  const CachedSyncChangesCompanion({
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.householdId = const Value.absent(),
    this.operation = const Value.absent(),
    this.serverSequence = const Value.absent(),
    this.tombstone = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSyncChangesCompanion.insert({
    required String entityType,
    required String entityId,
    required String householdId,
    required String operation,
    required BigInt serverSequence,
    this.tombstone = const Value.absent(),
    required DateTime changedAt,
    this.rowid = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       householdId = Value(householdId),
       operation = Value(operation),
       serverSequence = Value(serverSequence),
       changedAt = Value(changedAt);
  static Insertable<CachedSyncChange> custom({
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? householdId,
    Expression<String>? operation,
    Expression<BigInt>? serverSequence,
    Expression<bool>? tombstone,
    Expression<DateTime>? changedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (householdId != null) 'household_id': householdId,
      if (operation != null) 'operation': operation,
      if (serverSequence != null) 'server_sequence': serverSequence,
      if (tombstone != null) 'tombstone': tombstone,
      if (changedAt != null) 'changed_at': changedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSyncChangesCompanion copyWith({
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? householdId,
    Value<String>? operation,
    Value<BigInt>? serverSequence,
    Value<bool>? tombstone,
    Value<DateTime>? changedAt,
    Value<int>? rowid,
  }) {
    return CachedSyncChangesCompanion(
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      householdId: householdId ?? this.householdId,
      operation: operation ?? this.operation,
      serverSequence: serverSequence ?? this.serverSequence,
      tombstone: tombstone ?? this.tombstone,
      changedAt: changedAt ?? this.changedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (serverSequence.present) {
      map['server_sequence'] = Variable<BigInt>(serverSequence.value);
    }
    if (tombstone.present) {
      map['tombstone'] = Variable<bool>(tombstone.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSyncChangesCompanion(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('householdId: $householdId, ')
          ..write('operation: $operation, ')
          ..write('serverSequence: $serverSequence, ')
          ..write('tombstone: $tombstone, ')
          ..write('changedAt: $changedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _householdIdMeta = const VerificationMeta(
    'householdId',
  );
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
    'household_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<BigInt> cursor = GeneratedColumn<BigInt>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: false,
    defaultValue: const CustomExpression<BigInt>('0'),
  );
  static const VerificationMeta _lastSuccessAtMeta = const VerificationMeta(
    'lastSuccessAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSuccessAt =
      GeneratedColumn<DateTime>(
        'last_success_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [householdId, cursor, lastSuccessAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('household_id')) {
      context.handle(
        _householdIdMeta,
        householdId.isAcceptableOrUnknown(
          data['household_id']!,
          _householdIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('last_success_at')) {
      context.handle(
        _lastSuccessAtMeta,
        lastSuccessAt.isAcceptableOrUnknown(
          data['last_success_at']!,
          _lastSuccessAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {householdId};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      householdId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}household_id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}cursor'],
      )!,
      lastSuccessAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_success_at'],
      ),
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String householdId;
  final BigInt cursor;
  final DateTime? lastSuccessAt;
  const SyncCursor({
    required this.householdId,
    required this.cursor,
    this.lastSuccessAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['household_id'] = Variable<String>(householdId);
    map['cursor'] = Variable<BigInt>(cursor);
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<DateTime>(lastSuccessAt);
    }
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      householdId: Value(householdId),
      cursor: Value(cursor),
      lastSuccessAt: lastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessAt),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      householdId: serializer.fromJson<String>(json['householdId']),
      cursor: serializer.fromJson<BigInt>(json['cursor']),
      lastSuccessAt: serializer.fromJson<DateTime?>(json['lastSuccessAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'householdId': serializer.toJson<String>(householdId),
      'cursor': serializer.toJson<BigInt>(cursor),
      'lastSuccessAt': serializer.toJson<DateTime?>(lastSuccessAt),
    };
  }

  SyncCursor copyWith({
    String? householdId,
    BigInt? cursor,
    Value<DateTime?> lastSuccessAt = const Value.absent(),
  }) => SyncCursor(
    householdId: householdId ?? this.householdId,
    cursor: cursor ?? this.cursor,
    lastSuccessAt: lastSuccessAt.present
        ? lastSuccessAt.value
        : this.lastSuccessAt,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      householdId: data.householdId.present
          ? data.householdId.value
          : this.householdId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('householdId: $householdId, ')
          ..write('cursor: $cursor, ')
          ..write('lastSuccessAt: $lastSuccessAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(householdId, cursor, lastSuccessAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.householdId == this.householdId &&
          other.cursor == this.cursor &&
          other.lastSuccessAt == this.lastSuccessAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> householdId;
  final Value<BigInt> cursor;
  final Value<DateTime?> lastSuccessAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.householdId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String householdId,
    this.cursor = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : householdId = Value(householdId);
  static Insertable<SyncCursor> custom({
    Expression<String>? householdId,
    Expression<BigInt>? cursor,
    Expression<DateTime>? lastSuccessAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (householdId != null) 'household_id': householdId,
      if (cursor != null) 'cursor': cursor,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? householdId,
    Value<BigInt>? cursor,
    Value<DateTime?>? lastSuccessAt,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      householdId: householdId ?? this.householdId,
      cursor: cursor ?? this.cursor,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<BigInt>(cursor.value);
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<DateTime>(lastSuccessAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('householdId: $householdId, ')
          ..write('cursor: $cursor, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncEventsTable extends SyncEvents
    with TableInfo<$SyncEventsTable, SyncEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventType,
    operation,
    errorCode,
    occurredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $SyncEventsTable createAlias(String alias) {
    return $SyncEventsTable(attachedDatabase, alias);
  }
}

class SyncEvent extends DataClass implements Insertable<SyncEvent> {
  final int id;
  final String eventType;
  final String? operation;
  final String? errorCode;
  final DateTime occurredAt;
  const SyncEvent({
    required this.id,
    required this.eventType,
    this.operation,
    this.errorCode,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || operation != null) {
      map['operation'] = Variable<String>(operation);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  SyncEventsCompanion toCompanion(bool nullToAbsent) {
    return SyncEventsCompanion(
      id: Value(id),
      eventType: Value(eventType),
      operation: operation == null && nullToAbsent
          ? const Value.absent()
          : Value(operation),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      occurredAt: Value(occurredAt),
    );
  }

  factory SyncEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncEvent(
      id: serializer.fromJson<int>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      operation: serializer.fromJson<String?>(json['operation']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventType': serializer.toJson<String>(eventType),
      'operation': serializer.toJson<String?>(operation),
      'errorCode': serializer.toJson<String?>(errorCode),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  SyncEvent copyWith({
    int? id,
    String? eventType,
    Value<String?> operation = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    DateTime? occurredAt,
  }) => SyncEvent(
    id: id ?? this.id,
    eventType: eventType ?? this.eventType,
    operation: operation.present ? operation.value : this.operation,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  SyncEvent copyWithCompanion(SyncEventsCompanion data) {
    return SyncEvent(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      operation: data.operation.present ? data.operation.value : this.operation,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncEvent(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('operation: $operation, ')
          ..write('errorCode: $errorCode, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, eventType, operation, errorCode, occurredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEvent &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.operation == this.operation &&
          other.errorCode == this.errorCode &&
          other.occurredAt == this.occurredAt);
}

class SyncEventsCompanion extends UpdateCompanion<SyncEvent> {
  final Value<int> id;
  final Value<String> eventType;
  final Value<String?> operation;
  final Value<String?> errorCode;
  final Value<DateTime> occurredAt;
  const SyncEventsCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.operation = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.occurredAt = const Value.absent(),
  });
  SyncEventsCompanion.insert({
    this.id = const Value.absent(),
    required String eventType,
    this.operation = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.occurredAt = const Value.absent(),
  }) : eventType = Value(eventType);
  static Insertable<SyncEvent> custom({
    Expression<int>? id,
    Expression<String>? eventType,
    Expression<String>? operation,
    Expression<String>? errorCode,
    Expression<DateTime>? occurredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (operation != null) 'operation': operation,
      if (errorCode != null) 'error_code': errorCode,
      if (occurredAt != null) 'occurred_at': occurredAt,
    });
  }

  SyncEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? eventType,
    Value<String?>? operation,
    Value<String?>? errorCode,
    Value<DateTime>? occurredAt,
  }) {
    return SyncEventsCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      operation: operation ?? this.operation,
      errorCode: errorCode ?? this.errorCode,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('operation: $operation, ')
          ..write('errorCode: $errorCode, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalWalletsTable localWallets = $LocalWalletsTable(this);
  late final $PendingMutationsTable pendingMutations = $PendingMutationsTable(
    this,
  );
  late final $CachedSyncChangesTable cachedSyncChanges =
      $CachedSyncChangesTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $SyncEventsTable syncEvents = $SyncEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localWallets,
    pendingMutations,
    cachedSyncChanges,
    syncCursors,
    syncEvents,
  ];
}

typedef $$LocalWalletsTableCreateCompanionBuilder =
    LocalWalletsCompanion Function({
      required String id,
      required String ownerId,
      required String householdId,
      required String name,
      required String walletType,
      Value<BigInt> balanceMinor,
      Value<bool> isShared,
      Value<bool> active,
      Value<int> serverVersion,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalWalletsTableUpdateCompanionBuilder =
    LocalWalletsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> householdId,
      Value<String> name,
      Value<String> walletType,
      Value<BigInt> balanceMinor,
      Value<bool> isShared,
      Value<bool> active,
      Value<int> serverVersion,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalWalletsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalWalletsTable> {
  $$LocalWalletsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get walletType => $composableBuilder(
    column: $table.walletType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalWalletsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalWalletsTable> {
  $$LocalWalletsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get walletType => $composableBuilder(
    column: $table.walletType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalWalletsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalWalletsTable> {
  $$LocalWalletsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get walletType => $composableBuilder(
    column: $table.walletType,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get balanceMinor => $composableBuilder(
    column: $table.balanceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalWalletsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalWalletsTable,
          LocalWallet,
          $$LocalWalletsTableFilterComposer,
          $$LocalWalletsTableOrderingComposer,
          $$LocalWalletsTableAnnotationComposer,
          $$LocalWalletsTableCreateCompanionBuilder,
          $$LocalWalletsTableUpdateCompanionBuilder,
          (
            LocalWallet,
            BaseReferences<_$AppDatabase, $LocalWalletsTable, LocalWallet>,
          ),
          LocalWallet,
          PrefetchHooks Function()
        > {
  $$LocalWalletsTableTableManager(_$AppDatabase db, $LocalWalletsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalWalletsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalWalletsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalWalletsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> walletType = const Value.absent(),
                Value<BigInt> balanceMinor = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalWalletsCompanion(
                id: id,
                ownerId: ownerId,
                householdId: householdId,
                name: name,
                walletType: walletType,
                balanceMinor: balanceMinor,
                isShared: isShared,
                active: active,
                serverVersion: serverVersion,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String householdId,
                required String name,
                required String walletType,
                Value<BigInt> balanceMinor = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> serverVersion = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalWalletsCompanion.insert(
                id: id,
                ownerId: ownerId,
                householdId: householdId,
                name: name,
                walletType: walletType,
                balanceMinor: balanceMinor,
                isShared: isShared,
                active: active,
                serverVersion: serverVersion,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalWalletsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalWalletsTable,
      LocalWallet,
      $$LocalWalletsTableFilterComposer,
      $$LocalWalletsTableOrderingComposer,
      $$LocalWalletsTableAnnotationComposer,
      $$LocalWalletsTableCreateCompanionBuilder,
      $$LocalWalletsTableUpdateCompanionBuilder,
      (
        LocalWallet,
        BaseReferences<_$AppDatabase, $LocalWalletsTable, LocalWallet>,
      ),
      LocalWallet,
      PrefetchHooks Function()
    >;
typedef $$PendingMutationsTableCreateCompanionBuilder =
    PendingMutationsCompanion Function({
      required String clientReferenceId,
      required String operation,
      Value<String?> aggregateId,
      required String payloadJson,
      Value<String> syncStatus,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PendingMutationsTableUpdateCompanionBuilder =
    PendingMutationsCompanion Function({
      Value<String> clientReferenceId,
      Value<String> operation,
      Value<String?> aggregateId,
      Value<String> payloadJson,
      Value<String> syncStatus,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PendingMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientReferenceId => $composableBuilder(
    column: $table.clientReferenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientReferenceId => $composableBuilder(
    column: $table.clientReferenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientReferenceId => $composableBuilder(
    column: $table.clientReferenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingMutationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingMutationsTable,
          PendingMutation,
          $$PendingMutationsTableFilterComposer,
          $$PendingMutationsTableOrderingComposer,
          $$PendingMutationsTableAnnotationComposer,
          $$PendingMutationsTableCreateCompanionBuilder,
          $$PendingMutationsTableUpdateCompanionBuilder,
          (
            PendingMutation,
            BaseReferences<
              _$AppDatabase,
              $PendingMutationsTable,
              PendingMutation
            >,
          ),
          PendingMutation,
          PrefetchHooks Function()
        > {
  $$PendingMutationsTableTableManager(
    _$AppDatabase db,
    $PendingMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clientReferenceId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String?> aggregateId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion(
                clientReferenceId: clientReferenceId,
                operation: operation,
                aggregateId: aggregateId,
                payloadJson: payloadJson,
                syncStatus: syncStatus,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientReferenceId,
                required String operation,
                Value<String?> aggregateId = const Value.absent(),
                required String payloadJson,
                Value<String> syncStatus = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingMutationsCompanion.insert(
                clientReferenceId: clientReferenceId,
                operation: operation,
                aggregateId: aggregateId,
                payloadJson: payloadJson,
                syncStatus: syncStatus,
                attemptCount: attemptCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingMutationsTable,
      PendingMutation,
      $$PendingMutationsTableFilterComposer,
      $$PendingMutationsTableOrderingComposer,
      $$PendingMutationsTableAnnotationComposer,
      $$PendingMutationsTableCreateCompanionBuilder,
      $$PendingMutationsTableUpdateCompanionBuilder,
      (
        PendingMutation,
        BaseReferences<_$AppDatabase, $PendingMutationsTable, PendingMutation>,
      ),
      PendingMutation,
      PrefetchHooks Function()
    >;
typedef $$CachedSyncChangesTableCreateCompanionBuilder =
    CachedSyncChangesCompanion Function({
      required String entityType,
      required String entityId,
      required String householdId,
      required String operation,
      required BigInt serverSequence,
      Value<bool> tombstone,
      required DateTime changedAt,
      Value<int> rowid,
    });
typedef $$CachedSyncChangesTableUpdateCompanionBuilder =
    CachedSyncChangesCompanion Function({
      Value<String> entityType,
      Value<String> entityId,
      Value<String> householdId,
      Value<String> operation,
      Value<BigInt> serverSequence,
      Value<bool> tombstone,
      Value<DateTime> changedAt,
      Value<int> rowid,
    });

class $$CachedSyncChangesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSyncChangesTable> {
  $$CachedSyncChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tombstone => $composableBuilder(
    column: $table.tombstone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedSyncChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSyncChangesTable> {
  $$CachedSyncChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tombstone => $composableBuilder(
    column: $table.tombstone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedSyncChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSyncChangesTable> {
  $$CachedSyncChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<BigInt> get serverSequence => $composableBuilder(
    column: $table.serverSequence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tombstone =>
      $composableBuilder(column: $table.tombstone, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);
}

class $$CachedSyncChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedSyncChangesTable,
          CachedSyncChange,
          $$CachedSyncChangesTableFilterComposer,
          $$CachedSyncChangesTableOrderingComposer,
          $$CachedSyncChangesTableAnnotationComposer,
          $$CachedSyncChangesTableCreateCompanionBuilder,
          $$CachedSyncChangesTableUpdateCompanionBuilder,
          (
            CachedSyncChange,
            BaseReferences<
              _$AppDatabase,
              $CachedSyncChangesTable,
              CachedSyncChange
            >,
          ),
          CachedSyncChange,
          PrefetchHooks Function()
        > {
  $$CachedSyncChangesTableTableManager(
    _$AppDatabase db,
    $CachedSyncChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSyncChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSyncChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSyncChangesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> householdId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<BigInt> serverSequence = const Value.absent(),
                Value<bool> tombstone = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSyncChangesCompanion(
                entityType: entityType,
                entityId: entityId,
                householdId: householdId,
                operation: operation,
                serverSequence: serverSequence,
                tombstone: tombstone,
                changedAt: changedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entityType,
                required String entityId,
                required String householdId,
                required String operation,
                required BigInt serverSequence,
                Value<bool> tombstone = const Value.absent(),
                required DateTime changedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedSyncChangesCompanion.insert(
                entityType: entityType,
                entityId: entityId,
                householdId: householdId,
                operation: operation,
                serverSequence: serverSequence,
                tombstone: tombstone,
                changedAt: changedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedSyncChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedSyncChangesTable,
      CachedSyncChange,
      $$CachedSyncChangesTableFilterComposer,
      $$CachedSyncChangesTableOrderingComposer,
      $$CachedSyncChangesTableAnnotationComposer,
      $$CachedSyncChangesTableCreateCompanionBuilder,
      $$CachedSyncChangesTableUpdateCompanionBuilder,
      (
        CachedSyncChange,
        BaseReferences<
          _$AppDatabase,
          $CachedSyncChangesTable,
          CachedSyncChange
        >,
      ),
      CachedSyncChange,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String householdId,
      Value<BigInt> cursor,
      Value<DateTime?> lastSuccessAt,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> householdId,
      Value<BigInt> cursor,
      Value<DateTime?> lastSuccessAt,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get householdId => $composableBuilder(
    column: $table.householdId,
    builder: (column) => column,
  );

  GeneratedColumn<BigInt> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => column,
  );
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> householdId = const Value.absent(),
                Value<BigInt> cursor = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                householdId: householdId,
                cursor: cursor,
                lastSuccessAt: lastSuccessAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String householdId,
                Value<BigInt> cursor = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                householdId: householdId,
                cursor: cursor,
                lastSuccessAt: lastSuccessAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$SyncEventsTableCreateCompanionBuilder =
    SyncEventsCompanion Function({
      Value<int> id,
      required String eventType,
      Value<String?> operation,
      Value<String?> errorCode,
      Value<DateTime> occurredAt,
    });
typedef $$SyncEventsTableUpdateCompanionBuilder =
    SyncEventsCompanion Function({
      Value<int> id,
      Value<String> eventType,
      Value<String?> operation,
      Value<String?> errorCode,
      Value<DateTime> occurredAt,
    });

class $$SyncEventsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncEventsTable> {
  $$SyncEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncEventsTable> {
  $$SyncEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncEventsTable> {
  $$SyncEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );
}

class $$SyncEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncEventsTable,
          SyncEvent,
          $$SyncEventsTableFilterComposer,
          $$SyncEventsTableOrderingComposer,
          $$SyncEventsTableAnnotationComposer,
          $$SyncEventsTableCreateCompanionBuilder,
          $$SyncEventsTableUpdateCompanionBuilder,
          (
            SyncEvent,
            BaseReferences<_$AppDatabase, $SyncEventsTable, SyncEvent>,
          ),
          SyncEvent,
          PrefetchHooks Function()
        > {
  $$SyncEventsTableTableManager(_$AppDatabase db, $SyncEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String?> operation = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => SyncEventsCompanion(
                id: id,
                eventType: eventType,
                operation: operation,
                errorCode: errorCode,
                occurredAt: occurredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String eventType,
                Value<String?> operation = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => SyncEventsCompanion.insert(
                id: id,
                eventType: eventType,
                operation: operation,
                errorCode: errorCode,
                occurredAt: occurredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncEventsTable,
      SyncEvent,
      $$SyncEventsTableFilterComposer,
      $$SyncEventsTableOrderingComposer,
      $$SyncEventsTableAnnotationComposer,
      $$SyncEventsTableCreateCompanionBuilder,
      $$SyncEventsTableUpdateCompanionBuilder,
      (SyncEvent, BaseReferences<_$AppDatabase, $SyncEventsTable, SyncEvent>),
      SyncEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalWalletsTableTableManager get localWallets =>
      $$LocalWalletsTableTableManager(_db, _db.localWallets);
  $$PendingMutationsTableTableManager get pendingMutations =>
      $$PendingMutationsTableTableManager(_db, _db.pendingMutations);
  $$CachedSyncChangesTableTableManager get cachedSyncChanges =>
      $$CachedSyncChangesTableTableManager(_db, _db.cachedSyncChanges);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$SyncEventsTableTableManager get syncEvents =>
      $$SyncEventsTableTableManager(_db, _db.syncEvents);
}
