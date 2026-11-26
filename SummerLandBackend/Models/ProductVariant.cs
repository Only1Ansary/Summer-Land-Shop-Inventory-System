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

    /// <summary>Cost copied from the parent product's purchase price.</summary>
    public decimal PurchasePrice { get; set; }

    /// <summary>Selling price used by sales, reports and inventory values.</summary>
    public decimal SellingPrice { get; set; }

    public int LowStockThreshold { get; set; } = 2;

    public ICollection<Inventory> Inventory { get; set; }
        = new List<Inventory>();

    public ICollection<SaleInvoiceItem> InvoiceItems { get; set; }
        = new List<SaleInvoiceItem>();
}
