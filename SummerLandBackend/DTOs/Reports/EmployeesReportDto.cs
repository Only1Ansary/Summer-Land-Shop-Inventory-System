namespace SummerLandBackend.DTOs.Reports
{
    public class EmployeesReportDto
    {
        /// <summary>The month the report was run for.</summary>
        public int Year { get; set; }

        public int Month { get; set; }

        public int EmployeeCount { get; set; }

        /// <summary>The sum of every employee's monthly salary.</summary>
        public decimal TotalMonthlySalaries { get; set; }

        /// <summary>The bonus owed across employees for the month.</summary>
        public decimal TotalBonusOwed { get; set; }

        /// <summary>Sales recorded by employees during the month.</summary>
        public decimal TotalSales { get; set; }

        public int TargetMetCount { get; set; }

        /// <summary>Payments settled during the month.</summary>
        public int PaymentCountInMonth { get; set; }

        public decimal PaymentTotalInMonth { get; set; }

        /// <summary>Everything paid out so far, regardless of month.</summary>
        public decimal TotalPaid { get; set; }

        /// <summary>The sum of what is still owed to employees this month.</summary>
        public decimal TotalLeftToPay { get; set; }

        /// <summary>
        /// The employee(s) with the highest sales in the month. Holds every
        /// employee tied at the top, and is empty when nobody sold anything.
        /// </summary>
        public List<EmployeeOfMonthDto> EmployeeOfTheMonth { get; set; }
            = new List<EmployeeOfMonthDto>();

        public List<EmployeeReportItemDto> Employees { get; set; }
            = new List<EmployeeReportItemDto>();
    }

    public class EmployeeOfMonthDto
    {
        public int EmployeeId { get; set; }

        public string Name { get; set; } = string.Empty;

        public decimal TotalSales { get; set; }
    }

    public class EmployeeReportItemDto
    {
        public int EmployeeId { get; set; }

        public string Name { get; set; } = string.Empty;

        public int BonusType { get; set; }

        public decimal Salary { get; set; }

        public decimal Target { get; set; }

        /// <summary>The raw bonus value: EGP when fixed, percent when a
        /// percentage of sales.</summary>
        public decimal Bonus { get; set; }

        /// <summary>The bonus actually owed for the month.</summary>
        public decimal BonusAmount { get; set; }

        /// <summary>Sales recorded by the employee during the month.</summary>
        public decimal TotalSales { get; set; }

        public bool AchievedTarget { get; set; }

        public int PaymentCountInMonth { get; set; }

        public decimal PaymentTotalInMonth { get; set; }

        public decimal TotalPaid { get; set; }

        /// <summary>Salary + bonus owed for the month.</summary>
        public decimal MonthlyObligation { get; set; }

        /// <summary>What still has to be paid out for the month.</summary>
        public decimal LeftToPay { get; set; }
    }
}
