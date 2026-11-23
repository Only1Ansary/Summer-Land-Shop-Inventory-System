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

    /// <summary>How this payment to the supplier was handed over.</summary>
    public PaymentMethod Method { get; set; } = PaymentMethod.Cash;

    public DateTime PaidAt { get; set; } = DateTime.UtcNow;
}