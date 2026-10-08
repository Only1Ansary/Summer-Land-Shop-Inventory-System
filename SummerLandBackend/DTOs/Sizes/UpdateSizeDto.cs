using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Sizes
{
    public class UpdateSizeDto
    {
        [Required(ErrorMessage = "Size name is required.")]
        [MaxLength(50,
            ErrorMessage = "Size name cannot exceed 50 characters.")]
        public string Name { get; set; } = string.Empty;
    }
}
