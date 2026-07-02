using System.Net;
using System.Net.Mail;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.Extensions.Logging;

namespace BridalGlow.Services.Services;

public class SmtpEmailSenderService : IEmailSenderService
{
    private readonly SmtpSettings _settings;
    private readonly ILogger<SmtpEmailSenderService> _logger;

    public SmtpEmailSenderService(SmtpSettings settings, ILogger<SmtpEmailSenderService> logger)
    {
        _settings = settings;
        _logger = logger;
    }

    public async Task SendPlainTextAsync(string toEmail, string subject, string body)
    {
        if (!_settings.IsConfigured)
            throw new InvalidOperationException("SMTP is not configured.");

        using var client = new SmtpClient(_settings.Host!, _settings.Port)
        {
            EnableSsl = _settings.UseSsl,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(_settings.Email, _settings.Password)
        };

        using var mail = new MailMessage(_settings.Email!, toEmail, subject, body);

        try
        {
            await client.SendMailAsync(mail);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send email to {Recipient}.", toEmail);
            throw;
        }
    }
}
