namespace SummerLandBackend.DTOs.Reports;

public class StockMovementReportDto
{
    public DateTime From { get; set; }
    public DateTime To { get; set; }

    public int MovementCount { get; set; }

    public List<StockMovementReportItemDto> Items { get; set; }
        = new List<StockMovementReportItemDto>();
}

public class StockMovementReportItemDto
{
    public int Id { get; set; }

    public int ProductVariantId { get; set; }

    public string ModelNumber { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;

    public string? SizeName { get; set; }
    public string? ColourName { get; set; }

    public int LocationId { get; set; }
    public string LocationName { get; set; } = string.Empty;

    public int QuantityChange { get; set; }

    public string Reason { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }
}