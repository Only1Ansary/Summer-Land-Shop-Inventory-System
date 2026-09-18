using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.StockTransfers;
using SummerLandBackend.Models;

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
        if (dto.Quantity <= 0)
        {
            return BadRequest("Quantity must be greater than zero.");
        }

        if (dto.FromLocationId == dto.ToLocationId)
        {
            return BadRequest(
                "FromLocation and ToLocation must be different.");
        }

        var variant = await _context.ProductVariants
            .Include(v => v.Product)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .FirstOrDefaultAsync(v => v.Id == dto.ProductVariantId);

        if (variant == null)
        {
            return BadRequest("ProductVariant not found.");
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

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var sourceInventory = await _context.Inventory
                .FirstOrDefaultAsync(i =>
                    i.ProductVariantId == dto.ProductVariantId &&
                    i.LocationId == dto.FromLocationId);

            if (sourceInventory == null)
            {
                return BadRequest(
                    "ProductVariant is not available at the source location.");
            }

            if (sourceInventory.Quantity < dto.Quantity)
            {
                return BadRequest(
                    $"Insufficient stock at source location. " +
                    $"Available: {sourceInventory.Quantity}, " +
                    $"Requested: {dto.Quantity}.");
            }

            var destinationInventory = await _context.Inventory
                .FirstOrDefaultAsync(i =>
                    i.ProductVariantId == dto.ProductVariantId &&
                    i.LocationId == dto.ToLocationId);

            // Remove from source
            sourceInventory.Quantity -= dto.Quantity;

            // Add to destination
            if (destinationInventory == null)
            {
                destinationInventory = new Inventory
                {
                    ProductVariantId = dto.ProductVariantId,
                    LocationId = dto.ToLocationId,
                    Quantity = dto.Quantity
                };

                _context.Inventory.Add(destinationInventory);
            }
            else
            {
                destinationInventory.Quantity += dto.Quantity;
            }

            // Transfer out
            var transferOut = new StockMovement
            {
                ProductVariantId = dto.ProductVariantId,
                LocationId = dto.FromLocationId,
                QuantityChange = -dto.Quantity,
                Reason = "Transfer Out",
                CreatedAt = DateTime.UtcNow
            };

            // Transfer in
            var transferIn = new StockMovement
            {
                ProductVariantId = dto.ProductVariantId,
                LocationId = dto.ToLocationId,
                QuantityChange = dto.Quantity,
                Reason = "Transfer In",
                CreatedAt = DateTime.UtcNow
            };

            _context.StockMovements.Add(transferOut);
            _context.StockMovements.Add(transferIn);

            // Transfer record
            var transfer = new StockTransfer
            {
                ProductVariantId = dto.ProductVariantId,
                FromLocationId = dto.FromLocationId,
                ToLocationId = dto.ToLocationId,
                Quantity = dto.Quantity,
                CreatedAt = DateTime.UtcNow
            };

            _context.StockTransfers.Add(transfer);

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            var response = new StockTransferResponseDto
            {
                Id = transfer.Id,

                ProductVariantId = variant.Id,
                ModelNumber = variant.Product.ModelNumber,
                ProductName = variant.Product.Name,

                SizeName = variant.Size?.Name,
                ColourName = variant.Colour?.Name,

                FromLocationId = fromLocation.Id,
                FromLocationName = fromLocation.Name,

                ToLocationId = toLocation.Id,
                ToLocationName = toLocation.Name,

                Quantity = transfer.Quantity,
                CreatedAt = transfer.CreatedAt
            };

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
        var transfer = await _context.StockTransfers
            .Include(t => t.ProductVariant)
                .ThenInclude(v => v.Product)
            .Include(t => t.ProductVariant)
                .ThenInclude(v => v.Size)
            .Include(t => t.ProductVariant)
                .ThenInclude(v => v.Colour)
            .Include(t => t.FromLocation)
            .Include(t => t.ToLocation)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (transfer == null)
        {
            return NotFound();
        }

        var response = new StockTransferResponseDto
        {
            Id = transfer.Id,

            ProductVariantId = transfer.ProductVariantId,
            ModelNumber = transfer.ProductVariant.Product.ModelNumber,
            ProductName = transfer.ProductVariant.Product.Name,

            SizeName = transfer.ProductVariant.Size?.Name,
            ColourName = transfer.ProductVariant.Colour?.Name,

            FromLocationId = transfer.FromLocationId,
            FromLocationName = transfer.FromLocation.Name,

            ToLocationId = transfer.ToLocationId,
            ToLocationName = transfer.ToLocation.Name,

            Quantity = transfer.Quantity,
            CreatedAt = transfer.CreatedAt
        };

        return Ok(response);
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<StockTransferResponseDto>>>
        GetTransfers()
    {
        var transfers = await _context.StockTransfers
            .Include(t => t.ProductVariant)
                .ThenInclude(v => v.Product)
            .Include(t => t.ProductVariant)
                .ThenInclude(v => v.Size)
            .Include(t => t.ProductVariant)
                .ThenInclude(v => v.Colour)
            .Include(t => t.FromLocation)
            .Include(t => t.ToLocation)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();

        var response = transfers.Select(t =>
            new StockTransferResponseDto
            {
                Id = t.Id,

                ProductVariantId = t.ProductVariantId,
                ModelNumber = t.ProductVariant.Product.ModelNumber,
                ProductName = t.ProductVariant.Product.Name,

                SizeName = t.ProductVariant.Size?.Name,
                ColourName = t.ProductVariant.Colour?.Name,

                FromLocationId = t.FromLocationId,
                FromLocationName = t.FromLocation.Name,

                ToLocationId = t.ToLocationId,
                ToLocationName = t.ToLocation.Name,

                Quantity = t.Quantity,
                CreatedAt = t.CreatedAt
            }).ToList();

        return Ok(response);
    }
}