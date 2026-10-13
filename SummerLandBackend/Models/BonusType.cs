namespace SummerLandBackend.Models;

/// How an employee's bonus is worked out.
public enum BonusType
{
    /// A fixed amount in EGP, set by the manager.
    Fixed = 0,

    /// A percentage of the employee's total sales for the month.
    Percentage = 1,
}