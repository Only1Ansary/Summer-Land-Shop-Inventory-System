using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.SaleInvoices
{
    public class CreateInvoiceItemDto
    {
        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid product for every line.")]
        public int ProductVariantId { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Enter a quantity of 1 or more for every line.")]
        public int Quantity { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid location for every line.")]
        public int StockLocationId { get; set; }

        // Per-unit discount. Set amount OR percent, never both.
        [Range(0, double.MaxValue,
            ErrorMessage = "An item discount cannot be negative.")]
        public decimal DiscountAmount { get; set; }

        [Range(0, 100,
            ErrorMessage = "Enter an item discount percentage between "
                + "0 and 100.")]
        public decimal DiscountPercent { get; set; }
    }
}
