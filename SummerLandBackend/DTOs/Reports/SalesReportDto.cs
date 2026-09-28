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

        public int PurchaseInvoiceCount { get; set; }

        public decimal PurchaseTotalCost { get; set; }

        public decimal PurchaseTotalPaid { get; set; }

        public decimal PurchaseDebt { get; set; }

        public int SupplierCount { get; set; }

        public decimal SupplierDebtTotal { get; set; }

        public decimal Profit { get; set; }
    }
}
