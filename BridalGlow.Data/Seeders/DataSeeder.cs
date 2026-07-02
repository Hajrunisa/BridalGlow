using BridalGlow.Data.Entities;
using BridalGlow.Model.Enums;
using BridalGlow.Data.Helpers;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Data.Seeders;

public static class DataSeeder
{
    private static readonly DateTime SeedTimestamp = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    public static void SeedLookupData(this ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<DressCategory>().HasData(
            new DressCategory { Id = 1, Name = "A-Line", Description = "Klasična A-silueta, pogodna za većinu tipova tijela", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressCategory { Id = 2, Name = "Ball Gown", Description = "Princess/ball gown silueta sa širokim skotom", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressCategory { Id = 3, Name = "Mermaid", Description = "Uska silueta do koljena, zatim širi donji dio", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressCategory { Id = 4, Name = "Sheath", Description = "Elegantna, uska i jednostavna silueta", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressCategory { Id = 5, Name = "Bohemian", Description = "Lagani, romantični stil sa čipkom i detaljima", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressCategory { Id = 6, Name = "Vintage", Description = "Retro i vintage inspirisani modeli", CreatedAtUtc = SeedTimestamp, IsDeleted = false }
        );

        modelBuilder.Entity<DressTag>().HasData(
            new DressTag { Id = 1, Name = "Lace", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 2, Name = "Satin", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 3, Name = "Long Train", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 4, Name = "Sleeveless", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 5, Name = "Off-Shoulder", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 6, Name = "Beaded", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 7, Name = "Minimalist", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 8, Name = "Plus Size", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 9, Name = "Ivory", CreatedAtUtc = SeedTimestamp, IsDeleted = false },
            new DressTag { Id = 10, Name = "Open Back", CreatedAtUtc = SeedTimestamp, IsDeleted = false }
        );

        const string defaultPassword = "test";
        var adminSalt = PasswordGenerator.GenerateDeterministicSalt("admin");
        var adminHash = PasswordGenerator.GenerateHash(defaultPassword, adminSalt);

        modelBuilder.Entity<User>().HasData(
            new User
            {
                Id = 1,
                FirstName = "Admin",
                LastName = "BridalGlow",
                Email = "admin@bridalglow.com",
                Username = "admin",
                PasswordHash = adminHash,
                PasswordSalt = adminSalt,
                Role = UserRole.Admin,
                IsActive = true,
                CreatedAtUtc = SeedTimestamp,
                IsDeleted = false
            }
        );
    }
}
