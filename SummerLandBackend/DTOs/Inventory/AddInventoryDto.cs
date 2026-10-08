using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Inventory
{
    public class AddInventoryDto
    {
        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid product variant.")]
        public int ProductVariantId { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid location.")]
        public int LocationId { get; set; }

        [Range(1, int.MaxValue,
            ErrorMessage = "Enter a quantity of 1 or more.")]
        public int Quantity { get; set; }
    }
}
