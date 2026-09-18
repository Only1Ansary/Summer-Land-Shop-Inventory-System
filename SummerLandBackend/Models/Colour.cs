namespace SummerLandBackend.Models
{
    public class Colour
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public ICollection<ProductVariant> ProductVariants { get; set; }
            = new List<ProductVariant>();
    }
}
