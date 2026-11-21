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

        public int EmployeePaymentCount { get; set; }

        public decimal EmployeePaymentTotal { get; set; }

        public int SupplierCount { get; set; }

        public decimal SupplierDebtTotal { get; set; }

        public int CustomerCount { get; set; }

        public int CustomerPaymentCount { get; set; }

        public decimal CustomerPaymentsTotal { get; set; }

        public decimal CustomerDebtTotal { get; set; }

        public List<PaymentMethodTotalDto> PaymentsByMethod { get; set; }
            = new List<PaymentMethodTotalDto>();

        public decimal Profit { get; set; }

        public List<CategorySalesDto> CategorySales { get; set; }
            = new List<CategorySalesDto>();
    }

    public class PaymentMethodTotalDto
    {
        public int Method { get; set; }

        public string MethodName { get; set; } = string.Empty;

        public decimal Amount { get; set; }
    }

    public class CategorySalesDto
    {
        public string CategoryName { get; set; } = string.Empty;

        public int QuantitySold { get; set; }

        public decimal Amount { get; set; }
    }
}
