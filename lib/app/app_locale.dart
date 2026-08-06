import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const appLocale = 'id_ID';

Future<void> initializeAppLocale() async {
  Intl.defaultLocale = appLocale;
  await initializeDateFormatting(appLocale);
}
