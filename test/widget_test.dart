import 'package:bekara/app/bekara_app.dart';
import 'package:bekara/core/config/app_environment.dart';
import 'package:bekara/core/database/app_database.dart';
import 'package:bekara/core/providers/core_providers.dart';
import 'package:bekara/features/auth/presentation/auth_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows local-ready and Supabase configuration status', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(supabaseUrl: '', supabasePublishableKey: ''),
          ),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: const BekaraApp(),
      ),
    );

    expect(find.text('Fondasi aplikasi siap'), findsOneWidget);
    expect(find.text('Database offline'), findsOneWidget);
    expect(find.text('Supabase'), findsOneWidget);
  });

  testWidgets('auth form can switch to registration and validates fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(supabaseUrl: '', supabasePublishableKey: ''),
          ),
        ],
        child: const MaterialApp(home: AuthPage()),
      ),
    );

    expect(find.text('Masuk'), findsOneWidget);
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pump();
    expect(find.text('Nama'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.pump();
    expect(find.text('Nama minimal 2 karakter'), findsOneWidget);
    expect(find.text('Masukkan email yang valid'), findsOneWidget);
    expect(find.text('Kata sandi minimal 8 karakter'), findsOneWidget);
  });
}
