import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CashFlowService {
  CashFlowService(this.client);

  final SupabaseClient client;
  static const _uuid = Uuid();

  Future<List<Map<String, dynamic>>> periods() => _list('list_periods');

  Future<List<Map<String, dynamic>>> budgets(String periodId) =>
      _list('list_budgets', {'period_id': periodId});

  Future<List<Map<String, dynamic>>> lockedFunds() =>
      _list('list_locked_funds');

  Future<List<Map<String, dynamic>>> obligations() =>
      _list('list_recurring_obligations');

  Future<Map<String, dynamic>> forecast() => _map('forecast_summary');

  Future<Map<String, dynamic>> periodReport(String periodId) =>
      _map('period_report', {'period_id': periodId});

  Future<void> setPersonalStartDay(int day) async {
    await client.rpc('set_my_period_start_day', params: {'requested_day': day});
  }

  Future<void> reviewPeriod(String periodId) async {
    await client.rpc('review_period', params: {'period_id': periodId});
  }

  Future<void> lockPeriod(String periodId) async {
    await client.rpc('lock_period', params: {'period_id': periodId});
  }

  Future<void> saveBudget({
    required String periodId,
    required String categoryId,
    required String scope,
    required String amount,
    String? id,
    int? expectedVersion,
  }) async {
    await client.rpc(
      'upsert_budget',
      params: {
        'payload': {
          'id': id ?? '',
          'expectedVersion': expectedVersion?.toString() ?? '',
          'periodId': periodId,
          'categoryId': categoryId,
          'scope': scope,
          'amount': amount,
        },
      },
    );
  }

  Future<void> saveLockedFund({
    required String walletId,
    required String label,
    required String amount,
    String? id,
    int? expectedVersion,
  }) async {
    await client.rpc(
      'upsert_locked_fund',
      params: {
        'payload': {
          'id': id ?? '',
          'expectedVersion': expectedVersion?.toString() ?? '',
          'walletId': walletId,
          'label': label,
          'amount': amount,
        },
      },
    );
  }

  Future<void> releaseLockedFund(String id, int version) async {
    await client.rpc(
      'release_locked_fund',
      params: {'fund_id': id, 'expected_version': version},
    );
  }

  Future<void> saveObligation({
    required String name,
    required String walletId,
    required String categoryId,
    required String scope,
    required String frequency,
    required String estimatedAmount,
    required DateTime nextDueDate,
  }) async {
    await client.rpc(
      'upsert_recurring_obligation',
      params: {
        'payload': {
          'id': '',
          'expectedVersion': '',
          'name': name,
          'walletId': walletId,
          'categoryId': categoryId,
          'scope': scope,
          'privacyMode': scope == 'HOUSEHOLD'
              ? 'HOUSEHOLD_VISIBLE'
              : 'PRIVATE_FULL',
          'frequency': frequency,
          'estimatedAmount': estimatedAmount,
          'nextDueDate': _date(nextDueDate),
        },
      },
    );
  }

  Future<void> confirmObligation({
    required String occurrenceId,
    required String actualAmount,
    required DateTime transactionDate,
  }) async {
    await client.rpc(
      'confirm_obligation_payment',
      params: {
        'payload': {
          'occurrenceId': occurrenceId,
          'actualAmount': actualAmount,
          'transactionDate': _date(transactionDate),
          'clientReferenceId': _uuid.v4(),
        },
      },
    );
  }

  Future<void> resolveObligation({
    required String occurrenceId,
    required String action,
    DateTime? rescheduledDate,
  }) async {
    await client.rpc(
      'resolve_obligation_occurrence',
      params: {
        'occurrence_id': occurrenceId,
        'action': action,
        'rescheduled_date': rescheduledDate == null
            ? null
            : _date(rescheduledDate),
      },
    );
  }

  Future<void> correctTransaction({
    required String transactionId,
    required String correctedAmount,
    required String reason,
    required String description,
    required DateTime correctionDate,
  }) async {
    await client.rpc(
      'correct_transaction',
      params: {
        'payload': {
          'transactionId': transactionId,
          'correctedAmount': correctedAmount,
          'reason': reason,
          'description': description,
          'correctionDate': _date(correctionDate),
          'clientReferenceId': _uuid.v4(),
          'walletId': '',
          'categoryId': '',
        },
      },
    );
  }

  Future<Map<String, dynamic>> exportRemoteData() => _map('export_my_data');

  Future<List<Map<String, dynamic>>> _list(
    String function, [
    Map<String, dynamic>? params,
  ]) async {
    final value = await client.rpc(function, params: params);
    return (value as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> _map(
    String function, [
    Map<String, dynamic>? params,
  ]) async {
    final value = await client.rpc(function, params: params);
    return Map<String, dynamic>.from(value as Map);
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
