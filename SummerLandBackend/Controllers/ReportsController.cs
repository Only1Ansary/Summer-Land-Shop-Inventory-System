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
        var (fromDate, toDate) = QueryDateRange.Bounds(from, to);

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

        // Cost of goods sold: what the items we actually kept (net of returns)
        // cost us, using each variant's cost price.
        var costOfGoodsSold = await lines
            .SumAsync(l => (decimal?)(l.Quantity * l.ProductVariant.PurchasePrice), ct) ?? 0m;

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

        // ---------- Customers (collections in this period, debt today) ----------
        var customerCount = await _context.Customers.CountAsync(ct);

        var periodPayments = await _context.CustomerPayments.AsNoTracking()
            .Where(p => p.PaidAt >= fromDate && p.PaidAt <= toDate)
            .GroupBy(p => p.Method)
            .Select(g => new
            {
                Method = (int)g.Key,
                Count = g.Count(),
                Amount = g.Sum(p => p.Amount)
            })
            .ToListAsync(ct);

        var customerSalesTotal = await _context.Invoices.AsNoTracking()
            .Where(i => i.CustomerId != null)
            .SumAsync(i => (decimal?)i.TotalAmount, ct) ?? 0m;

        // Anonymous (fully paid) sales have a payment but no customer, so
        // they must not reduce the outstanding balance owed by customers.
        var customerPaidAllTime = await _context.CustomerPayments.AsNoTracking()
            .Where(p => p.CustomerId != null)
            .SumAsync(p => (decimal?)p.Amount, ct) ?? 0m;

        var customerDebtTotal = Math.Max(0,
            customerSalesTotal - customerPaidAllTime);

        // ---------- Staff payments (salary + bonuses settled) ----------
        var employeePayments = await _context.EmployeePayments.AsNoTracking()
            .Where(p => p.PaidAt >= fromDate && p.PaidAt <= toDate)
            .ToListAsync(ct);

        var employeePaymentCount = employeePayments.Count;
        var employeePaymentTotal = employeePayments.Sum(p => p.Amount);

        // ---------- Figures ----------
        var itemsSold = retainedQuantity;

        var grossSales = netSales + returnsAmount;
        // Real profit: revenue minus the cost of what was sold, minus staff
        // payments. Stock purchases are NOT subtracted here (that would count
        // stock still on the shelf as a cost); the cost of the items sold is
        // already covered by costOfGoodsSold.
        var grossProfit = netSales - costOfGoodsSold;
        var profit = grossProfit - employeePaymentTotal;

        // ---------- Daily sales (one entry per day, empty days included) ----------
        // Bucket by the day the user sees, not by the UTC date the row was
        // stored under. The configured IANA zone resolves EET/EEST per instant.
        var invoiceDays = await invoices
            .Select(i => new { i.CreatedAt, i.TotalAmount })
            .ToListAsync(ct);

        var byDay = invoiceDays
            .GroupBy(i => AppTimeZone.Current.ToLocal(i.CreatedAt).Date)
            .ToDictionary(
                g => g.Key,
                g => new { Net = g.Sum(i => i.TotalAmount), Count = g.Count() });

        var dailySales = new List<DailySalesDto>();
        for (var day = AppTimeZone.Current.ToLocal(fromDate).Date;
             day <= AppTimeZone.Current.ToLocal(toDate).Date;
             day = day.AddDays(1))
        {
            byDay.TryGetValue(day, out var entry);
            dailySales.Add(new DailySalesDto
            {
                // A calendar-day label, not an instant; the JSON converter
                // still writes it as an unambiguous ISO 8601 UTC value.
                Date = DateTime.SpecifyKind(day, DateTimeKind.Unspecified),
                NetSales = entry?.Net ?? 0m,
                InvoiceCount = entry?.Count ?? 0
            });
        }

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

            EmployeePaymentCount = employeePaymentCount,
            EmployeePaymentTotal = employeePaymentTotal,

            SupplierCount = supplierCount,
            SupplierDebtTotal = supplierDebtTotal,

            CustomerCount = customerCount,
            CustomerPaymentCount = periodPayments.Sum(p => p.Count),
            CustomerPaymentsTotal = periodPayments.Sum(p => p.Amount),
            CustomerDebtTotal = customerDebtTotal,
            PaymentsByMethod = periodPayments
                .OrderBy(p => p.Method)
                .Select(p => new PaymentMethodTotalDto
                {
                    Method = p.Method,
                    MethodName = ((PaymentMethod)p.Method).ToString(),
                    Amount = p.Amount
                })
                .ToList(),

            CostOfGoodsSold = costOfGoodsSold,
            GrossProfit = grossProfit,
            Profit = profit,
            DailySales = dailySales,

            CategorySales = categorySales
        });
    }

    [HttpGet("employees")]
    public async Task<ActionResult<EmployeesReportDto>> GetEmployeesReport(
        [FromQuery] int? year,
        [FromQuery] int? month,
        CancellationToken ct)
    {
        var today = AppTimeZone.Current.Today;
        var reportYear = year ?? today.Year;
        var reportMonth = month ?? today.Month;

        if (reportMonth < 1 || reportMonth > 12)
        {
            return BadRequest("Month must be between 1 and 12.");
        }

        var monthStart = AppTimeZone.Current.StartOfDayUtc(
            new DateTime(reportYear, reportMonth, 1));
        var monthEnd = AppTimeZone.Current.StartOfDayUtc(
            new DateTime(reportYear, reportMonth, 1).AddMonths(1));

        var employees = await _context.Employees.AsNoTracking()
            .OrderBy(e => e.Name)
            .ToListAsync(ct);

        // The sales and target flag for the month being reported on.
        var months = await _context.EmployeeMonths.AsNoTracking()
            .Where(m => m.Year == reportYear && m.Month == reportMonth)
            .ToListAsync(ct);
        var monthByEmployee = months
            .GroupBy(m => m.EmployeeId)
            .ToDictionary(g => g.Key, g => g.Last());

        var monthPayments = await _context.EmployeePayments.AsNoTracking()
            .Where(p => p.PaidAt >= monthStart && p.PaidAt < monthEnd)
            .GroupBy(p => p.EmployeeId)
            .Select(g => new
            {
                EmployeeId = g.Key,
                Count = g.Count(),
                Total = g.Sum(p => p.Amount)
            })
            .ToListAsync(ct);

        var allPayments = await _context.EmployeePayments.AsNoTracking()
            .GroupBy(p => p.EmployeeId)
            .Select(g => new
            {
                EmployeeId = g.Key,
                Total = g.Sum(p => p.Amount)
            })
            .ToListAsync(ct);

        var monthByEmployeePay = monthPayments
            .ToDictionary(p => p.EmployeeId);
        var allByEmployee = allPayments
            .ToDictionary(p => p.EmployeeId);

        var items = employees
            .Select(e =>
            {
                monthByEmployee.TryGetValue(e.Id, out var monthRecord);
                allByEmployee.TryGetValue(e.Id, out var all);
                monthByEmployeePay.TryGetValue(e.Id, out var monthPay);

                var sales = monthRecord?.TotalSales ?? 0m;
                var achieved = monthRecord?.AchievedTarget ?? false;
                var paidInMonth = monthPay?.Total ?? 0m;
                var bonusAmount = EmployeeCompensation.BonusAmount(e, sales);

                return new EmployeeReportItemDto
                {
                    EmployeeId = e.Id,
                    Name = e.Name,
                    BonusType = (int)e.BonusType,
                    Salary = e.Salary,
                    Target = e.Target,
                    Bonus = e.Bonus,
                    BonusAmount = bonusAmount,
                    TotalSales = sales,
                    AchievedTarget = achieved,
                    PaymentCountInMonth = monthPay?.Count ?? 0,
                    PaymentTotalInMonth = paidInMonth,
                    TotalPaid = all?.Total ?? 0m,
                    MonthlyObligation = e.Salary + bonusAmount,
                    LeftToPay = EmployeeCompensation.LeftToPay(e, sales, paidInMonth),
                };
            })
            .ToList();

        var topSales = items.Count > 0
            ? items.Max(i => i.TotalSales)
            : 0m;

        var employeeOfTheMonth = topSales > 0
            ? items
                .Where(i => i.TotalSales == topSales)
                .Select(i => new EmployeeOfMonthDto
                {
                    EmployeeId = i.EmployeeId,
                    Name = i.Name,
                    TotalSales = i.TotalSales,
                })
                .ToList()
            : new List<EmployeeOfMonthDto>();

        var response = new EmployeesReportDto
        {
            Year = reportYear,
            Month = reportMonth,

            EmployeeCount = employees.Count,

            TotalMonthlySalaries = employees.Sum(e => e.Salary),
            TotalBonusOwed = items.Sum(i => i.BonusAmount),
            TotalSales = items.Sum(i => i.TotalSales),
            TargetMetCount = items.Count(i => i.AchievedTarget),

            PaymentCountInMonth = monthPayments.Sum(p => p.Count),
            PaymentTotalInMonth = monthPayments.Sum(p => p.Total),
            TotalPaid = allPayments.Sum(p => p.Total),

            TotalLeftToPay = items.Sum(i => i.LeftToPay),

            EmployeeOfTheMonth = employeeOfTheMonth,

            Employees = items
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
                    Price = v.SellingPrice,

                    LowStockThreshold = v.LowStockThreshold,
                    TotalQuantity = totalQuantity,
                    InventoryValue = totalQuantity * v.SellingPrice,

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
                    Price = v.SellingPrice,

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
        var (fromDate, toDate) = QueryDateRange.Bounds(from, to);

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
    [FromQuery] int? categoryId)
    {
        var (fromDate, toDate) = QueryDateRange.Bounds(from, to);

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

        if (categoryId.HasValue)
        {
            query = query.Where(i =>
                i.ProductVariant.Product.CategoryId == categoryId.Value);
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