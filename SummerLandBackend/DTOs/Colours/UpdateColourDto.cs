using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Colours
{
    public class UpdateColourDto
    {
        [Required(ErrorMessage = "Colour name is required.")]
        [MaxLength(100,
            ErrorMessage = "Colour name cannot exceed 100 characters.")]
        public string Name { get; set; } = string.Empty;
    }
}
