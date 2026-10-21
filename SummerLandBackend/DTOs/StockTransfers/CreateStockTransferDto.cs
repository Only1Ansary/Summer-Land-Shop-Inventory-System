using System.Collections.Generic;

namespace SummerLandBackend.DTOs.StockTransfers
{
    public class CreateStockTransferDto
    {
        public int FromLocationId { get; set; }

        public int ToLocationId { get; set; }

        public List<CreateStockTransferItemDto> Items { get; set; } = new();
    }

    public class CreateStockTransferItemDto
    {
        public int ProductVariantId { get; set; }

        public int Quantity { get; set; }
    }
}
