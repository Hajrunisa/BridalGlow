import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/dress_category.dart';
import 'package:bridalglow_desktop/models/ledger_report.dart';
import 'package:bridalglow_desktop/models/report_models.dart';
import 'package:bridalglow_desktop/providers/dress_category_provider.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/providers/reports_provider.dart';
import 'package:bridalglow_desktop/utils/report_pdf_helper.dart';
import 'package:bridalglow_desktop/widgets/report_charts.dart';
import 'package:bridalglow_desktop/widgets/report_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late ReportsProvider _reportsProvider;
  late DressProvider _dressProvider;
  late DressCategoryProvider _categoryProvider;

  ReportFilterState _filter = ReportFilterState();
  List<DressCategory> _categories = [];
  List<DressListItem> _dresses = [];

  KpiSummary? _kpiSummary;
  BusinessPerformanceReport? _businessReport;
  FinancialReport? _financialReport;
  bool _initialLoading = true;
  bool _refreshing = false;
  bool _pdfLoading = false;
  _ReportPdfKind? _pdfLoadingKind;
  String? _error;

  bool get _hasReportData =>
      _kpiSummary != null &&
      _businessReport != null &&
      _financialReport != null;

  @override
  void initState() {
    super.initState();
    _filter.applyPresetDates();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportsProvider = context.read<ReportsProvider>();
      _dressProvider = context.read<DressProvider>();
      _categoryProvider = context.read<DressCategoryProvider>();
      _loadAll(isInitial: true);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceData() async {
    try {
      final catResult = await _categoryProvider.get(
        filter: {'pageSize': 100, 'page': 0, 'includeTotalCount': false},
      );
      final dressResult = await _dressProvider.get(
        filter: {'pageSize': 200, 'page': 0, 'includeTotalCount': false},
      );
      if (mounted) {
        setState(() {
          _categories = catResult.items;
          _dresses = dressResult.items;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAll({bool isInitial = false}) async {
    if (!mounted) return;

    setState(() {
      if (isInitial || !_hasReportData) {
        _initialLoading = true;
      } else {
        _refreshing = true;
      }
      _error = null;
    });

    await Future.wait([
      _loadReferenceData(),
      _loadReportsData(),
    ]);

    if (mounted) {
      setState(() {
        _initialLoading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadReportsData() async {
    final params = _filter.toQueryParams();

    try {
      final results = await Future.wait([
        _reportsProvider.getKpiSummary(filter: params),
        _reportsProvider.getBusinessPerformance(filter: params),
        _reportsProvider.getFinancial(filter: params),
      ]);

      if (mounted) {
        setState(() {
          _kpiSummary = results[0] as KpiSummary;
          _businessReport = results[1] as BusinessPerformanceReport;
          _financialReport = results[2] as FinancialReport;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Map<String, dynamic> get _filterParams => _filter.toQueryParams();

  Future<ReportPdfDocument> _fetchPdfDocument(_ReportPdfKind kind) {
    switch (kind) {
      case _ReportPdfKind.business:
        return _reportsProvider.downloadBusinessPdf(filter: _filterParams);
      case _ReportPdfKind.financial:
        return _reportsProvider.downloadFinancialPdf(filter: _filterParams);
    }
  }

  Future<void> _runPdfAction(
    _ReportPdfKind kind,
    Future<void> Function(ReportPdfDocument document) action,
  ) async {
    setState(() {
      _pdfLoading = true;
      _pdfLoadingKind = kind;
    });

    try {
      final document = await _fetchPdfDocument(kind);
      if (!mounted) return;
      await action(document);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pdfLoading = false;
          _pdfLoadingKind = null;
        });
      }
    }
  }

  Future<void> _previewPdf(_ReportPdfKind kind) => _runPdfAction(
        kind,
        (document) => ReportPdfHelper.preview(
          context,
          document: document,
          title: kind.previewTitle,
        ),
      );

  Future<void> _downloadPdf(_ReportPdfKind kind) => _runPdfAction(
        kind,
        (document) async {
          final path = await ReportPdfHelper.download(document);
          if (!mounted || path == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved to $path'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );

  Future<void> _printPdf(_ReportPdfKind kind) => _runPdfAction(
        kind,
        (document) => ReportPdfHelper.print(document),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          ReportFilterBar(
            filter: _filter,
            categories: _categories,
            dresses: _dresses,
            onChanged: (updated) => setState(() => _filter = updated),
            onApply: () => _loadAll(),
          ),
          const SizedBox(height: 16),
          _buildTabBar(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildReportBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kReportPrimary, Color(0xFFD4889A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: kReportPrimary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.analytics_outlined,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports & Analytics',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                'Manager overview with KPIs, trends and financial insights',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              SizedBox(height: 2),
              Text(
                'Period: ${formatReportPeriodLabel(_filter)}',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refreshing ? null : () => _loadAll(),
          icon: _refreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          color: kReportPrimary,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: kReportPrimary,
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: kReportPrimary,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Overview'),
          Tab(icon: Icon(Icons.trending_up_outlined, size: 20), text: 'Business'),
          Tab(
              icon: Icon(Icons.account_balance_outlined, size: 20),
              text: 'Financial'),
        ],
      ),
    );
  }

  Widget _buildReportBody() {
    if (_initialLoading && !_hasReportData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && !_hasReportData) {
      return _buildErrorState();
    }

    if (!_hasReportData) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        TabBarView(
          controller: _tabCtrl,
          children: [
            _ReportsOverviewTab(summary: _kpiSummary!),
            _ReportsBusinessTab(
              report: _businessReport!,
              pdfActions: ReportPdfActionBar(
                title: 'Business Performance PDF',
                loading: _pdfLoading &&
                    _pdfLoadingKind == _ReportPdfKind.business,
                onPreview: () => _previewPdf(_ReportPdfKind.business),
                onDownload: () => _downloadPdf(_ReportPdfKind.business),
                onPrint: () => _printPdf(_ReportPdfKind.business),
              ),
            ),
            _ReportsFinancialTab(
              report: _financialReport!,
              pdfActions: ReportPdfActionBar(
                title: 'Financial Report PDF',
                loading:
                    _pdfLoading && _pdfLoadingKind == _ReportPdfKind.financial,
                onPreview: () => _previewPdf(_ReportPdfKind.financial),
                onDownload: () => _downloadPdf(_ReportPdfKind.financial),
                onPrint: () => _printPdf(_ReportPdfKind.financial),
              ),
            ),
          ],
        ),
        if (_refreshing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: kReportPrimary,
              backgroundColor: kReportPrimary.withValues(alpha: 0.15),
            ),
          ),
        if (_error != null && _hasReportData)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              elevation: 2,
              color: Colors.red.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                            fontSize: 13, color: Colors.red.shade900),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _loadAll(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _loadAll(isInitial: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(backgroundColor: kReportPrimary),
          ),
        ],
      ),
    );
  }
}

enum _ReportPdfKind {
  business,
  financial,
}

extension on _ReportPdfKind {
  String get previewTitle => switch (this) {
        _ReportPdfKind.business => 'Business Performance PDF',
        _ReportPdfKind.financial => 'Financial Report PDF',
      };
}

// ── Overview Tab ──────────────────────────────────────────────────────────

class _ReportsOverviewTab extends StatelessWidget {
  final KpiSummary summary;

  const _ReportsOverviewTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    final f = summary.finance;
    final r = summary.rentals;
    final rev = summary.reviews;
    final m = summary.maintenance;
    final d = summary.dressPortfolio;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReportSectionTitle(
            title: 'Key performance indicators',
            subtitle: 'Aggregated metrics from backend reporting API',
          ),
          const SizedBox(height: 16),
          ReportResponsiveKpiGrid(
            children: [
              ReportKpiCard(
                label: 'Net revenue',
                value: formatCurrency(f.netRevenue, f.currency),
                icon: Icons.euro_rounded,
                color: Colors.green,
              ),
              ReportKpiCard(
                label: 'Reservations',
                value: '${r.totalCount}',
                icon: Icons.event_available_rounded,
                color: kReportPrimary,
              ),
              ReportKpiCard(
                label: 'Active dresses',
                value: '${d.activeDressCount}',
                icon: Icons.checkroom_rounded,
                color: Colors.indigo,
              ),
              ReportKpiCard(
                label: 'Avg. rating',
                value: rev.totalCount > 0
                    ? rev.averageRating.toStringAsFixed(1)
                    : '—',
                icon: Icons.star_rounded,
                color: Colors.amber,
              ),
              ReportKpiCard(
                label: 'Captured',
                value: formatCurrency(f.totalCapturedAmount, f.currency),
                icon: Icons.payments_outlined,
                color: Colors.blue,
              ),
              ReportKpiCard(
                label: 'Refunds',
                value: formatCurrency(f.totalRefundAmount, f.currency),
                icon: Icons.replay_outlined,
                color: Colors.orange,
              ),
              ReportKpiCard(
                label: 'Completion rate',
                value: '${r.completionRate.toStringAsFixed(1)}%',
                icon: Icons.check_circle_outline,
                color: Colors.teal,
              ),
              ReportKpiCard(
                label: 'Maintenance cost',
                value: formatCurrency(m.totalCostAmount, f.currency),
                icon: Icons.build_outlined,
                color: Colors.brown,
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 900;
              final charts = [
                ReportChartCard(
                  title: 'Rental status breakdown',
                  child: RentalStatusPieChart(items: r.statusBreakdown),
                ),
                ReportChartCard(
                  title: 'Top rented dresses',
                  child: TopDressesBarChart(items: d.topRentedDresses),
                ),
              ];

              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: charts[0]),
                    const SizedBox(width: 16),
                    Expanded(child: charts[1]),
                  ],
                );
              }

              return Column(
                children: [
                  charts[0],
                  const SizedBox(height: 16),
                  charts[1],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Business Tab ────────────────────────────────────────────────────────────

class _ReportsBusinessTab extends StatelessWidget {
  final BusinessPerformanceReport report;
  final Widget pdfActions;

  const _ReportsBusinessTab({
    required this.report,
    required this.pdfActions,
  });

  @override
  Widget build(BuildContext context) {
    final f = report.finance;
    final r = report.rentals;
    final rev = report.reviews.summary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pdfActions,
          const SizedBox(height: 16),
          const ReportSectionTitle(title: 'Business performance'),
          const SizedBox(height: 16),
          ReportResponsiveKpiGrid(
            children: [
              ReportKpiCard(
                label: 'Net revenue',
                value: formatCurrency(f.netRevenue, f.currency),
                icon: Icons.euro_rounded,
                color: Colors.green,
              ),
              ReportKpiCard(
                label: 'Total rentals',
                value: '${r.totalCount}',
                icon: Icons.weekend_outlined,
                color: kReportPrimary,
              ),
              ReportKpiCard(
                label: 'Cancellation rate',
                value: '${r.cancellationRate.toStringAsFixed(1)}%',
                icon: Icons.cancel_outlined,
                color: Colors.red,
              ),
              ReportKpiCard(
                label: 'Reviews',
                value:
                    '${rev.totalCount} (${rev.averageRating.toStringAsFixed(1)}★)',
                icon: Icons.star_outline,
                color: Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ReportChartCard(
            title: 'Monthly revenue trend',
            height: 280,
            child: MonthlyTrendLineChart(items: report.monthlyTrends),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 900;
              final charts = [
                ReportChartCard(
                  title: 'Review rating distribution',
                  child: RatingDistributionBarChart(
                    items: report.reviews.ratingDistribution,
                  ),
                ),
                ReportChartCard(
                  title: 'Maintenance by type',
                  child: MaintenanceTypeBarChart(
                    items: report.maintenance.byType,
                  ),
                ),
              ];

              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: charts[0]),
                    const SizedBox(width: 16),
                    Expanded(child: charts[1]),
                  ],
                );
              }

              return Column(
                children: [
                  charts[0],
                  const SizedBox(height: 16),
                  charts[1],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ReportChartCard(
            title: 'Rental status breakdown',
            child: RentalStatusPieChart(items: r.statusBreakdown),
          ),
        ],
      ),
    );
  }
}

// ── Financial Tab ───────────────────────────────────────────────────────────

class _ReportsFinancialTab extends StatelessWidget {
  final FinancialReport report;
  final Widget pdfActions;

  const _ReportsFinancialTab({
    required this.report,
    required this.pdfActions,
  });

  @override
  Widget build(BuildContext context) {
    final p = report.periodSummary;
    final refunds = report.refunds;
    final entries = report.ledger.entries;
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                pdfActions,
                const SizedBox(height: 16),
                const ReportSectionTitle(title: 'Financial summary'),
                const SizedBox(height: 16),
                ReportResponsiveKpiGrid(
                  children: [
                    ReportKpiCard(
                      label: 'Net revenue',
                      value: formatCurrency(p.netRevenue, p.currency),
                      icon: Icons.euro_rounded,
                      color: Colors.green,
                    ),
                    ReportKpiCard(
                      label: 'Captured',
                      value: formatCurrency(
                          p.totalCapturedAmount, p.currency),
                      icon: Icons.payments_outlined,
                      color: Colors.blue,
                    ),
                    ReportKpiCard(
                      label: 'Refunded',
                      value: formatCurrency(
                          refunds.totalSucceededAmount, refunds.currency),
                      icon: Icons.replay_outlined,
                      color: Colors.orange,
                    ),
                    ReportKpiCard(
                      label: 'Transactions',
                      value: '${p.transactionCount}',
                      icon: Icons.receipt_long_outlined,
                      color: kReportPrimary,
                    ),
                    ReportKpiCard(
                      label: 'Refund requests',
                      value: '${refunds.totalCount}',
                      icon: Icons.pending_actions_outlined,
                      color: Colors.amber,
                    ),
                    ReportKpiCard(
                      label: 'Succeeded refunds',
                      value: '${refunds.succeededCount}',
                      icon: Icons.check_circle_outline,
                      color: Colors.teal,
                    ),
                    ReportKpiCard(
                      label: 'Pending refunds',
                      value: '${refunds.pendingCount}',
                      icon: Icons.hourglass_empty,
                      color: Colors.indigo,
                    ),
                    ReportKpiCard(
                      label: 'Rejected refunds',
                      value: '${refunds.rejectedCount}',
                      icon: Icons.block_outlined,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 20, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'Ledger entries',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text('No ledger entries for selected filters'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 950),
                              child: _FinancialLedgerTable(
                                entries: entries,
                                dateFmt: fmt,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FinancialLedgerTable extends StatelessWidget {
  final List<TransactionLedgerEntry> entries;
  final DateFormat dateFmt;

  const _FinancialLedgerTable({
    required this.entries,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(130),
        1: FixedColumnWidth(120),
        2: FixedColumnWidth(90),
        3: FixedColumnWidth(110),
        4: FixedColumnWidth(140),
        5: FixedColumnWidth(160),
        6: FixedColumnWidth(180),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: kReportPrimaryLight),
          children: [
            _headerCell('Date'),
            _headerCell('Type'),
            _headerCell('Direction'),
            _headerCell('Amount'),
            _headerCell('Reservation'),
            _headerCell('Customer'),
            _headerCell('Reference'),
          ],
        ),
        ...entries.map((e) => TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              children: [
                _cell(dateFmt.format(e.occurredAtUtc.toLocal())),
                _cell(e.entryTypeLabel),
                _cell(e.directionLabel),
                _cell(
                  '${e.isDebit ? '−' : '+'}${e.amount.toStringAsFixed(2)} ${e.currency}',
                  color: e.isDebit ? Colors.red.shade700 : Colors.green.shade700,
                ),
                _cell(e.reservationNumber ?? '—'),
                _cell(e.customerName ?? '—'),
                _cell(e.externalReference ?? '—'),
              ],
            )),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _cell(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: color ?? Colors.black87),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
