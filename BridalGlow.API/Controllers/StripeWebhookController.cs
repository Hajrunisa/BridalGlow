using BridalGlow.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Stripe;

namespace BridalGlow.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StripeWebhookController : ControllerBase
{
    private readonly IStripeWebhookService _webhookService;
    private readonly ILogger<StripeWebhookController> _logger;

    public StripeWebhookController(
        IStripeWebhookService webhookService,
        ILogger<StripeWebhookController> logger)
    {
        _webhookService = webhookService;
        _logger = logger;
    }

    /// <summary>
    /// Receives Stripe webhook events. Signature is verified using the configured webhook secret.
    /// </summary>
    [HttpPost]
    [AllowAnonymous]
    public async Task<IActionResult> Handle()
    {
        var json = await new StreamReader(HttpContext.Request.Body).ReadToEndAsync();
        var signature = Request.Headers["Stripe-Signature"].FirstOrDefault();

        if (string.IsNullOrWhiteSpace(signature))
            return BadRequest(new { error = "Missing Stripe-Signature header." });

        try
        {
            await _webhookService.ProcessWebhookAsync(json, signature);
            return Ok();
        }
        catch (StripeException ex)
        {
            _logger.LogWarning(ex, "Stripe webhook signature verification failed.");
            return BadRequest(new { error = "Invalid Stripe webhook signature." });
        }
    }
}
