using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using BridalGlow.Data.Database;
using BridalGlow.Data.Entities;
using BridalGlow.Model.Enums;
using BridalGlow.Model.Responses;
using BridalGlow.Model.SearchObjects;
using BridalGlow.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BridalGlow.Services.Services;

public class ReportingAggregationService : IReportingAggregationService
{
    private readonly BridalGlowDbContext _context;
    private readonly IFinancialLedgerService _ledgerService;

    public ReportingAggregationService(
        BridalGlowDbContext context,
        IFinancialLedgerService ledgerService)
    {
        _context = context;
        _ledgerService = ledgerService;
    }

    public async Task<KpiSummaryResponse> GetKpiSummaryAsync(ReportFilterSearchObject filter)
    {
        filter ??= new ReportFilterSearchObject();

        var finance = await BuildFinanceSectionAsync(filter);
        var rentals = await BuildRentalSectionAsync(filter);
        var reviews = await BuildReviewSectionAsync(filter);
        var maintenance = await BuildMaintenanceSectionAsync(filter);
        var dressPortfolio = await BuildDressPortfolioSectionAsync(filter);

        return new KpiSummaryResponse
        {
            FromUtc = filter.FromUtc,
            ToUtc = filter.ToUtc,
            DressId = filter.DressId,
            DressCategoryId = filter.DressCategoryId,
            Finance = finance,
            Rentals = rentals,
            Reviews = reviews,
            Maintenance = maintenance,
            DressPortfolio = dressPortfolio
        };
    }

    public async Task<BusinessPerformanceReportResponse> GetBusinessPerformanceReportAsync(
        ReportFilterSearchObject filter)
    {
        filter ??= new ReportFilterSearchObject();

        var finance = await BuildFinanceSectionAsync(filter);
        var rentals = await BuildRentalSectionAsync(filter);
        var reviews = await BuildReviewSectionAsync(filter);
        var maintenance = await BuildMaintenanceSectionAsync(filter);
        var dressPortfolio = await BuildDressPortfolioSectionAsync(filter);
        var ratingDistribution = await BuildReviewRatingDistributionAsync(filter);
        var maintenanceByType = await BuildMaintenanceTypeBreakdownAsync(filter);
        var monthlyTrends = await BuildMonthlyTrendsAsync(filter);

        return new BusinessPerformanceReportResponse
        {
            FromUtc = filter.FromUtc,
            ToUtc = filter.ToUtc,
            DressId = filter.DressId,
            DressCategoryId = filter.DressCategoryId,
            Finance = finance,
            Rentals = rentals,
            Reviews = new BusinessReviewReportSection
            {
                Summary = reviews,
                RatingDistribution = ratingDistribution
            },
            Maintenance = new BusinessMaintenanceReportSection
            {
                Summary = maintenance,
                ByType = maintenanceByType
            },
            DressPortfolio = dressPortfolio,
            MonthlyTrends = monthlyTrends
        };
    }

    public async Task<FinancialReportResponse> GetFinancialReportAsync(ReportFilterSearchObject filter)
    {
        filter ??= new ReportFilterSearchObject();

        var periodSummary = await BuildFinanceSectionAsync(filter);
        var ledger = await BuildFinancialLedgerSectionAsync(filter, periodSummary);
        var refunds = await BuildRefundSummarySectionAsync(filter, periodSummary.Currency);

        return new FinancialReportResponse
        {
            FromUtc = filter.FromUtc,
            ToUtc = filter.ToUtc,
            DressId = filter.DressId,
            DressCategoryId = filter.DressCategoryId,
            PeriodSummary = periodSummary,
            Ledger = ledger,
            Refunds = refunds
        };
    }

    private async Task<LedgerReportResponse> BuildFinancialLedgerSectionAsync(
        ReportFilterSearchObject filter,
        FinanceKpiSection periodSummary)
    {
        var ledger = await _ledgerService.GetLedgerAsync(filter.FromUtc, filter.ToUtc);

        if (filter.DressId.HasValue || filter.DressCategoryId.HasValue)
        {
            var allowedEntryIds = await ApplyLedgerFilters(
                    _context.TransactionLedgerEntries.Where(e => !e.IsDeleted),
                    filter)
                .Select(e => e.Id)
                .ToListAsync();

            var allowedSet = allowedEntryIds.ToHashSet();
            ledger.Entries = ledger.Entries
                .Where(e => allowedSet.Contains(e.Id))
                .ToList();
        }

        ledger.FromUtc = filter.FromUtc;
        ledger.ToUtc = filter.ToUtc;
        ledger.Summary = new LedgerPeriodSummary
        {
            TotalReceivedAmount = periodSummary.TotalCapturedAmount,
            TransactionCount = periodSummary.TransactionCount,
            Currency = periodSummary.Currency
        };

        return ledger;
    }

    private async Task<RefundSummarySection> BuildRefundSummarySectionAsync(
        ReportFilterSearchObject filter,
        string defaultCurrency)
    {
        var query = ApplyRefundFilters(
            _context.Refunds.Where(r => !r.IsDeleted),
            filter);

        var statusCounts = await query
            .GroupBy(r => r.Status)
            .Select(g => new { Status = g.Key, Count = g.Count() })
            .ToListAsync();

        var succeededAggregate = await query
            .Where(r => r.Status == RefundStatus.Succeeded)
            .GroupBy(r => r.Currency)
            .Select(g => new
            {
                Currency = g.Key,
                TotalSucceededAmount = g.Sum(r => r.Amount)
            })
            .OrderByDescending(g => g.TotalSucceededAmount)
            .FirstOrDefaultAsync();

        return new RefundSummarySection
        {
            TotalCount = statusCounts.Sum(s => s.Count),
            TotalSucceededAmount = succeededAggregate?.TotalSucceededAmount ?? 0m,
            SucceededCount = statusCounts
                .Where(s => s.Status == RefundStatus.Succeeded)
                .Sum(s => s.Count),
            PendingCount = statusCounts
                .Where(s => s.Status is RefundStatus.Requested
                    or RefundStatus.Approved
                    or RefundStatus.Processing)
                .Sum(s => s.Count),
            RejectedCount = statusCounts
                .Where(s => s.Status is RefundStatus.Rejected or RefundStatus.Failed)
                .Sum(s => s.Count),
            Currency = succeededAggregate?.Currency ?? defaultCurrency
        };
    }

    private async Task<List<ReviewRatingDistributionItem>> BuildReviewRatingDistributionAsync(
        ReportFilterSearchObject filter)
    {
        var query = ApplyReviewFilters(
            _context.Reviews.Where(r => !r.IsDeleted),
            filter);

        return await query
            .Where(r => r.Status == ReviewStatus.Published)
            .GroupBy(r => r.Rating)
            .Select(g => new ReviewRatingDistributionItem
            {
                Rating = g.Key,
                Count = g.Count()
            })
            .OrderBy(r => r.Rating)
            .ToListAsync();
    }

    private async Task<List<MaintenanceTypeBreakdownItem>> BuildMaintenanceTypeBreakdownAsync(
        ReportFilterSearchObject filter)
    {
        var query = ApplyMaintenanceFilters(
            _context.MaintenanceRecords.Where(m => !m.IsDeleted),
            filter);

        return await query
            .GroupBy(m => m.MaintenanceType)
            .Select(g => new MaintenanceTypeBreakdownItem
            {
                MaintenanceType = g.Key,
                MaintenanceTypeLabel = g.Key.ToString(),
                RecordCount = g.Count(),
                TotalCostAmount = g.Sum(m => m.CostAmount)
            })
            .OrderBy(t => t.MaintenanceType)
            .ToListAsync();
    }

    private async Task<List<MonthlyTrendItem>> BuildMonthlyTrendsAsync(ReportFilterSearchObject filter)
    {
        var months = ResolveTrendMonths(filter);

        var ledgerQuery = ApplyLedgerFilters(
            _context.TransactionLedgerEntries.Where(e => !e.IsDeleted),
            filter);

        var revenueByMonth = await ledgerQuery
            .Where(e => e.EntryType == LedgerEntryType.PaymentCapture
                     && e.Direction == LedgerDirection.Credit)
            .GroupBy(e => new { e.OccurredAtUtc.Year, e.OccurredAtUtc.Month })
            .Select(g => new
            {
                g.Key.Year,
                g.Key.Month,
                Revenue = g.Sum(e => e.Amount)
            })
            .ToListAsync();

        var rentalQuery = ApplyRentalFilters(
            _context.RentalReservations.Where(r => !r.IsDeleted),
            filter);

        var rentalsByMonth = await rentalQuery
            .GroupBy(r => new { r.CreatedAtUtc.Year, r.CreatedAtUtc.Month })
            .Select(g => new
            {
                g.Key.Year,
                g.Key.Month,
                RentalCount = g.Count()
            })
            .ToListAsync();

        return months.Select(month => new MonthlyTrendItem
        {
            Month = month.ToString("yyyy-MM"),
            Revenue = revenueByMonth
                .Where(x => x.Year == month.Year && x.Month == month.Month)
                .Select(x => x.Revenue)
                .FirstOrDefault(),
            RentalCount = rentalsByMonth
                .Where(x => x.Year == month.Year && x.Month == month.Month)
                .Select(x => x.RentalCount)
                .FirstOrDefault()
        }).ToList();
    }

    private static List<DateTime> ResolveTrendMonths(ReportFilterSearchObject filter)
    {
        if (filter.FromUtc.HasValue && filter.ToUtc.HasValue)
        {
            var start = new DateTime(filter.FromUtc.Value.Year, filter.FromUtc.Value.Month, 1, 0, 0, 0, DateTimeKind.Utc);
            var end = new DateTime(filter.ToUtc.Value.Year, filter.ToUtc.Value.Month, 1, 0, 0, 0, DateTimeKind.Utc);

            if (end < start)
                (start, end) = (end, start);

            var months = new List<DateTime>();
            for (var cursor = start; cursor <= end; cursor = cursor.AddMonths(1))
                months.Add(cursor);

            return months;
        }

        if (filter.FromUtc.HasValue)
        {
            var start = new DateTime(filter.FromUtc.Value.Year, filter.FromUtc.Value.Month, 1, 0, 0, 0, DateTimeKind.Utc);
            var end = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1, 0, 0, 0, DateTimeKind.Utc);

            if (end < start)
                end = start;

            var months = new List<DateTime>();
            for (var cursor = start; cursor <= end; cursor = cursor.AddMonths(1))
                months.Add(cursor);

            return months;
        }

        if (filter.ToUtc.HasValue)
        {
            var end = new DateTime(filter.ToUtc.Value.Year, filter.ToUtc.Value.Month, 1, 0, 0, 0, DateTimeKind.Utc);
            var start = end.AddMonths(-11);

            var months = new List<DateTime>();
            for (var cursor = start; cursor <= end; cursor = cursor.AddMonths(1))
                months.Add(cursor);

            return months;
        }

        var currentMonth = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        return Enumerable.Range(0, 12)
            .Select(i => currentMonth.AddMonths(-i))
            .Reverse()
            .ToList();
    }

    private async Task<FinanceKpiSection> BuildFinanceSectionAsync(ReportFilterSearchObject filter)
    {
        var query = ApplyLedgerFilters(
            _context.TransactionLedgerEntries.Where(e => !e.IsDeleted),
            filter);

        var captureStats = await query
            .Where(e => e.EntryType == LedgerEntryType.PaymentCapture
                     && e.Direction == LedgerDirection.Credit)
            .GroupBy(e => e.Currency)
            .Select(g => new
            {
                Currency = g.Key,
                TotalCaptured = g.Sum(e => e.Amount),
                TransactionCount = g.Count()
            })
            .OrderByDescending(g => g.TransactionCount)
            .FirstOrDefaultAsync();

        var totalRefundAmount = await query
            .Where(e => e.EntryType == LedgerEntryType.Refund
                     && e.Direction == LedgerDirection.Debit)
            .SumAsync(e => (decimal?)e.Amount) ?? 0m;

        var totalCaptured = captureStats?.TotalCaptured ?? 0m;
        var transactionCount = captureStats?.TransactionCount ?? 0;

        return new FinanceKpiSection
        {
            TotalCapturedAmount = totalCaptured,
            TotalRefundAmount = totalRefundAmount,
            NetRevenue = totalCaptured - totalRefundAmount,
            TransactionCount = transactionCount,
            Currency = captureStats?.Currency ?? "EUR"
        };
    }

    private async Task<RentalKpiSection> BuildRentalSectionAsync(ReportFilterSearchObject filter)
    {
        var query = ApplyRentalFilters(
            _context.RentalReservations.Where(r => !r.IsDeleted),
            filter);

        var statusBreakdown = await query
            .GroupBy(r => r.Status)
            .Select(g => new RentalStatusCountItem
            {
                Status = g.Key,
                StatusLabel = g.Key.ToString(),
                Count = g.Count()
            })
            .OrderBy(s => s.Status)
            .ToListAsync();

        var totalCount = statusBreakdown.Sum(s => s.Count);
        var completedCount = statusBreakdown
            .Where(s => s.Status == RentalReservationStatus.Completed)
            .Sum(s => s.Count);
        var cancelledCount = statusBreakdown
            .Where(s => IsCancelledRentalStatus(s.Status))
            .Sum(s => s.Count);

        return new RentalKpiSection
        {
            TotalCount = totalCount,
            CompletionRate = totalCount > 0
                ? Math.Round((decimal)completedCount / totalCount * 100m, 2)
                : 0m,
            CancellationRate = totalCount > 0
                ? Math.Round((decimal)cancelledCount / totalCount * 100m, 2)
                : 0m,
            StatusBreakdown = statusBreakdown
        };
    }

    private async Task<ReviewKpiSection> BuildReviewSectionAsync(ReportFilterSearchObject filter)
    {
        var query = ApplyReviewFilters(
            _context.Reviews.Where(r => !r.IsDeleted),
            filter);

        var statusBreakdown = await query
            .GroupBy(r => r.Status)
            .Select(g => new { Status = g.Key, Count = g.Count() })
            .ToListAsync();

        var averageRating = await query
            .Where(r => r.Status == ReviewStatus.Published)
            .AverageAsync(r => (double?)r.Rating) ?? 0d;

        return new ReviewKpiSection
        {
            AverageRating = Math.Round((decimal)averageRating, 2),
            TotalCount = statusBreakdown.Sum(s => s.Count),
            PendingModerationCount = statusBreakdown
                .Where(s => s.Status == ReviewStatus.PendingModeration)
                .Sum(s => s.Count),
            PublishedCount = statusBreakdown
                .Where(s => s.Status == ReviewStatus.Published)
                .Sum(s => s.Count),
            HiddenCount = statusBreakdown
                .Where(s => s.Status == ReviewStatus.Hidden)
                .Sum(s => s.Count),
            RejectedCount = statusBreakdown
                .Where(s => s.Status == ReviewStatus.Rejected)
                .Sum(s => s.Count)
        };
    }

    private async Task<MaintenanceKpiSection> BuildMaintenanceSectionAsync(ReportFilterSearchObject filter)
    {
        var query = ApplyMaintenanceFilters(
            _context.MaintenanceRecords.Where(m => !m.IsDeleted),
            filter);

        var aggregate = await query
            .GroupBy(_ => 1)
            .Select(g => new
            {
                TotalRecordCount = g.Count(),
                TotalCostAmount = g.Sum(m => m.CostAmount)
            })
            .FirstOrDefaultAsync();

        return new MaintenanceKpiSection
        {
            TotalRecordCount = aggregate?.TotalRecordCount ?? 0,
            TotalCostAmount = aggregate?.TotalCostAmount ?? 0m
        };
    }

    private async Task<DressPortfolioKpiSection> BuildDressPortfolioSectionAsync(ReportFilterSearchObject filter)
    {
        var dressQuery = ApplyDressInventoryFilters(
            _context.Dresses.Where(d => !d.IsDeleted),
            filter);

        var activeDressCount = await dressQuery
            .CountAsync(d => d.Status == DressStatus.Active);

        var outOfServiceDressCount = await dressQuery
            .CountAsync(d => d.Status == DressStatus.OutOfService);

        var rentalQuery = ApplyRentalFilters(
            _context.RentalReservations.Where(r => !r.IsDeleted),
            filter);

        var topRentedDresses = await rentalQuery
            .GroupBy(r => new { r.DressId, r.Dress.Code, r.Dress.Name })
            .Select(g => new TopDressRentalItem
            {
                DressId = g.Key.DressId,
                DressCode = g.Key.Code,
                DressName = g.Key.Name,
                RentalCount = g.Count()
            })
            .OrderByDescending(x => x.RentalCount)
            .ThenBy(x => x.DressName)
            .Take(5)
            .ToListAsync();

        return new DressPortfolioKpiSection
        {
            ActiveDressCount = activeDressCount,
            OutOfServiceDressCount = outOfServiceDressCount,
            TopRentedDresses = topRentedDresses
        };
    }

    private static IQueryable<TransactionLedgerEntry> ApplyLedgerFilters(
        IQueryable<TransactionLedgerEntry> query,
        ReportFilterSearchObject filter)
    {
        if (filter.FromUtc.HasValue)
            query = query.Where(e => e.OccurredAtUtc >= filter.FromUtc.Value);

        if (filter.ToUtc.HasValue)
            query = query.Where(e => e.OccurredAtUtc <= filter.ToUtc.Value);

        if (filter.DressId.HasValue)
        {
            query = query.Where(e =>
                e.RentalReservation != null
                && e.RentalReservation.DressId == filter.DressId.Value);
        }

        if (filter.DressCategoryId.HasValue)
        {
            query = query.Where(e =>
                e.RentalReservation != null
                && e.RentalReservation.Dress.PrimaryCategoryId == filter.DressCategoryId.Value);
        }

        return query;
    }

    private static IQueryable<RentalReservation> ApplyRentalFilters(
        IQueryable<RentalReservation> query,
        ReportFilterSearchObject filter)
    {
        if (filter.FromUtc.HasValue)
            query = query.Where(r => r.CreatedAtUtc >= filter.FromUtc.Value);

        if (filter.ToUtc.HasValue)
            query = query.Where(r => r.CreatedAtUtc <= filter.ToUtc.Value);

        if (filter.DressId.HasValue)
            query = query.Where(r => r.DressId == filter.DressId.Value);

        if (filter.DressCategoryId.HasValue)
            query = query.Where(r => r.Dress.PrimaryCategoryId == filter.DressCategoryId.Value);

        return query;
    }

    private static IQueryable<Review> ApplyReviewFilters(
        IQueryable<Review> query,
        ReportFilterSearchObject filter)
    {
        if (filter.FromUtc.HasValue)
            query = query.Where(r => r.CreatedAtUtc >= filter.FromUtc.Value);

        if (filter.ToUtc.HasValue)
            query = query.Where(r => r.CreatedAtUtc <= filter.ToUtc.Value);

        if (filter.DressId.HasValue)
            query = query.Where(r => r.DressId == filter.DressId.Value);

        if (filter.DressCategoryId.HasValue)
            query = query.Where(r => r.Dress.PrimaryCategoryId == filter.DressCategoryId.Value);

        return query;
    }

    private static IQueryable<MaintenanceRecord> ApplyMaintenanceFilters(
        IQueryable<MaintenanceRecord> query,
        ReportFilterSearchObject filter)
    {
        if (filter.FromUtc.HasValue)
            query = query.Where(m => m.PerformedAtUtc >= filter.FromUtc.Value);

        if (filter.ToUtc.HasValue)
            query = query.Where(m => m.PerformedAtUtc <= filter.ToUtc.Value);

        if (filter.DressId.HasValue)
            query = query.Where(m => m.DressId == filter.DressId.Value);

        if (filter.DressCategoryId.HasValue)
            query = query.Where(m => m.Dress.PrimaryCategoryId == filter.DressCategoryId.Value);

        return query;
    }

    private static IQueryable<Dress> ApplyDressInventoryFilters(
        IQueryable<Dress> query,
        ReportFilterSearchObject filter)
    {
        if (filter.DressId.HasValue)
            query = query.Where(d => d.Id == filter.DressId.Value);

        if (filter.DressCategoryId.HasValue)
            query = query.Where(d => d.PrimaryCategoryId == filter.DressCategoryId.Value);

        return query;
    }

    private static IQueryable<Refund> ApplyRefundFilters(
        IQueryable<Refund> query,
        ReportFilterSearchObject filter)
    {
        if (filter.FromUtc.HasValue)
        {
            query = query.Where(r =>
                (r.ProcessedAtUtc ?? r.RequestedAtUtc) >= filter.FromUtc.Value);
        }

        if (filter.ToUtc.HasValue)
        {
            query = query.Where(r =>
                (r.ProcessedAtUtc ?? r.RequestedAtUtc) <= filter.ToUtc.Value);
        }

        if (filter.DressId.HasValue)
        {
            query = query.Where(r =>
                r.Payment.RentalReservationId != null
                && r.Payment.RentalReservation!.DressId == filter.DressId.Value);
        }

        if (filter.DressCategoryId.HasValue)
        {
            query = query.Where(r =>
                r.Payment.RentalReservationId != null
                && r.Payment.RentalReservation!.Dress.PrimaryCategoryId == filter.DressCategoryId.Value);
        }

        return query;
    }

    private static bool IsCancelledRentalStatus(RentalReservationStatus status)
    {
        return status is RentalReservationStatus.Cancelled
            or RentalReservationStatus.CancelledByCustomer
            or RentalReservationStatus.CancelledByStaff
            or RentalReservationStatus.Rejected;
    }
}
