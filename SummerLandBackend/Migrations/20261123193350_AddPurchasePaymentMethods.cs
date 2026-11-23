using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SummerLandBackend.Migrations
{
    /// <inheritdoc />
    public partial class AddPurchasePaymentMethods : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Method",
                table: "SupplierPayments",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "PaymentMethod",
                table: "PurchaseInvoices",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Method",
                table: "SupplierPayments");

            migrationBuilder.DropColumn(
                name: "PaymentMethod",
                table: "PurchaseInvoices");
        }
    }
}
