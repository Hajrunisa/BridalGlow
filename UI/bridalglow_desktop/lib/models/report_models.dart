import 'package:bridalglow_desktop/models/ledger_report.dart';

enum ReportPeriodPreset {
  allTime,
  last7Days,
  last30Days,
  last3Months,
  last12Months,
  custom,
}

const Map<ReportPeriodPreset, String> kReportPeriodLabels = {
  ReportPeriodPreset.allTime: 'All time',
  ReportPeriodPreset.last7Days: 'Last 7 days',
  ReportPeriodPreset.last30Days: 'Last 30 days',
  ReportPeriodPreset.last3Months: 'Last 3 months',
  ReportPeriodPreset.last12Months: 'Last 12 months',
  ReportPeriodPreset.custom: 'Custom range',
};

class ReportFilterState {
  ReportPeriodPreset preset;
  DateTime? fromUtc;
  DateTime? toUtc;
  int? dressCategoryId;
  int? dressId;

  ReportFilterState({
    this.preset = ReportPeriodPreset.last30Days,
    this.fromUtc,
    this.toUtc,
    this.dressCategoryId,
    this.dressId,
  });

  ReportFilterState copyWith({
    ReportPeriodPreset? preset,
    DateTime? fromUtc,
    DateTime? toUtc,
    int? dressCategoryId,
    int? dressId,
    bool clearDressCategoryId = false,
    bool clearDressId = false,
    bool clearFromUtc = false,
    bool clearToUtc = false,
  }) {
    return ReportFilterState(
      preset: preset ?? this.preset,
      fromUtc: clearFromUtc ? null : (fromUtc ?? this.fromUtc),
      toUtc: clearToUtc ? null : (toUtc ?? this.toUtc),
      dressCategoryId:
          clearDressCategoryId ? null : (dressCategoryId ?? this.dressCategoryId),
      dressId: clearDressId ? null : (dressId ?? this.dressId),
    );
  }

  void applyPresetDates() {
    if (preset == ReportPeriodPreset.custom || preset == ReportPeriodPreset.allTime) {
      if (preset == ReportPeriodPreset.allTime) {
        fromUtc = null;
        toUtc = null;
      }
      return;
    }

    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    fromUtc = switch (preset) {
      ReportPeriodPreset.last7Days => end.subtract(const Duration(days: 6)),
      ReportPeriodPreset.last30Days => end.subtract(const Duration(days: 29)),
      ReportPeriodPreset.last3Months => DateTime(now.year, now.month - 3, now.day),
      ReportPeriodPreset.last12Months => DateTime(now.year - 1, now.month, now.day),
      _ => fromUtc,
    };
    toUtc = end;
  }

  Map<String, dynamic> toQueryParams() {
    applyPresetDates();
    return {
      if (fromUtc != null) 'fromUtc': fromUtc!.toUtc().toIso8601String(),
      if (toUtc != null)
        'toUtc': toUtc!
            .toUtc()
            .add(const Duration(hours: 23, minutes: 59, seconds: 59))
            .toIso8601String(),
      if (dressId != null) 'dressId': dressId,
      if (dressCategoryId != null) 'dressCategoryId': dressCategoryId,
    };
  }
}

class FinanceKpiSection {
  final double totalCapturedAmount;
  final double totalRefundAmount;
  final double netRevenue;
  final int transactionCount;
  final String currency;

  const FinanceKpiSection({
    required this.totalCapturedAmount,
    required this.totalRefundAmount,
    required this.netRevenue,
    required this.transactionCount,
    required this.currency,
  });

  factory FinanceKpiSection.fromJson(Map<String, dynamic> json) {
    return FinanceKpiSection(
      totalCapturedAmount: (json['totalCapturedAmount'] as num?)?.toDouble() ?? 0,
      totalRefundAmount: (json['totalRefundAmount'] as num?)?.toDouble() ?? 0,
      netRevenue: (json['netRevenue'] as num?)?.toDouble() ?? 0,
      transactionCount: json['transactionCount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'EUR',
    );
  }
}

class RentalStatusCountItem {
  final String status;
  final String statusLabel;
  final int count;

  const RentalStatusCountItem({
    required this.status,
    required this.statusLabel,
    required this.count,
  });

  factory RentalStatusCountItem.fromJson(Map<String, dynamic> json) {
    return RentalStatusCountItem(
      status: json['status']?.toString() ?? '',
      statusLabel: json['statusLabel'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class RentalKpiSection {
  final int totalCount;
  final double completionRate;
  final double cancellationRate;
  final List<RentalStatusCountItem> statusBreakdown;

  const RentalKpiSection({
    required this.totalCount,
    required this.completionRate,
    required this.cancellationRate,
    required this.statusBreakdown,
  });

  factory RentalKpiSection.fromJson(Map<String, dynamic> json) {
    final breakdown = json['statusBreakdown'] as List<dynamic>? ?? [];
    return RentalKpiSection(
      totalCount: json['totalCount'] as int? ?? 0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0,
      cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 0,
      statusBreakdown: breakdown
          .map((e) => RentalStatusCountItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReviewKpiSection {
  final double averageRating;
  final int totalCount;
  final int pendingModerationCount;
  final int publishedCount;
  final int hiddenCount;
  final int rejectedCount;

  const ReviewKpiSection({
    required this.averageRating,
    required this.totalCount,
    required this.pendingModerationCount,
    required this.publishedCount,
    required this.hiddenCount,
    required this.rejectedCount,
  });

  factory ReviewKpiSection.fromJson(Map<String, dynamic> json) {
    return ReviewKpiSection(
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      pendingModerationCount: json['pendingModerationCount'] as int? ?? 0,
      publishedCount: json['publishedCount'] as int? ?? 0,
      hiddenCount: json['hiddenCount'] as int? ?? 0,
      rejectedCount: json['rejectedCount'] as int? ?? 0,
    );
  }
}

class MaintenanceKpiSection {
  final int totalRecordCount;
  final double totalCostAmount;

  const MaintenanceKpiSection({
    required this.totalRecordCount,
    required this.totalCostAmount,
  });

  factory MaintenanceKpiSection.fromJson(Map<String, dynamic> json) {
    return MaintenanceKpiSection(
      totalRecordCount: json['totalRecordCount'] as int? ?? 0,
      totalCostAmount: (json['totalCostAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TopDressRentalItem {
  final int dressId;
  final String dressCode;
  final String dressName;
  final int rentalCount;

  const TopDressRentalItem({
    required this.dressId,
    required this.dressCode,
    required this.dressName,
    required this.rentalCount,
  });

  factory TopDressRentalItem.fromJson(Map<String, dynamic> json) {
    return TopDressRentalItem(
      dressId: json['dressId'] as int? ?? 0,
      dressCode: json['dressCode'] as String? ?? '',
      dressName: json['dressName'] as String? ?? '',
      rentalCount: json['rentalCount'] as int? ?? 0,
    );
  }
}

class DressPortfolioKpiSection {
  final int activeDressCount;
  final int outOfServiceDressCount;
  final List<TopDressRentalItem> topRentedDresses;

  const DressPortfolioKpiSection({
    required this.activeDressCount,
    required this.outOfServiceDressCount,
    required this.topRentedDresses,
  });

  factory DressPortfolioKpiSection.fromJson(Map<String, dynamic> json) {
    final top = json['topRentedDresses'] as List<dynamic>? ?? [];
    return DressPortfolioKpiSection(
      activeDressCount: json['activeDressCount'] as int? ?? 0,
      outOfServiceDressCount: json['outOfServiceDressCount'] as int? ?? 0,
      topRentedDresses: top
          .map((e) => TopDressRentalItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class KpiSummary {
  final DateTime? fromUtc;
  final DateTime? toUtc;
  final int? dressId;
  final int? dressCategoryId;
  final FinanceKpiSection finance;
  final RentalKpiSection rentals;
  final ReviewKpiSection reviews;
  final MaintenanceKpiSection maintenance;
  final DressPortfolioKpiSection dressPortfolio;

  const KpiSummary({
    this.fromUtc,
    this.toUtc,
    this.dressId,
    this.dressCategoryId,
    required this.finance,
    required this.rentals,
    required this.reviews,
    required this.maintenance,
    required this.dressPortfolio,
  });

  factory KpiSummary.fromJson(Map<String, dynamic> json) {
    return KpiSummary(
      fromUtc: json['fromUtc'] != null
          ? DateTime.parse(json['fromUtc'] as String)
          : null,
      toUtc:
          json['toUtc'] != null ? DateTime.parse(json['toUtc'] as String) : null,
      dressId: json['dressId'] as int?,
      dressCategoryId: json['dressCategoryId'] as int?,
      finance: FinanceKpiSection.fromJson(
          json['finance'] as Map<String, dynamic>? ?? {}),
      rentals: RentalKpiSection.fromJson(
          json['rentals'] as Map<String, dynamic>? ?? {}),
      reviews: ReviewKpiSection.fromJson(
          json['reviews'] as Map<String, dynamic>? ?? {}),
      maintenance: MaintenanceKpiSection.fromJson(
          json['maintenance'] as Map<String, dynamic>? ?? {}),
      dressPortfolio: DressPortfolioKpiSection.fromJson(
          json['dressPortfolio'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class ReviewRatingDistributionItem {
  final int rating;
  final int count;

  const ReviewRatingDistributionItem({required this.rating, required this.count});

  factory ReviewRatingDistributionItem.fromJson(Map<String, dynamic> json) {
    return ReviewRatingDistributionItem(
      rating: json['rating'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class BusinessReviewReportSection {
  final ReviewKpiSection summary;
  final List<ReviewRatingDistributionItem> ratingDistribution;

  const BusinessReviewReportSection({
    required this.summary,
    required this.ratingDistribution,
  });

  factory BusinessReviewReportSection.fromJson(Map<String, dynamic> json) {
    final dist = json['ratingDistribution'] as List<dynamic>? ?? [];
    return BusinessReviewReportSection(
      summary: ReviewKpiSection.fromJson(
          json['summary'] as Map<String, dynamic>? ?? {}),
      ratingDistribution: dist
          .map((e) =>
              ReviewRatingDistributionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MaintenanceTypeBreakdownItem {
  final String maintenanceType;
  final String maintenanceTypeLabel;
  final int recordCount;
  final double totalCostAmount;

  const MaintenanceTypeBreakdownItem({
    required this.maintenanceType,
    required this.maintenanceTypeLabel,
    required this.recordCount,
    required this.totalCostAmount,
  });

  factory MaintenanceTypeBreakdownItem.fromJson(Map<String, dynamic> json) {
    return MaintenanceTypeBreakdownItem(
      maintenanceType: json['maintenanceType']?.toString() ?? '',
      maintenanceTypeLabel: json['maintenanceTypeLabel'] as String? ?? '',
      recordCount: json['recordCount'] as int? ?? 0,
      totalCostAmount: (json['totalCostAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BusinessMaintenanceReportSection {
  final MaintenanceKpiSection summary;
  final List<MaintenanceTypeBreakdownItem> byType;

  const BusinessMaintenanceReportSection({
    required this.summary,
    required this.byType,
  });

  factory BusinessMaintenanceReportSection.fromJson(Map<String, dynamic> json) {
    final byType = json['byType'] as List<dynamic>? ?? [];
    return BusinessMaintenanceReportSection(
      summary: MaintenanceKpiSection.fromJson(
          json['summary'] as Map<String, dynamic>? ?? {}),
      byType: byType
          .map((e) =>
              MaintenanceTypeBreakdownItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthlyTrendItem {
  final String month;
  final double revenue;
  final int rentalCount;

  const MonthlyTrendItem({
    required this.month,
    required this.revenue,
    required this.rentalCount,
  });

  factory MonthlyTrendItem.fromJson(Map<String, dynamic> json) {
    return MonthlyTrendItem(
      month: json['month'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      rentalCount: json['rentalCount'] as int? ?? 0,
    );
  }
}

class BusinessPerformanceReport {
  final DateTime? fromUtc;
  final DateTime? toUtc;
  final int? dressId;
  final int? dressCategoryId;
  final FinanceKpiSection finance;
  final RentalKpiSection rentals;
  final BusinessReviewReportSection reviews;
  final BusinessMaintenanceReportSection maintenance;
  final DressPortfolioKpiSection dressPortfolio;
  final List<MonthlyTrendItem> monthlyTrends;

  const BusinessPerformanceReport({
    this.fromUtc,
    this.toUtc,
    this.dressId,
    this.dressCategoryId,
    required this.finance,
    required this.rentals,
    required this.reviews,
    required this.maintenance,
    required this.dressPortfolio,
    required this.monthlyTrends,
  });

  factory BusinessPerformanceReport.fromJson(Map<String, dynamic> json) {
    final trends = json['monthlyTrends'] as List<dynamic>? ?? [];
    return BusinessPerformanceReport(
      fromUtc: json['fromUtc'] != null
          ? DateTime.parse(json['fromUtc'] as String)
          : null,
      toUtc:
          json['toUtc'] != null ? DateTime.parse(json['toUtc'] as String) : null,
      dressId: json['dressId'] as int?,
      dressCategoryId: json['dressCategoryId'] as int?,
      finance: FinanceKpiSection.fromJson(
          json['finance'] as Map<String, dynamic>? ?? {}),
      rentals: RentalKpiSection.fromJson(
          json['rentals'] as Map<String, dynamic>? ?? {}),
      reviews: BusinessReviewReportSection.fromJson(
          json['reviews'] as Map<String, dynamic>? ?? {}),
      maintenance: BusinessMaintenanceReportSection.fromJson(
          json['maintenance'] as Map<String, dynamic>? ?? {}),
      dressPortfolio: DressPortfolioKpiSection.fromJson(
          json['dressPortfolio'] as Map<String, dynamic>? ?? {}),
      monthlyTrends: trends
          .map((e) => MonthlyTrendItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RefundSummarySection {
  final int totalCount;
  final double totalSucceededAmount;
  final int succeededCount;
  final int pendingCount;
  final int rejectedCount;
  final String currency;

  const RefundSummarySection({
    required this.totalCount,
    required this.totalSucceededAmount,
    required this.succeededCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.currency,
  });

  factory RefundSummarySection.fromJson(Map<String, dynamic> json) {
    return RefundSummarySection(
      totalCount: json['totalCount'] as int? ?? 0,
      totalSucceededAmount:
          (json['totalSucceededAmount'] as num?)?.toDouble() ?? 0,
      succeededCount: json['succeededCount'] as int? ?? 0,
      pendingCount: json['pendingCount'] as int? ?? 0,
      rejectedCount: json['rejectedCount'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'EUR',
    );
  }
}

class FinancialReport {
  final DateTime? fromUtc;
  final DateTime? toUtc;
  final int? dressId;
  final int? dressCategoryId;
  final FinanceKpiSection periodSummary;
  final LedgerReport ledger;
  final RefundSummarySection refunds;

  const FinancialReport({
    this.fromUtc,
    this.toUtc,
    this.dressId,
    this.dressCategoryId,
    required this.periodSummary,
    required this.ledger,
    required this.refunds,
  });

  factory FinancialReport.fromJson(Map<String, dynamic> json) {
    return FinancialReport(
      fromUtc: json['fromUtc'] != null
          ? DateTime.parse(json['fromUtc'] as String)
          : null,
      toUtc:
          json['toUtc'] != null ? DateTime.parse(json['toUtc'] as String) : null,
      dressId: json['dressId'] as int?,
      dressCategoryId: json['dressCategoryId'] as int?,
      periodSummary: FinanceKpiSection.fromJson(
          json['periodSummary'] as Map<String, dynamic>? ?? {}),
      ledger: LedgerReport.fromJson(
          json['ledger'] as Map<String, dynamic>? ?? {}),
      refunds: RefundSummarySection.fromJson(
          json['refunds'] as Map<String, dynamic>? ?? {}),
    );
  }
}
