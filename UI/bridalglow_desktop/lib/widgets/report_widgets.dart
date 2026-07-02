import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/dress_category.dart';
import 'package:bridalglow_desktop/models/report_models.dart';

const kReportPrimary = Color(0xFFC2778A);
const kReportPrimaryLight = Color(0xFFFFF0F3);
final kReportDateFmt = DateFormat('dd.MM.yyyy');

class ReportFilterBar extends StatelessWidget {
  final ReportFilterState filter;
  final List<DressCategory> categories;
  final List<DressListItem> dresses;
  final ValueChanged<ReportFilterState> onChanged;
  final VoidCallback onApply;

  const ReportFilterBar({
    super.key,
    required this.filter,
    required this.categories,
    required this.dresses,
    required this.onChanged,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final isCustom = filter.preset == ReportPeriodPreset.custom;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final fields = [
            _buildPeriodDropdown(),
            if (isCustom) _buildDateField(context, 'From', filter.fromUtc, true),
            if (isCustom) _buildDateField(context, 'To', filter.toUtc, false),
            _buildCategoryDropdown(),
            _buildDressDropdown(),
            _buildApplyButton(),
          ];

          if (wide) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: fields,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                fields[i],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return SizedBox(
      width: 180,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Period',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ReportPeriodPreset>(
            value: filter.preset,
            isDense: true,
            isExpanded: true,
            items: ReportPeriodPreset.values
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(kReportPeriodLabels[p]!),
                    ))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final updated = filter.copyWith(preset: value);
              updated.applyPresetDates();
              onChanged(updated);
              if (value != ReportPeriodPreset.custom) onApply();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(
      BuildContext context, String label, DateTime? value, bool isFrom) {
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: () => _pickDate(context, isFrom),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(
            value != null ? kReportDateFmt.format(value) : 'Select date',
            style: TextStyle(
              fontSize: 14,
              color: value != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final initial = isFrom
        ? (filter.fromUtc ?? DateTime.now())
        : (filter.toUtc ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    final updated = filter.copyWith(
      preset: ReportPeriodPreset.custom,
      fromUtc: isFrom ? picked : filter.fromUtc,
      toUtc: isFrom ? filter.toUtc : picked,
    );
    onChanged(updated);
  }

  Widget _buildCategoryDropdown() {
    return SizedBox(
      width: 200,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Category',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: filter.dressCategoryId,
            isDense: true,
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('All categories')),
              ...categories.map(
                (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
              ),
            ],
            onChanged: (value) {
              onChanged(filter.copyWith(
                dressCategoryId: value,
                clearDressCategoryId: value == null,
              ));
              onApply();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDressDropdown() {
    final filteredDresses = filter.dressCategoryId == null
        ? dresses
        : dresses
            .where((d) => d.primaryCategoryId == filter.dressCategoryId)
            .toList();

    final dressId = filteredDresses.any((d) => d.id == filter.dressId)
        ? filter.dressId
        : null;

    return SizedBox(
      width: 220,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Dress',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: dressId,
            isDense: true,
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('All dresses')),
              ...filteredDresses.map(
                (d) => DropdownMenuItem<int?>(
                  value: d.id,
                  child: Text('[${d.code}] ${d.name}',
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              onChanged(filter.copyWith(
                dressId: value,
                clearDressId: value == null,
              ));
              onApply();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    if (filter.preset != ReportPeriodPreset.custom) {
      return const SizedBox.shrink();
    }

    return FilledButton.icon(
      onPressed: onApply,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Apply'),
      style: FilledButton.styleFrom(
        backgroundColor: kReportPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }
}

class ReportKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const ReportKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const ReportSectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ],
    );
  }
}

class ReportChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;

  const ReportChartCard({
    super.key,
    required this.title,
    required this.child,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

String formatCurrency(double amount, String currency) {
  final symbol = currency == 'EUR' ? '€' : currency;
  return '$symbol ${amount.toStringAsFixed(2)}';
}

String formatReportPeriodLabel(ReportFilterState filter) {
  if (filter.preset == ReportPeriodPreset.custom) {
    final from = filter.fromUtc;
    final to = filter.toUtc;
    if (from != null && to != null) {
      return '${kReportDateFmt.format(from)} – ${kReportDateFmt.format(to)}';
    }
    return kReportPeriodLabels[ReportPeriodPreset.custom]!;
  }
  return kReportPeriodLabels[filter.preset]!;
}

/// Responsive grid for KPI cards — avoids horizontal overflow on narrow windows.
class ReportResponsiveKpiGrid extends StatelessWidget {
  final List<Widget> children;

  const ReportResponsiveKpiGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 700
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: cols == 1 ? 3.2 : 2.8,
          ),
          itemCount: children.length,
          itemBuilder: (_, i) => children[i],
        );
      },
    );
  }
}

/// PDF action bar that wraps on narrow viewports instead of overflowing.
class ReportPdfActionBar extends StatelessWidget {
  final String title;
  final bool loading;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final VoidCallback onPrint;

  const ReportPdfActionBar({
    super.key,
    required this.title,
    required this.loading,
    required this.onPreview,
    required this.onDownload,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kReportPrimaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kReportPrimary.withValues(alpha: 0.2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _actionButton(
                icon: Icons.visibility_outlined,
                label: 'Preview PDF',
                onPressed: onPreview,
              ),
              _actionButton(
                icon: Icons.download_outlined,
                label: 'Download PDF',
                onPressed: onDownload,
              ),
              _actionButton(
                icon: Icons.print_outlined,
                label: 'Print PDF',
                onPressed: onPrint,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        color: kReportPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.picture_as_pdf_outlined,
                  color: kReportPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: actions,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: kReportPrimary,
        side: BorderSide(color: kReportPrimary.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
