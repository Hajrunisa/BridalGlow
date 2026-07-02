using BridalGlow.Model.Requests;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using Stripe;

namespace BridalGlow.Services.Interfaces;

public interface IRefundService
{
    Task<RefundResponse> RequestAsync(int userId, bool isStaff, RefundRequestCreateRequest request);
    Task<RefundResponse> ApproveAsync(int id, int staffUserId);
    Task<RefundResponse> RejectAsync(int id, int staffUserId, RefundRejectRequest request);
    Task<RefundResponse> ProcessAsync(int id, int staffUserId);
    Task<PagedResult<RefundResponse>> GetAsync(RefundSearchObject search);
    Task<PagedResult<RefundResponse>> GetMineAsync(int customerUserId, RefundSearchObject search);
    Task ApplyChargeRefundedAsync(Charge charge);
    Task ApplyRefundUpdatedAsync(Stripe.Refund stripeRefund);
}
