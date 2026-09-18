namespace SummerLandBackend.Models;

public class ProductVariant
{
    public int Id { get; set; }

    public int ProductId { get; set; }
    public Product Product { get; set; } = null!;

    public int? SizeId { get; set; }
    public Sizes? Size { get; set; }

    public int? ColourId { get; set; }
    public Colour? Colour { get; set; }

    public BarcodeType BarcodeType { get; set; }

    public string Barcode { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public int LowStockThreshold { get; set; } = 5;

    public ICollection<Inventory> Inventory { get; set; }
        = new List<Inventory>();

    public ICollection<InvoiceItem> InvoiceItems { get; set; }
        = new List<InvoiceItem>();
}
