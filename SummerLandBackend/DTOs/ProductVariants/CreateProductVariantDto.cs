using SummerLandBackend.Models;
using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.ProductVariants
{
    public class CreateProductVariantDto
    {
        [Range(1, int.MaxValue)]
        public int ProductId { get; set; }

        [Range(1, int.MaxValue)]
        public int? SizeId { get; set; }

        [Range(1, int.MaxValue)]
        public int? ColourId { get; set; }

        public BarcodeType BarcodeType { get; set; }

        public string? Barcode { get; set; }

        [Range(0, double.MaxValue)]
        public decimal Price { get; set; }

        [Range(0, int.MaxValue)]
        public int LowStockThreshold { get; set; } = 1;
    }
}
