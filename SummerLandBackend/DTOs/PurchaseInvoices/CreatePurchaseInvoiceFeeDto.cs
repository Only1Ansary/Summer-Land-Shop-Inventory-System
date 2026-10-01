namespace SummerLandBackend.DTOs.PurchaseInvoices
{
    public class CreatePurchaseInvoiceFeeDto
    {
        public string Description { get; set; } = string.Empty;

        public decimal Amount { get; set; }
    }
}