using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Sizes;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SizesController : ControllerBase
{
    private readonly ShopDbContext _context;

    public SizesController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Sizes>>> GetSizes()
    {
        return await _context.Sizes
            .OrderBy(s => s.Name)
            .ToListAsync();
    }

    [HttpPost]
    public async Task<ActionResult<Sizes>> CreateSize(Sizes size)
    {
        if (string.IsNullOrWhiteSpace(size.Name))
        {
            return BadRequest("Size name is required.");
        }

        var name = size.Name.Trim();

        var exists = await _context.Sizes
            .AnyAsync(s => s.Name == name);

        if (exists)
        {
            return Conflict("Size already exists.");
        }

        size.Name = name;

        _context.Sizes.Add(size);
        await _context.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetSizes),
            new { id = size.Id },
            size);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateSize(
    int id,
    UpdateSizeDto dto)
    {
        var size = await _context.Sizes
            .FirstOrDefaultAsync(s => s.Id == id);

        if (size == null)
        {
            return NotFound("Size not found.");
        }

        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            return BadRequest("Size name is required.");
        }

        var name = dto.Name.Trim();

        var exists = await _context.Sizes
            .AnyAsync(s => s.Id != id && s.Name == name);

        if (exists)
        {
            return Conflict("A size with this name already exists.");
        }

        size.Name = name;

        await _context.SaveChangesAsync();

        return Ok(size);
    }
}