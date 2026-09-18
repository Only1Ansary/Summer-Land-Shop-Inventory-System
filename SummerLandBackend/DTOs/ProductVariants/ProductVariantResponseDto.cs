using SummerLandBackend.Models;

namespace SummerLandBackend.DTOs.ProductVariants
{
    public class ProductVariantResponseDto
    {
        public int Id { get; set; }

        public int ProductId { get; set; }

        public string ModelNumber { get; set; } = string.Empty;

        public string ProductName { get; set; } = string.Empty;

        public int? SizeId { get; set; }

        public string? SizeName { get; set; }

        public int? ColourId { get; set; }

        public string? ColourName { get; set; }

        public BarcodeType BarcodeType { get; set; }

        public string Barcode { get; set; } = string.Empty;

        public decimal Price { get; set; }

        public int LowStockThreshold { get; set; }

        public int TotalQuantity { get; set; }

        public bool IsLowStock { get; set; }
    }
}
