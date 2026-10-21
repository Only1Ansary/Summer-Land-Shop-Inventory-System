namespace SummerLandBackend.DTOs.ProductVariants
{
    /// <summary>
    /// Splits the stock held by the auto-created "default" variant (no size, no
    /// colour) across a set of new size/colour variants.
    /// </summary>
    public class SplitProductVariantDto
    {
        public int SourceVariantId { get; set; }

        public List<SplitProductVariantLineDto> Splits { get; set; } = new();
    }

    public class SplitProductVariantLineDto
    {
        public int? SizeId { get; set; }

        public int? ColourId { get; set; }

        public int Quantity { get; set; }

        /// <summary>Optional per-variant low stock threshold.</summary>
        public int? LowStockThreshold { get; set; }
    }
}
