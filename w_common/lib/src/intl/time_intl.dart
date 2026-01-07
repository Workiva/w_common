import 'package:intl/intl.dart';

class TimeIntl {
  static String today(String timeOfDay) =>
      Intl.message('Today, $timeOfDay', args: [timeOfDay], name: 'TimeIntl_today');

  static String yesterday(String timeOfDay) =>
      Intl.message('Yesterday, $timeOfDay', args: [timeOfDay], name: 'TimeIntl_yesterday');
}
