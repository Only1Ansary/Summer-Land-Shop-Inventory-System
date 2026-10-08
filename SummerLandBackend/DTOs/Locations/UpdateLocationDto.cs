using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Locations
{
    public class UpdateLocationDto
    {
        [Required(ErrorMessage = "Location name is required.")]
        [MaxLength(100,
            ErrorMessage = "Location name cannot exceed 100 characters.")]
        public string Name { get; set; } = string.Empty;
    }
}
