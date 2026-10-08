using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Returns
{
    public class CreateReturnDto
    {
        [Range(1, int.MaxValue,
            ErrorMessage = "Enter a valid invoice ID.")]
        public int InvoiceId { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid product to return.")]
        public int ProductVariantId { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Enter a quantity of 1 or more.")]
        public int Quantity { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid location to return the stock to.")]
        public int StockLocationId { get; set; }

        public string Reason { get; set; } = string.Empty;
    }
}
