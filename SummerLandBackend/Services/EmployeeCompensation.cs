using SummerLandBackend.Models;

namespace SummerLandBackend.Services;

/// <summary>
/// Shared bonus and pay calculations for employees. Kept in one place so
/// the employee list and the report always agree.
/// </summary>
public static class EmployeeCompensation
{
    /// <summary>
    /// The bonus actually owed right now: a fixed amount, or a percentage
    /// of the employee's total sales.
    /// </summary>
    public static decimal BonusAmount(Employee employee)
    {
        return BonusAmount(employee, employee.TotalSales);
    }

    /// <summary>
    /// The bonus owed on a given sales figure: a fixed amount, or a
    /// percentage of those sales.
    /// </summary>
    public static decimal BonusAmount(Employee employee, decimal sales)
    {
        return employee.BonusType == BonusType.Fixed
            ? employee.Bonus
            : Math.Round(
                sales * employee.Bonus / 100m,
                2,
                MidpointRounding.AwayFromZero);
    }

    /// <summary>
    /// What still has to be paid out this month: the salary plus the bonus
    /// owed, minus whatever was already paid in the month, never negative.
    /// </summary>
    public static decimal LeftToPay(Employee employee, decimal paidThisMonth)
    {
        return LeftToPay(employee, employee.TotalSales, paidThisMonth);
    }

    /// <summary>
    /// What still has to be paid out for a month: the salary plus the bonus
    /// owed on that month's sales, minus what was paid in the month.
    /// </summary>
    public static decimal LeftToPay(
        Employee employee,
        decimal sales,
        decimal paid)
    {
        var owed = employee.Salary + BonusAmount(employee, sales) - paid;

        return owed > 0 ? owed : 0m;
    }
}