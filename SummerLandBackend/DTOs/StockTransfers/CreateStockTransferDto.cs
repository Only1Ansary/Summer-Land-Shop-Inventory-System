namespace SummerLandBackend.DTOs.StockTransfers
{
    public class CreateStockTransferDto
    {
        public int ProductVariantId { get; set; }

        public int FromLocationId { get; set; }

        public int ToLocationId { get; set; }

        public int Quantity { get; set; }
    }
}
