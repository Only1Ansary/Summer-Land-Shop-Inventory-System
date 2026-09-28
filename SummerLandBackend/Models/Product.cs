namespace SummerLandBackend.Models;

public class Product
{
    public int Id { get; set; }

    public string ModelNumber { get; set; } = string.Empty;

    public string Barcode { get; set; } = string.Empty;

    public decimal PurchasePrice { get; set; }

    public decimal ProfitMargin { get; set; }

    public decimal SellingPrice { get; private set; }

    public string Name { get; set; } = string.Empty;

    public int CategoryId { get; set; }

    public Category Category { get; set; } = null!;

    public ICollection<ProductVariant> Variants { get; set; }
        = new List<ProductVariant>();
}