using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.SaleInvoices
{
    public class CreateInvoiceDto
    {
        [Range(1, int.MaxValue)]
        public int LocationId { get; set; }

        [Required]
        [MinLength(1)]
        public List<CreateInvoiceItemDto> Items { get; set; }
            = new List<CreateInvoiceItemDto>();

        public decimal DiscountAmount { get; set; }
    }
}