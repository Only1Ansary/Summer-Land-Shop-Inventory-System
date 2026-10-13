namespace SummerLandBackend.Models
{
    public class Employee
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public decimal Salary { get; set; }

        /// <summary>Sales target the employee is expected to reach.</summary>
        public decimal Target { get; set; }

        public decimal Bonus { get; set; }

        /// <summary>
        /// How <see cref="Bonus"/> is read: a fixed amount, or a percentage
        /// of total sales.
        /// </summary>
        public BonusType BonusType { get; set; }

        /// <summary>Whether the employee reached their sales target.</summary>
        public bool AchievedTarget { get; set; }

        public decimal TotalSales { get; set; }
    }
}
