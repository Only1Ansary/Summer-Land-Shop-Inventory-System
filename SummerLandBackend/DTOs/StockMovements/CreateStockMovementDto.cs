namespace SummerLandBackend.DTOs.StockMovements
{
    public class CreateStockMovementDto
    {
        public int ProductVariantId { get; set; }

        public int LocationId { get; set; }

        public int QuantityChange { get; set; }

        public string Reason { get; set; } = string.Empty;
    }
}
