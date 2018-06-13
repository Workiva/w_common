library w_common.timestamp;

import 'package:intl/intl.dart';

/// The format of a timestamp with no date.
DateFormat timeFormat = new DateFormat('h:mma');

/// The format of a weekday with no time of day.
DateFormat weekdayFormat = new DateFormat.EEEE();

/// The format of a month and day with no time of day.
DateFormat monthDayFormat = new DateFormat.MMMMd();

/// The format of the full date with no time of day.
DateFormat yearMonthDayFormat = new DateFormat.yMMMd();

/// formating of string in our db
DateFormat dbFormat = new DateFormat("y-M-dd HH:mm:ss");

/// Formats a DateTime into the 'X ago' string format.
String formatTimeDifference(DateTime time, {DateTime now}) {
  now ??= new DateTime.now();
  final timeOfDay = timeFormat.format(time).toLowerCase();
  final deltaDays = now.difference(time).inDays.abs();

  if (deltaDays < 1 && now.day == time.day) {
    // "Today, XX:XXam"
    return 'Today, $timeOfDay';
  }

  if (deltaDays < 2 && now.weekday == (time.weekday + 1) % 7) {
    // "Yesterday, XX:XXam"
    return 'Yesterday, $timeOfDay';
  }

  // Weekday check prevents abiguity between comments
  // made almost a week apart in the same week day.
  if (deltaDays < 7 && now.weekday != time.weekday) {
    // "Tuesday, XX:XXam"
    return '${weekdayFormat.format(time)}, $timeOfDay';
  }

  // Month check prevents abiguity between comments
  // made almost a year apart in the same month.
  if (deltaDays < 365 && (now.year == time.year || now.month != time.month)) {
    // "January 25, XX:XXam"
    return '${monthDayFormat.format(time)}, $timeOfDay';
  }

  // "Jan 5, 2016"
  return '${yearMonthDayFormat.format(time)}';
}
