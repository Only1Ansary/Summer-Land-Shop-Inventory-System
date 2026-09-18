using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Inventory
{
    public class AddInventoryDto
    {
        [Range(1, int.MaxValue)]
        public int ProductVariantId { get; set; }

        [Range(1, int.MaxValue)]
        public int LocationId { get; set; }

        [Range(1, int.MaxValue)]
        public int Quantity { get; set; }
    }
}
