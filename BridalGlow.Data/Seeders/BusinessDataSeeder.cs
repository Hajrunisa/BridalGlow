using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Data.Helpers;
using BridalGlow.Model.Enums;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Data.Seeders;

/// <summary>
/// Runtime seeder for business data: Dress, DressImage, DressTagMap.
/// Runs once on startup when no Dresses exist.
/// Reference/lookup data (DressCategory, DressTag) is handled via HasData in migrations.
/// </summary>
public static class BusinessDataSeeder
{
    private static readonly DateTime SeedTs = new(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    private const int SeedImageCount = 40;

    private static int _nextSeedImageIndex = 1;

    private static string SeedImageFileName(int globalIndex)
    {
        var number = globalIndex <= SeedImageCount
            ? globalIndex
            : globalIndex - SeedImageCount;
        return $"wd{number}.jpg";
    }

    private static string LocalSeedUrl(int globalIndex)
        => $"/uploads/{SeedImageFileInitializer.SeedUploadSubdirectory}/{SeedImageFileName(globalIndex)}";

    private static string LocalStorageKey(int globalIndex)
        => $"{SeedImageFileInitializer.SeedUploadSubdirectory}/{SeedImageFileName(globalIndex)}";

    public static void SeedBusinessData(this BridalGlowDbContext context)
    {
        SeedTestUsers(context);

        // BG-001 je seed anchor – ako postoji, seed je već bio pokrenut.
        // Provjera je vezana za konkretan seed kod, ne za Any(),
        // kako ručno dodani testni zapisi iz Swaggera ne bi blokirali seed.
        if (context.Dresses.Any(d => d.Code == "BG-001"))
            return;

        // Ako postoje djelimični seed zapisi (npr. od prethodnog neuspjelog pokušaja),
        // ukloniti ih prije ponovnog inseriranja kako bi se izbjegla povreda UniqueIndex na Code.
        var seedCodes = Enumerable.Range(1, 20)
            .Select(i => $"BG-{i:D3}")
            .ToHashSet(StringComparer.Ordinal);

        var partial = context.Dresses
            .Where(d => seedCodes.Contains(d.Code))
            .ToList();

        if (partial.Count > 0)
            context.Dresses.RemoveRange(partial);

        _nextSeedImageIndex = 1;
        var dresses = BuildDresses();
        context.Dresses.AddRange(dresses);
        context.SaveChanges();
    }

    private static List<Dress> BuildDresses()
    {
        return new List<Dress>
        {
            // ─── A-Line (CategoryId = 1) ────────────────────────────────────────
            Dress("BG-001", "Biserná A-linija", 1, "Bijela", "Saten", "A-Line",
                "V-izrez", "Bez rukava", "Kratka šlep", "38", 88, 66, 92, 160,
                DressCondition.Excellent, 850m, 1200m, 250m, 50m, 150m,
                "Elegantna vjenčanica s bisernom aplikacijom, savršena za ljetna vjenčanja.",
                "Vera Wang", true,
                tags: new[] { 2, 4, 9 },
                images: 3),

            Dress("BG-002", "Romantična čipkana A-linija", 1, "Boja slonovače", "Čipka i tul",
                "A-Line", "Okrugli izrez", "Cap rukavi", "Srednja šlep", "36",
                84, 62, 88, 158,
                DressCondition.Excellent, 1100m, 1500m, 320m, 60m, 200m,
                "Lagana čipkana haljina s romantičnim detaljima i tulovskim suknjom.",
                "Maggie Sottero", true,
                tags: new[] { 1, 3, 5, 9 },
                images: 4),

            Dress("BG-003", "Minimalistička A-linija", 1, "Bijela", "Krep",
                "A-Line", "Zavijeni izrez", "Bez rukava", "Bez šlepa", "40",
                92, 70, 96, 162,
                DressCondition.VeryGood, 600m, 900m, 180m, 40m, 100m,
                "Čista minimalistička linija bez ukrasa, savršena za modernu mladu.",
                "Pronovias", false,
                tags: new[] { 4, 7, 9 },
                images: 2),

            Dress("BG-004", "Dvorska A-linija s perjem", 1, "Bijela", "Mikado",
                "A-Line", "Srcolik izrez", "Bez rukava", "Duga šlep", "34",
                80, 60, 86, 156,
                DressCondition.Excellent, 1500m, 2000m, 450m, 80m, 250m,
                "Luksuzna haljina s detaljima od perja na donjem rubu, za sofisticirane mladenke.",
                "Monique Lhuillier", true,
                tags: new[] { 4, 6, 9, 10 },
                images: 3),

            // ─── Ball Gown / Princeza (CategoryId = 2) ──────────────────────────
            Dress("BG-005", "Kraljevska princeza", 2, "Bijela", "Taft i tul",
                "Ball Gown", "Srcolik izrez", "Bez rukava", "Katedralna šlep", "38",
                88, 66, 92, 163,
                DressCondition.Excellent, 2000m, 2800m, 550m, 100m, 300m,
                "Veličanstvena princeza silueta s bujnim tulovskim slojevima i kristalnim aplikacijama.",
                "Elie Saab", true,
                tags: new[] { 3, 4, 6, 9 },
                images: 4),

            Dress("BG-006", "Zlatna princeza", 2, "Zlato-bijela", "Taft",
                "Ball Gown", "Off-shoulder", "Kratki rukavi", "Dvorska šlep", "36",
                84, 62, 88, 160,
                DressCondition.VeryGood, 1800m, 2400m, 480m, 90m, 280m,
                "Raskošna haljina sa zlatnim vezom i bujnim suknjom, inspirisana dvorskim stilom.",
                "Zuhair Murad", false,
                tags: new[] { 3, 5, 6 },
                images: 3),

            Dress("BG-007", "Bujni saten ball gown", 2, "Bijela", "Saten",
                "Ball Gown", "Kvadratni izrez", "Bez rukava", "Katedralna šlep", "42",
                96, 74, 100, 165,
                DressCondition.Good, 900m, 1400m, 280m, 55m, 180m,
                "Klasična saten princeza haljina s punim suknjom, dostupna u plus size velični.",
                "Justin Alexander", false,
                tags: new[] { 2, 3, 4, 8 },
                images: 2),

            Dress("BG-008", "Romantična princeza s čipkom", 2, "Boja slonovače", "Čipka i taft",
                "Ball Gown", "Srcolik izrez", "Cap rukavi", "Kapelska šlep", "36",
                84, 62, 88, 158,
                DressCondition.Excellent, 1400m, 1900m, 400m, 75m, 230m,
                "Romantična princeza haljina s punom čipkanom gornjom haljinom i voluminoznim taftom.",
                "Rebecca Ingram", true,
                tags: new[] { 1, 2, 3, 9 },
                images: 3),

            // ─── Mermaid / Sirena (CategoryId = 3) ─────────────────────────────
            Dress("BG-009", "Sirena u bijelom", 3, "Bijela", "Saten i krep",
                "Mermaid", "V-izrez", "Bez rukava", "Kapelska šlep", "36",
                84, 62, 88, 164,
                DressCondition.Excellent, 1300m, 1800m, 380m, 70m, 220m,
                "Senzualna sirena silueta koja naglašava figure, s elegantnom šlepom.",
                "Stella York", true,
                tags: new[] { 2, 4, 10 },
                images: 3),

            Dress("BG-010", "Sirena s punom čipkom", 3, "Boja slonovače", "Čipka",
                "Mermaid", "Okrugli izrez", "Illusion rukavi", "Dvorska šlep", "38",
                88, 66, 92, 162,
                DressCondition.Excellent, 1600m, 2100m, 420m, 80m, 240m,
                "Čipkana sirena haljina s iluzijskim rukavima i dugom šlepom, puna romantike.",
                "Essense of Australia", false,
                tags: new[] { 1, 3, 9 },
                images: 4),

            Dress("BG-011", "Moderna sirena – open back", 3, "Bijela", "Krep",
                "Mermaid", "Halter izrez", "Bez rukava", "Srednja šlep", "34",
                80, 58, 84, 166,
                DressCondition.VeryGood, 1000m, 1400m, 300m, 60m, 180m,
                "Moderna krep sirena s dramatičnim otvorenim leđima, za hrabre mladenke.",
                "Wtoo", false,
                tags: new[] { 4, 7, 10 },
                images: 2),

            Dress("BG-012", "Glamurozna sirena s perjem", 3, "Bijela", "Mikado",
                "Mermaid", "Off-shoulder", "Bez rukava", "Katedralna šlep", "38",
                88, 66, 92, 163,
                DressCondition.Excellent, 2200m, 3000m, 600m, 110m, 350m,
                "Glamurozna sirena haljina s perjem na donjem rubu i devet metara šlepa.",
                "Berta", true,
                tags: new[] { 3, 5, 6, 10 },
                images: 3),

            // ─── Sheath / Uska (CategoryId = 4) ─────────────────────────────────
            Dress("BG-013", "Minimalistička kolumna", 4, "Bijela", "Krep",
                "Sheath", "Okrugli izrez", "Bez rukava", "Bez šlepa", "38",
                88, 66, 92, 162,
                DressCondition.Excellent, 700m, 1000m, 200m, 45m, 120m,
                "Čista kolumna silueta za modernu mladu koja preferira minimalizam.",
                "Amsale", false,
                tags: new[] { 4, 7, 9 },
                images: 2),

            Dress("BG-014", "Saten sheath s V-leđima", 4, "Bijela", "Saten",
                "Sheath", "V-izrez", "Bez rukava", "Kratka šlep", "36",
                84, 62, 88, 160,
                DressCondition.VeryGood, 850m, 1200m, 240m, 50m, 140m,
                "Elegantna saten haljina s duboko urezanim leđima u V-obliku.",
                "Carolina Herrera", true,
                tags: new[] { 2, 4, 10 },
                images: 3),

            Dress("BG-015", "Luxe sheath s perlonosnim vezom", 4, "Boja slonovače", "Georgette",
                "Sheath", "Srcolik izrez", "Kratki rukavi", "Srednja šlep", "40",
                92, 70, 96, 164,
                DressCondition.Good, 950m, 1300m, 270m, 55m, 160m,
                "Lagana georgette haljina s perlonasnim vezom, idealna za primorska vjenčanja.",
                "Nicole Miller", false,
                tags: new[] { 2, 6, 9 },
                images: 2),

            // ─── Bohemian (CategoryId = 5) ──────────────────────────────────────
            Dress("BG-016", "Boho vila s cvjetovima", 5, "Boja slonovače", "Šifonj",
                "A-Line", "V-izrez", "Leptir rukavi", "Bez šlepa", "38",
                88, 66, 92, 158,
                DressCondition.Excellent, 650m, 950m, 190m, 40m, 110m,
                "Lagana šifon boho haljina s ručno apliciranim cvjetovima, savršena za vanjska vjenčanja.",
                "Grace Loves Lace", true,
                tags: new[] { 1, 4, 9 },
                images: 3),

            Dress("BG-017", "Romantični boho s čipkom", 5, "Bijela", "Čipka i šifonj",
                "A-Line", "Okrugli izrez", "Duge rukave", "Kapelska šlep", "36",
                84, 62, 88, 160,
                DressCondition.VeryGood, 800m, 1100m, 230m, 45m, 130m,
                "Romantična boho haljina s punim čipkanim rukavima i boho detaljima.",
                "For Love & Lemons", false,
                tags: new[] { 1, 3, 9 },
                images: 2),

            Dress("BG-018", "Maxi boho s prslukom", 5, "Krema", "Tul i krep",
                "A-Line", "Zavijeni izrez", "Bez rukava", "Bez šlepa", "42",
                96, 74, 100, 162,
                DressCondition.Good, 550m, 800m, 160m, 35m, 90m,
                "Slobodna boho maxi haljina, dostupna u plus size velični, s ukrasnim pojasom.",
                "BHLDN", false,
                tags: new[] { 4, 7, 8, 9 },
                images: 2),

            // ─── Vintage (CategoryId = 6) ───────────────────────────────────────
            Dress("BG-019", "Vintage čipkana 50-ih", 6, "Boja slonovače", "Čipka",
                "Ball Gown", "Srcolik izrez", "Cap rukavi", "Kapelska šlep", "36",
                84, 62, 88, 156,
                DressCondition.VeryGood, 750m, 1100m, 210m, 50m, 130m,
                "Inspirisana 1950-im godinama, s boatom neckline i punim suknjom od čipke.",
                "Vintage Atelier", true,
                tags: new[] { 1, 3, 9 },
                images: 3),

            Dress("BG-020", "Retro glamur 20-ih", 6, "Boja šampanjca", "Saten i perle",
                "Sheath", "V-izrez", "Kratki rukavi", "Bez šlepa", "38",
                88, 66, 92, 158,
                DressCondition.Good, 900m, 1300m, 260m, 55m, 150m,
                "Art Deco inspirisana vjenčanica s perlonasnim vezom i glamuroznim detaljem 1920-ih.",
                "Vintage Atelier", false,
                tags: new[] { 2, 6, 9 },
                images: 2),
        };
    }

    private static Dress Dress(
        string code, string name, int categoryId, string color, string material,
        string silhouette, string neckline, string sleeveType, string trainLength,
        string sizeLabel,
        decimal bust, decimal waist, decimal hip, decimal length,
        DressCondition condition,
        decimal acquisitionCost, decimal replacementValue,
        decimal baseRentalPrice, decimal tryOnPrice, decimal depositAmount,
        string description, string brand, bool isFeatured,
        int[] tags, int images)
    {
        var dress = new Dress
        {
            Code = code,
            Name = name,
            Description = description,
            Brand = brand,
            Color = color,
            Material = material,
            Silhouette = silhouette,
            Neckline = neckline,
            SleeveType = sleeveType,
            TrainLength = trainLength,
            SizeLabel = sizeLabel,
            BustCm = bust,
            WaistCm = waist,
            HipCm = hip,
            LengthCm = length,
            Condition = condition,
            AcquisitionCost = acquisitionCost,
            ReplacementValue = replacementValue,
            BaseRentalPrice = baseRentalPrice,
            TryOnPrice = tryOnPrice,
            DepositAmount = depositAmount,
            Status = DressStatus.Active,
            IsFeatured = isFeatured,
            AverageRating = 0,
            RatingCount = 0,
            PrimaryCategoryId = categoryId,
            CreatedAtUtc = SeedTs,
            IsDeleted = false
        };

        for (int i = 1; i <= images; i++)
        {
            var globalIndex = _nextSeedImageIndex++;
            dress.Images.Add(new DressImage
            {
                Url = LocalSeedUrl(globalIndex),
                StorageKey = LocalStorageKey(globalIndex),
                AltText = $"{name} – slika {i}",
                SortOrder = i,
                IsPrimary = i == 1,
                WidthPx = 800,
                HeightPx = 1200,
                FileSizeBytes = 120_000,
                MimeType = "image/jpeg",
                CreatedAtUtc = SeedTs,
                IsDeleted = false
            });
        }

        foreach (var tagId in tags)
        {
            dress.TagMaps.Add(new DressTagMap
            {
                DressTagId = tagId,
                CreatedAtUtc = SeedTs,
                IsDeleted = false
            });
        }

        return dress;
    }

    private static void SeedTestUsers(BridalGlowDbContext context)
    {
        bool changed = false;

        if (!context.Users.Any(u => u.Username == "staff"))
        {
            var salt = PasswordGenerator.GenerateDeterministicSalt("staff_seed");
            var hash = PasswordGenerator.GenerateHash("test", salt);
            context.Users.Add(new User
            {
                FirstName = "Salon",
                LastName = "Staff",
                Email = "staff@bridalglow.com",
                Username = "staff",
                PasswordHash = hash,
                PasswordSalt = salt,
                Role = UserRole.SalonStaff,
                IsActive = true,
                CreatedAtUtc = SeedTs,
                IsDeleted = false
            });
            changed = true;
        }

        if (!context.Users.Any(u => u.Username == "customer"))
        {
            var salt = PasswordGenerator.GenerateDeterministicSalt("customer_seed");
            var hash = PasswordGenerator.GenerateHash("test", salt);
            context.Users.Add(new User
            {
                FirstName = "Test",
                LastName = "Customer",
                Email = "customer@bridalglow.com",
                Username = "customer",
                PasswordHash = hash,
                PasswordSalt = salt,
                Role = UserRole.Customer,
                IsActive = true,
                CreatedAtUtc = SeedTs,
                IsDeleted = false
            });
            changed = true;
        }

        if (changed)
            context.SaveChanges();
    }
}
