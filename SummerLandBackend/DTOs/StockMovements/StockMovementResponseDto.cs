namespace SummerLandBackend.DTOs.StockMovements
{
    public class StockMovementResponseDto
    {
        public int Id { get; set; }

        public int ProductVariantId { get; set; }

        public string ModelNumber { get; set; } = string.Empty;

        public string ProductName { get; set; } = string.Empty;

        public int LocationId { get; set; }

        public string LocationName { get; set; } = string.Empty;

        public int QuantityChange { get; set; }

        public string Reason { get; set; } = string.Empty;

        public DateTime CreatedAt { get; set; }
    }
}
