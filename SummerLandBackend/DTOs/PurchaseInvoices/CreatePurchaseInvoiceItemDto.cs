namespace SummerLandBackend.DTOs.PurchaseInvoices
{
    public class CreatePurchaseInvoiceItemDto
    {
        public string Name { get; set; } = string.Empty;

        public string ModelNumber { get; set; } = string.Empty;

        public string Barcode { get; set; } = string.Empty;

        public decimal PurchasePrice { get; set; }

        public int Quantity { get; set; }

        public int CategoryId { get; set; }

        public decimal ProfitMargin { get; set; }
    }
}
