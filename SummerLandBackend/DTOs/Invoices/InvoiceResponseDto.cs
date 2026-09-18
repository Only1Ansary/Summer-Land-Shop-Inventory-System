namespace SummerLandBackend.DTOs.Invoices;

public class InvoiceResponseDto
{
    public int Id { get; set; }

    public DateTime CreatedAt { get; set; }

    public int LocationId { get; set; }

    public string LocationName { get; set; } = string.Empty;

    public decimal TotalAmount { get; set; }

    public List<InvoiceItemResponseDto> Items { get; set; }
        = new List<InvoiceItemResponseDto>();
}

public class InvoiceItemResponseDto
{
    public int ProductVariantId { get; set; }

    public string ModelNumber { get; set; } = string.Empty;

    public string ProductName { get; set; } = string.Empty;

    public string? SizeName { get; set; }

    public string? ColourName { get; set; }

    public int Quantity { get; set; }

    public decimal UnitPrice { get; set; }

    public decimal TotalPrice { get; set; }
}