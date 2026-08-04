import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_environment.dart';
import '../database/app_database.dart';

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => throw UnimplementedError('AppEnvironment must be overridden'),
);

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('AppDatabase must be overridden'),
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  if (!environment.hasSupabaseConfiguration) return null;
  return Supabase.instance.client;
});
