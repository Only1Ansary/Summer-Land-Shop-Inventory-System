namespace SummerLandBackend.Models
{
    public class Supplier
    {
        public int Id { get; set; }

        public string SupplierName { get; set; } = string.Empty;

        public decimal Debt { get; set; }

        public ICollection<PurchaseInvoice> PurchaseInvoices { get; set; }
            = new List<PurchaseInvoice>();
    }
}
