import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  const AuthService(this.client);

  final SupabaseClient client;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<bool> signUp(String name, String email, String password) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': name.trim()},
    );
    return response.session == null;
  }

  Future<void> signOut() => client.auth.signOut();

  Future<void> resetPassword(String email) =>
      client.auth.resetPasswordForEmail(email.trim());
}
