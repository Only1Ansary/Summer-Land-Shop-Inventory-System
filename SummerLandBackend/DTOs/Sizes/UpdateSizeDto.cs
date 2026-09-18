using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Sizes
{
    public class UpdateSizeDto
    {
        [Required]
        [MaxLength(50)]
        public string Name { get; set; } = string.Empty;
    }
}
