namespace SummerLandBackend.Models
{
    /// <summary>
    /// An extra cost added to a purchase invoice (shipping, customs, handling...)
    /// that is not attributable to a single purchased item.
    /// </summary>
    public class PurchaseInvoiceFee
    {
        public int Id { get; set; }

        public int PurchaseInvoiceId { get; set; }

        public PurchaseInvoice PurchaseInvoice { get; set; } = null!;

        public string Description { get; set; } = string.Empty;

        public decimal Amount { get; set; }
    }
}