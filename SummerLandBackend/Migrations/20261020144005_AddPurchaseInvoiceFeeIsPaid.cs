using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SummerLandBackend.Migrations
{
    /// <inheritdoc />
    public partial class AddPurchaseInvoiceFeeIsPaid : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsPaid",
                table: "PurchaseInvoiceFees",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsPaid",
                table: "PurchaseInvoiceFees");
        }
    }
}
