namespace SummerLandBackend.Models
{
    public class Inventory
    {
        public int Id { get; set; }

        public int ProductVariantId { get; set; }
        public ProductVariant ProductVariant { get; set; } = null!;

        public int LocationId { get; set; }
        public Location Location { get; set; } = null!;

        public int Quantity { get; set; }

        public int LowStockThreshold { get; set; } = 5;
    }
}
