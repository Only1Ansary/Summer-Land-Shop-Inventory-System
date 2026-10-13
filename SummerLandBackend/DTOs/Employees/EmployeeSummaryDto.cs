namespace SummerLandBackend.DTOs.Employees
{
    /// <summary>An employee as shown in the list, with pay figures.</summary>
    public class EmployeeSummaryDto
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public decimal Salary { get; set; }

        public decimal Target { get; set; }

        public decimal Bonus { get; set; }

        public int BonusType { get; set; }

        public bool AchievedTarget { get; set; }

        public decimal TotalSales { get; set; }

        /// <summary>Salary + bonus owed for the current month.</summary>
        public decimal MonthlyObligation { get; set; }

        /// <summary>Payments recorded in the current calendar month.</summary>
        public decimal PaidThisMonth { get; set; }

        /// <summary>What still has to be paid out this month.</summary>
        public decimal LeftToPay { get; set; }
    }
}