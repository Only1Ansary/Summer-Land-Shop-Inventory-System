using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.Models;
using SummerLandBackend.DTOs.Categories;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoriesController : ControllerBase
{
    private readonly ShopDbContext _context;

    public CategoriesController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Category>>> GetCategories()
    {
        return await _context.Categories
            .OrderBy(c => c.Id)
            .ToListAsync();
    }

    [HttpPost]
    public async Task<ActionResult<Category>> CreateCategory(Category category)
    {
        if (string.IsNullOrWhiteSpace(category.Name))
        {
            return BadRequest("Category name is required.");
        }

        var exists = await _context.Categories
            .AnyAsync(c => c.Name == category.Name);

        if (exists)
        {
            return Conflict("Category already exists.");
        }

        _context.Categories.Add(category);
        await _context.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetCategories),
            new { id = category.Id },
            category);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCategory(
    int id,
    UpdateCategoryDto dto)
    {
        var category = await _context.Categories
            .FirstOrDefaultAsync(c => c.Id == id);

        if (category == null)
        {
            return NotFound("Category not found.");
        }

        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            return BadRequest("Category name is required.");
        }

        var name = dto.Name.Trim();

        var exists = await _context.Categories
            .AnyAsync(c => c.Id != id && c.Name == name);

        if (exists)
        {
            return Conflict("A category with this name already exists.");
        }

        category.Name = name;

        await _context.SaveChangesAsync();

        return Ok(category);
    }
}