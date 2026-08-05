class HouseholdContext {
  const HouseholdContext({
    required this.displayName,
    this.householdId,
    this.householdName,
    this.role,
  });

  factory HouseholdContext.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>? ?? const {};
    final household = json['household'] as Map<String, dynamic>?;
    final membership = json['membership'] as Map<String, dynamic>?;
    return HouseholdContext(
      displayName: profile['displayName'] as String? ?? '',
      householdId: household?['id'] as String?,
      householdName: household?['name'] as String?,
      role: membership?['role'] as String?,
    );
  }

  final String displayName;
  final String? householdId;
  final String? householdName;
  final String? role;

  bool get hasHousehold => householdId != null;
  bool get isOwner => role == 'OWNER';
}
