import 'package:w_intl/intl_wrapper.dart';

class TimeIntl {
  static String get today => Intl.message('Today', name: 'TimeIntl_today');

  static String get yesterday => Intl.message('Yesterday', name: 'TimeIntl_yesterday');
}