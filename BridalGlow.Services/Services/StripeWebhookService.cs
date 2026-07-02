using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Services.Helpers;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Stripe;

namespace BridalGlow.Services.Services;

public class StripeWebhookService : IStripeWebhookService
{
    private readonly BridalGlowDbContext _context;
    private readonly IPaymentService _paymentService;
    private readonly IRefundService _refundService;
    private readonly string _webhookSecret;
    private readonly ILogger<StripeWebhookService> _logger;

    public StripeWebhookService(
        BridalGlowDbContext context,
        IPaymentService paymentService,
        IRefundService refundService,
        IConfiguration configuration,
        ILogger<StripeWebhookService> logger)
    {
        _context = context;
        _paymentService = paymentService;
        _refundService = refundService;
        _webhookSecret = StripeWebhookSecretResolver.ResolveWebhookSecret(configuration);
        _logger = logger;
    }

    public async Task ProcessWebhookAsync(string json, string stripeSignatureHeader)
    {
        var stripeEvent = EventUtility.ConstructEvent(json, stripeSignatureHeader, _webhookSecret);

        if (await _context.ProcessedStripeEvents
            .AnyAsync(e => e.EventId == stripeEvent.Id))
        {
            _logger.LogInformation(
                "Stripe event {EventId} ({EventType}) already processed — skipping.",
                stripeEvent.Id,
                stripeEvent.Type);
            return;
        }

        switch (stripeEvent.Type)
        {
            case "payment_intent.succeeded":
                await HandlePaymentIntentSucceededAsync(stripeEvent);
                break;
            case "payment_intent.payment_failed":
                await HandlePaymentIntentFailedAsync(stripeEvent);
                break;
            case "charge.refunded":
                await HandleChargeRefundedAsync(stripeEvent);
                break;
            case "refund.updated":
                await HandleRefundUpdatedAsync(stripeEvent);
                break;
            default:
                _logger.LogInformation(
                    "Stripe event {EventId} type {EventType} ignored.",
                    stripeEvent.Id,
                    stripeEvent.Type);
                break;
        }

        _context.ProcessedStripeEvents.Add(new ProcessedStripeEvent
        {
            EventId = stripeEvent.Id,
            EventType = stripeEvent.Type,
            ProcessedAtUtc = DateTime.UtcNow
        });

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException)
        {
            if (await _context.ProcessedStripeEvents
                .AnyAsync(e => e.EventId == stripeEvent.Id))
            {
                _logger.LogInformation(
                    "Stripe event {EventId} processed concurrently — treating as duplicate.",
                    stripeEvent.Id);
                return;
            }

            throw;
        }
    }

    private async Task HandlePaymentIntentSucceededAsync(Event stripeEvent)
    {
        var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
        if (paymentIntent == null)
        {
            _logger.LogWarning(
                "Stripe event {EventId} payment_intent.succeeded missing PaymentIntent payload.",
                stripeEvent.Id);
            return;
        }

        await _paymentService.ApplyPaymentIntentSucceededAsync(paymentIntent);
    }

    private async Task HandlePaymentIntentFailedAsync(Event stripeEvent)
    {
        var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
        if (paymentIntent == null)
        {
            _logger.LogWarning(
                "Stripe event {EventId} payment_intent.payment_failed missing PaymentIntent payload.",
                stripeEvent.Id);
            return;
        }

        await _paymentService.ApplyPaymentIntentFailedAsync(paymentIntent);
    }

    private async Task HandleChargeRefundedAsync(Event stripeEvent)
    {
        var charge = stripeEvent.Data.Object as Charge;
        if (charge == null)
        {
            _logger.LogWarning(
                "Stripe event {EventId} charge.refunded missing Charge payload.",
                stripeEvent.Id);
            return;
        }

        await _refundService.ApplyChargeRefundedAsync(charge);
    }

    private async Task HandleRefundUpdatedAsync(Event stripeEvent)
    {
        var refund = stripeEvent.Data.Object as Stripe.Refund;
        if (refund == null)
        {
            _logger.LogWarning(
                "Stripe event {EventId} refund.updated missing Refund payload.",
                stripeEvent.Id);
            return;
        }

        await _refundService.ApplyRefundUpdatedAsync(refund);
    }
}
