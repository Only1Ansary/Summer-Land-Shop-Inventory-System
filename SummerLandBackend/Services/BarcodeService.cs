using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;

namespace SummerLandBackend.Services;

public class BarcodeService
{
    private readonly ShopDbContext _context;

    public BarcodeService(ShopDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Generates a digits-only barcode that is not used by any product or
    /// variant. The counter advances on every collision so a reused database
    /// id can never trap the loop.
    /// </summary>
    public async Task<string> GenerateInternalBarcodeAsync()
    {
        var lastProductId = await _context.Products
            .Select(p => (int?)p.Id)
            .MaxAsync() ?? 0;

        var lastVariantId = await _context.ProductVariants
            .Select(v => (int?)v.Id)
            .MaxAsync() ?? 0;

        var candidateNumber = Math.Max(lastProductId, lastVariantId) + 1;

        while (true)
        {
            var barcode = candidateNumber.ToString("D8");

            var exists = await _context.Products
                             .AnyAsync(p => p.Barcode == barcode) ||
                         await _context.ProductVariants
                             .AnyAsync(v => v.Barcode == barcode);

            if (!exists) return barcode;

            candidateNumber++;
        }
    }
}
