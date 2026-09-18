using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Colours;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[Route("api/[controller]")]
[ApiController]
public class ColoursController : ControllerBase
{
    private readonly ShopDbContext _context;

    public ColoursController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Colour>>> GetColours()
    {
        return await _context.Colours
            .OrderBy(c => c.Name)
            .ToListAsync();
    }

    [HttpPost]
    public async Task<ActionResult<Colour>> CreateColour(Colour colour)
    {
        if (string.IsNullOrWhiteSpace(colour.Name))
        {
            return BadRequest("Colour name is required.");
        }

        var name = colour.Name.Trim();

        var exists = await _context.Colours
            .AnyAsync(c => c.Name == name);

        if (exists)
        {
            return Conflict("Colour already exists.");
        }

        colour.Name = name;

        _context.Colours.Add(colour);
        await _context.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetColours),
            new { id = colour.Id },
            colour);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateColour(
    int id,
    UpdateColourDto dto)
    {
        var colour = await _context.Colours
            .FirstOrDefaultAsync(c => c.Id == id);

        if (colour == null)
        {
            return NotFound("Colour not found.");
        }

        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            return BadRequest("Colour name is required.");
        }

        var name = dto.Name.Trim();

        var exists = await _context.Colours
            .AnyAsync(c => c.Id != id && c.Name == name);

        if (exists)
        {
            return Conflict("A colour with this name already exists.");
        }

        colour.Name = name;

        await _context.SaveChangesAsync();

        return Ok(colour);
    }
}
