namespace SummerLandBackend.DTOs.Products
{
    public class ProductResponseDto
    {
        public int Id { get; set; }

        public string ModelNumber { get; set; } = string.Empty;

        public string Barcode { get; set; } = string.Empty;

        public decimal PurchasePrice { get; set; }

        public decimal ProfitMargin { get; set; }

        public decimal SellingPrice { get; set; }

        public string Name { get; set; } = string.Empty;

        public int CategoryId { get; set; }

        public string CategoryName { get; set; } = string.Empty;
    }
}
