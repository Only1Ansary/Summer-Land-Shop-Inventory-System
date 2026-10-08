using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Products
{
    public class UpdateProductDto
    {
        [Required(ErrorMessage = "Model number is required.")]
        [MaxLength(50,
            ErrorMessage = "Model number cannot exceed 50 characters.")]
        public string ModelNumber { get; set; } = string.Empty;

        [MaxLength(50,
            ErrorMessage = "Barcode cannot exceed 50 characters.")]
        public string Barcode { get; set; } = string.Empty;

        [Range(1, int.MaxValue,
            ErrorMessage = "Enter a purchase price greater than zero.")]
        public int PurchasePrice { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Enter a profit margin greater than zero.")]
        public int ProfitMargin { get; set; }

        public decimal SellingPrice => PurchasePrice + (PurchasePrice * ProfitMargin / 100);

        [Required(ErrorMessage = "Product name is required.")]
        [MaxLength(200,
            ErrorMessage = "Product name cannot exceed 200 characters.")]
        public string Name { get; set; } = string.Empty;

        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a category.")]
        public int CategoryId { get; set; }
    }
}
