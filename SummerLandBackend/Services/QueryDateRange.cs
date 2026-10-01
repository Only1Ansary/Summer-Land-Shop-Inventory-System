namespace SummerLandBackend.Services;

/// Central handling of the from/to query bounds used by the reports and the
/// invoice lists.
///
/// Picking a date in the UI sends a bare calendar date with no offset
/// (2026-10-01T00:00:00). Two mistakes are easy to make here, and both have
/// happened:
///
/// 1. Calling DateTime.ToUniversalTime() on that value assumes the *server's*
///    local timezone, shifting the bound by the UTC offset. With a local time
///    of UTC+3, "to = 2026-10-01" became 2026-09-30T21:00Z. The value is
///    instead read as UTC, matching how CreatedAt and Date are stored.
/// 2. Using the picked date directly as an upper bound stops at midnight, so
///    the whole picked day drops out of the result. A picked "to" date means
///    the entire day, up to its last tick.
///
/// Every endpoint must use these two helpers, otherwise the same range
/// returns different rows depending on which screen asked for it.
internal static class QueryDateRange
{
    // Unspecified is treated as UTC (values are stored with DateTime.UtcNow),
    // instead of silently using the server's local timezone.
    private static DateTime ToUtc(DateTime value) => value.Kind switch
    {
        DateTimeKind.Utc => value,
        DateTimeKind.Local => value.ToUniversalTime(),
        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
    };

    /// First tick of the picked day, or today when no date was picked.
    public static DateTime Start(DateTime? value) =>
        value.HasValue ? ToUtc(value.Value).Date : DateTime.UtcNow.Date;

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
            ? ToUtc(value.Value.Date.AddDays(1)).AddTicks(-1)
            : ToUtc(value.Value);
    }
}