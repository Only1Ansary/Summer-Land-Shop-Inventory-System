using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Products
{
    public class UpdateProductDto
    {
        [Required]
        [MaxLength(50)]
        public string ModelNumber { get; set; } = string.Empty;

        [MaxLength(50)]
        public string Barcode { get; set; } = string.Empty;

        [Range(1, int.MaxValue)]
        public int PurchasePrice { get; set; }

        [Range(1, int.MaxValue)]
        public int ProfitMargin { get; set; }

        public decimal SellingPrice => PurchasePrice + (PurchasePrice * ProfitMargin / 100);

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        [Range(1, int.MaxValue)]
        public int CategoryId { get; set; }
    }
}
