using System.Security.Cryptography;
using System.Text;

namespace BridalGlow.Data.Helpers;

public static class PasswordGenerator
{
    private const int SaltSize = 16;
    private const int KeySize = 32;
    private const int Iterations = 10000;

    public static string GenerateSalt()
    {
        var salt = RandomNumberGenerator.GetBytes(SaltSize);
        return Convert.ToBase64String(salt);
    }

    public static string GenerateDeterministicSalt(string seed)
    {
        using var sha256 = SHA256.Create();
        var seedBytes = Encoding.UTF8.GetBytes(seed);
        var hash = sha256.ComputeHash(seedBytes);
        var salt = new byte[SaltSize];
        Array.Copy(hash, 0, salt, 0, SaltSize);
        return Convert.ToBase64String(salt);
    }

    public static string GenerateHash(string password, string salt)
    {
        var saltBytes = Convert.FromBase64String(salt);
        using var pbkdf2 = new Rfc2898DeriveBytes(password, saltBytes, Iterations, HashAlgorithmName.SHA256);
        var hashBytes = pbkdf2.GetBytes(KeySize);
        return Convert.ToBase64String(hashBytes);
    }

    public static bool VerifyPassword(string password, string passwordHash, string passwordSalt)
    {
        var salt = Convert.FromBase64String(passwordSalt);
        var hash = Convert.FromBase64String(passwordHash);
        using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, Iterations, HashAlgorithmName.SHA256);
        var hashBytes = pbkdf2.GetBytes(KeySize);
        return hash.SequenceEqual(hashBytes);
    }
}
