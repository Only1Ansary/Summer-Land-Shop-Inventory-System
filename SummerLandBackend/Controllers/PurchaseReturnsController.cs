using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.PurchaseReturns;
using SummerLandBackend.Models;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PurchaseReturnsController : ControllerBase
{
    private const int DefaultLocationId = 1;

    private readonly ShopDbContext _context;

    public PurchaseReturnsController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpPost]
    public async Task<IActionResult> CreatePurchaseReturn(
        CreatePurchaseReturnDto dto)
    {
        if (dto.Items == null || dto.Items.Count == 0)
            return BadRequest(
                "A purchase return must contain at least one item.");

        if (dto.Items.Any(i => i.ProductId <= 0 || i.Quantity <= 0))
            return BadRequest(
                "Each return item must have a valid product and " +
                "a positive quantity.");

        var duplicateProducts = dto.Items
            .GroupBy(i => i.ProductId)
            .Any(g => g.Count() > 1);

        if (duplicateProducts)
            return BadRequest(
                "A product cannot appear more than once in a return.");

        var invoice = await _context.PurchaseInvoices
            .Include(i => i.Supplier)
            .Include(i => i.Items)
            .FirstOrDefaultAsync(i => i.Id == dto.PurchaseInvoiceId);

        if (invoice == null)
            return NotFound("Purchase invoice not found.");

        var lineByProduct = invoice.Items
            .ToDictionary(i => i.ProductId);

        foreach (var item in dto.Items)
        {
            if (!lineByProduct.TryGetValue(item.ProductId, out var line))
                return BadRequest(
                    "One or more items do not belong to this invoice.");

            if (item.Quantity > line.Quantity)
                return BadRequest(
                    "Return quantity cannot exceed the purchased quantity.");
        }

        // A purchase return takes goods back to the supplier, so it can
        // only cover items that are still in stock.
        foreach (var item in dto.Items)
        {
            var variant = await _context.ProductVariants
                .FirstOrDefaultAsync(v =>
                    v.ProductId == item.ProductId &&
                    v.SizeId == null &&
                    v.ColourId == null);

            var inventory = variant == null
                ? null
                : await _context.Inventory.FirstOrDefaultAsync(i =>
                    i.ProductVariantId == variant.Id &&
                    i.LocationId == DefaultLocationId);

            var available = inventory?.Quantity ?? 0;

            if (available < item.Quantity)
            {
                return BadRequest(
                    "This item cannot be returned: only "
                    + $"{available} unit(s) are still in stock "
                    + "and the rest has already been sold.");
            }
        }

        await using var transaction =
            await _context.Database.BeginTransactionAsync();

        try
        {
            var createdReturns = new List<PurchaseReturn>();
            decimal returnedValue = 0;

            foreach (var item in dto.Items)
            {
                var line = lineByProduct[item.ProductId];

                returnedValue += line.UnitPurchasePrice * item.Quantity;

                // The returned items are removed from the invoice:
                // a full return deletes the line, a partial return
                // reduces the remaining quantity.
                if (item.Quantity >= line.Quantity)
                {
                    _context.PurchaseInvoiceItems.Remove(line);
                }
                else
                {
                    line.Quantity -= item.Quantity;
                    line.TotalPrice =
                        line.UnitPurchasePrice * line.Quantity;
                }

                createdReturns.Add(new PurchaseReturn
                {
                    PurchaseInvoiceId = invoice.Id,
                    ProductId = item.ProductId,
                    UnitPurchasePrice = line.UnitPurchasePrice,
                    Quantity = item.Quantity,
                    Reason = dto.Reason
                });

                // Best-effort stock adjustment for the default variant.
                var variant = await _context.ProductVariants
                    .FirstOrDefaultAsync(v =>
                        v.ProductId == item.ProductId &&
                        v.SizeId == null &&
                        v.ColourId == null);

                if (variant != null)
                {
                    var inventory = await _context.Inventory
                        .FirstOrDefaultAsync(i =>
                            i.ProductVariantId == variant.Id &&
                            i.LocationId == DefaultLocationId);

                    if (inventory != null)
                    {
                        inventory.Quantity = Math.Max(
                            0, inventory.Quantity - item.Quantity);

                        _context.StockMovements.Add(new StockMovement
                        {
                            ProductVariantId = variant.Id,
                            LocationId = DefaultLocationId,
                            QuantityChange = -item.Quantity,
                            Reason = "Purchase Return",
                            CreatedAt = DateTime.UtcNow
                        });
                    }
                }
            }

            // Recompute the invoice totals from the items that remain.
            // The returned value first wipes out unpaid debt, and any
            // excess reduces total paid (the overpayment is credited
            // back). Total cost drops by the exact value of the returned
            // goods (subtracting is reliable for full line returns,
            // where the removed line may still sit in the in-memory
            // navigation collection).
            var previousDebt = invoice.Debt;

            invoice.TotalCost = Math.Max(
                0, invoice.TotalCost - returnedValue);

            invoice.Debt = Math.Max(
                0, previousDebt - returnedValue);

            invoice.TotalPaid = Math.Max(
                0,
                invoice.TotalPaid -
                Math.Max(0, returnedValue - previousDebt));

            invoice.Supplier.Debt = Math.Max(
                0, invoice.Supplier.Debt - Math.Min(previousDebt, returnedValue));

            _context.PurchaseReturns.AddRange(createdReturns);

            await _context.SaveChangesAsync();
            await transaction.CommitAsync();

            return Ok(new
            {
                invoice.Id,
                invoice.SupplierId,
                invoice.Supplier.SupplierName,
                invoice.Date,
                invoice.CreatedAt,
                invoice.TotalCost,
                invoice.TotalPaid,
                InvoiceDebt = invoice.Debt,
                SupplierTotalDebt = invoice.Supplier.Debt,
                Returns = createdReturns.Select(r => new
                {
                    r.Id,
                    r.ProductId,
                    r.UnitPurchasePrice,
                    r.Quantity,
                    r.Reason,
                    r.CreatedAt
                })
            });
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }
}