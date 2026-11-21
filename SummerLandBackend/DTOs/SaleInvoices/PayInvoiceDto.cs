using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.SaleInvoices
{
    public class PayInvoiceDto
    {
        [Range(0.01, double.MaxValue,
            ErrorMessage = "Enter a payment amount greater than zero.")]
        public decimal Amount { get; set; }

        [Range(0, 3,
            ErrorMessage = "Choose a valid payment method.")]
        public int Method { get; set; }
    }
}
