using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SummerLandBackend.Migrations
{
    /// <inheritdoc />
    public partial class ChangeLowStockThresholdTo2 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                "UPDATE \"ProductVariants\" SET \"LowStockThreshold\" = 2 "
                + "WHERE \"LowStockThreshold\" = 5;");

            migrationBuilder.Sql(
                "UPDATE \"Inventory\" SET \"LowStockThreshold\" = 2 "
                + "WHERE \"LowStockThreshold\" = 5;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                "UPDATE \"ProductVariants\" SET \"LowStockThreshold\" = 5 "
                + "WHERE \"LowStockThreshold\" = 2;");

            migrationBuilder.Sql(
                "UPDATE \"Inventory\" SET \"LowStockThreshold\" = 5 "
                + "WHERE \"LowStockThreshold\" = 2;");
        }
    }
}
