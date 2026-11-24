class BillingCycle {
  const BillingCycle({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class ScopeAllocation {
  const ScopeAllocation({required this.household, required this.private});

  final int household;
  final int private;
}

abstract final class CreditRules {
  static BillingCycle billingCycle(DateTime date, int statementDay) {
    _validateDay(statementDay);
    final normalized = DateTime(date.year, date.month, date.day);
    var end = _clampedDate(normalized.year, normalized.month, statementDay);
    if (normalized.isAfter(end)) {
      end = _clampedDate(normalized.year, normalized.month + 1, statementDay);
    }
    final previousEnd = _clampedDate(end.year, end.month - 1, statementDay);
    return BillingCycle(
      start: previousEnd.add(const Duration(days: 1)),
      end: end,
    );
  }

  static DateTime dueDate(DateTime cutoff, int dueDay) {
    _validateDay(dueDay);
    var result = _clampedDate(cutoff.year, cutoff.month, dueDay);
    if (!result.isAfter(cutoff)) {
      result = _clampedDate(cutoff.year, cutoff.month + 1, dueDay);
    }
    return result;
  }

  /// Splits an integer amount so the last installment absorbs all rounding.
  static List<int> installmentAmounts(int total, int tenor) {
    if (total < 0 || tenor < 1 || tenor > 36) {
      throw ArgumentError('Nominal atau tenor cicilan tidak valid.');
    }
    final regular = total ~/ tenor;
    return [
      for (var index = 0; index < tenor; index++)
        index == tenor - 1 ? total - (regular * (tenor - 1)) : regular,
    ];
  }

  /// Mirrors server allocation: oldest bill first, then proportional by scope.
  static ScopeAllocation proportionalScopeAllocation({
    required int payment,
    required int householdOutstanding,
    required int privateOutstanding,
  }) {
    if (payment < 0 || householdOutstanding < 0 || privateOutstanding < 0) {
      throw ArgumentError('Nominal alokasi tidak boleh negatif.');
    }
    final total = householdOutstanding + privateOutstanding;
    if (payment > total) throw ArgumentError('Pembayaran melebihi tagihan.');
    if (total == 0 || payment == 0) {
      return const ScopeAllocation(household: 0, private: 0);
    }
    if (householdOutstanding == 0) {
      return ScopeAllocation(household: 0, private: payment);
    }
    if (privateOutstanding == 0) {
      return ScopeAllocation(household: payment, private: 0);
    }
    var household = (payment * householdOutstanding / total).round();
    if (household > householdOutstanding) household = householdOutstanding;
    var private = payment - household;
    if (private > privateOutstanding) {
      private = privateOutstanding;
      household = payment - private;
    }
    return ScopeAllocation(household: household, private: private);
  }

  static DateTime _clampedDate(int year, int month, int day) {
    final first = DateTime(year, month, 1);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, day > lastDay ? lastDay : day);
  }

  static void _validateDay(int day) {
    if (day < 1 || day > 31) throw ArgumentError('Tanggal harus 1–31.');
  }
}
