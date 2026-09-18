namespace SummerLandBackend.DTOs.StockTransfers
{
    public class StockTransferResponseDto
    {
        public int Id { get; set; }

        public int ProductVariantId { get; set; }

        public string ModelNumber { get; set; } = string.Empty;

        public string ProductName { get; set; } = string.Empty;

        public string? SizeName { get; set; }

        public string? ColourName { get; set; }

        public int FromLocationId { get; set; }

        public string FromLocationName { get; set; } = string.Empty;

        public int ToLocationId { get; set; }

        public string ToLocationName { get; set; } = string.Empty;

        public int Quantity { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
