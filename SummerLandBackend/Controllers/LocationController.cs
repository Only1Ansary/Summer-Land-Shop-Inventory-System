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
}