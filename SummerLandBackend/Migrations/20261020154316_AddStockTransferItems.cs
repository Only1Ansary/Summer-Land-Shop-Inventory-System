using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SummerLandBackend.Migrations
{
    /// <inheritdoc />
    public partial class AddStockTransferItems : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Create the items table first so existing transfers' variant and
            // quantity can be carried across before the old columns are dropped.
            migrationBuilder.CreateTable(
                name: "StockTransferItems",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    StockTransferId = table.Column<int>(type: "INTEGER", nullable: false),
                    ProductVariantId = table.Column<int>(type: "INTEGER", nullable: false),
                    Quantity = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockTransferItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_StockTransferItems_ProductVariants_ProductVariantId",
                        column: x => x.ProductVariantId,
                        principalTable: "ProductVariants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_StockTransferItems_StockTransfers_StockTransferId",
                        column: x => x.StockTransferId,
                        principalTable: "StockTransfers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StockTransferItems_ProductVariantId",
                table: "StockTransferItems",
                column: "ProductVariantId");

            migrationBuilder.CreateIndex(
                name: "IX_StockTransferItems_StockTransferId",
                table: "StockTransferItems",
                column: "StockTransferId");

            // Preserve existing transfers: one item per old transfer row.
            migrationBuilder.Sql(
                @"INSERT INTO StockTransferItems (StockTransferId, ProductVariantId, Quantity)
                  SELECT Id, ProductVariantId, Quantity FROM StockTransfers;");

            migrationBuilder.DropForeignKey(
                name: "FK_StockTransfers_ProductVariants_ProductVariantId",
                table: "StockTransfers");

            migrationBuilder.DropIndex(
                name: "IX_StockTransfers_ProductVariantId",
                table: "StockTransfers");

            migrationBuilder.DropColumn(
                name: "ProductVariantId",
                table: "StockTransfers");

            migrationBuilder.DropColumn(
                name: "Quantity",
                table: "StockTransfers");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StockTransferItems");

            migrationBuilder.AddColumn<int>(
                name: "ProductVariantId",
                table: "StockTransfers",
                type: "INTEGER",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "Quantity",
                table: "StockTransfers",
                type: "INTEGER",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_StockTransfers_ProductVariantId",
                table: "StockTransfers",
                column: "ProductVariantId");

            migrationBuilder.AddForeignKey(
                name: "FK_StockTransfers_ProductVariants_ProductVariantId",
                table: "StockTransfers",
                column: "ProductVariantId",
                principalTable: "ProductVariants",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
