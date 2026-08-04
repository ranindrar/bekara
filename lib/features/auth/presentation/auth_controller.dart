import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/auth_service.dart';

final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : AuthService(client);
});

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthController, AsyncValue<void>>(
      (ref) => AuthController(ref.watch(authServiceProvider)),
    );

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._service) : super(const AsyncData(null));

  final AuthService? _service;

  Future<bool> signIn(String email, String password) => _execute(() async {
    await _requiredService.signIn(email, password);
    return true;
  });

  Future<bool> signUp(String name, String email, String password) =>
      _execute(() => _requiredService.signUp(name, email, password));

  Future<bool> resetPassword(String email) => _execute(() async {
    await _requiredService.resetPassword(email);
    return true;
  });

  AuthService get _requiredService =>
      _service ?? (throw StateError('Supabase belum dikonfigurasi'));

  Future<bool> _execute(Future<bool> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
