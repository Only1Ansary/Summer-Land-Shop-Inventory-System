namespace SummerLandBackend.DTOs.Reports;

public class LowStockReportDto
{
    public int Count { get; set; }

    public List<LowStockItemDto> Items { get; set; }
        = new List<LowStockItemDto>();
}

public class LowStockItemDto
{
    public int ProductVariantId { get; set; }

    public string ModelNumber { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;

    public string? SizeName { get; set; }
    public string? ColourName { get; set; }

    public string Barcode { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public int LowStockThreshold { get; set; }
    public int TotalQuantity { get; set; }

    public List<LowStockLocationDto> Locations { get; set; }
        = new List<LowStockLocationDto>();
}

public class LowStockLocationDto
{
    public int LocationId { get; set; }
    public string LocationName { get; set; } = string.Empty;
    public int Quantity { get; set; }
}