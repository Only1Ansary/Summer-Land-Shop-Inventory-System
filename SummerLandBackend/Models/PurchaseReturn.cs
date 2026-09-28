namespace SummerLandBackend.Models
{
    public class PurchaseReturn
    {
        public int Id { get; set; }

        public int PurchaseInvoiceId { get; set; }
        public PurchaseInvoice PurchaseInvoice { get; set; } = null!;

        public int ProductId { get; set; }
        public Product Product { get; set; } = null!;

        // Snapshot of the purchase price at the time of the return.
        public decimal UnitPurchasePrice { get; set; }

        public int Quantity { get; set; }

        public string? Reason { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}