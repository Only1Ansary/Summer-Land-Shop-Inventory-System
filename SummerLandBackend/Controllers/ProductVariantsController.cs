using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.ProductVariants;
using SummerLandBackend.Models;

namespace ShopSystem.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductVariantsController : ControllerBase
{
    private readonly ShopDbContext _context;

    public ProductVariantsController(ShopDbContext context)
    {
        _context = context;
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
            return NotFound("Product variant not found.");
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
            var product = await _context.Products
                .FirstOrDefaultAsync(p => p.Id == dto.ProductId);

            if (product == null)
            {
                return BadRequest("Product not found.");
            }

            var baseBarcode = product.Barcode;

            var suffix = 1;

            while (true)
            {
                var candidateBarcode = $"{baseBarcode}{suffix}";

                var exists = await _context.ProductVariants
                    .AnyAsync(v => v.Barcode == candidateBarcode);

                if (!exists)
                {
                    barcode = candidateBarcode;
                    break;
                }

                suffix++;
            }
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
            return NotFound("Product variant not found.");
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
            return BadRequest("Choose a valid location.");
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

        _context.ProductVariants.Remove(variant);

        await _context.SaveChangesAsync();

        return NoContent();
    }

    /// <summary>
    /// Splits the stock held by the auto-created default variant (no size, no
    /// colour) into one or more new size/colour variants. All of the source
    /// variant's stock must be distributed across the splits; the source variant
    /// is deleted once emptied.
    /// </summary>
    [HttpPost("split")]
    public async Task<ActionResult<IEnumerable<ProductVariantResponseDto>>>
        SplitVariant(SplitProductVariantDto dto)
    {
        if (dto.Splits == null || dto.Splits.Count == 0)
        {
            return BadRequest("Provide at least one split.");
        }

        var source = await _context.ProductVariants
            .Include(v => v.Inventory)
            .Include(v => v.Product)
            .FirstOrDefaultAsync(v => v.Id == dto.SourceVariantId);

        if (source == null)
        {
            return NotFound("Product variant not found.");
        }

        if (source.SizeId != null || source.ColourId != null)
        {
            return BadRequest(
                "Only a default variant (no size or colour) can be split.");
        }

        var hasSales = await _context.InvoiceItems
            .AnyAsync(i => i.ProductVariantId == source.Id);

        if (hasSales)
        {
            return BadRequest(
                "This variant has sales history and cannot be split.");
        }

        // Validate each split line.
        var seen = new HashSet<(int? Size, int? Colour)>();

        foreach (var line in dto.Splits)
        {
            if (line.Quantity <= 0)
            {
                return BadRequest(
                    "Every split quantity must be greater than zero.");
            }

            if (line.LowStockThreshold.HasValue &&
                line.LowStockThreshold.Value < 0)
            {
                return BadRequest(
                    "Low stock threshold cannot be negative.");
            }

            if (!seen.Add((line.SizeId, line.ColourId)))
            {
                return BadRequest(
                    "Each split must target a different size and colour.");
            }

            if (line.SizeId.HasValue)
            {
                var sizeExists = await _context.Sizes
                    .AnyAsync(s => s.Id == line.SizeId.Value);

                if (!sizeExists)
                {
                    return BadRequest("Size does not exist.");
                }
            }

            if (line.ColourId.HasValue)
            {
                var colourExists = await _context.Colours
                    .AnyAsync(c => c.Id == line.ColourId.Value);

                if (!colourExists)
                {
                    return BadRequest("Colour does not exist.");
                }
            }

            var duplicate = await _context.ProductVariants
                .AnyAsync(v =>
                    v.ProductId == source.ProductId &&
                    v.SizeId == line.SizeId &&
                    v.ColourId == line.ColourId);

            if (duplicate)
            {
                return Conflict(
                    "A product variant with the same size and colour already exists.");
            }
        }

        var sourceQuantity = source.Inventory.Sum(i => i.Quantity);
        var splitQuantity = dto.Splits.Sum(l => l.Quantity);

        if (splitQuantity != sourceQuantity)
        {
            return BadRequest(
                $"Split quantities total {splitQuantity} but the variant holds {sourceQuantity}. Distribute all stock.");
        }

        // Snapshot the source locations so we can redistribute stock across them.
        var sourceLocations = source.Inventory
            .Where(i => i.Quantity > 0)
            .Select(i => (i.LocationId, i.Quantity))
            .ToList();

        var createdVariants = new List<ProductVariant>();

        var locationIndex = 0;
        var locationRemaining = sourceLocations.Count > 0
            ? sourceLocations[0].Quantity
            : 0;

        // Barcodes follow the same scheme as the normal variant-creation path:
        // the product barcode plus an incrementing suffix (e.g. 1001, 1002).
        var baseBarcode = source.Product.Barcode;
        var barcodeSuffix = 1;

        foreach (var line in dto.Splits)
        {
            string variantBarcode;

            while (true)
            {
                var candidateBarcode = $"{baseBarcode}{barcodeSuffix}";

                var exists = await _context.ProductVariants
                    .AnyAsync(v => v.Barcode == candidateBarcode);

                if (!exists)
                {
                    variantBarcode = candidateBarcode;
                    barcodeSuffix++;
                    break;
                }

                barcodeSuffix++;
            }

            var variant = new ProductVariant
            {
                ProductId = source.ProductId,
                SizeId = line.SizeId,
                ColourId = line.ColourId,
                BarcodeType = BarcodeType.Internal,
                Barcode = variantBarcode,
                Price = source.Price,
                LowStockThreshold = line.LowStockThreshold ?? source.LowStockThreshold
            };

            _context.ProductVariants.Add(variant);
            await _context.SaveChangesAsync();

            createdVariants.Add(variant);

            // Redistribute this split's quantity across the source locations,
            // preserving per-location totals as much as possible.
            var remaining = line.Quantity;

            while (remaining > 0 && locationIndex < sourceLocations.Count)
            {
                if (locationRemaining == 0)
                {
                    locationIndex++;
                    locationRemaining = locationIndex < sourceLocations.Count
                        ? sourceLocations[locationIndex].Quantity
                        : 0;
                    continue;
                }

                var take = Math.Min(remaining, locationRemaining);
                var locationId = sourceLocations[locationIndex].LocationId;

                var inventory = await _context.Inventory
                    .FirstOrDefaultAsync(i =>
                        i.ProductVariantId == variant.Id &&
                        i.LocationId == locationId);

                if (inventory == null)
                {
                    inventory = new Inventory
                    {
                        ProductVariantId = variant.Id,
                        LocationId = locationId,
                        Quantity = take
                    };

                    _context.Inventory.Add(inventory);
                }
                else
                {
                    inventory.Quantity += take;
                }

                _context.StockMovements.Add(new StockMovement
                {
                    ProductVariantId = variant.Id,
                    LocationId = locationId,
                    QuantityChange = take,
                    Reason = "Variant Split",
                    CreatedAt = DateTime.UtcNow
                });

                remaining -= take;
                locationRemaining -= take;
            }

            await _context.SaveChangesAsync();
        }

        // The source is now fully drained: remove it (and its inventory and
        // purchase/initial-stock movements cascade away).
        _context.ProductVariants.Remove(source);
        await _context.SaveChangesAsync();

        var createdIds = createdVariants.Select(v => v.Id).ToList();

        var response = await _context.ProductVariants
            .Include(v => v.Product)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .Include(v => v.Inventory)
            .Where(v => createdIds.Contains(v.Id))
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

        return Ok(response);
    }
}