namespace SummerLandBackend.DTOs.PurchaseInvoices
{
    public class CreatePurchaseInvoiceDto
    {
        public string SupplierName { get; set; } = string.Empty;

        public DateTime Date { get; set; }

        public decimal TotalPaid { get; set; }

        public decimal Discount { get; set; }

        public List<CreatePurchaseInvoiceItemDto> Items { get; set; }
            = new();
    }
}
