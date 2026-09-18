using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Inventory;
using SummerLandBackend.Models;

namespace ShopSystem.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InventoryController : ControllerBase
{
    private readonly ShopDbContext _context;

    public InventoryController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet("variant/{variantId:int}")]
    public async Task<ActionResult<IEnumerable<InventoryResponseDto>>> GetVariantInventory(
        int variantId)
    {
        var variantExists = await _context.ProductVariants
            .AnyAsync(v => v.Id == variantId);

        if (!variantExists)
        {
            return NotFound("Product variant does not exist.");
        }

        var inventory = await _context.Inventory
            .Include(i => i.Location)
            .Where(i => i.ProductVariantId == variantId)
            .Select(i => new InventoryResponseDto
            {
                Id = i.Id,
                ProductVariantId = i.ProductVariantId,
                LocationId = i.LocationId,
                LocationName = i.Location.Name,
                Quantity = i.Quantity
            })
            .ToListAsync();

        return Ok(inventory);
    }

    [HttpPost]
    public async Task<ActionResult<InventoryResponseDto>> AddInventory(
        AddInventoryDto dto)
    {
        if (dto.Quantity <= 0)
        {
            return BadRequest("Quantity must be greater than zero.");
        }

        var variant = await _context.ProductVariants
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

        if (dto.Quantity > 100000)
        {
            return BadRequest("Quantity cannot exceed 100,000.");
        }

        var inventory = await _context.Inventory
    .FirstOrDefaultAsync(i =>
        i.ProductVariantId == dto.ProductVariantId &&
        i.LocationId == dto.LocationId);

        var reason = "Initial Stock";

        if (inventory == null)
        {
            inventory = new Inventory
            {
                ProductVariantId = dto.ProductVariantId,
                LocationId = dto.LocationId,
                Quantity = dto.Quantity
            };

            _context.Inventory.Add(inventory);
        }
        else
        {
            inventory.Quantity += dto.Quantity;
            reason = "Stock Addition";
        }

        var movement = new StockMovement
        {
            ProductVariantId = dto.ProductVariantId,
            LocationId = dto.LocationId,
            QuantityChange = dto.Quantity,
            Reason = reason,
            CreatedAt = DateTime.UtcNow
        };

        _context.StockMovements.Add(movement);

        await _context.SaveChangesAsync();

        return Ok(new InventoryResponseDto
        {
            Id = inventory.Id,
            ProductVariantId = inventory.ProductVariantId,
            LocationId = inventory.LocationId,
            LocationName = location.Name,
            Quantity = inventory.Quantity
        });
    }
}