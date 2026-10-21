namespace SummerLandBackend.Models
{
    public class StockTransfer
    {
        public int Id { get; set; }

        public int FromLocationId { get; set; }

        public Location FromLocation { get; set; } = null!;

        public int ToLocationId { get; set; }

        public Location ToLocation { get; set; } = null!;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<StockTransferItem> Items { get; set; }
            = new List<StockTransferItem>();
    }
}
