using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Locations;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LocationsController : ControllerBase
{
    private readonly ShopDbContext _context;

    public LocationsController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Location>>> GetLocations()
    {
        return await _context.Locations
            .OrderBy(l => l.Name)
            .ToListAsync();
    }

    [HttpPost]
    public async Task<ActionResult<Location>> CreateLocation(Location location)
    {
        if (string.IsNullOrWhiteSpace(location.Name))
        {
            return BadRequest("Location name is required.");
        }

        var name = location.Name.Trim();

        var exists = await _context.Locations
            .AnyAsync(l => l.Name == name);

        if (exists)
        {
            return Conflict("Location already exists.");
        }

        location.Name = name;

        _context.Locations.Add(location);
        await _context.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetLocations),
            new { id = location.Id },
            location);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateLocation(
    int id,
    UpdateLocationDto dto)
    {
        var location = await _context.Locations
            .FirstOrDefaultAsync(l => l.Id == id);

        if (location == null)
        {
            return NotFound("Location not found.");
        }

        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            return BadRequest("Location name is required.");
        }

        var name = dto.Name.Trim();

        var exists = await _context.Locations
            .AnyAsync(l => l.Id != id && l.Name == name);

        if (exists)
        {
            return Conflict("A location with this name already exists.");
        }

        location.Name = name;

        await _context.SaveChangesAsync();

        return Ok(location);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteLocation(int id)
    {
        var location = await _context.Locations
            .FirstOrDefaultAsync(l => l.Id == id);

        if (location == null)
        {
            return NotFound("Location not found.");
        }

        var hasStock = await _context.Inventory
            .AnyAsync(i => i.LocationId == id && i.Quantity > 0);

        if (hasStock)
        {
            return BadRequest(
                "Location still has stock on hand. Move or clear the "
                + "stock before deleting it.");
        }

        var hasInvoices = await _context.Invoices
            .AnyAsync(i => i.LocationId == id);

        if (hasInvoices)
        {
            return BadRequest(
                "Location is used by sales invoices and cannot be deleted.");
        }

        var hasMovements = await _context.StockMovements
            .AnyAsync(m => m.LocationId == id);

        if (hasMovements)
        {
            return BadRequest(
                "Location is used by stock movements and cannot be deleted.");
        }

        var hasTransfers = await _context.StockTransfers
            .AnyAsync(t => t.FromLocationId == id || t.ToLocationId == id);

        if (hasTransfers)
        {
            return BadRequest(
                "Location is used by stock transfers and cannot be deleted.");
        }

        var hasReturns = await _context.Returns
            .AnyAsync(r => r.LocationId == id);

        if (hasReturns)
        {
            return BadRequest(
                "Location is used by returns and cannot be deleted.");
        }

        // Any inventory rows left are empty placeholders for this
        // location, so they go with it.
        var emptyInventory = await _context.Inventory
            .Where(i => i.LocationId == id)
            .ToListAsync();

        if (emptyInventory.Count > 0)
        {
            _context.Inventory.RemoveRange(emptyInventory);
        }

        _context.Locations.Remove(location);

        await _context.SaveChangesAsync();

        return NoContent();
    }
}