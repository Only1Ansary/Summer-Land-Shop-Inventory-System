using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SummerLandBackend.Migrations
{
    /// <inheritdoc />
    public partial class AddVariantPurchaseAndSellingPrices : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Price",
                table: "ProductVariants",
                newName: "SellingPrice");

            migrationBuilder.AddColumn<decimal>(
                name: "PurchasePrice",
                table: "ProductVariants",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            // The product's purchase price is authoritative; copy it to every
            // existing variant. SellingPrice keeps the old Price value from the
            // rename above.
            migrationBuilder.Sql("""
                UPDATE v
                SET v.PurchasePrice = p.PurchasePrice
                FROM ProductVariants v
                INNER JOIN Products p ON p.Id = v.ProductId;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PurchasePrice",
                table: "ProductVariants");

            migrationBuilder.RenameColumn(
                name: "SellingPrice",
                table: "ProductVariants",
                newName: "Price");
        }
    }
}
