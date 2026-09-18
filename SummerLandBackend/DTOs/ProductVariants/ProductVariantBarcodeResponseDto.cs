namespace SummerLandBackend.DTOs.ProductVariants
{
    public class ProductVariantBarcodeResponseDto
    {
        public int Id { get; set; }

        public string ModelNumber { get; set; } = string.Empty;

        public string ProductName { get; set; } = string.Empty;

        public int? SizeId { get; set; }

        public string? SizeName { get; set; }

        public int? ColourId { get; set; }

        public string? ColourName { get; set; }

        public string Barcode { get; set; } = string.Empty;

        public decimal Price { get; set; }

        public int TotalQuantity { get; set; }

        public int LocationQuantity { get; set; }
    }
}
