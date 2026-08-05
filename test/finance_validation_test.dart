import 'package:bekara/features/finance/domain/finance_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nominal validation', () {
    test('normalizes Indonesian grouping and decimal separators', () {
      expect(FinanceValidation.normalizeAmount('25.000'), '25000');
      expect(FinanceValidation.normalizeAmount('10,5'), '10.5');
    });

    test('rejects zero and invalid values', () {
      expect(
        () => FinanceValidation.normalizeAmount('0'),
        throwsFormatException,
      );
      expect(
        () => FinanceValidation.normalizeAmount('abc'),
        throwsFormatException,
      );
    });
  });

  group('safe error messages', () {
    test('maps authorization and concurrency errors', () {
      expect(
        FinanceValidation.friendlyError(Exception('FORBIDDEN')),
        contains('izin'),
      );
      expect(
        FinanceValidation.friendlyError(Exception('VERSION_CONFLICT')),
        contains('berubah'),
      );
    });

    test('does not expose unknown backend details', () {
      expect(
        FinanceValidation.friendlyError(Exception('secret database detail')),
        isNot(contains('secret')),
      );
    });
  });
}
