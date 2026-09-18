using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Reports;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReportsController : ControllerBase
{
    private readonly ShopDbContext _context;

    public ReportsController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet("sales")]
    public async Task<ActionResult<SalesReportDto>> GetSalesReport(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to)
    {
        var fromDate = from?.ToUniversalTime()
    ?? DateTime.UtcNow.Date;

        var toDate = to?.ToUniversalTime()
            ?? DateTime.UtcNow;

        if (to.HasValue && to.Value.TimeOfDay == TimeSpan.Zero)
        {
            toDate = toDate.Date.AddDays(1).AddTicks(-1);
        }

        if (fromDate > toDate)
        {
            return BadRequest(
                "From date cannot be greater than To date.");
        }

        var invoices = await _context.Invoices
            .Include(i => i.Items)
            .Where(i =>
                i.CreatedAt >= fromDate &&
                i.CreatedAt <= toDate)
            .ToListAsync();

        var returns = await _context.Returns
            .Where(r =>
                r.CreatedAt >= fromDate &&
                r.CreatedAt <= toDate)
            .ToListAsync();

        var invoiceCount = invoices.Count;

        var itemsSold = invoices
            .SelectMany(i => i.Items)
            .Sum(i => i.Quantity);

        var grossSales = invoices
            .Sum(i => i.TotalAmount);

        var itemsReturned = returns
            .Sum(r => r.Quantity);

        var returnsAmount = returns
            .Sum(r => r.TotalAmount);

        var netSales = grossSales - returnsAmount;

        var response = new SalesReportDto
        {
            From = fromDate,
            To = toDate,

            InvoiceCount = invoiceCount,

            ItemsSold = itemsSold,

            GrossSales = grossSales,

            ItemsReturned = itemsReturned,

            ReturnsAmount = returnsAmount,

            NetSales = netSales
        };

        return Ok(response);
    }

    [HttpGet("inventory")]
    public async Task<ActionResult<InventoryReportDto>> GetInventoryReport()
    {
        var variants = await _context.ProductVariants
            .Include(v => v.Product)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .Include(v => v.Inventory)
                .ThenInclude(i => i.Location)
            .OrderBy(v => v.Product.ModelNumber)
            .ToListAsync();

        var items = variants
            .Select(v =>
            {
                var totalQuantity = v.Inventory.Sum(i => i.Quantity);

                return new InventoryReportItemDto
                {
                    ProductVariantId = v.Id,
                    ModelNumber = v.Product.ModelNumber,
                    ProductName = v.Product.Name,

                    SizeName = v.Size?.Name,
                    ColourName = v.Colour?.Name,

                    Barcode = v.Barcode,
                    Price = v.Price,

                    LowStockThreshold = v.LowStockThreshold,
                    TotalQuantity = totalQuantity,
                    InventoryValue = totalQuantity * v.Price,

                    IsLowStock = totalQuantity <= v.LowStockThreshold,

                    Locations = v.Inventory
                        .Select(i => new InventoryLocationDto
                        {
                            LocationId = i.LocationId,
                            LocationName = i.Location.Name,
                            Quantity = i.Quantity
                        })
                        .ToList()
                };
            })
            .ToList();

        var response = new InventoryReportDto
        {
            TotalVariants = items.Count,

            TotalQuantity = items.Sum(i => i.TotalQuantity),

            TotalInventoryValue = items.Sum(i => i.InventoryValue),

            LowStockVariants = items.Count(i => i.IsLowStock),

            Items = items
        };

        return Ok(response);
    }

    [HttpGet("low-stock")]
    public async Task<ActionResult<LowStockReportDto>> GetLowStockReport()
    {
        var variants = await _context.ProductVariants
            .Include(v => v.Product)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .Include(v => v.Inventory)
                .ThenInclude(i => i.Location)
            .ToListAsync();

        var lowStockItems = variants
            .Select(v =>
            {
                var totalQuantity = v.Inventory.Sum(i => i.Quantity);

                return new LowStockItemDto
                {
                    ProductVariantId = v.Id,

                    ModelNumber = v.Product.ModelNumber,
                    ProductName = v.Product.Name,

                    SizeName = v.Size?.Name,
                    ColourName = v.Colour?.Name,

                    Barcode = v.Barcode,
                    Price = v.Price,

                    LowStockThreshold = v.LowStockThreshold,
                    TotalQuantity = totalQuantity,

                    Locations = v.Inventory
                        .Select(i => new LowStockLocationDto
                        {
                            LocationId = i.LocationId,
                            LocationName = i.Location.Name,
                            Quantity = i.Quantity
                        })
                        .ToList()
                };
            })
            .Where(v => v.TotalQuantity <= v.LowStockThreshold)
            .OrderBy(v => v.TotalQuantity)
            .ThenBy(v => v.ModelNumber)
            .ToList();

        var response = new LowStockReportDto
        {
            Count = lowStockItems.Count,
            Items = lowStockItems
        };

        return Ok(response);
    }

    [HttpGet("stock-movements")]
    public async Task<ActionResult<StockMovementReportDto>> GetStockMovementReport(
    [FromQuery] DateTime? from,
    [FromQuery] DateTime? to,
    [FromQuery] int? locationId,
    [FromQuery] int? productVariantId)
    {
        var fromDate = from?.ToUniversalTime()
    ?? DateTime.UtcNow.Date;

        var toDate = to?.ToUniversalTime()
            ?? DateTime.UtcNow;

        if (to.HasValue && to.Value.TimeOfDay == TimeSpan.Zero)
        {
            toDate = toDate.Date.AddDays(1).AddTicks(-1);
        }

        if (fromDate > toDate)
        {
            return BadRequest(
                "From date cannot be greater than To date.");
        }

        var query = _context.StockMovements
            .Include(s => s.ProductVariant)
                .ThenInclude(v => v.Product)
            .Include(s => s.ProductVariant)
                .ThenInclude(v => v.Size)
            .Include(s => s.ProductVariant)
                .ThenInclude(v => v.Colour)
            .Include(s => s.Location)
            .Where(s =>
                s.CreatedAt >= fromDate &&
                s.CreatedAt <= toDate)
            .AsQueryable();

        if (locationId.HasValue)
        {
            query = query.Where(s =>
                s.LocationId == locationId.Value);
        }

        if (productVariantId.HasValue)
        {
            query = query.Where(s =>
                s.ProductVariantId == productVariantId.Value);
        }

        var movements = await query
            .OrderByDescending(s => s.CreatedAt)
            .ToListAsync();

        var items = movements
            .Select(s => new StockMovementReportItemDto
            {
                Id = s.Id,

                ProductVariantId = s.ProductVariantId,

                ModelNumber = s.ProductVariant.Product.ModelNumber,
                ProductName = s.ProductVariant.Product.Name,

                SizeName = s.ProductVariant.Size?.Name,
                ColourName = s.ProductVariant.Colour?.Name,

                LocationId = s.LocationId,
                LocationName = s.Location.Name,

                QuantityChange = s.QuantityChange,

                Reason = s.Reason,

                CreatedAt = s.CreatedAt
            })
            .ToList();

        var response = new StockMovementReportDto
        {
            From = fromDate,
            To = toDate,

            MovementCount = items.Count,

            Items = items
        };

        return Ok(response);
    }

    [HttpGet("best-selling")]
    public async Task<ActionResult<BestSellingProductsReportDto>> GetBestSellingProductsReport(
    [FromQuery] DateTime? from,
    [FromQuery] DateTime? to,
    [FromQuery] int? locationId)
    {
        var fromDate = from?.ToUniversalTime()
            ?? DateTime.UtcNow.Date;

        var toDate = to?.ToUniversalTime()
            ?? DateTime.UtcNow;

        if (fromDate > toDate)
        {
            return BadRequest(
                "From date cannot be greater than To date.");
        }

        var query = _context.InvoiceItems
            .Include(i => i.Invoice)
            .Include(i => i.ProductVariant)
                .ThenInclude(v => v.Product)
            .Where(i =>
                i.Invoice.CreatedAt >= fromDate &&
                i.Invoice.CreatedAt <= toDate)
            .AsQueryable();

        if (locationId.HasValue)
        {
            query = query.Where(i =>
                i.Invoice.LocationId == locationId.Value);
        }

        var items = await query
            .GroupBy(i => new
            {
                i.ProductVariant.ProductId,
                i.ProductVariant.Product.ModelNumber,
                i.ProductVariant.Product.Name
            })
            .Select(g => new BestSellingProductDto
            {
                ProductId = g.Key.ProductId,

                ModelNumber = g.Key.ModelNumber,
                ProductName = g.Key.Name,

                TotalQuantitySold = g.Sum(i => i.Quantity),

                TotalSales = g.Sum(i => i.TotalPrice)
            })
            .OrderByDescending(i => i.TotalQuantitySold)
            .ThenByDescending(i => i.TotalSales)
            .ToListAsync();

        var response = new BestSellingProductsReportDto
        {
            From = fromDate,
            To = toDate,
            Items = items
        };

        return Ok(response);
    }
}