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

    public async Task<string> GenerateInternalBarcodeAsync()
    {
        string barcode;

        do
        {
            var nextNumber = await _context.ProductVariants
                .Select(v => (int?)v.Id)
                .MaxAsync() ?? 0;

            nextNumber++;

            barcode = $"SHOP-{nextNumber:D8}";

        } while (await _context.ProductVariants
                     .AnyAsync(v => v.Barcode == barcode));

        return barcode;
    }
}