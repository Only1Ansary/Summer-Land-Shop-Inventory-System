using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Colours
{
    public class UpdateColourDto
    {
        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;
    }
}
