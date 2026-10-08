using SummerLandBackend.Models;
using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.ProductVariants
{
    public class CreateProductVariantDto
    {
        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid product.")]
        public int ProductId { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid size.")]
        public int? SizeId { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid colour.")]
        public int? ColourId { get; set; }

        public BarcodeType BarcodeType { get; set; }

        public string? Barcode { get; set; }

        [Range(0, double.MaxValue,
            ErrorMessage = "Price cannot be negative.")]
        public decimal Price { get; set; }

        [Range(0, int.MaxValue,
            ErrorMessage = "Low stock threshold cannot be negative.")]
        public int LowStockThreshold { get; set; } = 1;
    }
}
