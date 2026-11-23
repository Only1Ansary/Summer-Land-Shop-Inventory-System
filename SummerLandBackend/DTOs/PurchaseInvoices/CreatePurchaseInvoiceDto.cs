using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.PurchaseInvoices
{
    public class CreatePurchaseInvoiceDto
    {
        public string SupplierName { get; set; } = string.Empty;

        public DateTime Date { get; set; }

        public decimal TotalPaid { get; set; }

        [Range(0, 3, ErrorMessage = "Choose a valid payment method.")]
        public int PaymentMethod { get; set; }

        public decimal Discount { get; set; }

        public List<CreatePurchaseInvoiceItemDto> Items { get; set; }
            = new();

        /// <summary>
        /// Extra costs such as shipping or customs. Added to TotalCost but
        /// excluded from the supplier debt.
        /// </summary>
        public List<CreatePurchaseInvoiceFeeDto> Fees { get; set; } = new();
    }
}
