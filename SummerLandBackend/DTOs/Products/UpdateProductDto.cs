using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Products
{
    public class UpdateProductDto
    {
        [Required]
        [MaxLength(50)]
        public string ModelNumber { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        public string Name { get; set; } = string.Empty;

        [Range(1, int.MaxValue)]
        public int CategoryId { get; set; }
    }
}
