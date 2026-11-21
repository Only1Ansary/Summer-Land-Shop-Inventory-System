namespace SummerLandBackend.DTOs.Customers
{
    public class CustomerResponseDto
    {
        public int Id { get; set; }

        public string PhoneNumber { get; set; } = string.Empty;

        public string? Name { get; set; }

        /// <summary>Sum of all payments recorded for this customer.</summary>
        public decimal TotalPaid { get; set; }

        /// <summary>Outstanding balance stored on the customer.</summary>
        public decimal TotalDebt { get; set; }

        public int InvoiceCount { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
