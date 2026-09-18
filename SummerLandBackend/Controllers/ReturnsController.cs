using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Returns;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReturnsController : ControllerBase
{
    private readonly ShopDbContext _context;

    public ReturnsController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpPost]
    public async Task<ActionResult<ReturnResponseDto>> CreateReturn(
        CreateReturnDto dto)
    {
        if (dto.Quantity <= 0)
        {
            return BadRequest("Quantity must be greater than zero.");
        }
       
        var invoice = await _context.Invoices
            .Include(i => i.Items)
            .FirstOrDefaultAsync(i => i.Id == dto.InvoiceId);

        if (invoice == null)
        {
            return BadRequest("Invoice not found.");
        }

        var invoiceItem = invoice.Items
            .FirstOrDefault(i =>
                i.ProductVariantId == dto.ProductVariantId);

        if (invoiceItem == null)
        {
            return BadRequest(
                "This product variant does not exist in the invoice.");
        }

        // Calculate how much of this item was already returned
        var alreadyReturned = await _context.Returns
            .Where(r =>
                r.InvoiceId == dto.InvoiceId &&
                r.ProductVariantId == dto.ProductVariantId)
            .SumAsync(r => r.Quantity);

        var remainingQuantity =
            invoiceItem.Quantity - alreadyReturned;

        if (dto.Quantity > remainingQuantity)
        {
            return BadRequest(
                $"Cannot return {dto.Quantity} item(s). " +
                $"Remaining returnable quantity: {remainingQuantity}.");
        }

        var variant = await _context.ProductVariants
            .Include(v => v.Product)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .FirstOrDefaultAsync(v =>
                v.Id == dto.ProductVariantId);

        if (variant == null)
        {
            return BadRequest("ProductVariant not found.");
        }

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var inventory = await _context.Inventory
                .FirstOrDefaultAsync(i =>
                    i.ProductVariantId == dto.ProductVariantId &&
                    i.LocationId == invoice.LocationId);

            if (inventory == null)
            {
                inventory = new Inventory
                {
                    ProductVariantId = dto.ProductVariantId,
                    LocationId = invoice.LocationId,
                    Quantity = 0
                };

                _context.Inventory.Add(inventory);
            }

            // Add returned quantity back to stock
            inventory.Quantity += dto.Quantity;

            var totalAmount =
                invoiceItem.UnitPrice * dto.Quantity;

            var returnRecord = new Return
            {
                InvoiceId = dto.InvoiceId,
                ProductVariantId = dto.ProductVariantId,
                LocationId = invoice.LocationId,
                Quantity = dto.Quantity,
                UnitPrice = invoiceItem.UnitPrice,
                TotalAmount = totalAmount,
                Reason = dto.Reason,
                CreatedAt = DateTime.UtcNow
            };

            _context.Returns.Add(returnRecord);

            // Record stock movement
            var stockMovement = new StockMovement
            {
                ProductVariantId = dto.ProductVariantId,
                LocationId = invoice.LocationId,
                QuantityChange = dto.Quantity,
                Reason = "Return",
                CreatedAt = DateTime.UtcNow
            };

            _context.StockMovements.Add(stockMovement);

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            var location = await _context.Locations
                .FirstAsync(l => l.Id == invoice.LocationId);

            var response = new ReturnResponseDto
            {
                Id = returnRecord.Id,

                InvoiceId = returnRecord.InvoiceId,

                ProductVariantId = returnRecord.ProductVariantId,

                ModelNumber = variant.Product.ModelNumber,

                ProductName = variant.Product.Name,

                SizeName = variant.Size?.Name,

                ColourName = variant.Colour?.Name,

                LocationId = returnRecord.LocationId,

                LocationName = location.Name,

                Quantity = returnRecord.Quantity,

                UnitPrice = returnRecord.UnitPrice,

                TotalAmount = returnRecord.TotalAmount,

                Reason = returnRecord.Reason,

                CreatedAt = returnRecord.CreatedAt
            };

            return CreatedAtAction(
                nameof(GetReturn),
                new { id = returnRecord.Id },
                response);
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ReturnResponseDto>> GetReturn(int id)
    {
        var returnRecord = await _context.Returns
            .Include(r => r.Invoice)
            .Include(r => r.ProductVariant)
                .ThenInclude(v => v.Product)
            .Include(r => r.ProductVariant)
                .ThenInclude(v => v.Size)
            .Include(r => r.ProductVariant)
                .ThenInclude(v => v.Colour)
            .Include(r => r.Location)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (returnRecord == null)
        {
            return NotFound();
        }

        var response = new ReturnResponseDto
        {
            Id = returnRecord.Id,

            InvoiceId = returnRecord.InvoiceId,

            ProductVariantId = returnRecord.ProductVariantId,

            ModelNumber =
                returnRecord.ProductVariant.Product.ModelNumber,

            ProductName =
                returnRecord.ProductVariant.Product.Name,

            SizeName =
                returnRecord.ProductVariant.Size?.Name,

            ColourName =
                returnRecord.ProductVariant.Colour?.Name,

            LocationId = returnRecord.LocationId,

            LocationName =
                returnRecord.Location.Name,

            Quantity = returnRecord.Quantity,

            UnitPrice = returnRecord.UnitPrice,

            TotalAmount = returnRecord.TotalAmount,

            Reason = returnRecord.Reason,

            CreatedAt = returnRecord.CreatedAt
        };

        return Ok(response);
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<ReturnResponseDto>>>
        GetReturns()
    {
        var returns = await _context.Returns
            .Include(r => r.ProductVariant)
                .ThenInclude(v => v.Product)
            .Include(r => r.ProductVariant)
                .ThenInclude(v => v.Size)
            .Include(r => r.ProductVariant)
                .ThenInclude(v => v.Colour)
            .Include(r => r.Location)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync();

        var response = returns.Select(r =>
            new ReturnResponseDto
            {
                Id = r.Id,

                InvoiceId = r.InvoiceId,

                ProductVariantId = r.ProductVariantId,

                ModelNumber =
                    r.ProductVariant.Product.ModelNumber,

                ProductName =
                    r.ProductVariant.Product.Name,

                SizeName =
                    r.ProductVariant.Size?.Name,

                ColourName =
                    r.ProductVariant.Colour?.Name,

                LocationId = r.LocationId,

                LocationName =
                    r.Location.Name,

                Quantity = r.Quantity,

                UnitPrice = r.UnitPrice,

                TotalAmount = r.TotalAmount,

                Reason = r.Reason,

                CreatedAt = r.CreatedAt
            })
            .ToList();

        return Ok(response);
    }
}