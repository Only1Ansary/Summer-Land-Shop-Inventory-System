using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SummerLandBackend.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerTotalDebt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "TotalDebt",
                table: "Customers",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            // Backfill existing customers from their invoices and payments so
            // the new stored value matches what the API used to compute.
            migrationBuilder.Sql(@"
UPDATE c
SET TotalDebt = ISNULL((
    SELECT SUM(CASE
        WHEN i.TotalAmount - ISNULL(p.Paid, 0) > 0
        THEN i.TotalAmount - ISNULL(p.Paid, 0)
        ELSE 0
    END)
    FROM Invoices i
    OUTER APPLY (
        SELECT SUM(cp.Amount) AS Paid
        FROM CustomerPayments cp
        WHERE cp.SaleInvoiceId = i.Id
    ) p
    WHERE i.CustomerId = c.Id
), 0)
FROM Customers c;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TotalDebt",
                table: "Customers");
        }
    }
}
