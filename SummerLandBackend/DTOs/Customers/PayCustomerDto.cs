using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Customers
{
    /// <summary>
    /// A payment made by a customer without choosing invoices. The backend
    /// applies it to the oldest unpaid invoices first.
    /// </summary>
    public class PayCustomerDto
    {
        [Range(0.01, double.MaxValue,
            ErrorMessage = "Enter a payment amount greater than zero.")]
        public decimal Amount { get; set; }

        [Range(0, 3,
            ErrorMessage = "Choose a valid payment method.")]
        public int Method { get; set; }
    }
}
