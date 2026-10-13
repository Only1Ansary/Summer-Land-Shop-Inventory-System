namespace SummerLandBackend.Models
{
    /// <summary>
    /// One month of an employee's recorded performance. Filled in from the
    /// sales data and shown in the app as read-only history.
    /// </summary>
    public class EmployeeMonth
    {
        public int Id { get; set; }

        public int EmployeeId { get; set; }

        public Employee Employee { get; set; } = null!;

        public int Year { get; set; }

        /// <summary>Month number, 1 (January) to 12 (December).</summary>
        public int Month { get; set; }

        public decimal TotalSales { get; set; }

        public decimal Bonus { get; set; }

        public bool AchievedTarget { get; set; }
    }
}
