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
    public DbSet<Sizes> Sizes { get; set; }
    public DbSet<Colour> Colours { get; set; }
    public DbSet<Location> Locations { get; set; }
    public DbSet<Inventory> Inventory { get; set; }
    public DbSet<Invoice> Invoices { get; set; }
    public DbSet<InvoiceItem> InvoiceItems { get; set; }
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

        modelBuilder.Entity<Invoice>()
            .HasOne(i => i.Location)
            .WithMany()
            .HasForeignKey(i => i.LocationId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<InvoiceItem>()
            .HasOne(i => i.Invoice)
            .WithMany(i => i.Items)
            .HasForeignKey(i => i.InvoiceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<InvoiceItem>()
            .HasOne(i => i.ProductVariant)
            .WithMany(v => v.InvoiceItems)
            .HasForeignKey(i => i.ProductVariantId)
            .OnDelete(DeleteBehavior.Restrict);

        // StockMovement -> ProductVariant
        modelBuilder.Entity<StockMovement>()
            .HasOne(s => s.ProductVariant)
            .WithMany()
            .HasForeignKey(s => s.ProductVariantId)
            .OnDelete(DeleteBehavior.Restrict);

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
            .OnDelete(DeleteBehavior.Restrict);

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
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Return>()
            .HasOne(r => r.Location)
            .WithMany()
            .HasForeignKey(r => r.LocationId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}