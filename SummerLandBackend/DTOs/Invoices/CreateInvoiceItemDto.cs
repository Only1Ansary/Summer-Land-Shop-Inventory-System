using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Invoices
{
    public class CreateInvoiceItemDto
    {
        [Range(1, int.MaxValue)]
        public int ProductVariantId { get; set; }

        [Range(1, int.MaxValue)]
        public int Quantity { get; set; }
    }
}
