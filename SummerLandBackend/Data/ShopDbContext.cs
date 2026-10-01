using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Models;

namespace SummerLandBackend.Data;

public class ShopDbContext : DbContext
{
    public ShopDbContext(DbContextOptions<ShopDbContext> options)
        : base(options)
    {
    }

    public DbSet<Return> Returns { get; set; }
    public DbSet<StockTransfer> StockTransfers { get; set; }
    public DbSet<Category> Categories { get; set; }
    public DbSet<Product> Products { get; set; }
    public DbSet<ProductVariant> ProductVariants { get; set; }
    public DbSet<Supplier> Suppliers { get; set; }
    public DbSet<SupplierPayment> SupplierPayments { get; set; }
    public DbSet<PurchaseInvoice> PurchaseInvoices { get; set; }
    public DbSet<PurchaseInvoiceItem> PurchaseInvoiceItems { get; set; }
    public DbSet<PurchaseInvoiceFee> PurchaseInvoiceFees { get; set; }
    public DbSet<PurchaseReturn> PurchaseReturns { get; set; }
    public DbSet<Sizes> Sizes { get; set; }
    public DbSet<Colour> Colours { get; set; }
    public DbSet<Location> Locations { get; set; }
    public DbSet<Inventory> Inventory { get; set; }
    public DbSet<SaleInvoice> Invoices { get; set; }
    public DbSet<SaleInvoiceItem> InvoiceItems { get; set; }
    public DbSet<StockMovement> StockMovements { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Product>()
            .HasIndex(p => p.ModelNumber)
            .IsUnique();

        modelBuilder.Entity<ProductVariant>()
            .HasIndex(v => v.Barcode)
            .IsUnique();

        modelBuilder.Entity<ProductVariant>()
            .HasIndex(v => new
            {
                v.ProductId,
                v.SizeId,
                v.ColourId
            })
            .IsUnique();

        modelBuilder.Entity<Product>()
            .HasOne(p => p.Category)
            .WithMany(c => c.Products)
            .HasForeignKey(p => p.CategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Product>()
            .Property(p => p.SellingPrice)
            .HasColumnType("decimal(18,2)")
            .HasComputedColumnSql("([PurchasePrice] + ([PurchasePrice] * [ProfitMargin] / 100))",
            stored: true);

        modelBuilder.Entity<ProductVariant>()
            .HasOne(v => v.Product)
            .WithMany(p => p.Variants)
            .HasForeignKey(v => v.ProductId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<ProductVariant>()
            .HasOne(v => v.Size)
            .WithMany(s => s.ProductVariants)
            .HasForeignKey(v => v.SizeId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<ProductVariant>()
            .HasOne(v => v.Colour)
            .WithMany(c => c.ProductVariants)
            .HasForeignKey(v => v.ColourId)
            .OnDelete(DeleteBehavior.Restrict);

        // ProductVariant -> Inventory
        modelBuilder.Entity<Inventory>()
            .HasOne(i => i.ProductVariant)
            .WithMany(v => v.Inventory)
            .HasForeignKey(i => i.ProductVariantId)
            .OnDelete(DeleteBehavior.Cascade);

        // Location -> Inventory
        modelBuilder.Entity<Inventory>()
            .HasOne(i => i.Location)
            .WithMany(l => l.Inventory)
            .HasForeignKey(i => i.LocationId)
            .OnDelete(DeleteBehavior.Restrict);

        // One variant can have only one inventory record per location
        modelBuilder.Entity<Inventory>()
            .HasIndex(i => new
            {
                i.ProductVariantId,
                i.LocationId
            })
            .IsUnique();

        modelBuilder.Entity<SaleInvoice>()
            .HasOne(i => i.Location)
            .WithMany()
            .HasForeignKey(i => i.LocationId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<SaleInvoiceItem>()
            .HasOne(i => i.Invoice)
            .WithMany(i => i.Items)
            .HasForeignKey(i => i.InvoiceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<SaleInvoiceItem>()
            .HasOne(i => i.ProductVariant)
            .WithMany(v => v.InvoiceItems)
            .HasForeignKey(i => i.ProductVariantId)
            .OnDelete(DeleteBehavior.Cascade);

        // StockMovement -> ProductVariant
        modelBuilder.Entity<StockMovement>()
            .HasOne(s => s.ProductVariant)
            .WithMany()
            .HasForeignKey(s => s.ProductVariantId)
            .OnDelete(DeleteBehavior.Cascade);

        // StockMovement -> Location
        modelBuilder.Entity<StockMovement>()
            .HasOne(s => s.Location)
            .WithMany()
            .HasForeignKey(s => s.LocationId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<StockTransfer>()
            .HasOne(s => s.ProductVariant)
            .WithMany()
            .HasForeignKey(s => s.ProductVariantId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<StockTransfer>()
            .HasOne(s => s.FromLocation)
            .WithMany()
            .HasForeignKey(s => s.FromLocationId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<StockTransfer>()
            .HasOne(s => s.ToLocation)
            .WithMany()
            .HasForeignKey(s => s.ToLocationId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Return>()
            .HasOne(r => r.Invoice)
            .WithMany()
            .HasForeignKey(r => r.InvoiceId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Return>()
            .HasOne(r => r.ProductVariant)
            .WithMany()
            .HasForeignKey(r => r.ProductVariantId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Return>()
            .HasOne(r => r.Location)
            .WithMany()
            .HasForeignKey(r => r.LocationId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Supplier>()
    .HasIndex(s => s.SupplierName)
    .IsUnique();

        modelBuilder.Entity<PurchaseInvoice>()
            .HasOne(i => i.Supplier)
            .WithMany(s => s.PurchaseInvoices)
            .HasForeignKey(i => i.SupplierId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<PurchaseInvoiceItem>()
            .HasOne(i => i.PurchaseInvoice)
            .WithMany(i => i.Items)
            .HasForeignKey(i => i.PurchaseInvoiceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<PurchaseInvoiceItem>()
            .HasOne(i => i.Product)
            .WithMany()
            .HasForeignKey(i => i.ProductId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Supplier>()
            .Property(s => s.Debt)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<PurchaseInvoice>()
            .Property(i => i.TotalCost)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<PurchaseInvoice>()
            .Property(i => i.TotalPaid)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<PurchaseInvoice>()
            .Property(i => i.Debt)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<PurchaseInvoiceItem>()
            .Property(i => i.UnitPurchasePrice)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<PurchaseInvoiceItem>()
            .Property(i => i.TotalPrice)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<PurchaseInvoiceFee>()
            .Property(f => f.Amount)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<PurchaseInvoiceFee>()
            .HasOne(f => f.PurchaseInvoice)
            .WithMany(i => i.Fees)
            .HasForeignKey(f => f.PurchaseInvoiceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<SupplierPayment>()
            .Property(p => p.Amount)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<SupplierPayment>()
            .HasOne(p => p.Supplier)
            .WithMany()
            .HasForeignKey(p => p.SupplierId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<SupplierPayment>()
            .HasOne(p => p.PurchaseInvoice)
            .WithMany()
            .HasForeignKey(p => p.PurchaseInvoiceId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<PurchaseReturn>()
            .HasOne(r => r.PurchaseInvoice)
            .WithMany(i => i.Returns)
            .HasForeignKey(r => r.PurchaseInvoiceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<PurchaseReturn>()
            .HasOne(r => r.Product)
            .WithMany()
            .HasForeignKey(r => r.ProductId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<PurchaseReturn>()
            .Property(r => r.UnitPurchasePrice)
            .HasColumnType("decimal(18,2)");
    }
}