import 'package:bekara/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local-only environment has no Supabase configuration', () {
    const environment = AppEnvironment(
      supabaseUrl: '',
      supabasePublishableKey: '',
    );

    expect(environment.hasSupabaseConfiguration, isFalse);
  });

  test('Supabase configuration requires both values', () {
    const missingKey = AppEnvironment(
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: '',
    );
    const configured = AppEnvironment(
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'publishable-key',
    );

    expect(missingKey.hasSupabaseConfiguration, isFalse);
    expect(configured.hasSupabaseConfiguration, isTrue);
  });
}
