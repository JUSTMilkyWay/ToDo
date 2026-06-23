using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ToDo_proj.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddDailyQuotesTable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Author",
                table: "Quotes",
                type: "TEXT",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Author",
                table: "Quotes");
        }
    }
}
