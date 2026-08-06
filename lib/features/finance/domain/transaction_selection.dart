class TransactionSelection {
  const TransactionSelection._();

  static List<Map<String, dynamic>> transactionWallets(
    List<Map<String, dynamic>> wallets,
    String userId,
  ) => wallets
      .where(
        (wallet) =>
            wallet['active'] == true &&
            (wallet['ownerId'] == userId || wallet['isShared'] == true),
      )
      .toList();

  static List<Map<String, dynamic>> transferSources(
    List<Map<String, dynamic>> wallets,
    String userId,
  ) => wallets
      .where(
        (wallet) => wallet['active'] == true && wallet['ownerId'] == userId,
      )
      .toList();

  static List<Map<String, dynamic>> transferDestinations(
    List<Map<String, dynamic>> wallets,
    String userId,
    String? sourceWalletId,
  ) => wallets
      .where(
        (wallet) =>
            wallet['active'] == true &&
            wallet['id'] != sourceWalletId &&
            (wallet['ownerId'] == userId ||
                wallet['acceptsHouseholdTransfer'] == true),
      )
      .toList();

  static List<Map<String, dynamic>> categories(
    List<Map<String, dynamic>> categories,
    String kind,
    String scope,
  ) => categories
      .where(
        (category) =>
            category['active'] == true &&
            category['direction'] == kind &&
            (scope == 'PRIVATE' || category['scope'] == 'HOUSEHOLD'),
      )
      .toList();

  static String? firstId(List<Map<String, dynamic>> items) =>
      items.isEmpty ? null : items.first['id'] as String;
}
