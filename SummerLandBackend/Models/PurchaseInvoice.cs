namespace SummerLandBackend.Models
{
    public class PurchaseInvoice
    {
        public int Id { get; set; }

        public int SupplierId { get; set; }
        public Supplier Supplier { get; set; } = null!;

        public DateTime Date { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public decimal TotalCost { get; set; }

        public decimal TotalPaid { get; set; }

        public decimal Debt { get; set; }

        public ICollection<PurchaseInvoiceItem> Items { get; set; }
            = new List<PurchaseInvoiceItem>();

        public ICollection<PurchaseReturn> Returns { get; set; }
            = new List<PurchaseReturn>();
    }
}
