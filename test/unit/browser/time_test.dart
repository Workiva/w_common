import 'package:test/test.dart';

import 'package:w_common/time.dart';

void main() {
  group('Utilities', () {
    test('formatting timeAgo', () {
      DateTime past;
      DateTime newDay;
      DateTime oldDay;

      // today

      // less than 24 hours ago && same day
      newDay = new DateTime.utc(2018, 1, 1, 23, 59, 59);
      oldDay = new DateTime.utc(2018, 1, 1);
      expect(formatTimeDifference(oldDay, now: newDay), startsWith("Today, "));

      // yesterday

      // different day
      newDay = new DateTime.utc(2018, 1, 1);
      oldDay = newDay.subtract(const Duration(seconds: 1));
      expect(
          formatTimeDifference(oldDay, now: newDay), startsWith("Yesterday, "));

      // very nearly 48 hours
      newDay = new DateTime.utc(2018, 1, 2, 23, 59, 59);
      oldDay = new DateTime.utc(2018, 1, 1);
      expect(
          formatTimeDifference(oldDay, now: newDay), startsWith("Yesterday, "));

      // week

      // at midnight, the day before yesterday was one day and 1 second ago
      newDay = new DateTime.utc(2018, 1, 1);
      oldDay = newDay.subtract(const Duration(days: 1, seconds: 1));
      expect(formatTimeDifference(oldDay, now: newDay),
          startsWith("${weekdayFormat.format(oldDay)}, "));

      // less than 7 days diff, and not on the same week day
      newDay = new DateTime.utc(2018, 1, 1, 1);
      oldDay = newDay.subtract(const Duration(days: 6, seconds: 1));
      expect(formatTimeDifference(oldDay, now: newDay),
          startsWith("${weekdayFormat.format(oldDay)}, "));

      // month

      // less than 7 days diff, same week day
      newDay = new DateTime.utc(2018, 1, 1, 1);
      oldDay = newDay.subtract(const Duration(days: 6, hours: 23));
      expect(formatTimeDifference(oldDay, now: newDay),
          startsWith("${monthDayFormat.format(oldDay)}, "));

      // 7 day diff
      newDay = new DateTime.utc(2018, 1, 1, 23, 59, 59);
      oldDay = newDay.subtract(const Duration(days: 7));
      expect(formatTimeDifference(oldDay, now: newDay),
          startsWith("${monthDayFormat.format(oldDay)}, "));

      // 9 day diff
      newDay = new DateTime.utc(2018, 1, 1, 23, 59, 59);
      oldDay = newDay.subtract(const Duration(days: 9));
      expect(formatTimeDifference(oldDay, now: newDay),
          startsWith("${monthDayFormat.format(oldDay)}, "));

      // year

      // 365 day diff
      newDay = new DateTime.utc(2018, 1, 1);
      oldDay = newDay.subtract(const Duration(days: 365));
      expect(formatTimeDifference(oldDay, now: newDay),
          "${yearMonthDayFormat.format(oldDay)}");

      // look out a ways
      past = new DateTime.now().subtract(const Duration(days: 9999));
      expect(formatTimeDifference(past), "${yearMonthDayFormat.format(past)}");
    });
  });
}
