using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.StockTransfers;
using SummerLandBackend.Models;
using SummerLandBackend.Services;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StockTransfersController : ControllerBase
{
    private readonly ShopDbContext _context;

    public StockTransfersController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpPost]
    public async Task<ActionResult<StockTransferResponseDto>> CreateTransfer(
        CreateStockTransferDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
        {
            return BadRequest("Add at least one product variant.");
        }

        if (dto.FromLocationId == dto.ToLocationId)
        {
            return BadRequest(
                "FromLocation and ToLocation must be different.");
        }

        var fromLocation = await _context.Locations
            .FirstOrDefaultAsync(l => l.Id == dto.FromLocationId);

        if (fromLocation == null)
        {
            return BadRequest("Source location not found.");
        }

        var toLocation = await _context.Locations
            .FirstOrDefaultAsync(l => l.Id == dto.ToLocationId);

        if (toLocation == null)
        {
            return BadRequest("Destination location not found.");
        }

        // A variant must not appear twice in the same transfer.
        var variantIds = dto.Items.Select(i => i.ProductVariantId).ToList();

        if (variantIds.Count != variantIds.Distinct().Count())
        {
            return BadRequest(
                "The same product variant appears more than once.");
        }

        foreach (var item in dto.Items)
        {
            if (item.Quantity <= 0)
            {
                return BadRequest(
                    "Every quantity must be greater than zero.");
            }

            var variantExists = await _context.ProductVariants
                .AnyAsync(v => v.Id == item.ProductVariantId);

            if (!variantExists)
            {
                return BadRequest("ProductVariant not found.");
            }
        }

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var transfer = new StockTransfer
            {
                FromLocationId = dto.FromLocationId,
                ToLocationId = dto.ToLocationId,
                CreatedAt = DateTime.UtcNow
            };

            foreach (var item in dto.Items)
            {
                var sourceInventory = await _context.Inventory
                    .FirstOrDefaultAsync(i =>
                        i.ProductVariantId == item.ProductVariantId &&
                        i.LocationId == dto.FromLocationId);

                if (sourceInventory == null)
                {
                    await transaction.RollbackAsync();

                    return BadRequest(
                        "A product variant is not available at the source location.");
                }

                if (sourceInventory.Quantity < item.Quantity)
                {
                    await transaction.RollbackAsync();

                    return BadRequest(
                        $"Insufficient stock at source location. " +
                        $"Available: {sourceInventory.Quantity}, " +
                        $"Requested: {item.Quantity}.");
                }

                var destinationInventory = await _context.Inventory
                    .FirstOrDefaultAsync(i =>
                        i.ProductVariantId == item.ProductVariantId &&
                        i.LocationId == dto.ToLocationId);

                // Remove from source
                sourceInventory.Quantity -= item.Quantity;

                // Add to destination
                if (destinationInventory == null)
                {
                    destinationInventory = new Inventory
                    {
                        ProductVariantId = item.ProductVariantId,
                        LocationId = dto.ToLocationId,
                        Quantity = item.Quantity
                    };

                    _context.Inventory.Add(destinationInventory);
                }
                else
                {
                    destinationInventory.Quantity += item.Quantity;
                }

                _context.StockMovements.Add(new StockMovement
                {
                    ProductVariantId = item.ProductVariantId,
                    LocationId = dto.FromLocationId,
                    QuantityChange = -item.Quantity,
                    Reason = "Transfer Out",
                    CreatedAt = DateTime.UtcNow
                });

                _context.StockMovements.Add(new StockMovement
                {
                    ProductVariantId = item.ProductVariantId,
                    LocationId = dto.ToLocationId,
                    QuantityChange = item.Quantity,
                    Reason = "Transfer In",
                    CreatedAt = DateTime.UtcNow
                });

                transfer.Items.Add(new StockTransferItem
                {
                    ProductVariantId = item.ProductVariantId,
                    Quantity = item.Quantity
                });
            }

            _context.StockTransfers.Add(transfer);

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            var response = await BuildResponseAsync(transfer.Id);

            return CreatedAtAction(
                nameof(GetTransfer),
                new { id = transfer.Id },
                response);
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<StockTransferResponseDto>> GetTransfer(
        int id)
    {
        var response = await BuildResponseAsync(id);

        if (response == null)
        {
            return NotFound("Stock transfer not found.");
        }

        return Ok(response);
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<StockTransferResponseDto>>>
        GetTransfers(
            [FromQuery] DateTime? from,
            [FromQuery] DateTime? to)
    {
        var query = _context.StockTransfers
            .Include(t => t.FromLocation)
            .Include(t => t.ToLocation)
            .Include(t => t.Items)
                .ThenInclude(i => i.ProductVariant)
                    .ThenInclude(v => v.Product)
            .Include(t => t.Items)
                .ThenInclude(i => i.ProductVariant)
                    .ThenInclude(v => v.Size)
            .Include(t => t.Items)
                .ThenInclude(i => i.ProductVariant)
                    .ThenInclude(v => v.Colour)
            .AsQueryable();

        if (from.HasValue)
        {
            var fromDate = QueryDateRange.Start(from);

            query = query.Where(t => t.CreatedAt >= fromDate);
        }

        if (to.HasValue)
        {
            var toDate = QueryDateRange.End(to);

            query = query.Where(t => t.CreatedAt <= toDate);
        }

        var transfers = await query
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();

        var response = transfers.Select(MapToResponse).ToList();

        return Ok(response);
    }

    private async Task<StockTransferResponseDto?> BuildResponseAsync(int id)
    {
        var transfer = await _context.StockTransfers
            .Include(t => t.FromLocation)
            .Include(t => t.ToLocation)
            .Include(t => t.Items)
                .ThenInclude(i => i.ProductVariant)
                    .ThenInclude(v => v.Product)
            .Include(t => t.Items)
                .ThenInclude(i => i.ProductVariant)
                    .ThenInclude(v => v.Size)
            .Include(t => t.Items)
                .ThenInclude(i => i.ProductVariant)
                    .ThenInclude(v => v.Colour)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (transfer == null)
        {
            return null;
        }

        return MapToResponse(transfer);
    }

    private static StockTransferResponseDto MapToResponse(StockTransfer t)
    {
        return new StockTransferResponseDto
        {
            Id = t.Id,

            FromLocationId = t.FromLocationId,
            FromLocationName = t.FromLocation.Name,

            ToLocationId = t.ToLocationId,
            ToLocationName = t.ToLocation.Name,

            TotalQuantity = t.Items.Sum(i => i.Quantity),
            CreatedAt = t.CreatedAt,

            Items = t.Items.Select(i => new StockTransferItemResponseDto
            {
                ProductVariantId = i.ProductVariantId,
                ModelNumber = i.ProductVariant.Product.ModelNumber,
                ProductName = i.ProductVariant.Product.Name,
                SizeName = i.ProductVariant.Size?.Name,
                ColourName = i.ProductVariant.Colour?.Name,
                Quantity = i.Quantity
            }).ToList()
        };
    }
}
