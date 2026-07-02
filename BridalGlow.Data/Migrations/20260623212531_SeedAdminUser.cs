using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BridalGlow.Data.Migrations
{
    /// <inheritdoc />
    public partial class SeedAdminUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "Users",
                columns: new[] { "Id", "CreatedAtUtc", "CreatedByUserId", "DateOfBirth", "Email", "FirstName", "IsActive", "LastLoginAtUtc", "LastName", "PasswordHash", "PasswordSalt", "Phone", "Role", "UpdatedAtUtc", "UpdatedByUserId", "Username" },
                values: new object[] { 1, new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Utc), null, null, "admin@bridalglow.com", "Admin", true, null, "BridalGlow", "6OyXqO2hMVhPnu28C3eluABDPfhwIXphrtpYIz+83MU=", "jGl25bVBBBW96Qi9Te4V3w==", null, 1, null, null, "admin" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "Users",
                keyColumn: "Id",
                keyValue: 1);
        }
    }
}
