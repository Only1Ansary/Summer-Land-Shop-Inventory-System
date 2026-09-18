using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Returns
{
    public class CreateReturnDto
    {
        [Range(1, int.MaxValue)]
        public int InvoiceId { get; set; }

        [Range(1, int.MaxValue)]
        public int ProductVariantId { get; set; }

        [Range(1, int.MaxValue)]
        public int Quantity { get; set; }

        public string Reason { get; set; } = string.Empty;
    }
}
