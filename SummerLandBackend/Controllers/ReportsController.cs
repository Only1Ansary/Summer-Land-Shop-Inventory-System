using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Reports;
using SummerLandBackend.Models;
using SummerLandBackend.Services;

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
    [FromQuery] DateTime? to,
    CancellationToken ct)
    {
        var fromDate = QueryDateRange.Start(from);
        var toDate = QueryDateRange.End(to);

        if (fromDate > toDate)
            return BadRequest("From date cannot be greater than To date.");

        // ---------- Sales (headline figures aggregated in SQL) ----------
        var invoices = _context.Invoices.AsNoTracking()
            .Where(i => i.CreatedAt >= fromDate && i.CreatedAt <= toDate);

        var invoiceCount = await invoices.CountAsync(ct);

        // Net revenue is the sum of the invoice totals: items at real price,
        // minus the invoice discount, minus returns at real price, floored
        // at zero. This reconciles with the Sale Invoices screen.
        var netSales = await invoices
            .SumAsync(i => (decimal?)i.TotalAmount, ct) ?? 0m;

        // Invoice lines are already net of returns (ReturnsController reduces them)
        var lines = invoices.SelectMany(i => i.Items);

        var retainedQuantity = await lines.SumAsync(i => (int?)i.Quantity, ct) ?? 0;

        // ---------- Sales by category ----------
        // Each invoice's discount is spread pro-rata over its lines, so the
        // category slices add up to exactly the Net Revenue figure.
        var invoiceLines = await lines
            .Select(l => new
            {
                l.InvoiceId,
                l.Quantity,
                l.TotalPrice,
                CategoryName = l.ProductVariant.Product.Category.Name
            })
            .ToListAsync(ct);

        var lineTotalByInvoice = invoiceLines
            .GroupBy(l => l.InvoiceId)
            .ToDictionary(
                group => group.Key,
                group => group.Sum(l => l.TotalPrice));

        var netByInvoice = await invoices
            .ToDictionaryAsync(i => i.Id, i => i.TotalAmount, ct);

        var categorySales = invoiceLines
            .GroupBy(l => l.CategoryName)
            .Select(group => new CategorySalesDto
            {
                CategoryName = group.Key,
                QuantitySold = group.Sum(l => l.Quantity),
                Amount = group.Sum(l =>
                {
                    var lineTotal = lineTotalByInvoice[l.InvoiceId];

                    return lineTotal > 0
                        ? l.TotalPrice * netByInvoice[l.InvoiceId] / lineTotal
                        : l.TotalPrice;
                })
            })
            .OrderByDescending(g => g.Amount)
            .ToList();

        // ---------- Returns against the period's invoices ----------
        var returns = _context.Returns.AsNoTracking()
            .Where(r => invoices.Any(i => i.Id == r.InvoiceId));

        var returnsQuantity = await returns.SumAsync(r => (int?)r.Quantity, ct) ?? 0;
        var returnsAmount = await returns.SumAsync(r => (decimal?)r.TotalAmount, ct) ?? 0m;

        // ---------- Purchases (small set, no Includes) ----------
        // Filtered by the invoice's own Date (when the purchase happened),
        // not CreatedAt (when the row was entered). toDate already covers the
        // whole day when a bare date is supplied.
        var purchases = await _context.PurchaseInvoices.AsNoTracking()
            .Where(p => p.Date >= fromDate && p.Date <= toDate)
            .ToListAsync(ct);

        var purchaseTotalCost = purchases.Sum(p => p.TotalCost);

        // ---------- Suppliers (current balance) ----------
        var supplierCount = await _context.Suppliers.CountAsync(ct);
        var supplierDebtTotal = await _context.Suppliers.SumAsync(s => (decimal?)s.Debt, ct) ?? 0m;

        // ---------- Figures ----------
        var itemsSold = retainedQuantity;

        var grossSales = netSales + returnsAmount;
        // Profit accounts for the purchase cost actually incurred in the period.
        var profit = netSales - purchases.Sum(p => p.TotalPaid);

        return Ok(new SalesReportDto
        {
            From = fromDate,
            To = toDate,

            InvoiceCount = invoiceCount,
            ItemsSold = itemsSold,
            GrossSales = grossSales,
            ItemsReturned = returnsQuantity,
            ReturnsAmount = returnsAmount,
            NetSales = netSales,

            PurchaseInvoiceCount = purchases.Count,
            PurchaseTotalCost = purchaseTotalCost,
            PurchaseTotalPaid = purchases.Sum(p => p.TotalPaid),
            PurchaseDebt = purchases.Sum(p => p.Debt),

            SupplierCount = supplierCount,
            SupplierDebtTotal = supplierDebtTotal,

            Profit = profit,

            CategorySales = categorySales
        });
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
    public async Task<ActionResult<LowStockReportDto>> GetLowStockReport(
        [FromQuery] int? categoryId)
    {
        IQueryable<ProductVariant> query = _context.ProductVariants
            .Include(v => v.Product)
                .ThenInclude(p => p.Category)
            .Include(v => v.Size)
            .Include(v => v.Colour)
            .Include(v => v.Inventory)
                .ThenInclude(i => i.Location);

        if (categoryId.HasValue)
        {
            query = query.Where(v =>
                v.Product.CategoryId == categoryId.Value);
        }

        var variants = await query.ToListAsync();

        var lowStockItems = variants
            .Select(v =>
            {
                var totalQuantity = v.Inventory.Sum(i => i.Quantity);

                return new LowStockItemDto
                {
                    ProductVariantId = v.Id,

                    ModelNumber = v.Product.ModelNumber,
                    ProductName = v.Product.Name,

                    CategoryId = v.Product.CategoryId,
                    CategoryName = v.Product.Category.Name,

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
        var fromDate = QueryDateRange.Start(from);

        var toDate = QueryDateRange.End(to);

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
        var fromDate = QueryDateRange.Start(from);

        var toDate = QueryDateRange.End(to);

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
            // Lines are already net of returns (ReturnsController reduces the
            // quantity and removes the line once it is fully returned), so
            // these sums are what was actually kept.
            .OrderByDescending(i => i.TotalQuantitySold)
            // Rank strictly by units sold. Revenue must not break ties,
            // otherwise equal-quantity products look revenue-sorted.
            .ThenBy(i => i.ProductName)
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