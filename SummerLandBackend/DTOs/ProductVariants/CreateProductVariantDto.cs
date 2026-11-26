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

        // Left null by existing clients; the controller copies the parent
        // product's purchase price in that case.
        [Range(0, double.MaxValue,
            ErrorMessage = "Purchase price cannot be negative.")]
        public decimal? PurchasePrice { get; set; }

        [Range(0, double.MaxValue,
            ErrorMessage = "Selling price cannot be negative.")]
        public decimal SellingPrice { get; set; }

        [Range(0, int.MaxValue,
            ErrorMessage = "Low stock threshold cannot be negative.")]
        public int LowStockThreshold { get; set; } = 2;
    }
}
