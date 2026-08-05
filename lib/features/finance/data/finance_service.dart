import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/finance_validation.dart';
import '../../../core/database/app_database.dart';

class FinanceService {
  FinanceService(this.client, [this.database]);
  final SupabaseClient client;
  final AppDatabase? database;
  static const _uuid = Uuid();

  Future<List<Map<String, dynamic>>> wallets() => _list('list_wallets');
  Future<List<Map<String, dynamic>>> categories([String? direction]) =>
      _list('list_categories', {'category_direction': direction});
  Future<List<Map<String, dynamic>>> transactions() =>
      _list('list_transactions');
  Future<List<Map<String, dynamic>>> categoryReport() =>
      _list('report_category');

  Future<Map<String, dynamic>> dashboard() async {
    final value = await client.rpc('dashboard_summary');
    return Map<String, dynamic>.from(value as Map);
  }

  Future<void> createWallet({
    required String name,
    required String type,
    required String openingBalance,
    required bool shared,
  }) async {
    await client.rpc(
      'create_wallet',
      params: {
        'payload': {
          'name': FinanceValidation.requiredText(
            name,
            'Nama dompet',
            minLength: 2,
          ),
          'walletType': type,
          'openingBalance': FinanceValidation.normalizeAmount(
            openingBalance,
            allowZero: true,
          ),
          'isShared': shared,
          'acceptsHouseholdTransfer': shared,
        },
      },
    );
  }

  Future<void> createCategory({
    required String name,
    required String direction,
    required String scope,
  }) async {
    await client.rpc(
      'create_category',
      params: {
        'payload': {
          'name': FinanceValidation.requiredText(
            name,
            'Nama kategori',
            minLength: 2,
          ),
          'direction': direction,
          'scope': scope,
          'necessityType': direction == 'EXPENSE' ? 'FLEXIBLE' : '',
        },
      },
    );
  }

  Future<void> postTransaction({
    required String walletId,
    required String categoryId,
    required String kind,
    required String amount,
    required String description,
    required String scope,
    required String privacyMode,
    required DateTime transactionDate,
  }) async {
    final reference = _uuid.v4();
    final params = {
      'payload': {
        'clientReferenceId': reference,
        'walletId': walletId,
        'categoryId': categoryId,
        'kind': kind,
        'amount': FinanceValidation.normalizeAmount(amount),
        'description': description.trim(),
        'transactionDate': DateFormat('yyyy-MM-dd').format(transactionDate),
        'scope': scope,
        'privacyMode': scope == 'HOUSEHOLD' ? 'HOUSEHOLD_VISIBLE' : privacyMode,
      },
    };
    await _financialRpc(
      function: 'post_transaction',
      params: params,
      reference: reference,
    );
  }

  Future<void> postTransfer({
    required String sourceWalletId,
    required String destinationWalletId,
    required String amount,
    required String description,
    required DateTime transactionDate,
  }) async {
    final reference = _uuid.v4();
    final params = {
      'payload': {
        'clientReferenceId': reference,
        'sourceWalletId': sourceWalletId,
        'destinationWalletId': destinationWalletId,
        'amount': FinanceValidation.normalizeAmount(amount),
        'description': description.trim(),
        'transactionDate': DateFormat('yyyy-MM-dd').format(transactionDate),
      },
    };
    await _financialRpc(
      function: 'post_transfer',
      params: params,
      reference: reference,
    );
  }

  Future<void> reverseTransaction(String transactionId, String reason) async {
    await client.rpc(
      'reverse_transaction',
      params: {
        'transaction_id': transactionId,
        'transaction_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'reason': FinanceValidation.requiredText(
          reason,
          'Alasan',
          minLength: 3,
        ),
        'client_reference_id': _uuid.v4(),
      },
    );
  }

  Future<void> reconcileWallet(
    String walletId,
    String actualBalance,
    String reason,
  ) async {
    await client.rpc(
      'reconcile_wallet',
      params: {
        'payload': {
          'walletId': walletId,
          'actualBalance': FinanceValidation.normalizeSignedAmount(
            actualBalance,
          ),
          'reason': FinanceValidation.requiredText(
            reason,
            'Alasan',
            minLength: 3,
          ),
          'transactionDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'clientReferenceId': _uuid.v4(),
        },
      },
    );
  }

  Future<List<Map<String, dynamic>>> _list(
    String function, [
    Map<String, dynamic>? params,
  ]) async {
    final value = await client.rpc(function, params: params);
    return (value as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _financialRpc({
    required String function,
    required Map<String, dynamic> params,
    required String reference,
  }) async {
    try {
      await client.rpc(function, params: params);
    } catch (error) {
      if (database == null || !_looksOffline(error)) rethrow;
      await database!
          .into(database!.pendingMutations)
          .insertOnConflictUpdate(
            PendingMutationsCompanion.insert(
              clientReferenceId: reference,
              operation: function,
              payloadJson: jsonEncode({'params': params}),
              syncStatus: const Value('PENDING_SYNC'),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
    }
  }

  static bool _looksOffline(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('socketexception') ||
        value.contains('clientexception') ||
        value.contains('failed host lookup') ||
        value.contains('network') ||
        value.contains('connection');
  }
}
