import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../bootstrap/presentation/bootstrap_page.dart';
import 'auth_controller.dart';
import 'auth_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return const BootstrapPage();
    final service = ref.watch(authServiceProvider)!;

    return StreamBuilder(
      stream: service.authStateChanges,
      builder: (context, snapshot) => client.auth.currentSession == null
          ? const AuthPage()
          : const BootstrapPage(),
    );
  }
}
