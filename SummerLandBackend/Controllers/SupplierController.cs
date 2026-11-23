using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class SupplierController : ControllerBase
{
    private readonly ShopDbContext _context;

    public SupplierController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetSuppliers()
    {
        var suppliers = await _context.Suppliers
            .Include(s => s.PurchaseInvoices)
            .OrderBy(s => s.SupplierName)
            .Select(s => new
            {
                s.Id,
                s.SupplierName,
                s.Debt,
                PurchaseInvoices = s.PurchaseInvoices.Select(pi => new
                {
                    pi.Id,
                    pi.Date,
                    pi.CreatedAt,
                    pi.TotalCost,
                    pi.TotalPaid,
                    PaymentMethod = (int)pi.PaymentMethod,
                    pi.Debt
                })
            })
            .ToListAsync();

        return Ok(suppliers);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetSupplier(int id)
    {
        var supplier = await _context.Suppliers
            .Include(s => s.PurchaseInvoices)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (supplier == null)
            return NotFound("Supplier not found.");

        return Ok(new
        {
            supplier.Id,
            supplier.SupplierName,
            supplier.Debt,
            PurchaseInvoices = supplier.PurchaseInvoices.Select(pi => new
            {
                pi.Id,
                pi.Date,
                pi.CreatedAt,
                pi.TotalCost,
                pi.TotalPaid,
                PaymentMethod = (int)pi.PaymentMethod,
                pi.Debt
            })
        });
    }

    // GET: api/Supplier/5/payments
    [HttpGet("{id:int}/payments")]
    public async Task<IActionResult> GetSupplierPayments(int id)
    {
        var payments = await _context.SupplierPayments
            .AsNoTracking()
            .Where(p => p.SupplierId == id)
            .OrderByDescending(p => p.PaidAt)
            .ThenByDescending(p => p.Id)
            .Select(p => new
            {
                p.Id,
                p.Amount,
                p.PaidAt,
                p.PurchaseInvoiceId,
                Method = (int)p.Method
            })
            .ToListAsync();

        return Ok(payments);
    }

    [HttpPost]
    public async Task<ActionResult<Supplier>> CreateSupplier([FromBody] Supplier supplier)
    {
        if (supplier == null)
            return BadRequest("Supplier data is required.");

        if (string.IsNullOrWhiteSpace(supplier.SupplierName))
            return BadRequest("Supplier name is required.");

        var name = supplier.SupplierName.Trim();

        var exists = await _context.Suppliers
            .AnyAsync(s => s.SupplierName.ToLower() == name.ToLower());

        if (exists)
            return Conflict("Supplier already exists.");

        supplier.SupplierName = name;

        _context.Suppliers.Add(supplier);
        await _context.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetSupplier),
            new { id = supplier.Id },
            supplier);
    }

    // POST: api/Supplier/5/pay
    [HttpPost("{id:int}/pay")]
    public async Task<IActionResult> PaySupplierDebt(
        int id,
        PaySupplierDebtDto dto)
    {
        if (dto.Amount <= 0)
            return BadRequest("Payment amount must be greater than zero.");

        if (!Enum.IsDefined(typeof(PaymentMethod), dto.Method))
            return BadRequest("Choose a valid payment method.");

        var supplier = await _context.Suppliers
            .Include(s => s.PurchaseInvoices)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (supplier == null)
            return NotFound("Supplier not found.");

        var unpaidInvoices = supplier.PurchaseInvoices
            .Where(i => i.Debt > 0)
            .OrderBy(i => i.Date)
            .ThenBy(i => i.Id)
            .ToList();

        if (supplier.Debt <= 0)
            return BadRequest("This supplier has no debt to pay.");

        if (dto.Amount > supplier.Debt)
            return BadRequest(
                $"Payment cannot exceed the supplier's total debt of "
                + $"{supplier.Debt}.");

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var remaining = dto.Amount;
            var paidAt = DateTime.UtcNow;
            var method = (PaymentMethod)dto.Method;

            // Mirrors the customer payment flow: one payment row per invoice,
            // so the history shows exactly which invoices were settled.
            foreach (var invoice in unpaidInvoices)
            {
                if (remaining <= 0)
                    break;

                var payment = Math.Min(remaining, invoice.Debt);

                if (payment <= 0)
                    continue;

                invoice.TotalPaid += payment;
                invoice.Debt -= payment;
                remaining -= payment;

                _context.SupplierPayments.Add(new SupplierPayment
                {
                    SupplierId = supplier.Id,
                    PurchaseInvoiceId = invoice.Id,
                    Amount = payment,
                    Method = method,
                    PaidAt = paidAt
                });
            }

            var amountApplied = dto.Amount - remaining;

            // The payment is distributed only as far as the invoices go;
            // anything left is kept on the supplier's balance. Unpaid fees
            // live there rather than on an invoice.
            supplier.Debt -= amountApplied;

            if (remaining > 0)
            {
                _context.SupplierPayments.Add(new SupplierPayment
                {
                    SupplierId = supplier.Id,
                    PurchaseInvoiceId = null,
                    Amount = remaining,
                    Method = method,
                    PaidAt = paidAt
                });
            }

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Ok(new
            {
                supplier.Id,
                supplier.SupplierName,
                supplier.Debt,
                Method = dto.Method,
                AmountApplied = dto.Amount - remaining,
                PurchaseInvoices = supplier.PurchaseInvoices
                    .OrderBy(i => i.Date)
                    .ThenBy(i => i.Id)
                    .Select(i => new
                    {
                        i.Id,
                        i.Date,
                        i.CreatedAt,
                        i.TotalCost,
                        i.TotalPaid,
                        PaymentMethod = (int)i.PaymentMethod,
                        i.Debt
                    })
            });
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateSupplier(int id, [FromBody] Supplier dto)
    {
        var supplier = await _context.Suppliers.FindAsync(id);

        if (supplier == null)
            return NotFound("Supplier not found.");

        if (string.IsNullOrWhiteSpace(dto.SupplierName))
            return BadRequest("Supplier name is required.");

        var name = dto.SupplierName.Trim();

        var exists = await _context.Suppliers
            .AnyAsync(s => s.Id != id && s.SupplierName.ToLower() == name.ToLower());

        if (exists)
            return Conflict("A supplier with this name already exists.");

        supplier.SupplierName = name;
        supplier.Debt = dto.Debt;

        await _context.SaveChangesAsync();

        return Ok(supplier);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteSupplier(int id)
    {
        var supplier = await _context.Suppliers
            .Include(s => s.PurchaseInvoices)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (supplier == null)
            return NotFound("Supplier not found.");

        if (supplier.PurchaseInvoices != null && supplier.PurchaseInvoices.Any())
            return BadRequest("Supplier has purchase invoices and cannot be deleted.");

        _context.Suppliers.Remove(supplier);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
