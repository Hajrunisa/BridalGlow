import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bridalglow_desktop/models/report_models.dart';
import 'package:bridalglow_desktop/widgets/report_widgets.dart';

const _chartColors = [
  Color(0xFFC2778A),
  Color(0xFF6366F1),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF3B82F6),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFF14B8A6),
  Color(0xFFEC4899),
  Color(0xFF64748B),
];

class RentalStatusPieChart extends StatelessWidget {
  final List<RentalStatusCountItem> items;

  const RentalStatusPieChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final data = items.where((e) => e.count > 0).toList();
    if (data.isEmpty) {
      return const Center(child: Text('No rental data for selected filters'));
    }

    final total = data.fold<int>(0, (sum, e) => sum + e.count);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < data.length; i++)
                  PieChartSectionData(
                    value: data[i].count.toDouble(),
                    color: _chartColors[i % _chartColors.length],
                    radius: 52,
                    title: '${((data[i].count / total) * 100).round()}%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final item = data[i];
              return Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _chartColors[i % _chartColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.statusLabel,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${item.count}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class RatingDistributionBarChart extends StatelessWidget {
  final List<ReviewRatingDistributionItem> items;

  const RatingDistributionBarChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No review ratings for selected filters'));
    }

    final sorted = List<ReviewRatingDistributionItem>.from(items)
      ..sort((a, b) => a.rating.compareTo(b.rating));
    final maxY = sorted
        .map((e) => e.count)
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final rating = value.toInt();
                if (rating < 1 || rating > 5) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('$rating★',
                      style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < sorted.length; i++)
            BarChartGroupData(
              x: sorted[i].rating,
              barRods: [
                BarChartRodData(
                  toY: sorted[i].count.toDouble(),
                  color: kReportPrimary,
                  width: 24,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class MaintenanceTypeBarChart extends StatelessWidget {
  final List<MaintenanceTypeBreakdownItem> items;

  const MaintenanceTypeBarChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('No maintenance data for selected filters'));
    }

    final maxY = items
        .map((e) => e.recordCount)
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= items.length) {
                  return const SizedBox.shrink();
                }
                final label = items[value.toInt()].maintenanceTypeLabel;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label.length > 8 ? '${label.substring(0, 7)}…' : label,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: items[i].recordCount.toDouble(),
                  color: _chartColors[i % _chartColors.length],
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class MonthlyTrendLineChart extends StatelessWidget {
  final List<MonthlyTrendItem> items;

  const MonthlyTrendLineChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No trend data for selected filters'));
    }

    final maxRevenue = items
        .map((e) => e.revenue)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final maxRentals = items
        .map((e) => e.rentalCount)
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxRevenue == 0 ? 1 : maxRevenue * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxRevenue > 0 ? maxRevenue / 4 : 1,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (maxRentals == 0) return const SizedBox.shrink();
                final rentalVal =
                    (value / (maxRevenue == 0 ? 1 : maxRevenue)) * maxRentals;
                return Text(
                  rentalVal.round().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) => Text(
                value >= 1000
                    ? '${(value / 1000).toStringAsFixed(1)}k'
                    : value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= items.length) {
                  return const SizedBox.shrink();
                }
                final month = items[idx].month;
                final parts = month.split('-');
                final label =
                    parts.length == 2 ? '${parts[1]}/${parts[0].substring(2)}' : month;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < items.length; i++)
                FlSpot(i.toDouble(), items[i].revenue),
            ],
            isCurved: true,
            color: kReportPrimary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: kReportPrimary.withValues(alpha: 0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= items.length) return null;
                final item = items[idx];
                return LineTooltipItem(
                  '${item.month}\n€ ${item.revenue.toStringAsFixed(2)}\n${item.rentalCount} rentals',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

class TopDressesBarChart extends StatelessWidget {
  final List<TopDressRentalItem> items;

  const TopDressesBarChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No rental ranking for selected filters'));
    }

    final maxY = items
        .map((e) => e.rentalCount)
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= items.length) {
                  return const SizedBox.shrink();
                }
                final code = items[value.toInt()].dressCode;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(code, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: items[i].rentalCount.toDouble(),
                  color: kReportPrimary,
                  width: 28,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
