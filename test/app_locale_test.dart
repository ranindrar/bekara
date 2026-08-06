import 'package:bekara/app/app_locale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  test(
    'initializes Indonesian date formatting used by transaction form',
    () async {
      await initializeAppLocale();

      expect(
        DateFormat('dd MMMM yyyy', appLocale).format(DateTime(2026, 8, 6)),
        '06 Agustus 2026',
      );
      expect(Intl.defaultLocale, appLocale);
    },
  );
}
