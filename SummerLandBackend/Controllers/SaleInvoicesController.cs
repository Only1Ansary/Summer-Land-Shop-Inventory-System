using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.SaleInvoices;
using SummerLandBackend.Models;
using SummerLandBackend.Services;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SaleInvoicesController : ControllerBase
{
    private readonly ShopDbContext _context;

    public SaleInvoicesController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpPost]
    public async Task<ActionResult<InvoiceResponseDto>> CreateInvoice(
    CreateInvoiceDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
            return BadRequest("Invoice must contain at least one item.");

        var cashierLocation = await _context.Locations
            .FirstOrDefaultAsync(l => l.Id == dto.LocationId);

        if (cashierLocation == null)
            return BadRequest("Invalid cashier location.");

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var invoice = new SaleInvoice
            {
                CreatedAt = DateTime.UtcNow,
                LocationId = dto.LocationId,
                TotalAmount = 0
            };

            _context.Invoices.Add(invoice);

            // 1. Process each stock allocation
            foreach (var item in dto.Items)
            {
                if (item.Quantity <= 0)
                {
                    return BadRequest(
                        "Item quantity must be greater than zero.");
                }

                var variant = await _context.ProductVariants
                    .Include(v => v.Product)
                    .Include(v => v.Size)
                    .Include(v => v.Colour)
                    .FirstOrDefaultAsync(v =>
                        v.Id == item.ProductVariantId);

                if (variant == null)
                {
                    return BadRequest(
                        $"Product variant {item.ProductVariantId} was not found.");
                }

                if (item.DiscountAmount > 0 && item.DiscountPercent > 0)
                {
                    return BadRequest(
                        "Give an item discount as either an amount or a " +
                        "percentage, not both.");
                }

                // Normalise: a percent discount becomes a per-unit amount.
                if (item.DiscountPercent > 0)
                {
                    item.DiscountAmount = Math.Round(
                        variant.Price * item.DiscountPercent / 100m,
                        2,
                        MidpointRounding.AwayFromZero);
                }

                var stockLocation = await _context.Locations
                    .FirstOrDefaultAsync(l =>
                        l.Id == item.StockLocationId);

                if (stockLocation == null)
                {
                    return BadRequest(
                        $"Stock location {item.StockLocationId} was not found.");
                }

                var inventory = await _context.Inventory
                    .FirstOrDefaultAsync(i =>
                        i.ProductVariantId == item.ProductVariantId &&
                        i.LocationId == item.StockLocationId);

                if (inventory == null)
                {
                    return BadRequest(
                        $"No inventory exists for " +
                        $"{variant.Product.Name} at " +
                        $"{stockLocation.Name}.");
                }

                if (inventory.Quantity < item.Quantity)
                {
                    return BadRequest(
                        $"Insufficient stock for " +
                        $"{variant.Product.Name} at " +
                        $"{stockLocation.Name}. " +
                        $"Available: {inventory.Quantity}, " +
                        $"Requested: {item.Quantity}.");
                }

                // Deduct stock
                inventory.Quantity -= item.Quantity;

                // Record stock movement
                _context.StockMovements.Add(
                    new StockMovement
                    {
                        ProductVariantId =
                            item.ProductVariantId,

                        LocationId =
                            item.StockLocationId,

                        QuantityChange =
                            -item.Quantity,

                        Reason = "Sale",

                        CreatedAt = DateTime.UtcNow
                    });
            }

            // 2. Group same variants with the SAME discount into ONE
            //    InvoiceItem; rows with different discounts stay separate.
            var groupedItems = dto.Items
                .GroupBy(x => new
                {
                    x.ProductVariantId,
                    x.DiscountAmount,
                    x.DiscountPercent
                })
                .Select(g => new
                {
                    g.Key.ProductVariantId,
                    g.Key.DiscountAmount,
                    g.Key.DiscountPercent,
                    Quantity = g.Sum(x => x.Quantity)
                })
                .ToList();

            // 3. Create one InvoiceItem per variant
            foreach (var groupedItem in groupedItems)
            {
                var variant = await _context.ProductVariants
                    .FirstOrDefaultAsync(v =>
                        v.Id == groupedItem.ProductVariantId);

                if (variant == null)
                {
                    return BadRequest(
                        "ProductVariant not found.");
                }

                if (groupedItem.DiscountAmount > variant.Price)
                {
                    return BadRequest(
                        $"Item discount cannot exceed the unit price of " +
                        $"{variant.Price}.");
                }

                var totalPrice =
                    (variant.Price - groupedItem.DiscountAmount) *
                    groupedItem.Quantity;

                var invoiceItem = new SaleInvoiceItem
                {
                    Invoice = invoice,

                    ProductVariantId =
                        groupedItem.ProductVariantId,

                    Quantity =
                        groupedItem.Quantity,

                    UnitPrice =
                        variant.Price,

                    TotalPrice =
                        totalPrice,

                    DiscountAmount =
                        groupedItem.DiscountAmount,

                    DiscountPercent =
                        groupedItem.DiscountPercent > 0
                            ? groupedItem.DiscountPercent
                            : null
                };

                _context.InvoiceItems.Add(invoiceItem);

                invoice.TotalAmount += totalPrice;
            }

            if (dto.DiscountAmount < 0)
            {
                return BadRequest("Discount amount cannot be negative.");
            }

            if (dto.DiscountAmount > 0 && dto.DiscountPercent > 0)
            {
                return BadRequest(
                    "Give the invoice discount as either an amount or a " +
                    "percentage, not both.");
            }

            var invoiceDiscount = dto.DiscountAmount;

            // A percent discount is taken on the items total after the
            // per-item discounts.
            if (dto.DiscountPercent > 0)
            {
                invoiceDiscount = Math.Round(
                    invoice.TotalAmount * dto.DiscountPercent / 100m,
                    2,
                    MidpointRounding.AwayFromZero);
            }

            if (invoiceDiscount > invoice.TotalAmount)
            {
                return BadRequest(
                    $"Discount cannot exceed the invoice total of " +
                    $"{invoice.TotalAmount}.");
            }

            invoice.DiscountAmount = invoiceDiscount;

            invoice.DiscountPercent = dto.DiscountPercent > 0
                ? dto.DiscountPercent
                : null;

            invoice.TotalAmount -= invoiceDiscount;

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            var createdInvoice = await _context.Invoices
                .Include(i => i.Location)
                .Include(i => i.Items)
                    .ThenInclude(ii => ii.ProductVariant)
                        .ThenInclude(v => v.Product)
                .Include(i => i.Items)
                    .ThenInclude(ii => ii.ProductVariant)
                        .ThenInclude(v => v.Size)
                .Include(i => i.Items)
                    .ThenInclude(ii => ii.ProductVariant)
                        .ThenInclude(v => v.Colour)
                .FirstAsync(i => i.Id == invoice.Id);

            var response = new InvoiceResponseDto
            {
                Id = createdInvoice.Id,
                CreatedAt = createdInvoice.CreatedAt,
                LocationId = createdInvoice.LocationId,
                LocationName = createdInvoice.Location.Name,
                TotalAmount = createdInvoice.TotalAmount,
                DiscountAmount = createdInvoice.DiscountAmount,
                DiscountPercent = createdInvoice.DiscountPercent,

                Items = createdInvoice.Items.Select(ii =>
                    new InvoiceItemResponseDto
                    {
                        ProductVariantId =
                            ii.ProductVariantId,

                        Quantity =
                            ii.Quantity,

                        UnitPrice =
                            ii.UnitPrice,

                        TotalPrice =
                            ii.TotalPrice,

                        TotalBeforeDiscount =
                            ii.UnitPrice * ii.Quantity,

                        UnitPriceAfterDiscount =
                            ii.UnitPrice - ii.DiscountAmount,

                        DiscountAmount =
                            ii.DiscountAmount,

                        DiscountPercent =
                            ii.DiscountPercent,

                        ModelNumber =
                            ii.ProductVariant.Product.ModelNumber,

                        ProductName =
                            ii.ProductVariant.Product.Name,

                        SizeName =
                            ii.ProductVariant.Size?.Name,

                        ColourName =
                            ii.ProductVariant.Colour?.Name
                    }).ToList()
            };

            return Ok(response);
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<InvoiceResponseDto>>> GetInvoices(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to)
    {
        var query = _context.Invoices
            .Include(i => i.Location)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Product)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Size)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Colour)
            .AsQueryable();

        if (from.HasValue)
        {
            query = query.Where(i => i.CreatedAt >= QueryDateRange.Start(from));
        }

        if (to.HasValue)
        {
            query = query.Where(i => i.CreatedAt <= QueryDateRange.End(to));
        }

        var invoices = await query
            .OrderByDescending(i => i.CreatedAt)
            .ToListAsync();

        var response = invoices.Select(i =>
            new InvoiceResponseDto
            {
                Id = i.Id,
                CreatedAt = i.CreatedAt,
                LocationId = i.LocationId,
                LocationName = i.Location.Name,
                TotalAmount = i.TotalAmount,
                DiscountAmount = i.DiscountAmount,
                DiscountPercent = i.DiscountPercent,

                Items = i.Items.Select(ii =>
                    new InvoiceItemResponseDto
                    {
                        ProductVariantId =
                            ii.ProductVariantId,

                        Quantity =
                            ii.Quantity,

                        UnitPrice =
                            ii.UnitPrice,

                        TotalPrice =
                            ii.TotalPrice,

                        TotalBeforeDiscount =
                            ii.UnitPrice * ii.Quantity,

                        UnitPriceAfterDiscount =
                            ii.UnitPrice - ii.DiscountAmount,

                        DiscountAmount =
                            ii.DiscountAmount,

                        DiscountPercent =
                            ii.DiscountPercent,

                        ModelNumber =
                            ii.ProductVariant.Product.ModelNumber,

                        ProductName =
                            ii.ProductVariant.Product.Name,

                        SizeName =
                            ii.ProductVariant.Size?.Name,

                        ColourName =
                            ii.ProductVariant.Colour?.Name
                    }).ToList()
            });

        return Ok(response);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<InvoiceResponseDto>> GetInvoice(int id)
    {
        var invoice = await _context.Invoices
            .Include(i => i.Location)
            .Include(i => i.Items)
                .ThenInclude(item => item.ProductVariant)
                    .ThenInclude(v => v.Product)
            .Include(i => i.Items)
                .ThenInclude(item => item.ProductVariant)
                    .ThenInclude(v => v.Size)
            .Include(i => i.Items)
                .ThenInclude(item => item.ProductVariant)
                    .ThenInclude(v => v.Colour)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (invoice == null)
        {
            return NotFound("Invoice not found.");
        }

        var response = new InvoiceResponseDto
        {
            Id = invoice.Id,
            CreatedAt = invoice.CreatedAt,
            LocationId = invoice.LocationId,
            LocationName = invoice.Location.Name,
            TotalAmount = invoice.TotalAmount,
            DiscountAmount = invoice.DiscountAmount,
            DiscountPercent = invoice.DiscountPercent,

            Items = invoice.Items.Select(item => new InvoiceItemResponseDto
            {
                ProductVariantId = item.ProductVariantId,
                ModelNumber = item.ProductVariant.Product.ModelNumber,
                ProductName = item.ProductVariant.Product.Name,
                SizeName = item.ProductVariant.Size?.Name,
                ColourName = item.ProductVariant.Colour?.Name,
                Quantity = item.Quantity,
                UnitPrice = item.UnitPrice,
                TotalPrice = item.TotalPrice,
                TotalBeforeDiscount = item.UnitPrice * item.Quantity,
                UnitPriceAfterDiscount =
                    item.UnitPrice - item.DiscountAmount,
                DiscountAmount = item.DiscountAmount,
                DiscountPercent = item.DiscountPercent
            }).ToList()
        };

        return Ok(response);
    }
}