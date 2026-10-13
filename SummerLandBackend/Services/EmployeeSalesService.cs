using Microsoft.EntityFrameworkCore;
using SummerLandBackend.Data;
using SummerLandBackend.Models;

namespace SummerLandBackend.Services;

/// <summary>
/// Keeps an employee's recorded sales in sync with the sale invoices and
/// returns raised against them. Every sale (or return) lands in the month
/// it belongs to, and the employee's own figures always mirror the month
/// currently in progress.
/// </summary>
public class EmployeeSalesService
{
    private readonly ShopDbContext _context;

    public EmployeeSalesService(ShopDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Adds the amount charged on a sale to the employee's figures for the
    /// month the sale was made in.
    /// </summary>
    public Task RecordSaleAsync(int employeeId, decimal amount, DateTime soldAt)
    {
        return ApplyAsync(employeeId, amount, soldAt);
    }

    /// <summary>
    /// Removes the amount refunded on a return from the employee's figures
    /// for the month the original sale was made in.
    /// </summary>
    public Task RecordReturnAsync(int employeeId, decimal amount, DateTime soldAt)
    {
        return ApplyAsync(employeeId, -amount, soldAt);
    }

    private async Task ApplyAsync(int employeeId, decimal amount, DateTime soldAt)
    {
        var employee = await _context.Employees
            .FirstOrDefaultAsync(e => e.Id == employeeId);

        if (employee == null)
        {
            return;
        }

        var month = await GetOrCreateMonthAsync(employeeId, soldAt);

        month.TotalSales += amount;

        // A return can never push a month below zero.
        if (month.TotalSales < 0)
        {
            month.TotalSales = 0;
        }

        month.AchievedTarget =
            employee.Target > 0 && month.TotalSales >= employee.Target;

        // The figures shown on the employee always describe the month in
        // progress, whatever month the invoice itself belongs to.
        await SyncWithCurrentMonthAsync(employee);
    }

    private async Task<EmployeeMonth> GetOrCreateMonthAsync(
        int employeeId,
        DateTime when)
    {
        // A row created earlier in this same request is not yet saved, so
        // it is not visible to a database query; check the tracked rows
        // first to avoid adding a duplicate.
        var month = _context.EmployeeMonths.Local.FirstOrDefault(m =>
                m.EmployeeId == employeeId &&
                m.Year == when.Year &&
                m.Month == when.Month)
            ?? await _context.EmployeeMonths.FirstOrDefaultAsync(m =>
                m.EmployeeId == employeeId &&
                m.Year == when.Year &&
                m.Month == when.Month);

        if (month != null)
        {
            return month;
        }

        month = new EmployeeMonth
        {
            EmployeeId = employeeId,
            Year = when.Year,
            Month = when.Month,
            TotalSales = 0,
            Bonus = 0,
            AchievedTarget = false,
        };

        _context.EmployeeMonths.Add(month);

        return month;
    }

    private async Task SyncWithCurrentMonthAsync(Employee employee)
    {
        var now = DateTime.UtcNow;

        var current = _context.EmployeeMonths.Local.FirstOrDefault(m =>
                m.EmployeeId == employee.Id &&
                m.Year == now.Year &&
                m.Month == now.Month)
            ?? await _context.EmployeeMonths.FirstOrDefaultAsync(m =>
                m.EmployeeId == employee.Id &&
                m.Year == now.Year &&
                m.Month == now.Month);

        employee.TotalSales = current?.TotalSales ?? 0;
        employee.AchievedTarget = current?.AchievedTarget ?? false;
    }
}
