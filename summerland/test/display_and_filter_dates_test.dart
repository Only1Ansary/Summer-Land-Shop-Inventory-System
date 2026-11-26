import 'package:flutter_test/flutter_test.dart';
import 'package:summerland/services/time_zone_service.dart';
import 'package:summerland/ui/app_widgets.dart';

void main() {
  setUp(() {
    TimeZoneService.instance.resetForTest();
  });

  group('Africa/Cairo display', () {
    test('shows the Cairo day of a UTC timestamp in winter (EET, +02:00)', () {
      // 23:06Z is 01:06 on the next day in Egypt.
      final createdAt = DateTime.utc(2026, 11, 25, 23, 6);

      expect(localDateOnly(createdAt), DateTime(2026, 11, 26));
      expect(formatDisplayDate(createdAt), '26/11/2026');
      expect(
        formatDisplayDateTime(createdAt),
        '2026/11/26 01:06:00 AM',
      );
    });

    test('uses EEST (+03:00) after the DST transition', () {
      // Egypt is on summer time in July: 22:00Z becomes 01:00 the next day.
      final createdAt = DateTime.utc(2026, 7, 14, 22, 0, 7);

      expect(localDateOnly(createdAt), DateTime(2026, 7, 15));
      expect(formatDisplayDate(createdAt), '15/7/2026');
      expect(
        formatDisplayDateTime(createdAt),
        '2026/07/15 01:00:07 AM',
      );
    });
  });

  group('Africa/Cairo day filters', () {
    test('send the winter day as explicit UTC bounds (+02:00)', () {
      final picked = DateTime(2026, 11, 26);

      expect(filterFromUtc(picked), DateTime.utc(2026, 11, 25, 22));
      expect(
        filterToUtc(picked),
        DateTime.utc(2026, 11, 26, 21, 59, 59, 999, 999),
      );
    });

    test('send the summer day as explicit UTC bounds (+03:00)', () {
      final picked = DateTime(2026, 7, 15);

      expect(filterFromUtc(picked), DateTime.utc(2026, 7, 14, 21));
      expect(
        filterToUtc(picked),
        DateTime.utc(2026, 7, 15, 20, 59, 59, 999, 999),
      );
    });

    test('uses the configured default timezone ID', () {
      expect(TimeZoneService.instance.timeZoneId.value, 'Africa/Cairo');
      expect(
        inAppTimeZone(DateTime.utc(2026, 11, 26)).timeZoneOffset,
        const Duration(hours: 2),
      );
    });
  });
}
