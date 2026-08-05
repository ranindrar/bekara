import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/household_context.dart';

class HouseholdService {
  HouseholdService(this.client);

  final SupabaseClient client;

  Future<HouseholdContext> getMyContext() async {
    final result = await client.rpc('get_my_context');
    return HouseholdContext.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<void> createHousehold(String name, int reportingStartDay) async {
    await client.rpc(
      'create_household',
      params: {
        'payload': {
          'name': name.trim(),
          'reportingStartDay': reportingStartDay,
        },
      },
    );
  }

  Future<void> acceptInvitation(String token) async {
    await client.rpc(
      'accept_invitation',
      params: {'invitation_token': token.trim()},
    );
  }

  Future<Map<String, dynamic>> createInvitation(String email) async {
    final result = await client.rpc(
      'create_invitation',
      params: {'invitee_email': email.trim()},
    );
    return Map<String, dynamic>.from(result as Map);
  }
}
