using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Products;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly ShopDbContext _context;

    public ProductsController(ShopDbContext context)
    {
        _context = context;
    }

    // GET: api/Products
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ProductResponseDto>>> GetProducts()
    {
        var products = await _context.Products
            .Include(p => p.Category)
            .OrderBy(p => p.Name)
            .Select(p => new ProductResponseDto
            {
                Id = p.Id,
                ModelNumber = p.ModelNumber,
                Name = p.Name,
                CategoryId = p.CategoryId,
                CategoryName = p.Category.Name
            })
            .ToListAsync();

        return Ok(products);
    }

    // GET: api/Products/5
    [HttpGet("{id:int}")]
    public async Task<ActionResult<ProductResponseDto>> GetProduct(int id)
    {
        var product = await _context.Products
            .Include(p => p.Category)
            .Where(p => p.Id == id)
            .Select(p => new ProductResponseDto
            {
                Id = p.Id,
                ModelNumber = p.ModelNumber,
                Name = p.Name,
                CategoryId = p.CategoryId,
                CategoryName = p.Category.Name
            })
            .FirstOrDefaultAsync();

        if (product == null)
        {
            return NotFound();
        }

        return Ok(product);
    }

    // POST: api/Products
    [HttpPost]
    public async Task<ActionResult<ProductResponseDto>> CreateProduct(
        CreateProductDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.ModelNumber))
        {
            return BadRequest("Model number is required.");
        }

        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            return BadRequest("Product name is required.");
        }

        var categoryExists = await _context.Categories
        .AnyAsync(c => c.Id == dto.CategoryId);

        if (!categoryExists)
        {
            return BadRequest("Category does not exist.");
        }

        categoryExists = await _context.Categories
            .AnyAsync(c => c.Id == dto.CategoryId);

        if (!categoryExists)
        {
            return BadRequest("Category does not exist.");
        }

        var modelExists = await _context.Products
            .AnyAsync(p => p.ModelNumber == dto.ModelNumber);

        if (modelExists)
        {
            return Conflict("A product with this model number already exists.");
        }



        var product = new Product
        {
            ModelNumber = dto.ModelNumber.Trim(),
            Name = dto.Name.Trim(),
            CategoryId = dto.CategoryId
        };

        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        var response = await _context.Products
            .Include(p => p.Category)
            .Where(p => p.Id == product.Id)
            .Select(p => new ProductResponseDto
            {
                Id = p.Id,
                ModelNumber = p.ModelNumber,
                Name = p.Name,
                CategoryId = p.CategoryId,
                CategoryName = p.Category.Name
            })
            .FirstAsync();

        return CreatedAtAction(
            nameof(GetProduct),
            new { id = product.Id },
            response);
    }

    // PUT: api/Products/5
    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateProduct(
        int id,
        UpdateProductDto dto)
    {
        var product = await _context.Products.FindAsync(id);

        if (product == null)
        {
            return NotFound();
        }

        var categoryExists = await _context.Categories
            .AnyAsync(c => c.Id == dto.CategoryId);

        if (!categoryExists)
        {
            return BadRequest("Category does not exist.");
        }

        categoryExists = await _context.Categories
            .AnyAsync(c => c.Id == dto.CategoryId);

        if (!categoryExists)
        {
            return BadRequest("Category does not exist.");
        }

        var modelExists = await _context.Products
            .AnyAsync(p =>
                p.ModelNumber == dto.ModelNumber &&
                p.Id != id);

        if (modelExists)
        {
            return Conflict("A product with this model number already exists.");
        }

        product.ModelNumber = dto.ModelNumber.Trim();
        product.Name = dto.Name.Trim();
        product.CategoryId = dto.CategoryId;

        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpGet("search")]
    public async Task<ActionResult<IEnumerable<ProductSearchResponseDto>>> Search(
    [FromQuery] string? query,
    [FromQuery] int? categoryId,
    [FromQuery] int? sizeId,
    [FromQuery] int? colourId)
    {
        var productsQuery = _context.Products
            .Include(p => p.Category)
            .Include(p => p.Variants)
                .ThenInclude(v => v.Size)
            .Include(p => p.Variants)
                .ThenInclude(v => v.Colour)
            .Include(p => p.Variants)
                .ThenInclude(v => v.Inventory)
                    .ThenInclude(i => i.Location)
            .AsQueryable();

        // Text search
        if (!string.IsNullOrWhiteSpace(query))
        {
            query = query.Trim();

            productsQuery = productsQuery.Where(p =>
                p.ModelNumber.Contains(query) ||
                p.Name.Contains(query) ||
                p.Variants.Any(v => v.Barcode.Contains(query)));
        }

        // Category filter
        if (categoryId.HasValue)
        {
            productsQuery = productsQuery.Where(p =>
                p.CategoryId == categoryId.Value);
        }

        // Size filter
        if (sizeId.HasValue)
        {
            productsQuery = productsQuery.Where(p =>
                p.Variants.Any(v => v.SizeId == sizeId.Value));
        }

        // Colour filter
        if (colourId.HasValue)
        {
            productsQuery = productsQuery.Where(p =>
                p.Variants.Any(v => v.ColourId == colourId.Value));
        }

        var products = await productsQuery
            .OrderBy(p => p.ModelNumber)
            .ToListAsync();

        var response = products.Select(p =>
            new ProductSearchResponseDto
            {
                Id = p.Id,

                ModelNumber = p.ModelNumber,

                Name = p.Name,

                CategoryId = p.CategoryId,

                CategoryName = p.Category.Name,

                Variants = p.Variants
                    .Where(v =>
                        (!sizeId.HasValue || v.SizeId == sizeId.Value) &&
                        (!colourId.HasValue || v.ColourId == colourId.Value) &&
                        (
                            string.IsNullOrWhiteSpace(query) ||
                            v.Barcode.Contains(query) ||
                            p.ModelNumber.Contains(query) ||
                            p.Name.Contains(query)
                        ))
                    .Select(v =>
                    {
                        var totalQuantity =
                            v.Inventory.Sum(i => i.Quantity);

                        return new ProductSearchVariantDto
                        {
                            Id = v.Id,

                            SizeId = v.SizeId,
                            SizeName = v.Size?.Name,

                            ColourId = v.ColourId,
                            ColourName = v.Colour?.Name,

                            Barcode = v.Barcode,

                            Price = v.Price,

                            LowStockThreshold =
                                v.LowStockThreshold,

                            TotalQuantity = totalQuantity,

                            IsLowStock =
                                totalQuantity <= v.LowStockThreshold,

                            Locations = v.Inventory
                                .Select(i =>
                                    new VariantLocationStockDto
                                    {
                                        LocationId = i.LocationId,

                                        LocationName =
                                            i.Location.Name,

                                        Quantity = i.Quantity
                                    })
                                .ToList()
                        };
                    })
                    .ToList()
            })
            .ToList();

        return Ok(response);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteProduct(int id)
    {
        var product = await _context.Products
            .FirstOrDefaultAsync(p => p.Id == id);

        if (product == null)
        {
            return NotFound("Product not found.");
        }

        var hasVariants = await _context.ProductVariants
            .AnyAsync(v => v.ProductId == id);

        if (hasVariants)
        {
            return Conflict(
                "Cannot delete a product that has product variants.");
        }

        _context.Products.Remove(product);

        await _context.SaveChangesAsync();

        return NoContent();
    }
}