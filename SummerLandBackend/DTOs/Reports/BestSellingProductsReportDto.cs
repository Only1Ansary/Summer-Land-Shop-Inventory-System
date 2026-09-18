namespace SummerLandBackend.DTOs.Reports;

public class BestSellingProductsReportDto
{
    public DateTime From { get; set; }
    public DateTime To { get; set; }

    public List<BestSellingProductDto> Items { get; set; }
        = new List<BestSellingProductDto>();
}

public class BestSellingProductDto
{
    public int ProductId { get; set; }

    public string ModelNumber { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;

    public int TotalQuantitySold { get; set; }

    public decimal TotalSales { get; set; }
}