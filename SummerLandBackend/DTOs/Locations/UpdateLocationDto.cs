using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Locations
{
    public class UpdateLocationDto
    {
        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;
    }
}
