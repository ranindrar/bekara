import 'package:bekara/features/cash_flow/domain/cash_flow_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('financial periods', () {
    test('maps a 25-24 cycle and uses a two-cycle lock grace', () {
      final period = CashFlowRules.periodFor(DateTime(2026, 8, 3), 25);

      expect(period.start, DateTime(2026, 7, 25));
      expect(period.end, DateTime(2026, 8, 24));
      expect(CashFlowRules.autoLockDate(period), DateTime(2026, 10, 25));
    });

    test('clamps day 31 for short months and leap years', () {
      expect(
        CashFlowRules.periodFor(DateTime(2028, 2, 29), 31).start,
        DateTime(2028, 2, 29),
      );
      expect(
        CashFlowRules.periodFor(DateTime(2027, 2, 28), 31).start,
        DateTime(2027, 2, 28),
      );
    });

    test('counts every calendar day including today', () {
      expect(
        CashFlowRules.remainingCalendarDays(
          DateTime(2026, 8, 20),
          DateTime(2026, 8, 24),
        ),
        5,
      );
    });
  });

  group('budget and forecast', () {
    test('uses deterministic thresholds', () {
      expect(CashFlowRules.budgetHealth(749, 1000), BudgetHealth.safe);
      expect(CashFlowRules.budgetHealth(750, 1000), BudgetHealth.warning);
      expect(CashFlowRules.budgetHealth(900, 1000), BudgetHealth.critical);
      expect(CashFlowRules.budgetHealth(1001, 1000), BudgetHealth.exceeded);
    });

    test('never exposes a negative safe daily limit', () {
      final available = CashFlowRules.availableCash(
        cashBalance: 200000,
        lockedFunds: 150000,
        routineNeeds: 100000,
      );
      expect(available, -50000);
      expect(
        CashFlowRules.safeDailyLimit(
          availableCash: available,
          remainingDays: 10,
        ),
        0,
      );
      expect(
        CashFlowRules.cashFlowHealth(
          cashBalance: 200000,
          availableCash: available,
        ),
        CashFlowHealth.deficitRisk,
      );
    });
  });

  group('recurrence', () {
    test('monthly day 31 follows month end', () {
      final february = CashFlowRules.nextRecurrence(
        from: DateTime(2028, 1, 31),
        frequency: RecurrenceFrequency.monthly,
        requestedDay: 31,
      );
      expect(february, DateTime(2028, 2, 29));
      expect(
        CashFlowRules.nextRecurrence(
          from: february,
          frequency: RecurrenceFrequency.monthly,
          requestedDay: 31,
        ),
        DateTime(2028, 3, 31),
      );
    });

    test('weekly recurrence adds seven days', () {
      expect(
        CashFlowRules.nextRecurrence(
          from: DateTime(2026, 8, 3),
          frequency: RecurrenceFrequency.weekly,
          requestedDay: DateTime.monday,
        ),
        DateTime(2026, 8, 10),
      );
    });
  });
}
