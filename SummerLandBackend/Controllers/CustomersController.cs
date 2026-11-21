using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Customers;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CustomersController : ControllerBase
{
    private readonly ShopDbContext _context;

    public CustomersController(ShopDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Customers, optionally filtered by phone. Used by the sale screen to
    /// recognise a returning customer before creating the invoice.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<CustomerResponseDto>>> GetCustomers(
        [FromQuery] string? phone,
        [FromQuery] string? search,
        CancellationToken ct)
    {
        var query = _context.Customers.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            // The Customers screen searches by name or phone. Phone numbers
            // are compared as digits so spaces and dashes do not matter.
            var text = search.Trim();
            var digits = NormalizePhone(text);

            if (digits.Length == 0)
                return Ok(Array.Empty<CustomerResponseDto>());

            var lowered = text.ToLower();

            query = query.Where(c =>
                c.PhoneNumber.Contains(digits) ||
                (c.Name != null && c.Name.ToLower().Contains(lowered)));
        }
        else if (!string.IsNullOrWhiteSpace(phone))
        {
            var normalized = NormalizePhone(phone);

            if (normalized.Length == 0)
                return Ok(Array.Empty<CustomerResponseDto>());

            query = query.Where(c => c.PhoneNumber.Contains(normalized));
        }

        var customers = await query
            .OrderBy(c => c.Name ?? c.PhoneNumber)
            .Take(50)
            .ToListAsync(ct);

        var summaries = await LoadSummariesAsync(customers, ct);

        return Ok(customers.Select(c => summaries[c.Id]).ToList());
    }

    /// <summary>
    /// Exact phone lookup. Returns 200 with null when the number is new.
    /// </summary>
    [HttpGet("lookup")]
    public async Task<ActionResult<CustomerResponseDto?>> Lookup(
        [FromQuery] string phone,
        CancellationToken ct)
    {
        var normalized = NormalizePhone(phone);

        if (normalized.Length < 3)
            return Ok(null);

        var customer = await _context.Customers.AsNoTracking()
            .FirstOrDefaultAsync(c => c.PhoneNumber == normalized, ct);

        if (customer == null)
            return Ok(null);

        var summaries = await LoadSummariesAsync(new[] { customer }, ct);

        return Ok(summaries[customer.Id]);
    }

    /// <summary>
    /// Full customer view: totals, every sale invoice and the complete
    /// payment history. Search results use the lightweight list endpoint.
    /// </summary>
    [HttpGet("{id}/details")]
    public async Task<ActionResult<CustomerDetailsDto>> GetDetails(
        int id,
        CancellationToken ct)
    {
        var details = await BuildDetailsAsync(id, ct);

        if (details == null)
            return NotFound("Customer not found.");

        return Ok(details);
    }

    /// <summary>
    /// Records a payment for the customer without selecting invoices. The
    /// amount is applied to the oldest unpaid invoices first, splitting an
    /// invoice where necessary.
    /// </summary>
    [HttpPost("{id}/payments")]
    public async Task<ActionResult<CustomerDetailsDto>> RecordPayment(
        int id,
        PayCustomerDto dto,
        CancellationToken ct)
    {
        if (dto.Amount <= 0)
            return BadRequest("Enter a payment amount greater than zero.");

        if (!Enum.IsDefined(typeof(PaymentMethod), dto.Method))
            return BadRequest("Choose a valid payment method.");

        var customer = await _context.Customers
            .FirstOrDefaultAsync(c => c.Id == id, ct);

        if (customer == null)
            return NotFound("Customer not found.");

        await using var transaction =
            await _context.Database.BeginTransactionAsync(ct);

        try
        {
            var invoices = await _context.Invoices
                .Where(i => i.CustomerId == id)
                .Include(i => i.Payments)
                .OrderBy(i => i.CreatedAt)
                .ThenBy(i => i.Id)
                .ToListAsync(ct);

            var unpaid = invoices
                .Select(i => new
                {
                    Invoice = i,
                    Balance = i.TotalAmount - i.Payments.Sum(p => p.Amount)
                })
                .Where(x => x.Balance > 0)
                .ToList();

            var totalDue = unpaid.Sum(x => x.Balance);

            if (dto.Amount > totalDue)
                return BadRequest(
                    $"Payment cannot exceed the customer's total debt of " +
                    $"{totalDue}.");

            var remaining = dto.Amount;
            var paidAt = DateTime.UtcNow;

            foreach (var entry in unpaid)
            {
                if (remaining <= 0) break;

                var applied = Math.Min(remaining, entry.Balance);

                _context.CustomerPayments.Add(new CustomerPayment
                {
                    CustomerId = id,
                    SaleInvoiceId = entry.Invoice.Id,
                    Amount = applied,
                    Method = (PaymentMethod)dto.Method,
                    PaidAt = paidAt
                });

                remaining -= applied;
            }

            customer.TotalPaid += dto.Amount - remaining;
            customer.TotalDebt = Math.Max(
                0,
                customer.TotalDebt - (dto.Amount - remaining));

            await _context.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
        }
        catch
        {
            await transaction.RollbackAsync(ct);
            throw;
        }

        var updated = await BuildDetailsAsync(id, ct);

        if (updated == null)
            return NotFound("Customer not found.");

        return Ok(updated);
    }

    private static string NormalizePhone(string phone)
    {
        return new string((phone ?? string.Empty)
            .Where(char.IsDigit)
            .ToArray());
    }

    private async Task<CustomerDetailsDto?> BuildDetailsAsync(
        int id,
        CancellationToken ct)
    {
        var customer = await _context.Customers.AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == id, ct);

        if (customer == null)
            return null;

        var invoices = await _context.Invoices.AsNoTracking()
            .Where(i => i.CustomerId == id)
            .OrderByDescending(i => i.CreatedAt)
            .ThenByDescending(i => i.Id)
            .Select(i => new
            {
                i.Id,
                i.CreatedAt,
                LocationName = i.Location.Name,
                i.TotalAmount,
                PaidAmount = i.Payments.Sum(p => p.Amount)
            })
            .ToListAsync(ct);

        var payments = await _context.CustomerPayments.AsNoTracking()
            .Where(p => p.CustomerId == id)
            .OrderByDescending(p => p.PaidAt)
            .ThenByDescending(p => p.Id)
            .Select(p => new
            {
                p.Id,
                p.SaleInvoiceId,
                p.Amount,
                p.Method,
                p.PaidAt
            })
            .ToListAsync(ct);

        var invoiceDtos = invoices.Select(i => new CustomerInvoiceSummaryDto
        {
            Id = i.Id,
            CreatedAt = i.CreatedAt,
            LocationName = i.LocationName,
            TotalAmount = i.TotalAmount,
            PaidAmount = i.PaidAmount,
            RemainingAmount = Math.Max(0, i.TotalAmount - i.PaidAmount)
        }).ToList();

        return new CustomerDetailsDto
        {
            Id = customer.Id,
            PhoneNumber = customer.PhoneNumber,
            Name = customer.Name,
            TotalPaid = customer.TotalPaid,
            TotalDebt = customer.TotalDebt,
            InvoiceCount = invoiceDtos.Count,
            UnpaidInvoiceCount = invoiceDtos.Count(i => i.RemainingAmount > 0),
            CreatedAt = customer.CreatedAt,
            Invoices = invoiceDtos,
            Payments = payments.Select(p => new CustomerPaymentDto
            {
                Id = p.Id,
                SaleInvoiceId = p.SaleInvoiceId,
                Amount = p.Amount,
                Method = (int)p.Method,
                PaidAt = p.PaidAt
            }).ToList()
        };
    }

    private async Task<Dictionary<int, CustomerResponseDto>> LoadSummariesAsync(
        IEnumerable<Customer> customers,
        CancellationToken ct)
    {
        var list = customers.DistinctBy(c => c.Id).ToList();

        if (list.Count == 0)
            return new Dictionary<int, CustomerResponseDto>();

        var ids = list.Select(c => c.Id).ToList();

        var totals = await _context.Invoices.AsNoTracking()
            .Where(i => i.CustomerId.HasValue && ids.Contains(i.CustomerId.Value))
            .GroupBy(i => i.CustomerId!.Value)
            .Select(g => new
            {
                CustomerId = g.Key,
                Count = g.Count()
            })
            .ToListAsync(ct);

        var byCustomer = totals.ToDictionary(t => t.CustomerId);

        return list.ToDictionary(c => c.Id, customer =>
        {
            byCustomer.TryGetValue(customer.Id, out var total);

            return new CustomerResponseDto
            {
                Id = customer.Id,
                PhoneNumber = customer.PhoneNumber,
                Name = customer.Name,
                TotalPaid = customer.TotalPaid,
                TotalDebt = customer.TotalDebt,
                InvoiceCount = total?.Count ?? 0,
                CreatedAt = customer.CreatedAt
            };
        });
    }
}
