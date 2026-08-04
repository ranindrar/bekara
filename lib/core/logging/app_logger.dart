import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void info(String message, {String name = 'bekara'}) {
    developer.log(message, name: name, level: 800);
  }

  static void error(
    String message,
    Object error,
    StackTrace stackTrace, {
    String name = 'bekara',
  }) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
    if (kDebugMode) {
      debugPrint('$message: $error');
    }
  }
}
