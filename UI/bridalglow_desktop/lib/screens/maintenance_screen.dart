import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/maintenance_record.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/providers/maintenance_record_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);
final _dateFmt = DateFormat('dd.MM.yyyy');

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late MaintenanceRecordProvider _provider;
  late DressProvider _dressProvider;
  late TabController _tabCtrl;

  // List tab state
  List<DressListItem> _dresses = [];
  int? _filterDressId;
  int? _filterStatus;
  int? _filterType;
  SearchResult<MaintenanceRecord>? _result;
  bool _loading = false;

  // Summary tab state
  int? _summaryDressId;
  DateTime? _summaryFrom;
  DateTime? _summaryTo;
  MaintenanceSummary? _summary;
  bool _summaryLoading = false;

  static const _statusOptions = [
    {'label': 'All statuses', 'value': null},
    {'label': 'Logged', 'value': 1},
    {'label': 'In Progress', 'value': 2},
    {'label': 'Completed', 'value': 3},
    {'label': 'Cancelled', 'value': 4},
  ];

  static const _typeOptions = [
    {'label': 'All types', 'value': null},
    {'label': 'Cleaning', 'value': 1},
    {'label': 'Repair', 'value': 2},
    {'label': 'Alteration', 'value': 3},
    {'label': 'Inspection', 'value': 4},
    {'label': 'Preservation', 'value': 5},
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _provider = context.read<MaintenanceRecordProvider>();
      _dressProvider = context.read<DressProvider>();
      await _loadDresses();
      await _search();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDresses() async {
    try {
      final r = await _dressProvider
          .get(filter: {'pageSize': 200, 'page': 0, 'includeTotalCount': false});
      if (mounted) setState(() => _dresses = r.items);
    } catch (_) {}
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final filter = <String, dynamic>{
        'pageSize': 100,
        'page': 0,
        'includeTotalCount': true,
        if (_filterDressId != null) 'dressId': _filterDressId,
        if (_filterStatus != null) 'status': _filterStatus,
        if (_filterType != null) 'maintenanceType': _filterType,
      };
      final r = await _provider.get(filter: filter);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSummary() async {
    if (_summaryDressId == null) {
      _showError('Select a dress to view the summary.');
      return;
    }
    setState(() => _summaryLoading = true);
    try {
      final s = await _provider.getSummary(
        _summaryDressId!,
        fromDate: _summaryFrom,
        toDate: _summaryTo,
      );
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  // ── Status actions ────────────────────────────────────────────────────────

  Future<void> _startRecord(MaintenanceRecord r) async {
    try {
      await _provider.start(r.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maintenance started.'),
          behavior: SnackBarBehavior.floating,
        ));
        await _search();
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _completeRecord(MaintenanceRecord r) async {
    try {
      await _provider.complete(r.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maintenance completed.'),
          behavior: SnackBarBehavior.floating,
        ));
        await _search();
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _cancelRecord(MaintenanceRecord r) async {
    final confirmed = await _confirmDialog('Cancel maintenance',
        'Are you sure you want to cancel this maintenance record?');
    if (confirmed == true && mounted) {
      try {
        await _provider.cancel(r.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Maintenance record has been cancelled.'),
            behavior: SnackBarBehavior.floating,
          ));
          await _search();
        }
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteRecord(MaintenanceRecord r) async {
    final confirmed = await _confirmDialog('Delete record',
        'Are you sure you want to delete this maintenance record?');
    if (confirmed == true && mounted) {
      try {
        await _provider.delete(r.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Record deleted.'),
            behavior: SnackBarBehavior.floating,
          ));
          await _search();
        }
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MaintenanceFormDialog(
        dresses: _dresses,
        provider: _provider,
      ),
    );
    if (saved == true && mounted) await _search();
  }

  Future<void> _showEditDialog(MaintenanceRecord record) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MaintenanceFormDialog(
        dresses: _dresses,
        provider: _provider,
        record: record,
      ),
    );
    if (saved == true && mounted) await _search();
  }

  Future<bool?> _confirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.error_outline_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Error'),
        ]),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabCtrl,
            labelColor: _kPrimary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _kPrimary,
            tabs: const [
              Tab(icon: Icon(Icons.list_alt_rounded), text: 'List'),
              Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Cost Summary'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildListTab(),
                _buildSummaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle get _primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      );

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleSection = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B8FBF), Color(0xFF8EADDC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B8FBF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.build_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maintenance',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D1B2E))),
                  Text('Track and manage service interventions',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          ],
        );
        final createButton = ElevatedButton.icon(
          onPressed: _showCreateDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Record'),
          style: _primaryButtonStyle,
        );

        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleSection,
              const SizedBox(height: 12),
              createButton,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleSection),
            createButton,
          ],
        );
      },
    );
  }

  // ── List tab ──────────────────────────────────────────────────────────────

  Widget _buildListTab() {
    return Column(
      children: [
        // Extra top spacing so floating filter labels are not clipped by the
        // TabBar divider line directly above this tab's content area.
        const SizedBox(height: 12),
        _buildFilters(),
        const SizedBox(height: 12),
        Expanded(child: _buildTable()),
      ],
    );
  }

  String _dressLabel(int dressId) {
    for (final d in _dresses) {
      if (d.id == dressId) return '[${d.code}] ${d.name}';
    }
    return 'Dress #$dressId';
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final isCompact = maxW < 520;
        final isMedium = maxW < 760;
        final dressWidth = isCompact ? maxW : (isMedium ? maxW : 220.0);
        final smallWidth =
            isCompact ? maxW : (isMedium ? (maxW - 12) / 2 : 160.0);

        final filters = <Widget>[
          _buildDropdown<int?>(
            label: 'Dress',
            value: _filterDressId,
            width: dressWidth,
            labelBuilder: (v) =>
                v == null ? 'All dresses' : _dressLabel(v),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('All dresses')),
              ..._dresses.map((d) => DropdownMenuItem<int?>(
                  value: d.id,
                  child: Text('[${d.code}] ${d.name}'))),
            ],
            onChanged: (v) {
              setState(() => _filterDressId = v);
              _search();
            },
          ),
          _buildDropdown<int?>(
            label: 'Type',
            value: _filterType,
            width: smallWidth,
            items: _typeOptions
                .map((o) => DropdownMenuItem<int?>(
                    value: o['value'] as int?,
                    child: Text(o['label'] as String)))
                .toList(),
            onChanged: (v) {
              setState(() => _filterType = v);
              _search();
            },
          ),
          _buildDropdown<int?>(
            label: 'Status',
            value: _filterStatus,
            width: smallWidth,
            items: _statusOptions
                .map((o) => DropdownMenuItem<int?>(
                    value: o['value'] as int?,
                    child: Text(o['label'] as String)))
                .toList(),
            onChanged: (v) {
              setState(() => _filterStatus = v);
              _search();
            },
          ),
        ];

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...filters.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: f,
                  )),
              ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Search'),
                style: _primaryButtonStyle,
              ),
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...filters,
            ElevatedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search'),
              style: _primaryButtonStyle,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required double width,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String Function(T? value)? labelBuilder,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        isExpanded: true,
        isDense: true,
        items: items,
        selectedItemBuilder: labelBuilder != null
            ? (context) => items.map((item) {
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      labelBuilder(item.value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  );
                }).toList()
            : null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTable() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kPrimary));
    }
    final items = _result?.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No maintenance records',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final minTableWidth =
            constraints.maxWidth < 920 ? 920.0 : constraints.maxWidth;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.8),
                      1: FixedColumnWidth(110),
                      2: FixedColumnWidth(110),
                      3: FlexColumnWidth(2.2),
                      4: FixedColumnWidth(90),
                      5: FixedColumnWidth(110),
                      6: FixedColumnWidth(220),
                    },
                    children: [
                      _tableHeader(),
                      ...items.map(_tableRow),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TableRow _tableHeader() {
    const style = TextStyle(
        fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF6B5860));
    final headers = [
      'Dress', 'Type', 'Status', 'Description', 'Cost (€)', 'Performed', 'Actions'
    ];
    return TableRow(
      decoration: const BoxDecoration(color: _kPrimaryLight),
      children: headers
          .map((h) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                child: Text(h, style: style),
              ))
          .toList(),
    );
  }

  TableRow _tableRow(MaintenanceRecord r) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: Colors.grey.withValues(alpha: 0.08))),
      ),
      children: [
        _td('[${r.dressCode}] ${r.dressName}'),
        _tdC(_buildTypeBadge(r.maintenanceType)),
        _tdC(_buildStatusBadge(r.status)),
        _td(r.description, maxLines: 2),
        _td(r.costAmount.toStringAsFixed(2)),
        _td(_dateFmt.format(r.performedAtUtc.toLocal())),
        _tdC(_buildActions(r)),
      ],
    );
  }

  Widget _buildTypeBadge(int type) {
    const colors = {
      1: Color(0xFF0077B6),
      2: Color(0xFFE63946),
      3: Color(0xFF2D6A4F),
      4: Color(0xFF7B2D8B),
      5: Color(0xFFB07D12),
    };
    final color = colors[type] ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(kMaintenanceTypeLabels[type] ?? '$type',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildStatusBadge(int status) {
    Color bg, fg;
    switch (status) {
      case 1:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        break;
      case 2:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        break;
      case 3:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 4:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(kMaintenanceStatusLabels[status] ?? '$status',
            style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildActions(MaintenanceRecord r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (r.isLogged || r.isInProgress)
            _actionBtn(Icons.edit_outlined, 'Edit', Colors.blue,
                () => _showEditDialog(r)),
          if (r.isLogged)
            _actionBtn(Icons.play_circle_outline_rounded, 'Start',
                Colors.orange, () => _startRecord(r)),
          if (r.isInProgress)
            _actionBtn(Icons.check_circle_outline_rounded, 'Complete',
                Colors.green, () => _completeRecord(r)),
          if (r.isLogged || r.isInProgress)
            _actionBtn(Icons.cancel_outlined, 'Cancel', Colors.red,
                () => _cancelRecord(r)),
          if (!r.isInProgress)
            _actionBtn(Icons.delete_outline_rounded, 'Delete',
                Colors.red.shade300, () => _deleteRecord(r)),
        ],
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _td(String text, {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: maxLines),
      );

  Widget _tdC(Widget child) => child;

  // ── Summary tab ───────────────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildSummaryFilters(),
        const SizedBox(height: 12),
        Expanded(child: _buildSummaryContent()),
      ],
    );
  }

  Widget _buildSummaryFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final isCompact = maxW < 520;
        final dressWidth = isCompact ? maxW : (maxW < 760 ? maxW : 250.0);

        final children = <Widget>[
        _buildDropdown<int?>(
          label: 'Dress *',
          value: _summaryDressId,
          width: dressWidth,
          labelBuilder: (v) =>
              v == null ? 'Select a dress' : _dressLabel(v),
          items: [
            const DropdownMenuItem<int?>(
                value: null, child: Text('Select a dress')),
            ..._dresses.map((d) => DropdownMenuItem<int?>(
                value: d.id,
                child: Text('[${d.code}] ${d.name}'))),
          ],
            onChanged: (v) => setState(() => _summaryDressId = v),
          ),
          _buildDateBtn(
            label: _summaryFrom != null
                ? _dateFmt.format(_summaryFrom!)
                : 'From date',
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _summaryFrom ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (d != null && mounted) setState(() => _summaryFrom = d);
            },
          ),
          _buildDateBtn(
            label: _summaryTo != null
                ? _dateFmt.format(_summaryTo!)
                : 'To date',
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _summaryTo ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (d != null && mounted) setState(() => _summaryTo = d);
            },
          ),
          if (_summaryFrom != null || _summaryTo != null)
            TextButton.icon(
              onPressed: () =>
                  setState(() => _summaryFrom = _summaryTo = null),
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text('Clear'),
            ),
        ];

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...children.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: c,
                  )),
              ElevatedButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.bar_chart_rounded, size: 18),
                label: const Text('Show summary'),
                style: _primaryButtonStyle,
              ),
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...children,
            ElevatedButton.icon(
              onPressed: _loadSummary,
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: const Text('Show summary'),
              style: _primaryButtonStyle,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateBtn(
      {required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_rounded, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kPrimary,
        side: const BorderSide(color: _kPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSummaryContent() {
    if (_summaryLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Select a dress and click "Show summary"',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
    }
    final s = _summary!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards
          Row(
            children: [
              _kpiCard('Total records', '${s.totalRecordCount}',
                  Icons.assignment_rounded, Colors.blue),
              const SizedBox(width: 16),
              _kpiCard('Total cost',
                  '€ ${s.totalCostAmount.toStringAsFixed(2)}',
                  Icons.euro_rounded, Colors.green),
              const SizedBox(width: 16),
              _kpiCard('Dress', '[${s.dressCode}] ${s.dressName}',
                  Icons.checkroom_rounded, _kPrimary),
            ],
          ),
          const SizedBox(height: 20),
          // Breakdown by type
          if (s.byType.isNotEmpty) ...[
            const Text('Breakdown by type',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FixedColumnWidth(120),
                    2: FixedColumnWidth(160),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: _kPrimaryLight),
                      children: [
                        _summaryTh('Maintenance type'),
                        _summaryTh('No. of records'),
                        _summaryTh('Total cost'),
                      ],
                    ),
                    ...s.byType.map(
                      (t) => TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey
                                      .withValues(alpha: 0.1))),
                        ),
                        children: [
                          _summaryTd(t.maintenanceTypeLabel),
                          _summaryTd('${t.recordCount}'),
                          _summaryTd(
                              '€ ${t.totalCostAmount.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2)),
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
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTh(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF6B5860))),
      );

  Widget _summaryTd(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      );
}

// ── Maintenance Form Dialog ───────────────────────────────────────────────

class _MaintenanceFormDialog extends StatefulWidget {
  final List<DressListItem> dresses;
  final MaintenanceRecordProvider provider;
  final MaintenanceRecord? record;

  const _MaintenanceFormDialog({
    required this.dresses,
    required this.provider,
    this.record,
  });

  @override
  State<_MaintenanceFormDialog> createState() =>
      _MaintenanceFormDialogState();
}

class _MaintenanceFormDialogState extends State<_MaintenanceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _dressId;
  int _maintenanceType = 1;
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '0');
  final _vendorCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  int? _beforeCondition;
  int? _afterCondition;
  DateTime? _outOfServiceFrom;
  DateTime? _outOfServiceTo;
  DateTime? _performedAt;
  bool _saving = false;

  final _dateFmt = DateFormat('dd.MM.yyyy');

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _dressId = r.dressId;
      _maintenanceType = r.maintenanceType;
      _descCtrl.text = r.description;
      _costCtrl.text = r.costAmount.toStringAsFixed(2);
      _vendorCtrl.text = r.vendorName ?? '';
      _invoiceCtrl.text = r.invoiceNumber ?? '';
      _beforeCondition = r.beforeCondition;
      _afterCondition = r.afterCondition;
      _outOfServiceFrom = r.outOfServiceFromUtc;
      _outOfServiceTo = r.outOfServiceToUtc;
      _performedAt = r.performedAtUtc;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _costCtrl.dispose();
    _vendorCtrl.dispose();
    _invoiceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _dressId == null) {
      _showError('Select a dress.');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        if (!_isEdit) 'dressId': _dressId,
        'maintenanceType': _maintenanceType,
        'description': _descCtrl.text.trim(),
        'costAmount': double.tryParse(_costCtrl.text.replaceAll(',', '.')) ?? 0.0,
        if (_vendorCtrl.text.trim().isNotEmpty)
          'vendorName': _vendorCtrl.text.trim(),
        if (_invoiceCtrl.text.trim().isNotEmpty)
          'invoiceNumber': _invoiceCtrl.text.trim(),
        if (_beforeCondition != null) 'beforeCondition': _beforeCondition,
        if (_afterCondition != null) 'afterCondition': _afterCondition,
        if (_outOfServiceFrom != null)
          'outOfServiceFromUtc':
              _outOfServiceFrom!.toUtc().toIso8601String(),
        if (_outOfServiceTo != null)
          'outOfServiceToUtc': _outOfServiceTo!.toUtc().toIso8601String(),
        if (_performedAt != null)
          'performedAtUtc': _performedAt!.toUtc().toIso8601String(),
      };

      if (_isEdit) {
        await widget.provider.update(widget.record!.id, body);
      } else {
        await widget.provider.insert(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.error_outline_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Error'),
        ]),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(_isEdit ? Icons.edit_rounded : Icons.add_rounded,
              color: _kPrimary, size: 22),
          const SizedBox(width: 8),
          Text(
            _isEdit ? 'Edit record' : 'New maintenance record',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dress (only on create)
                if (!_isEdit)
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Dress *',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _dressId,
                        isExpanded: true,
                        isDense: true,
                        items: [
                          const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Select a dress')),
                          ...widget.dresses.map((d) =>
                              DropdownMenuItem<int?>(
                                  value: d.id,
                                  child: Text('[${d.code}] ${d.name}'))),
                        ],
                        selectedItemBuilder: (context) => [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'Select a dress',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                          ...widget.dresses.map((d) => Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  '[${d.code}] ${d.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              )),
                        ],
                        onChanged: (v) => setState(() => _dressId = v),
                      ),
                    ),
                  ),
                if (!_isEdit) const SizedBox(height: 12),
                // Type
                InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Type *',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _maintenanceType,
                      isDense: true,
                      items: kMaintenanceTypeLabels.entries
                          .map((e) => DropdownMenuItem<int>(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _maintenanceType = v ?? 1),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                      labelText: 'Description *',
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Description is required'
                          : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Cost (€)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vendorCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Vendor',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _invoiceCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Invoice number',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                // Conditions
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Condition before',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _beforeCondition,
                            isDense: true,
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('—')),
                              ...kMaintenanceDressConditionLabels.entries
                                  .map((e) => DropdownMenuItem<int?>(
                                      value: e.key, child: Text(e.value))),
                            ],
                            onChanged: (v) =>
                                setState(() => _beforeCondition = v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Condition after',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _afterCondition,
                            isDense: true,
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('—')),
                              ...kMaintenanceDressConditionLabels.entries
                                  .map((e) => DropdownMenuItem<int?>(
                                      value: e.key, child: Text(e.value))),
                            ],
                            onChanged: (v) =>
                                setState(() => _afterCondition = v),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Out-of-service dates
                Row(
                  children: [
                    Expanded(
                        child: _datePicker(
                            'Out of service from',
                            _outOfServiceFrom,
                            (d) => setState(
                                () => _outOfServiceFrom = d))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _datePicker(
                            'Out of service until',
                            _outOfServiceTo,
                            (d) => setState(
                                () => _outOfServiceTo = d))),
                  ],
                ),
                const SizedBox(height: 12),
                _datePicker('Performed', _performedAt,
                    (d) => setState(() => _performedAt = d)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _datePicker(String label, DateTime? value,
      ValueChanged<DateTime?> onPicked) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () => onPicked(null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const Icon(Icons.calendar_today_rounded, size: 16),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(
          value != null ? _dateFmt.format(value) : '—',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
