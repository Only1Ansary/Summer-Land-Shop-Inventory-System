namespace SummerLandBackend.Services;

/// The shop's IANA time zone.
///
/// Instants are always stored in UTC (DateTime.UtcNow / ISO 8601 with `Z`).
/// This zone is used only to interpret bare calendar values and to group UTC
/// instants into the days the user sees. IANA data supplies Egypt's DST rules,
/// so the offset is never hardcoded.
public sealed class AppTimeZone
{
    public const string DefaultId = "Africa/Cairo";

    private static AppTimeZone _current = new(DefaultId);

    /// The configured zone, shared by model binding, queries and reports.
    public static AppTimeZone Current => _current;

    public string Id { get; }

    public TimeZoneInfo Zone { get; }

    public AppTimeZone(string? id)
    {
        Id = string.IsNullOrWhiteSpace(id) ? DefaultId : id.Trim();
        Zone = Resolve(Id);
    }

    /// Applies the configured zone once at startup.
    public static void Configure(string? id) => _current = new AppTimeZone(id);

    /// Treats a database value as the UTC instant it represents.
    public static DateTime EnsureUtc(DateTime value) =>
        value.Kind == DateTimeKind.Utc
            ? value
            : DateTime.SpecifyKind(value, DateTimeKind.Utc);

    /// Converts a UTC instant to the shop's wall clock.
    public DateTime ToLocal(DateTime value) =>
        TimeZoneInfo.ConvertTimeFromUtc(EnsureUtc(value), Zone);

    /// Converts any incoming value to a UTC instant.
    ///
    /// A bare value (from a date picker or an old client) is a wall-clock time
    /// in the shop's zone, so DST decides its offset at that date.
    public DateTime ToUtc(DateTime value) => value.Kind switch
    {
        DateTimeKind.Utc => value,
        DateTimeKind.Local => value.ToUniversalTime(),
        _ => TimeZoneInfo.ConvertTimeToUtc(
            DateTime.SpecifyKind(value, DateTimeKind.Unspecified),
            Zone)
    };

    /// First tick of a wall-clock day, as a UTC instant.
    public DateTime StartOfDayUtc(DateTime wallClock) =>
        ToUtc(DateTime.SpecifyKind(wallClock.Date, DateTimeKind.Unspecified));

    /// Last tick of a wall-clock day, as a UTC instant. A DST change makes the
    /// day 23 or 25 hours long, so this is based on the *next* local midnight.
    public DateTime EndOfDayUtc(DateTime wallClock) =>
        ToUtc(DateTime.SpecifyKind(
            wallClock.Date.AddDays(1),
            DateTimeKind.Unspecified)).AddTicks(-1);

    /// Today on the shop's clock, not the server's clock.
    public DateTime Today => ToLocal(DateTime.UtcNow).Date;

    private static TimeZoneInfo Resolve(string id)
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(id);
        }
        catch (TimeZoneNotFoundException)
        {
            // Invariant-globalization hosts may only know Windows zone IDs.
            if (TimeZoneInfo.TryConvertIanaIdToWindowsId(id, out var windows) &&
                !string.IsNullOrEmpty(windows))
            {
                return TimeZoneInfo.FindSystemTimeZoneById(windows);
            }

            throw;
        }
    }
}
