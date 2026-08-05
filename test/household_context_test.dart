import 'package:bekara/features/household/domain/household_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('context without membership requires onboarding', () {
    final context = HouseholdContext.fromJson({
      'profile': {'displayName': 'Rani'},
      'membership': null,
      'household': null,
    });

    expect(context.displayName, 'Rani');
    expect(context.hasHousehold, isFalse);
    expect(context.isOwner, isFalse);
  });

  test('owner household context is parsed', () {
    final context = HouseholdContext.fromJson({
      'profile': {'displayName': 'Rani'},
      'membership': {'role': 'OWNER'},
      'household': {'id': 'household-1', 'name': 'Keluarga Rani'},
    });

    expect(context.householdName, 'Keluarga Rani');
    expect(context.hasHousehold, isTrue);
    expect(context.isOwner, isTrue);
  });
}
