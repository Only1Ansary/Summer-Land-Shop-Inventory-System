using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.ProductVariants;
using SummerLandBackend.Models;
using SummerLandBackend.Services;

namespace ShopSystem.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductVariantsController : ControllerBase
{
    private readonly ShopDbContext _context;
    private readonly BarcodeService _barcodeService;

    public ProductVariantsController(
        ShopDbContext context,
        BarcodeService barcodeService)
    {
        _context = context;
        _barcodeService = barcodeService;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<ProductVariantResponseDto>>> GetVariants()
    {
        var variants = await _context.ProductVariants
            .Include(v => v.Product)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .Include(v => v.Inventory)
            .Select(v => new ProductVariantResponseDto
            {
                Id = v.Id,
                ProductId = v.ProductId,
                ModelNumber = v.Product.ModelNumber,
                ProductName = v.Product.Name,
                SizeId = v.SizeId,
                SizeName = v.Size != null ? v.Size.Name : null,
                ColourId = v.ColourId,
                ColourName = v.Colour != null ? v.Colour.Name : null,
                BarcodeType = v.BarcodeType,
                Barcode = v.Barcode,
                Price = v.Price,
                LowStockThreshold = v.LowStockThreshold,
                TotalQuantity = v.Inventory.Sum(i => i.Quantity),
                IsLowStock = v.Inventory.Sum(i => i.Quantity)
                               <= v.LowStockThreshold
            })
            .ToListAsync();

        return Ok(variants);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<ProductVariantResponseDto>> GetVariant(int id)
    {
        var variant = await _context.ProductVariants
            .Include(v => v.Product)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .Include(v => v.Inventory)
            .Where(v => v.Id == id)
            .Select(v => new ProductVariantResponseDto
            {
                Id = v.Id,
                ProductId = v.ProductId,
                ModelNumber = v.Product.ModelNumber,
                ProductName = v.Product.Name,
                SizeId = v.SizeId,
                SizeName = v.Size != null ? v.Size.Name : null,
                ColourId = v.ColourId,
                ColourName = v.Colour != null ? v.Colour.Name : null,
                BarcodeType = v.BarcodeType,
                Barcode = v.Barcode,
                Price = v.Price,
                LowStockThreshold = v.LowStockThreshold,
                TotalQuantity = v.Inventory.Sum(i => i.Quantity),
                IsLowStock = v.Inventory.Sum(i => i.Quantity)
                   <= v.LowStockThreshold
            })
            .FirstOrDefaultAsync();

        if (variant == null)
        {
            return NotFound();
        }

        return Ok(variant);
    }

    [HttpPost]
    public async Task<ActionResult<ProductVariantResponseDto>> CreateVariant(
        CreateProductVariantDto dto)
    {
        // Product must exist
        var productExists = await _context.Products
            .AnyAsync(p => p.Id == dto.ProductId);

        if (!productExists)
        {
            return BadRequest("Product does not exist.");
        }

        // Size must exist if provided
        if (dto.SizeId.HasValue)
        {
            var sizeExists = await _context.Sizes
                .AnyAsync(s => s.Id == dto.SizeId.Value);

            if (!sizeExists)
            {
                return BadRequest("Size does not exist.");
            }
        }

        // Colour must exist if provided
        if (dto.ColourId.HasValue)
        {
            var colourExists = await _context.Colours
                .AnyAsync(c => c.Id == dto.ColourId.Value);

            if (!colourExists)
            {
                return BadRequest("Colour does not exist.");
            }
        }

        // Validate price
        if (dto.Price < 0)
        {
            return BadRequest("Price cannot be negative.");
        }

        // Validate threshold
        if (dto.LowStockThreshold < 0)
        {
            return BadRequest("Low stock threshold cannot be negative.");
        }

        // Barcode must be unique
        string barcode;

        if (dto.BarcodeType == BarcodeType.Internal)
        {
            barcode = await _barcodeService.GenerateInternalBarcodeAsync();
        }
        else if (dto.BarcodeType == BarcodeType.Manufacturer)
        {
            if (string.IsNullOrWhiteSpace(dto.Barcode))
            {
                return BadRequest(
                    "Manufacturer barcode is required.");
            }

            barcode = dto.Barcode.Trim();

            var barcodeExists = await _context.ProductVariants
                .AnyAsync(v => v.Barcode == barcode);

            if (barcodeExists)
            {
                return Conflict(
                    "A variant with this barcode already exists.");
            }
        }
        else
        {
            return BadRequest("Invalid barcode type.");
        }

        var duplicateVariant = await _context.ProductVariants
        .AnyAsync(v =>
            v.ProductId == dto.ProductId &&
            v.SizeId == dto.SizeId &&
            v.ColourId == dto.ColourId);

        if (duplicateVariant)
        {
            return Conflict(
                "A product variant with the same product, size, and colour already exists.");
        }

        var variant = new ProductVariant
        {
            ProductId = dto.ProductId,
            SizeId = dto.SizeId,
            ColourId = dto.ColourId,
            BarcodeType = dto.BarcodeType,
            Barcode = barcode,
            Price = dto.Price,
            LowStockThreshold = dto.LowStockThreshold
        };

        _context.ProductVariants.Add(variant);

        await _context.SaveChangesAsync();

        return await GetVariant(variant.Id);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateVariant(int id, UpdateProductVariantDto dto)
    {

        var variant = await _context.ProductVariants
            .FirstOrDefaultAsync(v => v.Id == id);

        if (variant == null)
        {
            return NotFound();
        }

        if (dto.SizeId.HasValue)
        {
            var sizeExists = await _context.Sizes
                .AnyAsync(s => s.Id == dto.SizeId.Value);

            if (!sizeExists)
            {
                return BadRequest("Size does not exist.");
            }
        }

        if (dto.ColourId.HasValue)
        {
            var colourExists = await _context.Colours
                .AnyAsync(c => c.Id == dto.ColourId.Value);

            if (!colourExists)
            {
                return BadRequest("Colour does not exist.");
            }
        }

        if (dto.Price < 0)
        {
            return BadRequest("Price cannot be negative.");
        }

        if (dto.LowStockThreshold < 0)
        {
            return BadRequest("Low stock threshold cannot be negative.");
        }

        if (!string.IsNullOrWhiteSpace(dto.Barcode))
        {
            var barcode = dto.Barcode.Trim();

            var barcodeExists = await _context.ProductVariants
                .AnyAsync(v =>
                    v.Barcode == barcode &&
                    v.Id != id);

            if (barcodeExists)
            {
                return Conflict("A variant with this barcode already exists.");
            }

            variant.Barcode = barcode;
        }
        else
        {
            variant.Barcode = string.Empty;
        }

        variant.SizeId = dto.SizeId;
        variant.ColourId = dto.ColourId;
        variant.Price = dto.Price;
        variant.LowStockThreshold = dto.LowStockThreshold;

        var duplicateVariant = await _context.ProductVariants
    .AnyAsync(v =>
        v.Id != id &&
        v.ProductId == variant.ProductId &&
        v.SizeId == dto.SizeId &&
        v.ColourId == dto.ColourId);

        if (duplicateVariant)
        {
            return Conflict(
                "A product variant with the same product, size, and colour already exists.");
        }

        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpGet("barcode/{barcode}")]
    public async Task<ActionResult<ProductVariantBarcodeResponseDto>> GetByBarcode(
    string barcode,
    [FromQuery] int locationId)
    {
        if (string.IsNullOrWhiteSpace(barcode))
        {
            return BadRequest("Barcode is required.");
        }

        if (locationId <= 0)
        {
            return BadRequest("LocationId must be valid.");
        }

        var variant = await _context.ProductVariants
            .Include(v => v.Product)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .Include(v => v.Inventory)
            .FirstOrDefaultAsync(v => v.Barcode == barcode);

        if (variant == null)
        {
            return NotFound("Product with this barcode was not found.");
        }

        var locationQuantity = variant.Inventory
            .Where(i => i.LocationId == locationId)
            .Select(i => i.Quantity)
            .FirstOrDefault();

        var totalQuantity = variant.Inventory
            .Sum(i => i.Quantity);

        var response = new ProductVariantBarcodeResponseDto
        {
            Id = variant.Id,
            ModelNumber = variant.Product.ModelNumber,
            ProductName = variant.Product.Name,

            SizeId = variant.SizeId,
            SizeName = variant.Size?.Name,

            ColourId = variant.ColourId,
            ColourName = variant.Colour?.Name,

            Barcode = variant.Barcode,

            Price = variant.Price,

            TotalQuantity = totalQuantity,
            LocationQuantity = locationQuantity
        };

        return Ok(response);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteProductVariant(int id)
    {
        var variant = await _context.ProductVariants
            .FirstOrDefaultAsync(v => v.Id == id);

        if (variant == null)
        {
            return NotFound("Product variant not found.");
        }

        var hasInvoiceItems = await _context.InvoiceItems
            .AnyAsync(i => i.ProductVariantId == id);

        if (hasInvoiceItems)
        {
            return Conflict(
                "Cannot delete a product variant that has sales history.");
        }

        var hasReturns = await _context.Returns
            .AnyAsync(r => r.ProductVariantId == id);

        if (hasReturns)
        {
            return Conflict(
                "Cannot delete a product variant that has return history.");
        }

        var hasMovements = await _context.StockMovements
            .AnyAsync(s => s.ProductVariantId == id);

        if (hasMovements)
        {
            return Conflict(
                "Cannot delete a product variant that has stock movement history.");
        }

        var hasTransfers = await _context.StockTransfers
            .AnyAsync(s => s.ProductVariantId == id);

        if (hasTransfers)
        {
            return Conflict(
                "Cannot delete a product variant that has stock transfer history.");
        }

        _context.ProductVariants.Remove(variant);

        await _context.SaveChangesAsync();

        return NoContent();
    }
}