using System.ComponentModel.DataAnnotations;
using SummerLandBackend.Models;

namespace SummerLandBackend.DTOs.Employees
{
    // Total sales and the "achieved target" flag are not part of editing:
    // they are recorded by the sales data and are read-only in the app.
    public class UpdateEmployeeDto
    {
        [Required(ErrorMessage = "Enter the employee name.")]
        [MaxLength(200,
            ErrorMessage = "Employee name cannot exceed 200 characters.")]
        public string Name { get; set; } = string.Empty;

        [Range(0, double.MaxValue,
            ErrorMessage = "Enter a salary of 0 or more.")]
        public decimal Salary { get; set; }

        [Range(0, double.MaxValue,
            ErrorMessage = "Enter a target of 0 or more.")]
        public decimal Target { get; set; }

        [Range(0, double.MaxValue,
            ErrorMessage = "Enter a bonus of 0 or more.")]
        public decimal Bonus { get; set; }

        /// <summary>Fixed amount or percentage of total sales.</summary>
        public BonusType BonusType { get; set; }
    }
}
