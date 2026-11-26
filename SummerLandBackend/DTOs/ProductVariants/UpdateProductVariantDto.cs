using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.ProductVariants
{
    public class UpdateProductVariantDto
    {
        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid size.")]
        public int? SizeId { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid colour.")]
        public int? ColourId { get; set; }

        public string? Barcode { get; set; }

        // Null keeps the variant's current purchase price.
        [Range(0, double.MaxValue,
            ErrorMessage = "Purchase price cannot be negative.")]
        public decimal? PurchasePrice { get; set; }

        [Range(0, double.MaxValue,
            ErrorMessage = "Selling price cannot be negative.")]
        public decimal SellingPrice { get; set; }

        [Range(0, int.MaxValue,
            ErrorMessage = "Low stock threshold cannot be negative.")]
        public int LowStockThreshold { get; set; }
    }
}
