import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../finance/presentation/finance_home_page.dart';
import '../data/household_service.dart';
import '../domain/household_context.dart';
import 'household_onboarding_page.dart';

final householdServiceProvider = Provider<HouseholdService>((ref) {
  return HouseholdService(ref.watch(supabaseClientProvider)!);
});

final householdContextProvider = FutureProvider<HouseholdContext>((ref) {
  return ref.watch(householdServiceProvider).getMyContext();
});

class HouseholdGate extends ConsumerWidget {
  const HouseholdGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(householdContextProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Konteks keluarga gagal dimuat.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(householdContextProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (value) => value.hasHousehold
              ? FinanceHomePage(contextData: value)
              : const HouseholdOnboardingPage(),
        );
  }
}
