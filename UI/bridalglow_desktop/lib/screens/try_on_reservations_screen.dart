import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/models/try_on_reservation.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/providers/notification_refresh_coordinator.dart';
import 'package:bridalglow_desktop/providers/try_on_reservation_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class TryOnReservationsScreen extends StatefulWidget {
  const TryOnReservationsScreen({super.key});

  @override
  State<TryOnReservationsScreen> createState() =>
      _TryOnReservationsScreenState();
}

class _TryOnReservationsScreenState extends State<TryOnReservationsScreen> {
  late TryOnReservationProvider _provider;
  late DressProvider _dressProvider;

  List<DressListItem> _dresses = [];
  int? _selectedDressId;
  int? _selectedStatusFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  SearchResult<TryOnReservation>? _result;
  bool _loading = false;
  NotificationRefreshCoordinator? _refreshCoordinator;

  static const List<Map<String, dynamic>> _statusFilters = [
    {'label': 'All Statuses', 'value': null},
    {'label': 'Pending', 'value': 1},
    {'label': 'Confirmed', 'value': 2},
    {'label': 'Checked In', 'value': 3},
    {'label': 'Completed', 'value': 4},
    {'label': 'Cancelled by Customer', 'value': 5},
    {'label': 'Cancelled by Staff', 'value': 6},
    {'label': 'No Show', 'value': 7},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _provider = context.read<TryOnReservationProvider>();
      _dressProvider = context.read<DressProvider>();
      _refreshCoordinator = context.read<NotificationRefreshCoordinator>();
      _refreshCoordinator!.addListener(_onRealtimeRefresh);
      await _loadDresses();
      await _search();
    });
  }

  @override
  void dispose() {
    _refreshCoordinator?.removeListener(_onRealtimeRefresh);
    super.dispose();
  }

  void _onRealtimeRefresh() {
    final entityType = _refreshCoordinator?.lastRelatedEntityType;
    if (NotificationRefreshCoordinator.affectsTryOn(entityType)) {
      _search();
    }
  }

  Future<void> _loadDresses() async {
    try {
      final result = await _dressProvider
          .get(filter: {'pageSize': 200, 'page': 0, 'includeTotalCount': false});
      if (mounted) setState(() => _dresses = result.items);
    } catch (_) {}
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final filter = <String, dynamic>{
        'pageSize': 100,
        'page': 0,
        'includeTotalCount': true,
        if (_selectedDressId != null) 'dressId': _selectedDressId,
        if (_selectedStatusFilter != null) 'status': _selectedStatusFilter,
        if (_fromDate != null)
          'fromDate': _fromDate!.toUtc().toIso8601String(),
        if (_toDate != null)
          'toDate': _toDate!
              .toUtc()
              .add(const Duration(hours: 23, minutes: 59))
              .toIso8601String(),
      };
      final result = await _provider.get(filter: filter);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _fromDate = picked);
      await _search();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _toDate = picked);
      await _search();
    }
  }

  Future<void> _clearDates() async {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    await _search();
  }

  Future<void> _viewDetail(TryOnReservation r) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _ReservationDetailDialog(
        reservation: r,
        provider: _provider,
      ),
    );
    if (updated == true) await _search();
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.red, size: 22),
          SizedBox(width: 10),
          Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 20),
          _buildPipelineSummary(),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
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
              colors: [_kPrimary, Color(0xFFD4889A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.event_note_outlined,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Try-On Reservations',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              Text(
                'Manage and process try-on appointments',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _search,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // ── Responsive filter row ─────────────────────────────────────────────────
  // Uses LayoutBuilder to switch between a single-row (wide) and two-row
  // (narrow) layout, preventing RenderFlex overflow on small window sizes.

  Widget _buildFilters() {
    final fmt = DateFormat('dd.MM.yyyy');
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return _buildFiltersWide(fmt);
        }
        return _buildFiltersNarrow(fmt);
      },
    );
  }

  Widget _buildFiltersWide(DateFormat fmt) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildDropdown<int?>(
            value: _selectedDressId,
            hint: 'All Dresses',
            icon: Icons.checkroom_outlined,
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('All Dresses')),
              ..._dresses.map((d) => DropdownMenuItem<int?>(
                    value: d.id,
                    child: Text('${d.code} – ${d.name}',
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  )),
            ],
            onChanged: (v) async {
              setState(() => _selectedDressId = v);
              await _search();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _buildDropdown<int?>(
            value: _selectedStatusFilter,
            hint: 'All Statuses',
            icon: Icons.filter_list_outlined,
            items: _statusFilters
                .map((o) => DropdownMenuItem<int?>(
                      value: o['value'] as int?,
                      child: Text(o['label'] as String),
                    ))
                .toList(),
            onChanged: (v) async {
              setState(() => _selectedStatusFilter = v);
              await _search();
            },
          ),
        ),
        const SizedBox(width: 10),
        _dateButton(
          label: _fromDate != null ? 'From: ${fmt.format(_fromDate!)}' : 'From Date',
          icon: Icons.calendar_today_outlined,
          onTap: _pickFromDate,
        ),
        const SizedBox(width: 10),
        _dateButton(
          label: _toDate != null ? 'To: ${fmt.format(_toDate!)}' : 'To Date',
          icon: Icons.calendar_today_outlined,
          onTap: _pickToDate,
        ),
        if (_fromDate != null || _toDate != null) ...[
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: _clearDates,
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
          ),
        ],
      ],
    );
  }

  Widget _buildFiltersNarrow(DateFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildDropdown<int?>(
                value: _selectedDressId,
                hint: 'All Dresses',
                icon: Icons.checkroom_outlined,
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('All Dresses')),
                  ..._dresses.map((d) => DropdownMenuItem<int?>(
                        value: d.id,
                        child: Text('${d.code} – ${d.name}',
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      )),
                ],
                onChanged: (v) async {
                  setState(() => _selectedDressId = v);
                  await _search();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildDropdown<int?>(
                value: _selectedStatusFilter,
                hint: 'All Statuses',
                icon: Icons.filter_list_outlined,
                items: _statusFilters
                    .map((o) => DropdownMenuItem<int?>(
                          value: o['value'] as int?,
                          child: Text(o['label'] as String),
                        ))
                    .toList(),
                onChanged: (v) async {
                  setState(() => _selectedStatusFilter = v);
                  await _search();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _dateButton(
                label: _fromDate != null
                    ? 'From: ${fmt.format(_fromDate!)}'
                    : 'From Date',
                icon: Icons.calendar_today_outlined,
                onTap: _pickFromDate,
                fillWidth: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _dateButton(
                label: _toDate != null
                    ? 'To: ${fmt.format(_toDate!)}'
                    : 'To Date',
                icon: Icons.calendar_today_outlined,
                onTap: _pickToDate,
                fillWidth: true,
              ),
            ),
            if (_fromDate != null || _toDate != null) ...[
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _clearDates,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── Pipeline summary ──────────────────────────────────────────────────────
  // Uses LayoutBuilder: wide screens → single Expanded row; narrow → Wrap
  // so cards flow to additional lines without overflowing.

  Widget _buildPipelineSummary() {
    final items = _result?.items ?? [];
    final counts = {
      'Pending': items.where((r) => r.isPending).length,
      'Confirmed': items.where((r) => r.isConfirmed).length,
      'Completed': items.where((r) => r.isCompleted).length,
      'Cancelled': items.where((r) => r.isCancelled).length,
      'No Show': items.where((r) => r.isNoShow).length,
    };

    final colors = {
      'Pending': Colors.orange.shade600,
      'Confirmed': Colors.blue.shade600,
      'Completed': Colors.green.shade600,
      'Cancelled': Colors.red.shade600,
      'No Show': Colors.grey.shade600,
    };

    final entries = counts.entries.toList();
    const spacing = 10.0;
    const minCardWidth = 90.0;
    final totalMinWidth =
        minCardWidth * entries.length + spacing * (entries.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= totalMinWidth) {
          // Single row — each card takes equal flex space.
          return Row(
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                Expanded(
                  child: _buildStatCard(entries[i], colors[entries[i].key]!),
                ),
                if (i < entries.length - 1) const SizedBox(width: spacing),
              ],
            ],
          );
        }

        // Narrow — 2-per-row wrap layout.
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: entries
              .map((e) => SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(e, colors[e.key]!),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(MapEntry<String, int> entry, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.value}',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            entry.key,
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final reservations = _result?.items ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: reservations.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.8), // Reservation #
                        1: FlexColumnWidth(2.0), // Customer
                        2: FlexColumnWidth(2.0), // Dress
                        3: FlexColumnWidth(2.0), // Date & Time
                        4: FlexColumnWidth(1.2), // Status
                        5: FixedColumnWidth(80), // Price
                        6: FixedColumnWidth(80), // Actions
                      },
                      children: [
                        _buildHeaderRow(),
                        ...reservations.map(_buildDataRow),
                      ],
                    ),
                  ),
          ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '${_result!.totalCount ?? reservations.length} reservation(s) found',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.event_note_outlined, color: _kPrimary, size: 20),
          SizedBox(width: 10),
          Text(
            'Reservation List',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      children: [
        _headerCell('Reservation #'),
        _headerCell('Customer'),
        _headerCell('Dress'),
        _headerCell('Date & Time'),
        _headerCell('Status'),
        _headerCell('Price'),
        _headerCell('Actions'),
      ],
    );
  }

  Widget _headerCell(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5)),
      );

  TableRow _buildDataRow(TryOnReservation r) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final fmtTime = DateFormat('HH:mm');
    final local = r.startAtUtc.toLocal();
    final localEnd = r.endAtUtc.toLocal();

    return TableRow(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      children: [
        _dataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.reservationNumber,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                    fontFamily: 'monospace')),
          ],
        )),
        _dataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.customerName,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text(r.customerEmail,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        )),
        _dataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.dressName,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(r.dressCode,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        )),
        _dataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmt.format(local),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text('→ ${fmtTime.format(localEnd)}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        )),
        _dataCell(_buildStatusBadge(r.status)),
        _dataCell(Text('${r.priceAmount.toStringAsFixed(2)} BAM',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600))),
        _dataCell(IconButton(
          icon: const Icon(Icons.open_in_new_rounded,
              color: _kPrimary, size: 20),
          tooltip: 'View / Manage',
          onPressed: () => _viewDetail(r),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        )),
      ],
    );
  }

  Widget _dataCell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: child,
      );

  Widget _buildStatusBadge(int status) {
    final cfg = _statusBadgeConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cfg.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(cfg.$3,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: cfg.$1)),
    );
  }

  (Color, Color, String) _statusBadgeConfig(int status) {
    switch (status) {
      case 1:
        return (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Pending');
      case 2:
        return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Confirmed');
      case 3:
        return (Colors.teal.shade700, const Color(0xFFE0F2F1), 'Checked In');
      case 4:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Completed');
      case 5:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Cancelled');
      case 6:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Cancelled');
      case 7:
        return (Colors.grey.shade700, const Color(0xFFF5F5F5), 'No Show');
      default:
        return (Colors.grey.shade600, const Color(0xFFF5F5F5), 'Unknown');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No reservations found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('Adjust the filters to see more results.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // The [fillWidth] flag switches the inner Row from MainAxisSize.min (natural
  // button width) to MainAxisSize.max so the button expands inside an Expanded
  // parent in the narrow two-row filter layout.
  Widget _dateButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool fillWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, color: _kPrimary, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Row(children: [
          Icon(icon, color: Colors.grey.shade500, size: 18),
          const SizedBox(width: 8),
          Text(hint,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ]),
        items: items,
        onChanged: (v) {
          if (v != value) onChanged(v as T);
        },
      ),
    );
  }
}

// ── Reservation Detail Dialog ─────────────────────────────────────────────

class _ReservationDetailDialog extends StatefulWidget {
  final TryOnReservation reservation;
  final TryOnReservationProvider provider;

  const _ReservationDetailDialog({
    required this.reservation,
    required this.provider,
  });

  @override
  State<_ReservationDetailDialog> createState() =>
      _ReservationDetailDialogState();
}

class _ReservationDetailDialogState extends State<_ReservationDetailDialog> {
  TryOnReservation? _current;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFull();
  }

  Future<void> _loadFull() async {
    setState(() => _loading = true);
    try {
      final full = await widget.provider.getReservationById(widget.reservation.id);
      if (mounted) setState(() => _current = full);
    } catch (_) {
      if (mounted) setState(() => _current = widget.reservation);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performAction(
      String actionLabel, Future<TryOnReservation> Function() action) async {
    setState(() => _loading = true);
    try {
      final updated = await action();
      if (mounted) {
        setState(() => _current = updated);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$actionLabel successful'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAction(String title, String message,
      Future<TryOnReservation> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _performAction(title, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _current ?? widget.reservation;
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(r),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: _kPrimary),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Reservation #', r.reservationNumber,
                          monospace: true),
                      _buildInfoRow('Customer', '${r.customerName} (${r.customerEmail})'),
                      _buildInfoRow('Dress', '${r.dressCode} – ${r.dressName}'),
                      _buildInfoRow('Date & Time',
                          '${fmt.format(r.startAtUtc.toLocal())} → ${DateFormat('HH:mm').format(r.endAtUtc.toLocal())}'),
                      _buildInfoRow('Price', '${r.priceAmount.toStringAsFixed(2)} BAM'),
                      if (r.depositAmount != null)
                        _buildInfoRow('Deposit', '${r.depositAmount!.toStringAsFixed(2)} BAM'),
                      if (r.notes != null && r.notes!.isNotEmpty)
                        _buildInfoRow('Notes', r.notes!),
                      if (r.cancellationReason != null &&
                          r.cancellationReason!.isNotEmpty)
                        _buildInfoRow('Cancellation Reason',
                            r.cancellationReason!),
                      const SizedBox(height: 16),
                      _buildStatusHistory(r),
                      const SizedBox(height: 16),
                      _buildActions(r),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context,
                        _current != widget.reservation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(TryOnReservation r) {
    final cfg = _statusConfig(r.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: _kPrimaryLight,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_note_outlined,
                color: _kPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reservation Details',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                Text(r.reservationNumber,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: cfg.$2, borderRadius: BorderRadius.circular(20)),
            child: Text(cfg.$3,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cfg.$1)),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () =>
                Navigator.pop(context, _current != widget.reservation),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF1F2937),
                    fontFamily: monospace ? 'monospace' : null,
                    fontWeight:
                        monospace ? FontWeight.w700 : FontWeight.normal)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHistory(TryOnReservation r) {
    if (r.statusHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status History',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: r.statusHistory.asMap().entries.map((entry) {
              final h = entry.value;
              final isLast = entry.key == r.statusHistory.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(
                      h.toStatusLabel,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(h.toStatus)),
                    ),
                    const SizedBox(width: 8),
                    if (h.reason != null && h.reason!.isNotEmpty) ...[
                      Flexible(
                        child: Text('– ${h.reason!}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    Text(
                      '${DateFormat('dd.MM.yyyy HH:mm').format(h.changedAtUtc.toLocal())} by ${h.changedByUserName}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(TryOnReservation r) {
    if (!r.isActive) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (r.isPending)
              _actionButton(
                label: 'Confirm',
                icon: Icons.check_circle_outline_rounded,
                color: Colors.blue.shade600,
                onTap: () => _confirmAction(
                  'Confirm Reservation',
                  'Confirm reservation ${r.reservationNumber}?',
                  () => widget.provider.confirm(r.id),
                ),
              ),
            if (r.isConfirmed || r.isCheckedIn)
              _actionButton(
                label: 'Complete',
                icon: Icons.task_alt_rounded,
                color: Colors.green.shade600,
                onTap: () => _confirmAction(
                  'Complete Reservation',
                  'Mark reservation ${r.reservationNumber} as completed?',
                  () => widget.provider.complete(r.id),
                ),
              ),
            if (r.isConfirmed)
              _actionButton(
                label: 'No Show',
                icon: Icons.person_off_outlined,
                color: Colors.grey.shade600,
                onTap: () => _confirmAction(
                  'Mark No Show',
                  'Mark ${r.reservationNumber} as no show?',
                  () => widget.provider.markNoShow(r.id),
                ),
              ),
            if (r.isPending || r.isConfirmed)
              _actionButton(
                label: 'Cancel',
                icon: Icons.cancel_outlined,
                color: Colors.red.shade600,
                onTap: () => _confirmAction(
                  'Cancel Reservation',
                  'Cancel reservation ${r.reservationNumber}? This will free the time slot.',
                  () => widget.provider.cancel(r.id),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: _loading ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  (Color, Color, String) _statusConfig(int status) {
    switch (status) {
      case 1:
        return (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Pending');
      case 2:
        return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Confirmed');
      case 3:
        return (Colors.teal.shade700, const Color(0xFFE0F2F1), 'Checked In');
      case 4:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Completed');
      case 5:
      case 6:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Cancelled');
      case 7:
        return (Colors.grey.shade700, const Color(0xFFF5F5F5), 'No Show');
      default:
        return (Colors.grey.shade600, const Color(0xFFF5F5F5), 'Unknown');
    }
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange.shade700;
      case 2:
        return Colors.blue.shade700;
      case 3:
        return Colors.teal.shade700;
      case 4:
        return Colors.green.shade700;
      case 5:
      case 6:
        return Colors.red.shade700;
      case 7:
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
