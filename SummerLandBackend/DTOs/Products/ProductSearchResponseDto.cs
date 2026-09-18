namespace SummerLandBackend.DTOs.Products;

public class ProductSearchResponseDto
{
    public int Id { get; set; }

    public string ModelNumber { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public int CategoryId { get; set; }

    public string CategoryName { get; set; } = string.Empty;

    public List<ProductSearchVariantDto> Variants { get; set; }
        = new List<ProductSearchVariantDto>();
}

public class ProductSearchVariantDto
{
    public int Id { get; set; }

    public int? SizeId { get; set; }

    public string? SizeName { get; set; }

    public int? ColourId { get; set; }

    public string? ColourName { get; set; }

    public string Barcode { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public int LowStockThreshold { get; set; }

    public int TotalQuantity { get; set; }

    public bool IsLowStock { get; set; }

    public List<VariantLocationStockDto> Locations { get; set; }
        = new List<VariantLocationStockDto>();
}

public class VariantLocationStockDto
{
    public int LocationId { get; set; }

    public string LocationName { get; set; } = string.Empty;

    public int Quantity { get; set; }
}