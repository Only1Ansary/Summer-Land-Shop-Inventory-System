namespace SummerLandBackend.Models;

/// A recorded payment to an employee (salary and/or bonus).
public class EmployeePayment
{
    public int Id { get; set; }

    public int EmployeeId { get; set; }

    public Employee? Employee { get; set; }

    public decimal Amount { get; set; }

    /// When the payment was settled. The sales report uses this date.
    public DateTime PaidAt { get; set; }
}