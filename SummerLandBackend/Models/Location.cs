namespace SummerLandBackend.Models
{
    public class Location
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public ICollection<Inventory> Inventory { get; set; }
            = new List<Inventory>();
    }
}
