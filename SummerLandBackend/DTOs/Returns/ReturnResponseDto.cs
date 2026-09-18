namespace SummerLandBackend.DTOs.Returns;

public class ReturnResponseDto
{
    public int Id { get; set; }

    public int InvoiceId { get; set; }

    public int ProductVariantId { get; set; }

    public string ModelNumber { get; set; } = string.Empty;

    public string ProductName { get; set; } = string.Empty;

    public string? SizeName { get; set; }

    public string? ColourName { get; set; }

    public int LocationId { get; set; }

    public string LocationName { get; set; } = string.Empty;

    public int Quantity { get; set; }

    public decimal UnitPrice { get; set; }

    public decimal TotalAmount { get; set; }

    public string Reason { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }
}