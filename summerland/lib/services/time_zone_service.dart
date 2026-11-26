import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The IANA zone used for every date and time the app shows.
///
/// IANA data carries Egypt's daylight-saving rules (EET/EEST), so offsets are
/// never hardcoded. Instants are still sent to and stored by the backend in
/// UTC; this zone is only used to turn those instants into the shop's clock.
const String defaultTimeZoneId = 'Africa/Cairo';

/// Persists the user's timezone choice and exposes the matching IANA zone.
///
/// Defaults to [defaultTimeZoneId] before preferences are loaded and whenever
/// a stored value is missing or unknown.
class TimeZoneService {
  TimeZoneService._();

  static final TimeZoneService instance = TimeZoneService._();

  static const String _key = 'settings.timeZone';

  /// The only zone the app supports; kept as a setting so the default is
  /// explicit and can be read from SharedPreferences in tests and settings.
  static const List<String> supportedIds = <String>[defaultTimeZoneId];

  /// Current choice; applies immediately to every formatter and filter.
  final ValueNotifier<String> timeZoneId = ValueNotifier(defaultTimeZoneId);

  static bool _initialized = false;

  /// Loads IANA data once. Synchronous, so the helpers can be used from
  /// constructors and tests without awaiting startup.
  static void ensureInitialized() {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    _initialized = true;
  }

  /// The IANA location for the current setting, with a safe fallback.
  tz.Location get location {
    ensureInitialized();

    try {
      return tz.getLocation(timeZoneId.value);
    } on tz.LocationNotFoundException {
      timeZoneId.value = defaultTimeZoneId;
      return tz.getLocation(defaultTimeZoneId);
    }
  }

  /// Reads the stored choice. Safe to call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    if (saved != null && supportedIds.contains(saved)) {
      timeZoneId.value = saved;
    } else {
      timeZoneId.value = defaultTimeZoneId;
    }
  }

  /// Persists a new choice and applies it immediately.
  Future<void> setTimeZone(String id) async {
    if (!supportedIds.contains(id)) return;

    timeZoneId.value = id;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }

  @visibleForTesting
  void resetForTest([String? id]) {
    timeZoneId.value = id ?? defaultTimeZoneId;
  }
}
