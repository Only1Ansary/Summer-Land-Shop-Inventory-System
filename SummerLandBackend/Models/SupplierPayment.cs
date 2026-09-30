namespace SummerLandBackend.Models;

public class SupplierPayment
{
    public int Id { get; set; }

    public int SupplierId { get; set; }
    public Supplier Supplier { get; set; } = null!;

    /// <summary>Invoice the money was applied to, when known.</summary>
    public int? PurchaseInvoiceId { get; set; }
    public PurchaseInvoice? PurchaseInvoice { get; set; }

    public decimal Amount { get; set; }

    public DateTime PaidAt { get; set; } = DateTime.UtcNow;
}