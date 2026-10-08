using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.SaleInvoices
{
    public class CreateInvoiceDto
    {
        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid location for the invoice.")]
        public int LocationId { get; set; }

        [Required(ErrorMessage = "Invoice must contain at least one item.")]
        [MinLength(1,
            ErrorMessage = "Invoice must contain at least one item.")]
        public List<CreateInvoiceItemDto> Items { get; set; }
            = new List<CreateInvoiceItemDto>();

        public decimal DiscountAmount { get; set; }

        // Invoice-level discount. Set amount OR percent, never both;
        // the percent is taken on the items total after item discounts.
        [Range(0, 100,
            ErrorMessage = "Enter an invoice discount percentage between "
                + "0 and 100.")]
        public decimal DiscountPercent { get; set; }
    }
}