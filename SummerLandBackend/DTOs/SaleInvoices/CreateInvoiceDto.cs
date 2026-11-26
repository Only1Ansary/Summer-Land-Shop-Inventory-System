using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.SaleInvoices
{
    public class CreateInvoiceDto
    {
        [Range(1, int.MaxValue,
            ErrorMessage = "Choose a valid location for the invoice.")]
        public int LocationId { get; set; }

        // Every new sale must be assigned to the employee who made it.
        [Range(1, int.MaxValue,
            ErrorMessage = "Choose an employee for the invoice.")]
        public int EmployeeId { get; set; }

        // Optional for a sale paid in full. The controller requires it when
        // the invoice leaves an unpaid balance, and validates its length
        // whenever a number is supplied.
        [StringLength(50,
            ErrorMessage = "Enter a valid customer phone number.")]
        public string? CustomerPhone { get; set; }

        [StringLength(100,
            ErrorMessage = "Customer name cannot be longer than 100 characters.")]
        public string? CustomerName { get; set; }

        // 0 means the customer is buying on credit; the rest is paid now.
        [Range(0, double.MaxValue,
            ErrorMessage = "Enter a valid paid amount.")]
        public decimal PaidAmount { get; set; }

        // 0 Cash, 1 Visa, 2 InstaPay, 3 VCash. Only used when PaidAmount > 0.
        [Range(0, 3, ErrorMessage = "Choose a valid payment method.")]
        public int PaymentMethod { get; set; }

        [Required(ErrorMessage = "Invoice must contain at least one item.")]
        [MinLength(1,
            ErrorMessage = "Invoice must contain at least one item.")]
        public List<CreateInvoiceItemDto> Items { get; set; }
            = new List<CreateInvoiceItemDto>();

        public decimal DiscountAmount { get; set; }

        // Invoice-level discount. Set amount OR percent, never both;
        // the percent is taken on the items total after item discounts.
        [Range(0, 100,
            ErrorMessage = "Enter an invoice discount percentage between "
                + "0 and 100.")]
        public decimal DiscountPercent { get; set; }
    }
}