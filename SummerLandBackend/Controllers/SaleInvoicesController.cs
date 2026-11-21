using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Customers;
using SummerLandBackend.DTOs.SaleInvoices;
using SummerLandBackend.Models;
using SummerLandBackend.Services;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SaleInvoicesController : ControllerBase
{
    private readonly ShopDbContext _context;
    private readonly EmployeeSalesService _employeeSalesService;

    public SaleInvoicesController(
        ShopDbContext context,
        EmployeeSalesService employeeSalesService)
    {
        _context = context;
        _employeeSalesService = employeeSalesService;
    }

    [HttpPost]
    public async Task<ActionResult<InvoiceResponseDto>> CreateInvoice(
    CreateInvoiceDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
            return BadRequest("Invoice must contain at least one item.");

        var cashierLocation = await _context.Locations
            .FirstOrDefaultAsync(l => l.Id == dto.LocationId);

        if (cashierLocation == null)
            return BadRequest("Invalid cashier location.");

        var employee = await _context.Employees
            .FirstOrDefaultAsync(e => e.Id == dto.EmployeeId);

        if (employee == null)
            return BadRequest("Invalid employee.");

        var phone = NormalizePhone(dto.CustomerPhone);
        if (phone.Length < 3)
            return BadRequest("Enter a valid customer phone number.");

        if (!Enum.IsDefined(typeof(PaymentMethod), dto.PaymentMethod))
            return BadRequest("Choose a valid payment method.");

        var customerName = dto.CustomerName?.Trim();
        var customer = await _context.Customers
            .FirstOrDefaultAsync(c => c.PhoneNumber == phone);

        if (customer == null)
        {
            customer = new Customer
            {
                PhoneNumber = phone,
                Name = string.IsNullOrWhiteSpace(customerName)
                    ? null
                    : customerName
            };

            _context.Customers.Add(customer);
        }
        else if (string.IsNullOrWhiteSpace(customer.Name) &&
                 !string.IsNullOrWhiteSpace(customerName))
        {
            // A returning customer can gain a name on a later visit.
            customer.Name = customerName;
        }

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var invoice = new SaleInvoice
            {
                CreatedAt = DateTime.UtcNow,
                LocationId = dto.LocationId,
                EmployeeId = dto.EmployeeId,
                EmployeeName = employee.Name,
                Customer = customer,
                PaymentMethod = dto.PaidAmount > 0
                    ? (PaymentMethod)dto.PaymentMethod
                    : null,
                TotalAmount = 0
            };

            _context.Invoices.Add(invoice);

            // 1. Process each stock allocation
            foreach (var item in dto.Items)
            {
                if (item.Quantity <= 0)
                {
                    return BadRequest(
                        "Item quantity must be greater than zero.");
                }

                var variant = await _context.ProductVariants
                    .Include(v => v.Product)
                    .Include(v => v.Size)
                    .Include(v => v.Colour)
                    .FirstOrDefaultAsync(v =>
                        v.Id == item.ProductVariantId);

                if (variant == null)
                {
                    return BadRequest(
                        $"Product variant {item.ProductVariantId} was not found.");
                }

                if (item.DiscountAmount > 0 && item.DiscountPercent > 0)
                {
                    return BadRequest(
                        "Give an item discount as either an amount or a " +
                        "percentage, not both.");
                }

                // Normalise: a percent discount becomes a per-unit amount.
                if (item.DiscountPercent > 0)
                {
                    item.DiscountAmount = Math.Round(
                        variant.Price * item.DiscountPercent / 100m,
                        2,
                        MidpointRounding.AwayFromZero);
                }

                var stockLocation = await _context.Locations
                    .FirstOrDefaultAsync(l =>
                        l.Id == item.StockLocationId);

                if (stockLocation == null)
                {
                    return BadRequest(
                        $"Stock location {item.StockLocationId} was not found.");
                }

                var inventory = await _context.Inventory
                    .FirstOrDefaultAsync(i =>
                        i.ProductVariantId == item.ProductVariantId &&
                        i.LocationId == item.StockLocationId);

                if (inventory == null)
                {
                    return BadRequest(
                        $"No inventory exists for " +
                        $"{variant.Product.Name} at " +
                        $"{stockLocation.Name}.");
                }

                if (inventory.Quantity < item.Quantity)
                {
                    return BadRequest(
                        $"Insufficient stock for " +
                        $"{variant.Product.Name} at " +
                        $"{stockLocation.Name}. " +
                        $"Available: {inventory.Quantity}, " +
                        $"Requested: {item.Quantity}.");
                }

                // Deduct stock
                inventory.Quantity -= item.Quantity;

                // Record stock movement
                _context.StockMovements.Add(
                    new StockMovement
                    {
                        ProductVariantId =
                            item.ProductVariantId,

                        LocationId =
                            item.StockLocationId,

                        QuantityChange =
                            -item.Quantity,

                        Reason = "Sale",

                        CreatedAt = DateTime.UtcNow
                    });
            }

            // 2. Group same variants with the SAME discount into ONE
            //    InvoiceItem; rows with different discounts stay separate.
            var groupedItems = dto.Items
                .GroupBy(x => new
                {
                    x.ProductVariantId,
                    x.DiscountAmount,
                    x.DiscountPercent
                })
                .Select(g => new
                {
                    g.Key.ProductVariantId,
                    g.Key.DiscountAmount,
                    g.Key.DiscountPercent,
                    Quantity = g.Sum(x => x.Quantity)
                })
                .ToList();

            // 3. Create one InvoiceItem per variant
            foreach (var groupedItem in groupedItems)
            {
                var variant = await _context.ProductVariants
                    .FirstOrDefaultAsync(v =>
                        v.Id == groupedItem.ProductVariantId);

                if (variant == null)
                {
                    return BadRequest(
                        "ProductVariant not found.");
                }

                if (groupedItem.DiscountAmount > variant.Price)
                {
                    return BadRequest(
                        $"Item discount cannot exceed the unit price of " +
                        $"{variant.Price}.");
                }

                var totalPrice =
                    (variant.Price - groupedItem.DiscountAmount) *
                    groupedItem.Quantity;

                var invoiceItem = new SaleInvoiceItem
                {
                    Invoice = invoice,

                    ProductVariantId =
                        groupedItem.ProductVariantId,

                    Quantity =
                        groupedItem.Quantity,

                    UnitPrice =
                        variant.Price,

                    TotalPrice =
                        totalPrice,

                    DiscountAmount =
                        groupedItem.DiscountAmount,

                    DiscountPercent =
                        groupedItem.DiscountPercent > 0
                            ? groupedItem.DiscountPercent
                            : null
                };

                _context.InvoiceItems.Add(invoiceItem);

                invoice.TotalAmount += totalPrice;
            }

            if (dto.DiscountAmount < 0)
            {
                return BadRequest("Discount amount cannot be negative.");
            }

            if (dto.DiscountAmount > 0 && dto.DiscountPercent > 0)
            {
                return BadRequest(
                    "Give the invoice discount as either an amount or a " +
                    "percentage, not both.");
            }

            var invoiceDiscount = dto.DiscountAmount;

            // A percent discount is taken on the items total after the
            // per-item discounts.
            if (dto.DiscountPercent > 0)
            {
                invoiceDiscount = Math.Round(
                    invoice.TotalAmount * dto.DiscountPercent / 100m,
                    2,
                    MidpointRounding.AwayFromZero);
            }

            if (invoiceDiscount > invoice.TotalAmount)
            {
                return BadRequest(
                    $"Discount cannot exceed the invoice total of " +
                    $"{invoice.TotalAmount}.");
            }

            invoice.DiscountAmount = invoiceDiscount;

            invoice.DiscountPercent = dto.DiscountPercent > 0
                ? dto.DiscountPercent
                : null;

            invoice.TotalAmount -= invoiceDiscount;

            if (dto.PaidAmount > invoice.TotalAmount)
            {
                return BadRequest(
                    $"Paid amount cannot exceed the invoice total of " +
                    $"{invoice.TotalAmount}.");
            }

            if (dto.PaidAmount > 0)
            {
                _context.CustomerPayments.Add(new CustomerPayment
                {
                    Customer = customer,
                    SaleInvoice = invoice,
                    Amount = dto.PaidAmount,
                    Method = (PaymentMethod)dto.PaymentMethod,
                    PaidAt = DateTime.UtcNow
                });

                customer.TotalPaid += dto.PaidAmount;
            }

            // Debt is the unpaid part of this invoice. A payment taken now
            // already reduced it, so only the remainder is added.
            customer.TotalDebt += invoice.TotalAmount - dto.PaidAmount;

            // Credit the amount the customer actually pays (after every
            // discount) to the employee who made the sale.
            await _employeeSalesService.RecordSaleAsync(
                dto.EmployeeId,
                invoice.TotalAmount,
                invoice.CreatedAt);

            await _context.SaveChangesAsync();

            await transaction.CommitAsync();

            var createdInvoice = await _context.Invoices
                .Include(i => i.Location)
                .Include(i => i.Employee)
                .Include(i => i.Customer)
                .Include(i => i.Payments)
                .Include(i => i.Items)
                    .ThenInclude(ii => ii.ProductVariant)
                        .ThenInclude(v => v.Product)
                .Include(i => i.Items)
                    .ThenInclude(ii => ii.ProductVariant)
                        .ThenInclude(v => v.Size)
                .Include(i => i.Items)
                    .ThenInclude(ii => ii.ProductVariant)
                        .ThenInclude(v => v.Colour)
                .FirstAsync(i => i.Id == invoice.Id);

            var summaries = await LoadCustomerSummariesAsync(
                new[] { createdInvoice.CustomerId!.Value });

            return Ok(ToResponse(createdInvoice, summaries));
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<InvoiceResponseDto>>> GetInvoices(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to)
    {
        var query = _context.Invoices
            .Include(i => i.Location)
            .Include(i => i.Employee)
            .Include(i => i.Customer)
            .Include(i => i.Payments)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Product)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Size)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Colour)
            .AsQueryable();

        if (from.HasValue)
        {
            query = query.Where(i => i.CreatedAt >= QueryDateRange.Start(from));
        }

        if (to.HasValue)
        {
            query = query.Where(i => i.CreatedAt <= QueryDateRange.End(to));
        }

        var invoices = await query
            .OrderByDescending(i => i.CreatedAt)
            .ToListAsync();

        var summaries = await LoadCustomerSummariesAsync(
            invoices
                .Where(i => i.CustomerId.HasValue)
                .Select(i => i.CustomerId!.Value));

        var response = invoices
            .Select(i => ToResponse(i, summaries))
            .ToList();

        return Ok(response);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<InvoiceResponseDto>> GetInvoice(int id)
    {
        var invoice = await _context.Invoices
            .Include(i => i.Location)
            .Include(i => i.Employee)
            .Include(i => i.Customer)
            .Include(i => i.Payments)
            .Include(i => i.Items)
                .ThenInclude(item => item.ProductVariant)
                    .ThenInclude(v => v.Product)
            .Include(i => i.Items)
                .ThenInclude(item => item.ProductVariant)
                    .ThenInclude(v => v.Size)
            .Include(i => i.Items)
                .ThenInclude(item => item.ProductVariant)
                    .ThenInclude(v => v.Colour)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (invoice == null)
        {
            return NotFound("Invoice not found.");
        }

        var summaries = invoice.CustomerId.HasValue
            ? await LoadCustomerSummariesAsync(
                new[] { invoice.CustomerId.Value })
            : new Dictionary<int, CustomerResponseDto>();

        return Ok(ToResponse(invoice, summaries));
    }

    /// <summary>
    /// Records a payment against an existing invoice, for customers who
    /// bought on credit or only paid part of the total at checkout.
    /// </summary>
    [HttpPost("{id}/payments")]
    public async Task<ActionResult<InvoiceResponseDto>> RecordPayment(
        int id,
        PayInvoiceDto dto)
    {
        if (!Enum.IsDefined(typeof(PaymentMethod), dto.Method))
            return BadRequest("Choose a valid payment method.");

        var invoice = await _context.Invoices
            .Include(i => i.Customer)
            .Include(i => i.Payments)
            .FirstOrDefaultAsync(i => i.Id == id);

        if (invoice == null)
            return NotFound("Invoice not found.");

        if (!invoice.CustomerId.HasValue)
            return BadRequest("This invoice has no customer to pay for.");

        var remaining = invoice.TotalAmount - invoice.Payments.Sum(p => p.Amount);

        if (dto.Amount > remaining)
        {
            return BadRequest(
                $"Payment cannot exceed the remaining balance of " +
                $"{remaining}.");
        }

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var customer = await _context.Customers
                .FirstAsync(c => c.Id == invoice.CustomerId!.Value);

            _context.CustomerPayments.Add(new CustomerPayment
            {
                Customer = customer,
                SaleInvoice = invoice,
                Amount = dto.Amount,
                Method = (PaymentMethod)dto.Method,
                PaidAt = DateTime.UtcNow
            });

            customer.TotalPaid += dto.Amount;
            customer.TotalDebt = Math.Max(0, customer.TotalDebt - dto.Amount);

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }

        var updated = await _context.Invoices
            .Include(i => i.Location)
            .Include(i => i.Employee)
            .Include(i => i.Customer)
            .Include(i => i.Payments)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Product)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Size)
            .Include(i => i.Items)
                .ThenInclude(ii => ii.ProductVariant)
                    .ThenInclude(v => v.Colour)
            .FirstAsync(i => i.Id == id);

        var summaries = await LoadCustomerSummariesAsync(
            new[] { updated.CustomerId!.Value });

        return Ok(ToResponse(updated, summaries));
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private static string NormalizePhone(string phone)
    {
        return new string((phone ?? string.Empty)
            .Where(char.IsDigit)
            .ToArray());
    }

    private static InvoiceResponseDto ToResponse(
        SaleInvoice invoice,
        IReadOnlyDictionary<int, CustomerResponseDto> summaries)
    {
        summaries.TryGetValue(invoice.CustomerId ?? 0, out var customer);

        var paid = invoice.Payments.Sum(p => p.Amount);

        return new InvoiceResponseDto
        {
            Id = invoice.Id,
            CreatedAt = invoice.CreatedAt,
            LocationId = invoice.LocationId,
            LocationName = invoice.Location.Name,
            EmployeeId = invoice.EmployeeId,
            EmployeeName = invoice.EmployeeName
                ?? (invoice.Employee != null ? invoice.Employee.Name : null),

            CustomerId = invoice.CustomerId,
            CustomerPhone = customer?.PhoneNumber ?? invoice.Customer?.PhoneNumber,
            CustomerName = customer?.Name ?? invoice.Customer?.Name,
            CustomerTotalPaid = customer?.TotalPaid ?? 0m,
            CustomerTotalDebt = customer?.TotalDebt ?? 0m,

            PaymentMethod = invoice.PaymentMethod.HasValue
                ? (int)invoice.PaymentMethod.Value
                : null,
            PaidAmount = paid,
            RemainingAmount = Math.Max(0, invoice.TotalAmount - paid),

            TotalAmount = invoice.TotalAmount,
            DiscountAmount = invoice.DiscountAmount,
            DiscountPercent = invoice.DiscountPercent,

            Payments = invoice.Payments
                .OrderBy(p => p.PaidAt)
                .Select(p => new InvoicePaymentDto
                {
                    Id = p.Id,
                    CustomerId = p.CustomerId,
                    Amount = p.Amount,
                    Method = (int)p.Method,
                    PaidAt = p.PaidAt
                })
                .ToList(),

            Items = invoice.Items.Select(ii => new InvoiceItemResponseDto
            {
                ProductVariantId = ii.ProductVariantId,
                ModelNumber = ii.ProductVariant.Product.ModelNumber,
                ProductName = ii.ProductVariant.Product.Name,
                SizeName = ii.ProductVariant.Size?.Name,
                ColourName = ii.ProductVariant.Colour?.Name,
                Quantity = ii.Quantity,
                UnitPrice = ii.UnitPrice,
                TotalPrice = ii.TotalPrice,
                TotalBeforeDiscount = ii.UnitPrice * ii.Quantity,
                UnitPriceAfterDiscount = ii.UnitPrice - ii.DiscountAmount,
                DiscountAmount = ii.DiscountAmount,
                DiscountPercent = ii.DiscountPercent
            }).ToList()
        };
    }

    private async Task<Dictionary<int, CustomerResponseDto>>
        LoadCustomerSummariesAsync(IEnumerable<int> customerIds)
    {
        var ids = customerIds.Distinct().ToList();

        if (ids.Count == 0)
            return new Dictionary<int, CustomerResponseDto>();

        var customers = await _context.Customers.AsNoTracking()
            .Where(c => ids.Contains(c.Id))
            .ToListAsync(QueryCancellationToken);

        var invoiceTotals = await _context.Invoices.AsNoTracking()
            .Where(i => i.CustomerId.HasValue &&
                        ids.Contains(i.CustomerId.Value))
            .GroupBy(i => i.CustomerId!.Value)
            .Select(g => new
            {
                CustomerId = g.Key,
                Count = g.Count()
            })
            .ToListAsync(QueryCancellationToken);

        var totals = invoiceTotals.ToDictionary(t => t.CustomerId);

        return customers.ToDictionary(c => c.Id, c =>
        {
            totals.TryGetValue(c.Id, out var total);

            return new CustomerResponseDto
            {
                Id = c.Id,
                PhoneNumber = c.PhoneNumber,
                Name = c.Name,
                TotalPaid = c.TotalPaid,
                TotalDebt = c.TotalDebt,
                InvoiceCount = total?.Count ?? 0,
                CreatedAt = c.CreatedAt
            };
        });
    }

    // Cancellation is not threaded through the existing read actions; using
    // the request's token here keeps the extra summary queries consistent.
    private CancellationToken QueryCancellationToken => HttpContext.RequestAborted;
}