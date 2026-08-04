import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_environment.dart';
import '../core/database/app_database.dart';
import '../core/providers/core_providers.dart';
import 'bekara_app.dart';

class AppBootstrap {
  const AppBootstrap({required this.app, required this.overrides});

  final Widget app;
  final List<Override> overrides;
}

Future<AppBootstrap> bootstrapApplication() async {
  const environment = AppEnvironment.fromDefines();
  if (environment.hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: environment.supabaseUrl,
      publishableKey: environment.supabasePublishableKey,
    );
  }

  final database = AppDatabase();
  return AppBootstrap(
    app: const BekaraApp(),
    overrides: [
      appEnvironmentProvider.overrideWithValue(environment),
      appDatabaseProvider.overrideWithValue(database),
    ],
  );
}
