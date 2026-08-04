import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'app/bootstrap_error_app.dart';
import 'core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'Unhandled Flutter error',
      details.exception,
      details.stack ?? StackTrace.current,
      name: 'bekara.flutter',
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      'Unhandled platform error',
      error,
      stackTrace,
      name: 'bekara.platform',
    );
    return true;
  };

  await runZonedGuarded(
    () async {
      try {
        final bootstrap = await bootstrapApplication();
        runApp(
          ProviderScope(overrides: bootstrap.overrides, child: bootstrap.app),
        );
      } on Object catch (error, stackTrace) {
        AppLogger.error(
          'Application bootstrap failed',
          error,
          stackTrace,
          name: 'bekara.bootstrap',
        );
        runApp(const BootstrapErrorApp());
      }
    },
    (error, stackTrace) => AppLogger.error(
      'Unhandled zone error',
      error,
      stackTrace,
      name: 'bekara.zone',
    ),
  );
}
