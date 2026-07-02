using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Data.Helpers;
using BridalGlow.Services.Interfaces;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class UserService : BaseService<UserResponse, UserSearchObject, User>, IUserService
{
    public UserService(BridalGlowDbContext context, IMapper mapper) : base(context, mapper)
    {
    }

    protected override IQueryable<User> ApplyFilter(IQueryable<User> query, UserSearchObject search)
    {
        if (!string.IsNullOrEmpty(search.Username))
            query = query.Where(u => u.Username.Contains(search.Username));

        if (!string.IsNullOrEmpty(search.Email))
            query = query.Where(u => u.Email.Contains(search.Email));

        if (!string.IsNullOrEmpty(search.FTS))
            query = query.Where(u =>
                u.FirstName.Contains(search.FTS) ||
                u.LastName.Contains(search.FTS) ||
                u.Username.Contains(search.FTS) ||
                u.Email.Contains(search.FTS));

        if (search.Role.HasValue)
            query = query.Where(u => u.Role == search.Role.Value);

        if (search.IsActive.HasValue)
            query = query.Where(u => u.IsActive == search.IsActive.Value);

        return query.OrderBy(u => u.Id);
    }

    public async Task<UserResponse?> GetMyProfileAsync(int userId)
    {
        return await GetByIdAsync(userId);
    }

    public async Task<UserResponse?> UpdateProfileAsync(int userId, UserUpdateProfileRequest request)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            return null;

        user.FirstName = request.FirstName;
        user.LastName = request.LastName;
        user.Phone = request.Phone;
        user.DateOfBirth = request.DateOfBirth;
        user.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return MapToResponse(user);
    }

    public async Task ChangePasswordAsync(int userId, ChangePasswordRequest request)
    {
        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            throw new UserException("User not found.");

        if (!PasswordGenerator.VerifyPassword(request.CurrentPassword, user.PasswordHash, user.PasswordSalt))
            throw new UserException("Current password is incorrect.");

        user.PasswordSalt = PasswordGenerator.GenerateSalt();
        user.PasswordHash = PasswordGenerator.GenerateHash(request.NewPassword, user.PasswordSalt);
        user.UpdatedAtUtc = DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }

    public async Task<bool> ActivateUserAsync(int id)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null)
            return false;

        user.IsActive = true;
        user.UpdatedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> DeactivateUserAsync(int id)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null)
            return false;

        user.IsActive = false;
        user.UpdatedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<UserResponse> PromoteToSalonStaffAsync(int id)
    {
        var user = await _context.Users.FindAsync(id);
        if (user == null || user.IsDeleted)
            throw new UserException("Korisnik nije pronađen.");

        if (!user.IsActive)
            throw new UserException("Promocija je dozvoljena samo za aktivne korisnike.");

        if (user.Role == UserRole.Admin)
            throw new UserException("Admin korisnik se ne može promovirati u SalonStaff.");

        if (user.Role == UserRole.SalonStaff)
            throw new UserException("Korisnik je već SalonStaff.");

        if (user.Role != UserRole.Customer)
            throw new UserException("Promocija je dozvoljena samo za Customer korisnike.");

        user.Role = UserRole.SalonStaff;
        user.UpdatedAtUtc = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return MapToResponse(user);
    }

    protected override UserResponse MapToResponse(User user) => new()
    {
        Id = user.Id,
        FirstName = user.FirstName,
        LastName = user.LastName,
        Email = user.Email,
        Username = user.Username,
        Phone = user.Phone,
        DateOfBirth = user.DateOfBirth,
        Role = user.Role,
        RoleName = user.Role.ToString(),
        IsActive = user.IsActive,
        CreatedAtUtc = user.CreatedAtUtc,
        LastLoginAtUtc = user.LastLoginAtUtc
    };
}
