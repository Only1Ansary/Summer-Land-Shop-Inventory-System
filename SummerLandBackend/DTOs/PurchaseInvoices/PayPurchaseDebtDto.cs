using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.PurchaseInvoices
{
    public class PayPurchaseDebtDto
    {
        public decimal Amount { get; set; }

        [Range(0, 3, ErrorMessage = "Choose a valid payment method.")]
        public int Method { get; set; }
    }
}
