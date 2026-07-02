namespace BridalGlow.Services.Interfaces;

public interface IEmailSenderService
{
    Task SendPlainTextAsync(string toEmail, string subject, string body);
}
