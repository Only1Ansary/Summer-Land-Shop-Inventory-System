namespace SummerLandBackend.Models
{
    public class StockTransfer
    {
        public int Id { get; set; }

        public int ProductVariantId { get; set; }

        public ProductVariant ProductVariant { get; set; } = null!;

        public int FromLocationId { get; set; }

        public Location FromLocation { get; set; } = null!;

        public int ToLocationId { get; set; }

        public Location ToLocation { get; set; } = null!;

        public int Quantity { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
