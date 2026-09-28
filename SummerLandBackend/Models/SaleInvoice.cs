namespace SummerLandBackend.Models
{
    public class SaleInvoice
    {
        public int Id { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public int LocationId { get; set; }

        public Location Location { get; set; } = null!;

        public decimal TotalAmount { get; set; }

        public ICollection<SaleInvoiceItem> Items { get; set; }
            = new List<SaleInvoiceItem>();
    }
}
