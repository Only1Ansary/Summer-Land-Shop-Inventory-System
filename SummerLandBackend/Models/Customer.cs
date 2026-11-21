namespace SummerLandBackend.Models
{
    public class Customer
    {
        public int Id { get; set; }

        /// <summary>Normalised phone number. Unique across customers.</summary>
        public string PhoneNumber { get; set; } = string.Empty;

        /// <summary>Optional display name.</summary>
        public string? Name { get; set; }

        /// <summary>
        /// Running total of every payment recorded for this customer.
        /// Updated in the same transaction as each CustomerPayment.
        /// </summary>
        public decimal TotalPaid { get; set; }

        /// <summary>
        /// Outstanding balance across all of this customer's invoices.
        /// Stored on the customer (not just computed on read) and kept in sync
        /// whenever an invoice or payment is written.
        /// </summary>
        public decimal TotalDebt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<SaleInvoice> Invoices { get; set; }
            = new List<SaleInvoice>();

        public ICollection<CustomerPayment> Payments { get; set; }
            = new List<CustomerPayment>();
    }
}
