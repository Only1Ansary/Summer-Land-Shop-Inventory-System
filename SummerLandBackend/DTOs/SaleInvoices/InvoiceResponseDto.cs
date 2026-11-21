namespace SummerLandBackend.DTOs.SaleInvoices;

public class InvoiceResponseDto
{
    public int Id { get; set; }

    public DateTime CreatedAt { get; set; }

    public int LocationId { get; set; }

    public string LocationName { get; set; } = string.Empty;

    // Null for invoices recorded before employees were tracked.
    public int? EmployeeId { get; set; }

    public string? EmployeeName { get; set; }

    // Null for invoices created before customers were tracked.
    public int? CustomerId { get; set; }

    public string? CustomerPhone { get; set; }

    public string? CustomerName { get; set; }

    public decimal CustomerTotalPaid { get; set; }

    public decimal CustomerTotalDebt { get; set; }

    // Method used for the payment taken at checkout, when there was one.
    public int? PaymentMethod { get; set; }

    public decimal PaidAmount { get; set; }

    public decimal RemainingAmount { get; set; }

    public List<InvoicePaymentDto> Payments { get; set; }
        = new List<InvoicePaymentDto>();

    public decimal TotalAmount { get; set; }

    public decimal DiscountAmount { get; set; }

    // Percent the invoice discount was entered as; null when it was a
    // fixed amount.
    public decimal? DiscountPercent { get; set; }

    public List<InvoiceItemResponseDto> Items { get; set; }
        = new List<InvoiceItemResponseDto>();
}

public class InvoicePaymentDto
{
    public int Id { get; set; }

    public int CustomerId { get; set; }

    public decimal Amount { get; set; }

    public int Method { get; set; }

    public DateTime PaidAt { get; set; }
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

    // Total the line would have had with no per-item discount.
    public decimal TotalBeforeDiscount { get; set; }

    // Unit price after the per-unit discount (== UnitPrice when no discount).
    public decimal UnitPriceAfterDiscount { get; set; }

    // Per-unit discount actually applied.
    public decimal DiscountAmount { get; set; }

    // Percent the discount was entered as; null when entered as an amount.
    public decimal? DiscountPercent { get; set; }
}