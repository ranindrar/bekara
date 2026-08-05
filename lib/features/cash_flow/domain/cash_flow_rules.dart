enum BudgetHealth { safe, warning, critical, exceeded }

enum CashFlowHealth { safe, controlNeeded, deficitRisk }

enum RecurrenceFrequency { weekly, monthly }

class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) =>
      !value.isBefore(start) && !value.isAfter(end);
}

class CashFlowRules {
  const CashFlowRules._();

  static DateTime clampedDate(int year, int month, int day) {
    final normalized = DateTime(year, month);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    return DateTime(normalized.year, normalized.month, day.clamp(1, lastDay));
  }

  static DateRange periodFor(DateTime date, int startDay) {
    var start = clampedDate(date.year, date.month, startDay);
    if (date.isBefore(start)) {
      start = clampedDate(date.year, date.month - 1, startDay);
    }
    final nextStart = clampedDate(start.year, start.month + 1, startDay);
    return DateRange(start, nextStart.subtract(const Duration(days: 1)));
  }

  static DateTime autoLockDate(DateRange period) =>
      clampedDate(period.end.year, period.end.month + 2, period.start.day);

  static int remainingCalendarDays(DateTime today, DateTime periodEnd) {
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
    if (start.isAfter(end)) return 0;
    return end.difference(start).inDays + 1;
  }

  static BudgetHealth budgetHealth(num spent, num planned) {
    if (planned <= 0 || spent > planned) return BudgetHealth.exceeded;
    final ratio = spent / planned;
    if (ratio >= .90) return BudgetHealth.critical;
    if (ratio >= .75) return BudgetHealth.warning;
    return BudgetHealth.safe;
  }

  static DateTime nextRecurrence({
    required DateTime from,
    required RecurrenceFrequency frequency,
    required int requestedDay,
  }) {
    if (frequency == RecurrenceFrequency.weekly) {
      return from.add(const Duration(days: 7));
    }
    return clampedDate(from.year, from.month + 1, requestedDay);
  }

  static double availableCash({
    required num cashBalance,
    required num lockedFunds,
    required num routineNeeds,
  }) => (cashBalance - lockedFunds - routineNeeds).toDouble();

  static double safeDailyLimit({
    required num availableCash,
    required int remainingDays,
  }) {
    if (availableCash <= 0 || remainingDays <= 0) return 0;
    return availableCash / remainingDays;
  }

  static CashFlowHealth cashFlowHealth({
    required num cashBalance,
    required num availableCash,
  }) {
    if (availableCash < 0) return CashFlowHealth.deficitRisk;
    if (cashBalance > 0 && availableCash < cashBalance * .20) {
      return CashFlowHealth.controlNeeded;
    }
    return CashFlowHealth.safe;
  }
}
