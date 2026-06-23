using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ToDo_proj.Data.Migrations
{
    /// <inheritdoc />
    public partial class UpdatePriorityTableAndAddSeeding : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "HexColor",
                table: "Priorities",
                type: "TEXT",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "HexColor",
                table: "Priorities");
        }
    }
}
