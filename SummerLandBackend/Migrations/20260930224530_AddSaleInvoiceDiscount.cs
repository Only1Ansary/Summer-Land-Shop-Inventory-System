using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SummerLandBackend.Migrations
{
    /// <inheritdoc />
    public partial class AddSaleInvoiceDiscount : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "DiscountAmount",
                table: "Invoices",
                type: "TEXT",
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DiscountAmount",
                table: "Invoices");
        }
    }
}
