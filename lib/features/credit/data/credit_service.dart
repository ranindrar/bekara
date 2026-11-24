import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../finance/data/finance_service.dart';
import '../../finance/domain/finance_validation.dart';

class CreditService {
  CreditService(this.client, this.database);

  final SupabaseClient client;
  final AppDatabase database;
  static const _uuid = Uuid();

  Future<Map<String, dynamic>> dashboard(String householdId) async {
    try {
      final value = Map<String, dynamic>.from(
        await client.rpc('credit_dashboard') as Map,
      );
      final accounts = _maps(value['accounts']);
      await database.transaction(() async {
        for (final account in accounts) {
          await database
              .into(database.localCreditAccounts)
              .insertOnConflictUpdate(
                LocalCreditAccountsCompanion.insert(
                  id: account['id'] as String,
                  householdId: householdId,
                  payloadJson: jsonEncode(account),
                  serverVersion: Value(account['version'] as int? ?? 1),
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
        }
      });
      return value;
    } catch (error) {
      if (!_looksOffline(error)) rethrow;
      final cached = await (database.select(
        database.localCreditAccounts,
      )..where((row) => row.householdId.equals(householdId))).get();
      if (cached.isEmpty) rethrow;
      return {
        'accounts': cached
            .map(
              (row) =>
                  Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
            )
            .toList(),
        'forecast': const {'personalDue': '0', 'householdReserve': '0'},
        'nearestDue': null,
        'offline': true,
      };
    }
  }

  Future<List<Map<String, dynamic>>> bills(
    String accountId,
    String householdId,
  ) async {
    try {
      final rows = await _list('list_credit_bills', {'account_id': accountId});
      for (final bill in rows) {
        await database
            .into(database.localCreditBills)
            .insertOnConflictUpdate(
              LocalCreditBillsCompanion.insert(
                id: bill['id'] as String,
                creditAccountId: accountId,
                householdId: householdId,
                payloadJson: jsonEncode(bill),
                dueDate: Value(DateTime.tryParse('${bill['dueDate']}')),
                status: '${bill['status']}',
                serverVersion: Value(bill['version'] as int? ?? 1),
                updatedAt: DateTime.now().toUtc(),
              ),
            );
      }
      return rows;
    } catch (error) {
      if (!_looksOffline(error)) rethrow;
      final cached =
          await (database.select(database.localCreditBills)
                ..where((row) => row.creditAccountId.equals(accountId))
                ..orderBy([(row) => OrderingTerm.desc(row.dueDate)]))
              .get();
      return cached
          .map(
            (row) =>
                Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> installments(
    String accountId,
    String householdId,
  ) async {
    try {
      final rows = await _list('list_credit_installments', {
        'account_id': accountId,
      });
      for (final item in rows) {
        await database
            .into(database.localCreditInstallments)
            .insertOnConflictUpdate(
              LocalCreditInstallmentsCompanion.insert(
                id: item['id'] as String,
                creditAccountId: accountId,
                householdId: householdId,
                payloadJson: jsonEncode(item),
                dueDate: DateTime.parse('${item['dueDate']}'),
                status: '${item['status']}',
                updatedAt: DateTime.now().toUtc(),
              ),
            );
      }
      return rows;
    } catch (error) {
      if (!_looksOffline(error)) rethrow;
      final cached =
          await (database.select(database.localCreditInstallments)
                ..where((row) => row.creditAccountId.equals(accountId))
                ..orderBy([(row) => OrderingTerm.asc(row.dueDate)]))
              .get();
      return cached
          .map(
            (row) =>
                Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
          )
          .toList();
    }
  }

  Future<List<Map<String, dynamic>>> payments(String accountId) =>
      _list('list_credit_payments', {'account_id': accountId});

  Future<List<Map<String, dynamic>>> notifications() async {
    try {
      final rows = await _list('list_credit_notifications');
      for (final item in rows) {
        await database
            .into(database.localCreditNotifications)
            .insertOnConflictUpdate(
              LocalCreditNotificationsCompanion.insert(
                eventKey: item['eventKey'] as String,
                creditAccountId: Value(item['accountId'] as String?),
                payloadJson: jsonEncode(item),
                dueDate: Value(DateTime.tryParse('${item['dueDate']}')),
                isRead: Value(item['read'] as bool? ?? false),
                dismissed: Value(item['dismissed'] as bool? ?? false),
                updatedAt: DateTime.now().toUtc(),
              ),
            );
      }
      return rows;
    } catch (error) {
      if (!_looksOffline(error)) rethrow;
      final cached =
          await (database.select(database.localCreditNotifications)
                ..where((row) => row.dismissed.equals(false))
                ..orderBy([(row) => OrderingTerm.asc(row.dueDate)]))
              .get();
      return cached
          .map(
            (row) =>
                Map<String, dynamic>.from(jsonDecode(row.payloadJson) as Map),
          )
          .toList();
    }
  }

  Future<void> markNotification(String eventKey, {bool dismiss = false}) async {
    await client.rpc(
      'mark_credit_notification',
      params: {'target_event_key': eventKey, 'target_dismissed': dismiss},
    );
  }

  Future<void> createAccount({
    required String accountType,
    required String scope,
    required String providerName,
    required String accountName,
    required String lastFour,
    required String creditLimit,
    required String openingLiability,
    required int statementDay,
    required int dueDay,
  }) async {
    await client.rpc(
      'create_credit_account',
      params: {
        'payload': {
          'clientReferenceId': _uuid.v4(),
          'accountType': accountType,
          'scope': accountType == 'PAYLATER' ? 'PRIVATE' : scope,
          'providerName': FinanceValidation.requiredText(
            providerName,
            'Penyedia',
            minLength: 2,
          ),
          'accountName': FinanceValidation.requiredText(
            accountName,
            'Nama akun',
            minLength: 2,
          ),
          'lastFour': lastFour.trim(),
          'creditLimit': FinanceValidation.normalizeAmount(creditLimit),
          'openingLiability': FinanceValidation.normalizeAmount(
            openingLiability,
            allowZero: true,
          ),
          'statementDay': statementDay,
          'dueDay': dueDay,
        },
      },
    );
  }

  Future<void> updateAccount({
    required String accountId,
    required int expectedVersion,
    required String providerName,
    required String accountName,
    required String lastFour,
    required String creditLimit,
    required int statementDay,
    required int dueDay,
  }) async {
    await client.rpc(
      'update_credit_account',
      params: {
        'account_id': accountId,
        'expected_version': expectedVersion,
        'patch': {
          'providerName': FinanceValidation.requiredText(
            providerName,
            'Penyedia',
            minLength: 2,
          ),
          'accountName': FinanceValidation.requiredText(
            accountName,
            'Nama akun',
            minLength: 2,
          ),
          'lastFour': lastFour.trim(),
          'creditLimit': FinanceValidation.normalizeAmount(creditLimit),
          'statementDay': statementDay,
          'dueDay': dueDay,
        },
      },
    );
  }

  Future<void> archiveAccount(String accountId, int expectedVersion) async {
    await client.rpc(
      'archive_credit_account',
      params: {'account_id': accountId, 'expected_version': expectedVersion},
    );
  }

  Future<FinancialMutationResult> postPurchase({
    required String accountId,
    required String categoryId,
    required String principal,
    required String financingCost,
    required int tenor,
    required String description,
    required String scope,
    required String privacyMode,
    required DateTime transactionDate,
  }) async {
    final reference = _uuid.v4();
    final params = {
      'payload': {
        'clientReferenceId': reference,
        'accountId': accountId,
        'categoryId': categoryId,
        'principal': FinanceValidation.normalizeAmount(principal),
        'financingCost': FinanceValidation.normalizeAmount(
          financingCost,
          allowZero: true,
        ),
        'tenor': tenor,
        'description': description.trim(),
        'scope': scope,
        'privacyMode': scope == 'HOUSEHOLD' ? 'HOUSEHOLD_VISIBLE' : privacyMode,
        'transactionDate': DateFormat('yyyy-MM-dd').format(transactionDate),
      },
    };
    try {
      await client.rpc('post_credit_purchase', params: params);
      return FinancialMutationResult.committed;
    } catch (error) {
      if (!_looksOffline(error)) rethrow;
      await database
          .into(database.pendingMutations)
          .insertOnConflictUpdate(
            PendingMutationsCompanion.insert(
              clientReferenceId: reference,
              operation: 'post_credit_purchase',
              payloadJson: jsonEncode({'params': params}),
              syncStatus: const Value('PENDING_SYNC'),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      return FinancialMutationResult.queued;
    }
  }

  Future<Map<String, dynamic>> payBill({
    required String accountId,
    required String sourceWalletId,
    required String amount,
    required String description,
    required DateTime paymentDate,
  }) async => Map<String, dynamic>.from(
    await client.rpc(
          'pay_credit_bill',
          params: {
            'payload': {
              'clientReferenceId': _uuid.v4(),
              'accountId': accountId,
              'sourceWalletId': sourceWalletId,
              'amount': FinanceValidation.normalizeAmount(amount),
              'description': description.trim(),
              'paymentDate': DateFormat('yyyy-MM-dd').format(paymentDate),
            },
          },
        )
        as Map,
  );

  Future<void> refundPurchase({
    required String purchaseId,
    required String amount,
    required String reason,
  }) async {
    await client.rpc(
      'refund_credit_purchase',
      params: {
        'payload': {
          'clientReferenceId': _uuid.v4(),
          'purchaseId': purchaseId,
          'amount': FinanceValidation.normalizeAmount(amount),
          'refundDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'reason': FinanceValidation.requiredText(
            reason,
            'Alasan',
            minLength: 3,
          ),
        },
      },
    );
  }

  Future<void> reconcile({
    required String accountId,
    required String actualLiability,
    required String reason,
  }) async {
    await client.rpc(
      'reconcile_credit_account',
      params: {
        'payload': {
          'clientReferenceId': _uuid.v4(),
          'accountId': accountId,
          'actualLiability': FinanceValidation.normalizeAmount(
            actualLiability,
            allowZero: true,
          ),
          'reason': FinanceValidation.requiredText(
            reason,
            'Alasan',
            minLength: 3,
          ),
        },
      },
    );
  }

  Future<List<Map<String, dynamic>>> _list(
    String function, [
    Map<String, dynamic>? params,
  ]) async => _maps(await client.rpc(function, params: params));

  static List<Map<String, dynamic>> _maps(Object? value) =>
      (value as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  static bool _looksOffline(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('socketexception') ||
        value.contains('clientexception') ||
        value.contains('failed host lookup') ||
        value.contains('network') ||
        value.contains('connection');
  }
}
