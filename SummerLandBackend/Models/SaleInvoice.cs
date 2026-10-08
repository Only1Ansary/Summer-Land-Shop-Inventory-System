namespace SummerLandBackend.Models
{
    public class SaleInvoice
    {
        public int Id { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public int LocationId { get; set; }

        public Location Location { get; set; } = null!;

        public decimal TotalAmount { get; set; }

        public decimal DiscountAmount { get; set; }

        // Percent the invoice discount was entered as; null when it was
        // entered as a fixed amount.
        public decimal? DiscountPercent { get; set; }

        public ICollection<SaleInvoiceItem> Items { get; set; }
            = new List<SaleInvoiceItem>();
    }
}
