import 'package:bekara/features/finance/domain/transaction_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const actor = 'user-1';
  final wallets = <Map<String, dynamic>>[
    {
      'id': 'own-active',
      'ownerId': actor,
      'active': true,
      'isShared': false,
      'acceptsHouseholdTransfer': false,
    },
    {
      'id': 'own-inactive',
      'ownerId': actor,
      'active': false,
      'isShared': true,
      'acceptsHouseholdTransfer': true,
    },
    {
      'id': 'partner-private',
      'ownerId': 'user-2',
      'active': true,
      'isShared': false,
      'acceptsHouseholdTransfer': false,
    },
    {
      'id': 'partner-shared',
      'ownerId': 'user-2',
      'active': true,
      'isShared': true,
      'acceptsHouseholdTransfer': true,
    },
    {
      'id': 'partner-transfer-only',
      'ownerId': 'user-2',
      'active': true,
      'isShared': false,
      'acceptsHouseholdTransfer': true,
    },
  ];

  test('transaction wallets match server ownership and sharing rules', () {
    final result = TransactionSelection.transactionWallets(wallets, actor);

    expect(result.map((wallet) => wallet['id']), [
      'own-active',
      'partner-shared',
    ]);
  });

  test('transfer source must be an active wallet owned by actor', () {
    final result = TransactionSelection.transferSources(wallets, actor);

    expect(result.map((wallet) => wallet['id']), ['own-active']);
  });

  test('transfer destinations exclude source and enforce acceptance', () {
    final result = TransactionSelection.transferDestinations(
      wallets,
      actor,
      'own-active',
    );

    expect(result.map((wallet) => wallet['id']), [
      'partner-shared',
      'partner-transfer-only',
    ]);
  });

  test('household transaction only offers household categories', () {
    final categories = <Map<String, dynamic>>[
      {
        'id': 'household-expense',
        'active': true,
        'direction': 'EXPENSE',
        'scope': 'HOUSEHOLD',
      },
      {
        'id': 'private-expense',
        'active': true,
        'direction': 'EXPENSE',
        'scope': 'PRIVATE',
      },
      {
        'id': 'household-income',
        'active': true,
        'direction': 'INCOME',
        'scope': 'HOUSEHOLD',
      },
    ];

    expect(
      TransactionSelection.categories(
        categories,
        'EXPENSE',
        'HOUSEHOLD',
      ).map((category) => category['id']),
      ['household-expense'],
    );
    expect(
      TransactionSelection.categories(
        categories,
        'EXPENSE',
        'PRIVATE',
      ).map((category) => category['id']),
      ['household-expense', 'private-expense'],
    );
  });
}
