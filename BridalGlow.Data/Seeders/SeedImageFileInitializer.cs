namespace BridalGlow.Data.Seeders;

/// <summary>
/// Copies bundled seed dress images from the repository seed-images folder
/// into uploads/dresses/seed/ without overwriting existing files.
/// </summary>
public static class SeedImageFileInitializer
{
    public const string SeedUploadSubdirectory = "dresses/seed";

    public static void EnsureSeedImagesCopied(string seedImagesSourceDirectory, string uploadsRoot)
    {
        if (string.IsNullOrWhiteSpace(seedImagesSourceDirectory) || !Directory.Exists(seedImagesSourceDirectory))
            return;

        var targetDir = Path.Combine(uploadsRoot, SeedUploadSubdirectory.Replace('/', Path.DirectorySeparatorChar));
        Directory.CreateDirectory(targetDir);

        foreach (var sourcePath in Directory.EnumerateFiles(seedImagesSourceDirectory, "wd*.jpg"))
        {
            var fileName = Path.GetFileName(sourcePath);
            var destinationPath = Path.Combine(targetDir, fileName);

            if (File.Exists(destinationPath))
                continue;

            File.Copy(sourcePath, destinationPath);
        }
    }

    /// <summary>
    /// Resolves seed-images source directory for local run (../seed-images)
    /// and Docker (/app/seed-images).
    /// </summary>
    public static string ResolveSeedImagesSourceDirectory(string contentRootPath)
    {
        var candidates = new[]
        {
            Path.Combine(contentRootPath, "seed-images"),
            Path.GetFullPath(Path.Combine(contentRootPath, "..", "seed-images"))
        };

        foreach (var candidate in candidates)
        {
            if (Directory.Exists(candidate))
                return candidate;
        }

        return candidates[0];
    }
}
