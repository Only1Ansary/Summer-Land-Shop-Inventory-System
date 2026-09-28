using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.PurchaseInvoices;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PurchaseInvoicesController : ControllerBase
{
    private const int DefaultLocationId = 1;
    private const int InternalBarcodeType = 1;

    private readonly ShopDbContext _context;

    public PurchaseInvoicesController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpPost]
    public async Task<IActionResult> CreatePurchaseInvoice(
        CreatePurchaseInvoiceDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.SupplierName))
            return BadRequest("Supplier name is required.");

        if (dto.Items == null || dto.Items.Count == 0)
            return BadRequest("Purchase invoice must contain at least one item.");

        if (dto.TotalPaid < 0)
            return BadRequest("TotalPaid cannot be negative.");

        if (dto.Items.Any(i =>
            string.IsNullOrWhiteSpace(i.Name) ||
            string.IsNullOrWhiteSpace(i.ModelNumber) ||
            string.IsNullOrWhiteSpace(i.Barcode)))
        {
            return BadRequest(
                "Every item must have a name, model number, and barcode.");
        }

        if (dto.Items.Any(i =>
            i.Quantity <= 0 ||
            i.PurchasePrice < 0 ||
            i.ProfitMargin < 0 ||
            i.CategoryId <= 0))
        {
            return BadRequest(
                "Each item must have a valid category, positive quantity, " +
                "and non-negative prices and profit margin.");
        }

        var duplicateModelNumbers = dto.Items
            .GroupBy(i => i.ModelNumber.Trim(),
                StringComparer.OrdinalIgnoreCase)
            .Any(g => g.Count() > 1);

        if (duplicateModelNumbers)
            return BadRequest("A model number cannot appear more than once.");

        var duplicateBarcodes = dto.Items
            .GroupBy(i => i.Barcode.Trim(),
                StringComparer.OrdinalIgnoreCase)
            .Any(g => g.Count() > 1);

        if (duplicateBarcodes)
            return BadRequest("A product barcode cannot appear more than once.");

        var locationExists = await _context.Locations
            .AnyAsync(l => l.Id == DefaultLocationId);

        if (!locationExists)
            return BadRequest("Location with ID 1 does not exist.");

        var categoryIds = dto.Items
            .Select(i => i.CategoryId)
            .Distinct()
            .ToList();

        var existingCategoryIds = await _context.Categories
            .Where(c => categoryIds.Contains(c.Id))
            .Select(c => c.Id)
            .ToListAsync();

        if (categoryIds.Except(existingCategoryIds).Any())
            return BadRequest("One or more categories do not exist.");

        var itemsTotal = dto.Items.Sum(
            i => i.PurchasePrice * i.Quantity);

        if (dto.Discount < 0)
            return BadRequest("Discount cannot be negative.");

        if (dto.Discount > itemsTotal)
            return BadRequest("Discount cannot exceed the total cost.");

        var totalCost = itemsTotal - dto.Discount;

        if (dto.TotalPaid > totalCost)
            return BadRequest("TotalPaid cannot exceed TotalCost.");

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var supplierName = dto.SupplierName.Trim();

            var supplier = await _context.Suppliers
                .FirstOrDefaultAsync(s =>
                    s.SupplierName.ToLower() == supplierName.ToLower());

            if (supplier == null)
            {
                supplier = new Supplier
                {
                    SupplierName = supplierName,
                    Debt = 0
                };

                _context.Suppliers.Add(supplier);
                await _context.SaveChangesAsync();
            }

            var invoiceDebt = totalCost - dto.TotalPaid;

            var invoice = new PurchaseInvoice
            {
                SupplierId = supplier.Id,
                Date = dto.Date,
                CreatedAt = DateTime.UtcNow,
                TotalCost = totalCost,
                TotalPaid = dto.TotalPaid,
                Debt = invoiceDebt
            };

            foreach (var itemDto in dto.Items)
            {
                var modelNumber = itemDto.ModelNumber.Trim();
                var productBarcode = itemDto.Barcode.Trim();

                var productByModel = await _context.Products
                    .FirstOrDefaultAsync(p =>
                        p.ModelNumber == modelNumber);

                var productByBarcode = await _context.Products
                    .FirstOrDefaultAsync(p =>
                        p.Barcode == productBarcode);

                if (productByModel != null &&
                    productByBarcode != null &&
                    productByModel.Id != productByBarcode.Id)
                {
                    return BadRequest(
                        "The model number and barcode belong to different products.");
                }

                var product = productByModel ?? productByBarcode;

                if (product == null)
                {
                    product = new Product
                    {
                        Name = itemDto.Name.Trim(),
                        ModelNumber = modelNumber,
                        Barcode = productBarcode,
                        CategoryId = itemDto.CategoryId,
                        PurchasePrice = itemDto.PurchasePrice,
                        ProfitMargin = itemDto.ProfitMargin
                    };

                    _context.Products.Add(product);
                    await _context.SaveChangesAsync();
                }
                else
                {
                    // Keep the existing product; update its latest pricing.
                    product.PurchasePrice = itemDto.PurchasePrice;
                    product.ProfitMargin = itemDto.ProfitMargin;

                    await _context.SaveChangesAsync();
                }

                // Reload to obtain the database-computed SellingPrice.
                await _context.Entry(product).ReloadAsync();

                var variant = await _context.ProductVariants
                    .FirstOrDefaultAsync(v =>
                        v.ProductId == product.Id &&
                        v.SizeId == null &&
                        v.ColourId == null);

                if (variant == null)
                {
                    var variantBarcode =
                        await GenerateVariantBarcodeAsync(product.Barcode);

                    variant = new ProductVariant
                    {
                        ProductId = product.Id,
                        SizeId = null,
                        ColourId = null,
                        BarcodeType = (BarcodeType)InternalBarcodeType,
                        Barcode = variantBarcode,
                        Price = product.SellingPrice,
                        LowStockThreshold = 5
                    };

                    _context.ProductVariants.Add(variant);
                    await _context.SaveChangesAsync();
                }
                else
                {
                    // Keep the variant's selling price aligned with the product.
                    variant.Price = product.SellingPrice;
                }

                var inventory = await _context.Inventory
                    .FirstOrDefaultAsync(i =>
                        i.ProductVariantId == variant.Id &&
                        i.LocationId == DefaultLocationId);

                if (inventory == null)
                {
                    inventory = new Inventory
                    {
                        ProductVariantId = variant.Id,
                        LocationId = DefaultLocationId,
                        Quantity = itemDto.Quantity
                    };

                    _context.Inventory.Add(inventory);
                }
                else
                {
                    inventory.Quantity += itemDto.Quantity;
                }

                _context.StockMovements.Add(new StockMovement
                {
                    ProductVariantId = variant.Id,
                    LocationId = DefaultLocationId,
                    QuantityChange = itemDto.Quantity,
                    Reason = "Purchase",
                    CreatedAt = DateTime.UtcNow
                });

                invoice.Items.Add(new PurchaseInvoiceItem
                {
                    ProductId = product.Id,
                    UnitPurchasePrice = itemDto.PurchasePrice,
                    Quantity = itemDto.Quantity,
                    TotalPrice = itemDto.PurchasePrice * itemDto.Quantity
                });
            }

            supplier.Debt += invoiceDebt;

            _context.PurchaseInvoices.Add(invoice);

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Ok(new
            {
                invoice.Id,
                invoice.SupplierId,
                SupplierName = supplier.SupplierName,
                invoice.Date,
                invoice.CreatedAt,
                invoice.TotalCost,
                dto.Discount,
                invoice.TotalPaid,
                InvoiceDebt = invoice.Debt,
                SupplierTotalDebt = supplier.Debt,
                Items = invoice.Items.Select(i => new
                {
                    i.ProductId,
                    i.UnitPurchasePrice,
                    i.Quantity,
                    i.TotalPrice
                })
            });
        }
        catch (DbUpdateException)
        {
            await transaction.RollbackAsync();

            return Conflict(
                "The purchase invoice could not be saved. Check for duplicate model numbers or barcodes.");
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetPurchaseInvoices()
    {
        var invoices = await _context.PurchaseInvoices
            .Include(i => i.Supplier)
            .Include(i => i.Items)
            .OrderByDescending(i => i.Date)
            .ThenByDescending(i => i.CreatedAt)
            .Select(i => new
            {
                i.Id,
                i.Supplier.SupplierName,
                i.Date,
                i.CreatedAt,
                i.TotalCost,
                i.TotalPaid,
                InvoiceDebt = i.Debt,
                Items = i.Items.Select(item => new
                {
                    item.ProductId,
                    item.UnitPurchasePrice,
                    item.Quantity,
                    item.TotalPrice
                })
            })
            .ToListAsync();
        return Ok(invoices);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetPurchaseInvoice(int id)
    {
        var invoice = await _context.PurchaseInvoices
            .Include(i => i.Supplier)
            .Include(i => i.Items)
                .ThenInclude(item => item.Product)
            .Include(i => i.Returns)
                .ThenInclude(r => r.Product)
            .FirstOrDefaultAsync(i => i.Id == id);
        if (invoice == null)
            return NotFound();
        return Ok(new
        {
            invoice.Id,
            invoice.SupplierId,
            invoice.Supplier.SupplierName,
            invoice.Date,
            invoice.CreatedAt,
            invoice.TotalCost,
            invoice.TotalPaid,
            InvoiceDebt = invoice.Debt,
            SupplierTotalDebt = invoice.Supplier.Debt,
            Items = invoice.Items.Select(i => new
            {
                i.ProductId,
                i.Product.Name,
                i.Product.ModelNumber,
                i.UnitPurchasePrice,
                i.Quantity,
                i.TotalPrice
            }),
            Returns = invoice.Returns.Select(r => new
            {
                r.Id,
                r.ProductId,
                ProductName = r.Product.Name,
                r.UnitPurchasePrice,
                r.Quantity,
                r.Reason,
                r.CreatedAt
            })
        });
    }

    // POST: api/PurchaseInvoices/5/pay
    [HttpPost("{id:int}/pay")]
    public async Task<IActionResult> PayPurchaseDebt(
        int id,
        PayPurchaseDebtDto dto)
    {
        if (dto.Amount <= 0)
        {
            return BadRequest("Payment amount must be greater than zero.");
        }

        var invoice = await _context.PurchaseInvoices
            .Include(i => i.Supplier)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (invoice == null)
        {
            return NotFound("Purchase invoice not found.");
        }

        if (dto.Amount > invoice.Debt)
        {
            return BadRequest(
                $"Payment cannot exceed the remaining debt of {invoice.Debt}.");
        }

        invoice.TotalPaid += dto.Amount;
        invoice.Debt -= dto.Amount;

        invoice.Supplier.Debt = Math.Max(
            0, invoice.Supplier.Debt - dto.Amount);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            invoice.Id,
            invoice.TotalCost,
            invoice.TotalPaid,
            InvoiceDebt = invoice.Debt,
            SupplierTotalDebt = invoice.Supplier.Debt
        });
    }

    private async Task<string> GenerateVariantBarcodeAsync(
        string productBarcode)
    {
        var suffix = 1;

        while (true)
        {
            var candidate = $"{productBarcode}{suffix}";

            var exists = await _context.ProductVariants
                .AnyAsync(v => v.Barcode == candidate);

            if (!exists)
                return candidate;

            suffix++;
        }
    }
}