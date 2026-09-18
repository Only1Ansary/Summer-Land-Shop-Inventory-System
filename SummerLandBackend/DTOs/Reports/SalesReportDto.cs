namespace SummerLandBackend.DTOs.Reports
{
    public class SalesReportDto
    {
        public DateTime From { get; set; }

        public DateTime To { get; set; }

        public int InvoiceCount { get; set; }

        public int ItemsSold { get; set; }

        public decimal GrossSales { get; set; }

        public int ItemsReturned { get; set; }

        public decimal ReturnsAmount { get; set; }

        public decimal NetSales { get; set; }
    }
}
