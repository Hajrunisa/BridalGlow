using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using Stripe;

namespace BridalGlow.Services.Interfaces;

public interface IPaymentService
{
    Task<PaymentIntentResponse> CreatePaymentIntentAsync(int customerUserId, CreatePaymentIntentRequest request);
    Task<PaymentResponse?> GetByIdAsync(int id, int? requestingUserId = null, bool isStaff = false);
    Task<PaymentStatusResponse> GetStatusAsync(int id, int? requestingUserId = null, bool isStaff = false);
    Task<PaymentStatusResponse> SyncStatusAsync(int id, int? requestingUserId = null, bool isStaff = false);
    Task ApplyPaymentIntentSucceededAsync(PaymentIntent paymentIntent);
    Task ApplyPaymentIntentFailedAsync(PaymentIntent paymentIntent);
    Task<PagedResult<PaymentResponse>> GetMineAsync(int customerUserId, PaymentSearchObject search);
    Task<PagedResult<PaymentResponse>> GetAsync(PaymentSearchObject search);
}
