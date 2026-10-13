namespace SummerLandBackend.DTOs.Employees;

public class CreateEmployeePaymentDto
{
    public decimal Amount { get; set; }

    /// Defaults to today when not supplied.
    public DateTime? PaidAt { get; set; }
}