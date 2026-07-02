using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BridalGlow.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalReservationCompletedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CompletedAtUtc",
                table: "RentalReservations",
                type: "timestamp without time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CompletedAtUtc",
                table: "RentalReservations");
        }
    }
}
