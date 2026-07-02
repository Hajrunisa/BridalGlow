using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BridalGlow.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalReservationNotes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "RentalReservations",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Notes",
                table: "RentalReservations");
        }
    }
}
