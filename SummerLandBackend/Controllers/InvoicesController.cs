using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Invoices;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InvoicesController : ControllerBase
{
    private readonly ShopDbContext _context;

    public InvoicesController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpPost]
    public async Task<ActionResult<InvoiceResponseDto>> CreateInvoice(
    CreateInvoiceDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
        {
            return BadRequest("Invoice must contain at least one item.");
        }

        if (dto.LocationId <= 0)
        {
            return BadRequest("LocationId must be valid.");
        }

        var location = await _context.Locations
            .FirstOrDefaultAsync(l => l.Id == dto.LocationId);

        if (location == null)
        {
            return BadRequest("Location not found.");
        }

        await using var transaction = await _context.Database.BeginTransactionAsync();

        try
        {
            var invoice = new Invoice
            {
                LocationId = dto.LocationId,
                CreatedAt = DateTime.UtcNow
            };

            decimal totalAmount = 0;

            foreach (var itemDto in dto.Items)
            {
                if (itemDto.Quantity <= 0)
                {
                    return BadRequest(
                        $"Quantity must be greater than zero for ProductVariantId {itemDto.ProductVariantId}.");
                }

                var variant = await _context.ProductVariants
                    .Include(v => v.Product)
                    .Include(v => v.Size)
                    .Include(v => v.Colour)
                    .FirstOrDefaultAsync(v => v.Id == itemDto.ProductVariantId);

                if (variant == null)
                {
                    return BadRequest(
                        $"ProductVariant {itemDto.ProductVariantId} not found.");
                }

                var inventory = await _context.Inventory
                    .FirstOrDefaultAsync(i =>
                        i.ProductVariantId == itemDto.ProductVariantId &&
                        i.LocationId == dto.LocationId);

                if (inventory == null)
                {
                    return BadRequest(
                        $"ProductVariant {itemDto.ProductVariantId} is not available at this location.");
                }

                if (inventory.Quantity < itemDto.Quantity)
                {
                    return BadRequest(
                        $"Insufficient stock for ProductVariant {itemDto.ProductVariantId}. " +
                        $"Available: {inventory.Quantity}, Requested: {itemDto.Quantity}.");
                }

                var duplicateVariant = dto.Items
                    .GroupBy(i => i.ProductVariantId)
                    .Any(g => g.Count() > 1);

                if (duplicateVariant)
                {
                    return BadRequest(
                        "The same product variant cannot appear more than once in an invoice.");
                }

                // Decrease inventory
                inventory.Quantity -= itemDto.Quantity;

                // Record stock movement
                var stockMovement = new StockMovement
                {
                    ProductVariantId = itemDto.ProductVariantId,
                    LocationId = dto.LocationId,
                    QuantityChange = -itemDto.Quantity,
                    Reason = "Sale",
                    CreatedAt = DateTime.UtcNow
                };

                _context.StockMovements.Add(stockMovement);

                // Create invoice item
                var itemTotal = variant.Price * itemDto.Quantity;

                var invoiceItem = new InvoiceItem
                {
                    ProductVariantId = variant.Id,
                    Quantity = itemDto.Quantity,
                    UnitPrice = variant.Price,
                    TotalPrice = itemTotal
                };

                invoice.Items.Add(invoiceItem);

                totalAmount += itemTotal;
            }

            invoice.TotalAmount = totalAmount;

            _context.Invoices.Add(invoice);

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            var response = new InvoiceResponseDto
            {
                Id = invoice.Id,
                CreatedAt = invoice.CreatedAt,
                LocationId = location.Id,
                LocationName = location.Name,
                TotalAmount = invoice.TotalAmount,

                Items = invoice.Items.Select(item => new InvoiceItemResponseDto
                {
                    ProductVariantId = item.ProductVariantId,
                    Quantity = item.Quantity,
                    UnitPrice = item.UnitPrice,
                    TotalPrice = item.TotalPrice,

                    ModelNumber = item.ProductVariant.Product.ModelNumber,
                    ProductName = item.ProductVariant.Product.Name,
                    SizeName = item.ProductVariant.Size?.Name,
                    ColourName = item.ProductVariant.Colour?.Name
                }).ToList()
            };

            return CreatedAtAction(
                nameof(GetInvoice),
                new { id = invoice.Id },
                response);
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
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
            return NotFound();
        }

        var response = new InvoiceResponseDto
        {
            Id = invoice.Id,
            CreatedAt = invoice.CreatedAt,
            LocationId = invoice.LocationId,
            LocationName = invoice.Location.Name,
            TotalAmount = invoice.TotalAmount,

            Items = invoice.Items.Select(item => new InvoiceItemResponseDto
            {
                ProductVariantId = item.ProductVariantId,
                ModelNumber = item.ProductVariant.Product.ModelNumber,
                ProductName = item.ProductVariant.Product.Name,
                SizeName = item.ProductVariant.Size?.Name,
                ColourName = item.ProductVariant.Colour?.Name,
                Quantity = item.Quantity,
                UnitPrice = item.UnitPrice,
                TotalPrice = item.TotalPrice
            }).ToList()
        };

        return Ok(response);
    }
}