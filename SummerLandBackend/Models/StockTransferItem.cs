namespace SummerLandBackend.Models
{
    public class StockTransferItem
    {
        public int Id { get; set; }

        public int StockTransferId { get; set; }
        public StockTransfer StockTransfer { get; set; } = null!;

        public int ProductVariantId { get; set; }
        public ProductVariant ProductVariant { get; set; } = null!;

        public int Quantity { get; set; }
    }
}
