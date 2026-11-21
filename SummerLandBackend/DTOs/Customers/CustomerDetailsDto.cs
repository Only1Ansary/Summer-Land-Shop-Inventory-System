namespace SummerLandBackend.DTOs.Customers
{
    /// <summary>
    /// Everything the Customers screen needs once a customer is selected.
    /// Invoices and payments are deliberately lightweight: the full invoice
    /// is fetched separately when the user opens one.
    /// </summary>
    public class CustomerDetailsDto
    {
        public int Id { get; set; }

        public string PhoneNumber { get; set; } = string.Empty;

        public string? Name { get; set; }

        public decimal TotalPaid { get; set; }

        /// <summary>Outstanding balance stored on the customer.</summary>
        public decimal TotalDebt { get; set; }

        public int InvoiceCount { get; set; }

        public int UnpaidInvoiceCount { get; set; }

        public DateTime CreatedAt { get; set; }

        public List<CustomerInvoiceSummaryDto> Invoices { get; set; }
            = new List<CustomerInvoiceSummaryDto>();

        public List<CustomerPaymentDto> Payments { get; set; }
            = new List<CustomerPaymentDto>();
    }

    public class CustomerInvoiceSummaryDto
    {
        public int Id { get; set; }

        public DateTime CreatedAt { get; set; }

        public string LocationName { get; set; } = string.Empty;

        public decimal TotalAmount { get; set; }

        public decimal PaidAmount { get; set; }

        public decimal RemainingAmount { get; set; }
    }

    public class CustomerPaymentDto
    {
        public int Id { get; set; }

        /// <summary>Invoice this part of the payment was applied to.</summary>
        public int SaleInvoiceId { get; set; }

        public decimal Amount { get; set; }

        public int Method { get; set; }

        public DateTime PaidAt { get; set; }
    }
}
