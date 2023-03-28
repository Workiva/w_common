library w_common.timestamp;

import 'package:intl/intl.dart';

/// The format of a timestamp with no date.
DateFormat timeFormat = DateFormat('h:mma');

/// The format of a weekday with no time of day.
DateFormat weekdayFormat = DateFormat.EEEE();

/// The format of a month and day with no time of day.
DateFormat monthDayFormat = DateFormat.MMMMd();

/// The format of the full date with no time of day.
DateFormat yearMonthDayFormat = DateFormat.yMMMd();

/// Formats a DateTime into the 'X ago' string format.
String formatTimeDifference(DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
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

  // Weekday check prevents ambiguity between dates that are
  // almost a week apart in the same week day.
  if (deltaDays < 7 && now.weekday != time.weekday) {
    // "Tuesday, XX:XXam"
    return '${weekdayFormat.format(time)}, $timeOfDay';
  }

  // Month check prevents ambiguity between dates that are
  // almost a year apart in the same month.
  if (deltaDays < 365 && (now.year == time.year || now.month != time.month)) {
    // "January 25, XX:XXam"
    return '${monthDayFormat.format(time)}, $timeOfDay';
  }

  // "Jan 5, 2016"
  return '${yearMonthDayFormat.format(time)}';
}
