using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.StockMovements;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StockMovementsController : ControllerBase
{
    private readonly ShopDbContext _context;

    public StockMovementsController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet("variant/{variantId:int}")]
    public async Task<ActionResult<IEnumerable<StockMovementResponseDto>>>
        GetVariantMovements(int variantId)
    {
        var movements = await _context.StockMovements
            .Include(m => m.ProductVariant)
                .ThenInclude(v => v.Product)
            .Include(m => m.Location)
            .Where(m => m.ProductVariantId == variantId)
            .OrderByDescending(m => m.CreatedAt)
            .Select(m => new StockMovementResponseDto
            {
                Id = m.Id,
                ProductVariantId = m.ProductVariantId,
                ModelNumber = m.ProductVariant.Product.ModelNumber,
                ProductName = m.ProductVariant.Product.Name,
                LocationId = m.LocationId,
                LocationName = m.Location.Name,
                QuantityChange = m.QuantityChange,
                Reason = m.Reason,
                CreatedAt = m.CreatedAt
            })
            .ToListAsync();

        return Ok(movements);
    }

    [HttpPost]
    public async Task<ActionResult<StockMovementResponseDto>>
        CreateMovement(CreateStockMovementDto dto)
    {
        if (dto.QuantityChange == 0)
        {
            return BadRequest("Quantity change cannot be zero.");
        }

        if (Math.Abs(dto.QuantityChange) > 100000)
        {
            return BadRequest(
                "Quantity change cannot exceed 100,000.");
        }

        if (string.IsNullOrWhiteSpace(dto.Reason))
        {
            return BadRequest("Reason is required.");
        }

        var variant = await _context.ProductVariants
    .Include(v => v.Product)
    .FirstOrDefaultAsync(v => v.Id == dto.ProductVariantId);

        if (variant == null)
        {
            return BadRequest("Product variant does not exist.");
        }

        var location = await _context.Locations
            .FirstOrDefaultAsync(l => l.Id == dto.LocationId);

        if (location == null)
        {
            return BadRequest("Location does not exist.");
        }

        var inventory = await _context.Inventory
            .FirstOrDefaultAsync(i =>
                i.ProductVariantId == dto.ProductVariantId &&
                i.LocationId == dto.LocationId);

        // If there is no inventory record yet,
        // create one with zero stock.
        if (inventory == null)
        {
            inventory = new Inventory
            {
                ProductVariantId = dto.ProductVariantId,
                LocationId = dto.LocationId,
                Quantity = 0,
                LowStockThreshold = variant.LowStockThreshold
            };

            _context.Inventory.Add(inventory);
        }

        // Prevent negative stock
        if (inventory.Quantity + dto.QuantityChange < 0)
        {
            return BadRequest(
                $"Insufficient stock. Current quantity: {inventory.Quantity}.");
        }

        // Change the actual inventory
        inventory.Quantity += dto.QuantityChange;

        // Record the movement
        var movement = new StockMovement
        {
            ProductVariantId = dto.ProductVariantId,
            LocationId = dto.LocationId,
            QuantityChange = dto.QuantityChange,
            Reason = dto.Reason.Trim()
        };

        _context.StockMovements.Add(movement);

        await _context.SaveChangesAsync();

        return Ok(new StockMovementResponseDto
        {
            Id = movement.Id,
            ProductVariantId = movement.ProductVariantId,
            ModelNumber = variant.Product?.ModelNumber ?? string.Empty,
            ProductName = variant.Product?.Name ?? string.Empty,
            LocationId = movement.LocationId,
            LocationName = location.Name,
            QuantityChange = movement.QuantityChange,
            Reason = movement.Reason,
            CreatedAt = movement.CreatedAt
        });
    }
}