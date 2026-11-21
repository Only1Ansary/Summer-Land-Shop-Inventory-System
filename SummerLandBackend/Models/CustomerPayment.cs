namespace SummerLandBackend.Models
{
    /// <summary>
    /// A single payment made by a customer against one sale invoice.
    /// Every payment, whether taken at checkout or later, is stored here so
    /// the invoice's paid amount and the customer's TotalPaid stay in sync.
    /// </summary>
    public class CustomerPayment
    {
        public int Id { get; set; }

        public int CustomerId { get; set; }
        public Customer Customer { get; set; } = null!;

        public int SaleInvoiceId { get; set; }
        public SaleInvoice SaleInvoice { get; set; } = null!;

        public decimal Amount { get; set; }

        public PaymentMethod Method { get; set; }

        public DateTime PaidAt { get; set; } = DateTime.UtcNow;
    }
}
