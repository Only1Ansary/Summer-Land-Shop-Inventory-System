using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace SummerLandBackend.Services;

/// Keeps every DateTime on the wire as an ISO 8601 UTC instant.
///
/// EF reads SQL `datetime2` columns as Unspecified, so without this converter
/// those values would be serialized without a `Z` and clients could read them
/// as their own local time. Bare incoming values are interpreted in the shop's
/// configured zone before being stored as UTC.
public sealed class UtcIsoDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(
        ref Utf8JsonReader reader,
        Type typeToConvert,
        JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.String)
        {
            return reader.GetDateTime();
        }

        var text = reader.GetString() ?? string.Empty;
        var parsed = DateTime.Parse(
            text,
            CultureInfo.InvariantCulture,
            DateTimeStyles.RoundtripKind);

        return AppTimeZone.Current.ToUtc(parsed);
    }

    public override void Write(
        Utf8JsonWriter writer,
        DateTime value,
        JsonSerializerOptions options) =>
        writer.WriteStringValue(AppTimeZone.EnsureUtc(value));
}
