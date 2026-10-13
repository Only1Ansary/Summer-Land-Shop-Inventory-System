using System.ComponentModel.DataAnnotations;

namespace SummerLandBackend.DTOs.Employees
{
    public class CreateEmployeeDto
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
    }
}
