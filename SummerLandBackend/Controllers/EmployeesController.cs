using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.DTOs.Employees;
using SummerLandBackend.Models;
using SummerLandBackend.Services;

namespace SummerLandBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EmployeesController : ControllerBase
{
    private readonly ShopDbContext _context;

    public EmployeesController(ShopDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<EmployeeSummaryDto>>> GetEmployees()
    {
        var employees = await _context.Employees
            .OrderBy(e => e.Name)
            .ToListAsync();

        var paidThisMonth = await GetPaidThisMonthAsync();

        return employees
            .Select(e =>
            {
                var paid = paidThisMonth.TryGetValue(e.Id, out var value)
                    ? value
                    : 0m;

                return new EmployeeSummaryDto
                {
                    Id = e.Id,
                    Name = e.Name,
                    Salary = e.Salary,
                    Target = e.Target,
                    Bonus = e.Bonus,
                    BonusType = (int)e.BonusType,
                    AchievedTarget = e.AchievedTarget,
                    TotalSales = e.TotalSales,
                    MonthlyObligation = e.Salary
                        + EmployeeCompensation.BonusAmount(e),
                    PaidThisMonth = paid,
                    LeftToPay = EmployeeCompensation.LeftToPay(e, paid),
                };
            })
            .ToList();
    }

    private async Task<Dictionary<int, decimal>> GetPaidThisMonthAsync()
    {
        var now = DateTime.UtcNow;
        var monthStart = new DateTime(now.Year, now.Month, 1,
            0, 0, 0, DateTimeKind.Utc);

        var rows = await _context.EmployeePayments
            .Where(p => p.PaidAt >= monthStart && p.PaidAt < monthStart.AddMonths(1))
            .GroupBy(p => p.EmployeeId)
            .Select(g => new
            {
                EmployeeId = g.Key,
                Paid = g.Sum(p => p.Amount)
            })
            .ToListAsync();

        return rows.ToDictionary(r => r.EmployeeId, r => r.Paid);
    }

    [HttpGet("{id}/history")]
    public async Task<ActionResult<IEnumerable<EmployeeMonth>>> GetEmployeeHistory(
        int id)
    {
        var exists = await _context.Employees
            .AnyAsync(e => e.Id == id);

        if (!exists)
        {
            return NotFound("Employee not found.");
        }

        return await _context.EmployeeMonths
            .Where(m => m.EmployeeId == id)
            .OrderByDescending(m => m.Year)
            .ThenByDescending(m => m.Month)
            .ToListAsync();
    }

    [HttpPost]
    public async Task<ActionResult<Employee>> CreateEmployee(
        CreateEmployeeDto dto)
    {
        // A new employee starts with no bonus and no recorded sales; those
        // are filled in later when the employee is edited.
        var employee = new Employee
        {
            Name = dto.Name.Trim(),
            Salary = dto.Salary,
            Target = dto.Target,
            Bonus = 0,
            AchievedTarget = false,
            TotalSales = 0,
        };

        _context.Employees.Add(employee);
        await _context.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetEmployees),
            new { id = employee.Id },
            employee);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateEmployee(
        int id,
        UpdateEmployeeDto dto)
    {
        var employee = await _context.Employees
            .FirstOrDefaultAsync(e => e.Id == id);

        if (employee == null)
        {
            return NotFound("Employee not found.");
        }

        employee.Name = dto.Name.Trim();
        employee.Salary = dto.Salary;
        employee.Target = dto.Target;
        employee.Bonus = dto.Bonus;
        employee.BonusType = dto.BonusType;

        // TotalSales is recorded from sales data and is view-only in the
        // app, but the target flag has to follow the new target.
        employee.AchievedTarget =
            employee.Target > 0 && employee.TotalSales >= employee.Target;

        var now = DateTime.UtcNow;

        var currentMonth = await _context.EmployeeMonths
            .FirstOrDefaultAsync(m =>
                m.EmployeeId == id &&
                m.Year == now.Year &&
                m.Month == now.Month);

        if (currentMonth != null)
        {
            currentMonth.AchievedTarget = employee.AchievedTarget;
        }

        await _context.SaveChangesAsync();

        return Ok(employee);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteEmployee(int id)
    {
        var employee = await _context.Employees
            .FirstOrDefaultAsync(e => e.Id == id);

        if (employee == null)
        {
            return NotFound("Employee not found.");
        }

        // Removing the employee drops their monthly history. The invoices
        // they sold stay and keep the stored EmployeeName.
        _context.Employees.Remove(employee);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    [HttpPost("{id}/payments")]
    public async Task<ActionResult<EmployeePayment>> RecordEmployeePayment(
        int id,
        CreateEmployeePaymentDto dto)
    {
        var employee = await _context.Employees
            .FirstOrDefaultAsync(e => e.Id == id);

        if (employee == null)
        {
            return NotFound("Employee not found.");
        }

        if (dto.Amount <= 0)
        {
            return BadRequest("Payment amount must be greater than zero.");
        }

        var payment = new EmployeePayment
        {
            EmployeeId = id,
            Amount = dto.Amount,
            PaidAt = dto.PaidAt?.ToUniversalTime() ?? DateTime.UtcNow,
        };

        // A fixed bonus settles in one go, so it is cleared afterwards and is
        // not paid out twice. A percentage is a standing rate worked out
        // from the month's sales, so it is left in place.
        if (employee.BonusType == BonusType.Fixed && employee.Bonus > 0)
        {
            employee.Bonus = 0;
        }

        _context.EmployeePayments.Add(payment);
        await _context.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetEmployeePayments),
            new { id },
            payment);
    }

    [HttpGet("{id}/payments")]
    public async Task<ActionResult<IEnumerable<EmployeePayment>>> GetEmployeePayments(
        int id)
    {
        var exists = await _context.Employees
            .AnyAsync(e => e.Id == id);

        if (!exists)
        {
            return NotFound("Employee not found.");
        }

        return await _context.EmployeePayments
            .Where(p => p.EmployeeId == id)
            .OrderByDescending(p => p.PaidAt)
            .ThenByDescending(p => p.Id)
            .ToListAsync();
    }
}
