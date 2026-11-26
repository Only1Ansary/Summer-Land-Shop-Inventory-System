namespace SummerLandBackend.Services;

/// Central handling of the from/to query bounds used by reports and lists.
///
/// Rows are stored as UTC instants. A picked calendar day arrives either as a
/// bare value (`2026-10-01T00:00:00`) or as an explicit UTC instant
/// (`2026-09-30T21:00:00Z`); the latter is what the app sends for a day in the
/// shop's IANA zone. Explicit instants are used exactly as sent. Bare values
/// are read as wall-clock times in the configured zone (Africa/Cairo by
/// default), so DST decides their offset.
///
/// Every endpoint must use [Bounds], otherwise the same range returns
/// different rows depending on which screen asked for it.
internal static class QueryDateRange
{
    private static DateTime ToUtc(DateTime value) =>
        AppTimeZone.Current.ToUtc(value);

    private static DateTime LocalDay(DateTime value) =>
        AppTimeZone.Current.ToLocal(ToUtc(value)).Date;

    /// First tick of the picked day, or today when no date was picked.
    public static DateTime Start(DateTime? value) =>
        value.HasValue
            ? AppTimeZone.Current.StartOfDayUtc(LocalDay(value.Value))
            : AppTimeZone.Current.StartOfDayUtc(AppTimeZone.Current.Today);

    /// Last tick of the picked day, or now when no date was picked.
    public static DateTime End(DateTime? value)
    {
        if (!value.HasValue)
        {
            return DateTime.UtcNow;
        }

        // Check the RAW value for midnight: after conversion a bare date no
        // longer looks like the start of a day.
        return value.Value.TimeOfDay == TimeSpan.Zero
            ? AppTimeZone.Current.EndOfDayUtc(LocalDay(value.Value))
            : ToUtc(value.Value);
    }

    /// Bounds for a from/to filter.
    ///
    /// Explicit UTC bounds are used as sent: the app converts a local day to
    /// UTC before sending it, and that range can span two UTC dates.
    ///
    /// For bare values, when both picks land on the same shop day the whole
    /// day is returned, from its first tick through its last tick.
    public static (DateTime Start, DateTime End) Bounds(
        DateTime? from,
        DateTime? to)
    {
        if (from.HasValue && to.HasValue &&
            from.Value.Kind != DateTimeKind.Unspecified &&
            to.Value.Kind != DateTimeKind.Unspecified)
        {
            return (ToUtc(from.Value), ToUtc(to.Value));
        }

        var start = Start(from);
        var end = End(to);

        if (from.HasValue && to.HasValue &&
            LocalDay(from.Value) == LocalDay(to.Value))
        {
            var day = LocalDay(from.Value);

            return (
                AppTimeZone.Current.StartOfDayUtc(day),
                AppTimeZone.Current.EndOfDayUtc(day));
        }

        return (start, end);
    }
}
