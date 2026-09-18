namespace SummerLandBackend.DTOs.Reports;

public class InventoryReportDto
{
    public int TotalVariants { get; set; }
    public int TotalQuantity { get; set; }
    public decimal TotalInventoryValue { get; set; }
    public int LowStockVariants { get; set; }

    public List<InventoryReportItemDto> Items { get; set; }
        = new List<InventoryReportItemDto>();
}

public class InventoryReportItemDto
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
    public decimal InventoryValue { get; set; }

    public bool IsLowStock { get; set; }

    public List<InventoryLocationDto> Locations { get; set; }
        = new List<InventoryLocationDto>();
}

public class InventoryLocationDto
{
    public int LocationId { get; set; }
    public string LocationName { get; set; } = string.Empty;
    public int Quantity { get; set; }
}