import 'package:bekara/features/credit/domain/credit_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cutoff is inclusive and next cycle starts on following day', () {
    final onCutoff = CreditRules.billingCycle(DateTime(2026, 8, 25), 25);
    final afterCutoff = CreditRules.billingCycle(DateTime(2026, 8, 26), 25);

    expect(onCutoff.start, DateTime(2026, 7, 26));
    expect(onCutoff.end, DateTime(2026, 8, 25));
    expect(afterCutoff.start, DateTime(2026, 8, 26));
    expect(afterCutoff.end, DateTime(2026, 9, 25));
  });

  test('day 31 clamps and due date is strictly after cutoff', () {
    final cycle = CreditRules.billingCycle(DateTime(2026, 2, 28), 31);
    expect(cycle.end, DateTime(2026, 2, 28));
    expect(CreditRules.dueDate(cycle.end, 10), DateTime(2026, 3, 10));
    expect(
      CreditRules.dueDate(DateTime(2026, 1, 31), 31),
      DateTime(2026, 2, 28),
    );
  });

  test('last installment absorbs rounding', () {
    expect(CreditRules.installmentAmounts(1000, 3), [333, 333, 334]);
    expect(CreditRules.installmentAmounts(100, 6), [16, 16, 16, 16, 16, 20]);
  });

  test('mixed-scope payment is proportional', () {
    final allocation = CreditRules.proportionalScopeAllocation(
      payment: 500,
      householdOutstanding: 600,
      privateOutstanding: 400,
    );
    expect(allocation.household, 300);
    expect(allocation.private, 200);
  });
}
