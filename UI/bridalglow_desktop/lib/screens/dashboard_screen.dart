import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/recommendation.dart';
import 'package:bridalglow_desktop/models/report_models.dart';
import 'package:bridalglow_desktop/models/user.dart';
import 'package:bridalglow_desktop/providers/recommendation_provider.dart';
import 'package:bridalglow_desktop/providers/reports_provider.dart';
import 'package:bridalglow_desktop/utils/recommender_display_helper.dart';
import 'package:bridalglow_desktop/widgets/report_widgets.dart';

const _kPrimary = Color(0xFFC2778A);

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ReportsProvider _reportsProvider;
  late RecommendationProvider _recommendationProvider;
  ReportFilterState _filter = ReportFilterState();
  KpiSummary? _summary;
  bool _initialLoading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filter.applyPresetDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportsProvider = context.read<ReportsProvider>();
      _recommendationProvider = context.read<RecommendationProvider>();
      _loadDashboard(isInitial: true);
    });
  }

  Future<void> _loadDashboard({bool isInitial = false}) async {
    if (!mounted) return;

    setState(() {
      if (isInitial || _summary == null) {
        _initialLoading = true;
      } else {
        _refreshing = true;
      }
      _error = null;
    });

    try {
      final summaryFuture =
          _reportsProvider.getKpiSummary(filter: _filter.toQueryParams());
      final recommendationsFuture =
          _recommendationProvider.loadDashboardInsights(limit: 10, force: true);
      final summary = await summaryFuture;
      await recommendationsFuture;
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadKpis({bool isInitial = false}) async {
    await _loadDashboard(isInitial: isInitial);
  }

  void _onPeriodChanged(ReportPeriodPreset preset) {
    final updated = _filter.copyWith(preset: preset);
    updated.applyPresetDates();
    setState(() => _filter = updated);
    _loadKpis();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                        'Welcome, ${widget.user.fullName} (${widget.user.roleName})'),
                    const SizedBox(height: 4),
                    Text(
                      'Period: ${formatReportPeriodLabel(_filter)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Period',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ReportPeriodPreset>(
                      value: _filter.preset,
                      isDense: true,
                      isExpanded: true,
                      items: ReportPeriodPreset.values
                          .where((p) => p != ReportPeriodPreset.custom)
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(kReportPeriodLabels[p]!),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _onPeriodChanged(value);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Refresh KPIs',
                onPressed: _refreshing ? null : () => _loadKpis(),
                icon: _refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                color: _kPrimary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_initialLoading && _summary == null)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _summary == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _loadKpis(isInitial: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                    ),
                  ],
                ),
              ),
            )
          else if (_summary != null)
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiGrid(_summary!),
                        const SizedBox(height: 24),
                        _buildRecommendationsSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  if (_refreshing)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        color: _kPrimary,
                        backgroundColor: _kPrimary.withValues(alpha: 0.15),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(KpiSummary summary) {
    final f = summary.finance;
    final r = summary.rentals;
    final d = summary.dressPortfolio;

    final cards = [
      _DashboardKpiCard(
        title: 'Reservations',
        value: '${r.totalCount}',
        subtitle: '${r.completionRate.toStringAsFixed(1)}% completed',
        icon: Icons.event_available_outlined,
        color: _kPrimary,
      ),
      _DashboardKpiCard(
        title: 'Revenue',
        value: formatCurrency(f.netRevenue, f.currency),
        subtitle: '${f.transactionCount} transactions',
        icon: Icons.euro_rounded,
        color: Colors.green,
      ),
      _DashboardKpiCard(
        title: 'Captured',
        value: formatCurrency(f.totalCapturedAmount, f.currency),
        subtitle: 'Gross payments',
        icon: Icons.payments_outlined,
        color: Colors.blue,
      ),
      _DashboardKpiCard(
        title: 'Refunds',
        value: formatCurrency(f.totalRefundAmount, f.currency),
        subtitle: 'Total refunded',
        icon: Icons.replay_outlined,
        color: Colors.orange,
      ),
      _DashboardKpiCard(
        title: 'Reviews',
        value: summary.reviews.totalCount > 0
            ? '${summary.reviews.averageRating.toStringAsFixed(1)}★'
            : '—',
        subtitle: '${summary.reviews.totalCount} in period',
        icon: Icons.star_outline,
        color: Colors.amber,
      ),
      _DashboardKpiCard(
        title: 'Dresses',
        value: '${d.activeDressCount}',
        subtitle: '${d.outOfServiceDressCount} out of service',
        icon: Icons.checkroom_outlined,
        color: Colors.indigo,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;

        return SingleChildScrollView(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: cols == 1 ? 3.0 : 2.4,
            ),
            itemCount: cards.length,
            itemBuilder: (_, i) => cards[i],
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsSection() {
    return Consumer<RecommendationProvider>(
      builder: (context, provider, _) {
        final status = provider.status;
        final trends = provider.trends;
        final loading = provider.loading;
        final error = provider.error;

        final lastRun = trends?.lastSnapshotRunAtUtc ??
            status?.lastSnapshotRunAtUtc;
        final modelVersion =
            trends?.modelVersion.isNotEmpty == true
                ? trends!.modelVersion
                : status?.modelVersion ?? '—';
        final modelVersionDisplay = modelVersion.isEmpty || modelVersion == '—'
            ? modelVersion
            : formatRecommenderModelVersionForDisplay(modelVersion);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ReportSectionTitle(
              title: 'Top recommended dresses',
              subtitle:
                  'Aggregate from the latest recommendation snapshots for the salon',
            ),
            const SizedBox(height: 16),
            ReportResponsiveKpiGrid(
              children: [
                ReportKpiCard(
                  label: 'Model version',
                  value: modelVersionDisplay.isEmpty ? '—' : modelVersionDisplay,
                  icon: Icons.memory_outlined,
                  color: kReportPrimary,
                ),
                ReportKpiCard(
                  label: 'Last snapshot run',
                  value: lastRun != null
                      ? kReportDateFmt.format(lastRun.toLocal())
                      : '—',
                  icon: Icons.schedule_outlined,
                  color: Colors.blue,
                ),
                ReportKpiCard(
                  label: 'Snapshot rows',
                  value: '${status?.snapshotCount ?? 0}',
                  icon: Icons.storage_outlined,
                  color: Colors.teal,
                ),
                ReportKpiCard(
                  label: 'Interactions',
                  value: '${status?.interactionCount ?? 0}',
                  icon: Icons.touch_app_outlined,
                  color: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loading && trends == null)
              const ReportChartCard(
                title: 'Ranking',
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && (trends == null || trends.items.isEmpty))
              ReportChartCard(
                title: 'Ranking',
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => provider.loadDashboardInsights(
                          limit: 10,
                          force: true,
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (trends == null || trends.items.isEmpty)
              const ReportChartCard(
                title: 'Ranking',
                height: 120,
                child: Center(
                  child: Text(
                    'No snapshot data. Run similarity and snapshot recompute.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ReportChartCard(
                title: 'Top ${trends.items.length} recommended dresses',
                height: _trendsTableHeight(trends.items.length),
                child: _buildTrendsTable(trends.items),
              ),
          ],
        );
      },
    );
  }

  double _trendsTableHeight(int rowCount) {
    final rows = rowCount.clamp(1, 10);
    return 44.0 + rows * 44.0;
  }

  Widget _buildTrendsTable(List<RecommendationTrendItem> items) {
    return SingleChildScrollView(
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Dress')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Appearances'), numeric: true),
          DataColumn(label: Text('Total score'), numeric: true),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text('${item.rank}')),
                  DataCell(Text(item.dress.code)),
                  DataCell(
                    Text(
                      item.dress.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(Text(item.dress.primaryCategoryName)),
                  DataCell(Text('${item.appearanceCount}')),
                  DataCell(Text(item.totalScore.toStringAsFixed(2))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DashboardKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _DashboardKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: Colors.grey[600])),
                  Text(value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
