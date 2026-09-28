namespace SummerLandBackend.DTOs.PurchaseReturns
{
    public class CreatePurchaseReturnDto
    {
        public int PurchaseInvoiceId { get; set; }

        public string? Reason { get; set; }

        public List<CreatePurchaseReturnItemDto> Items { get; set; }
            = new();
    }
}