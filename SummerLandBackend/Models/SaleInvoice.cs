namespace SummerLandBackend.Models
{
    public class SaleInvoice
    {
        public int Id { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public int LocationId { get; set; }

        public Location Location { get; set; } = null!;

        // Null for invoices recorded before employees were tracked, or
        // after the employee was deleted. The name is kept separately so
        // the invoice still shows who sold it.
        public int? EmployeeId { get; set; }

        public Employee? Employee { get; set; }

        public string? EmployeeName { get; set; }

        public decimal TotalAmount { get; set; }

        public decimal DiscountAmount { get; set; }

        // Percent the invoice discount was entered as; null when it was
        // entered as a fixed amount.
        public decimal? DiscountPercent { get; set; }

        public ICollection<SaleInvoiceItem> Items { get; set; }
            = new List<SaleInvoiceItem>();
    }
}
