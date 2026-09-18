using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.ProductVariants
{
    public class UpdateProductVariantDto
    {
        [Range(1, int.MaxValue)]
        public int? SizeId { get; set; }

        [Range(1, int.MaxValue)]
        public int? ColourId { get; set; }

        public string? Barcode { get; set; }

        [Range(0, double.MaxValue)]
        public decimal Price { get; set; }

        [Range(0, int.MaxValue)]
        public int LowStockThreshold { get; set; }
    }
}
