import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/rental_reservation.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/providers/notification_refresh_coordinator.dart';
import 'package:bridalglow_desktop/providers/rental_reservation_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class RentalReservationsScreen extends StatefulWidget {
  const RentalReservationsScreen({super.key});

  @override
  State<RentalReservationsScreen> createState() =>
      _RentalReservationsScreenState();
}

class _RentalReservationsScreenState extends State<RentalReservationsScreen> {
  late RentalReservationProvider _provider;
  late DressProvider _dressProvider;

  List<DressListItem> _dresses = [];
  int? _selectedDressId;
  int? _selectedStatusFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  SearchResult<RentalReservation>? _result;
  bool _loading = false;
  NotificationRefreshCoordinator? _refreshCoordinator;

  static const List<Map<String, dynamic>> _statusFilters = [
    {'label': 'All Statuses', 'value': null},
    {'label': 'Pending', 'value': 1},
    {'label': 'Approved', 'value': 2},
    {'label': 'Rejected', 'value': 3},
    {'label': 'Awaiting Payment', 'value': 4},
    {'label': 'Paid', 'value': 5},
    {'label': 'Ready for Pickup', 'value': 6},
    {'label': 'Picked Up', 'value': 7},
    {'label': 'Returned', 'value': 8},
    {'label': 'Completed', 'value': 9},
    {'label': 'Cancelled', 'value': 10},
    {'label': 'Refunded', 'value': 11},
    {'label': 'Cancelled by Customer', 'value': 12},
    {'label': 'Cancelled by Staff', 'value': 13},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _provider = context.read<RentalReservationProvider>();
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
    if (NotificationRefreshCoordinator.affectsRental(entityType)) {
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

  Future<void> _viewDetail(RentalReservation r) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _RentalDetailDialog(
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
          child: const Icon(Icons.weekend_outlined, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rental Reservations',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              Text(
                'Manage the complete dress rental lifecycle',
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
  // Uses LayoutBuilder to switch between single-row (wide) and two-row
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
      'Approved': items.where((r) => r.isApproved).length,
      'Ready': items.where((r) => r.isReadyForPickup).length,
      'Picked Up': items.where((r) => r.isPickedUp).length,
      'Returned': items.where((r) => r.isReturned).length,
      'Completed': items.where((r) => r.isCompleted).length,
      'Cancelled': items.where((r) => r.isCancelled).length,
    };

    final colors = {
      'Pending': Colors.orange.shade600,
      'Approved': Colors.blue.shade600,
      'Ready': Colors.indigo.shade500,
      'Picked Up': Colors.teal.shade600,
      'Returned': Colors.cyan.shade700,
      'Completed': Colors.green.shade600,
      'Cancelled': Colors.red.shade600,
    };

    final entries = counts.entries.toList();
    const spacing = 8.0;
    const minCardWidth = 80.0;
    final totalMinWidth =
        minCardWidth * entries.length + spacing * (entries.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= totalMinWidth) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            entry.key,
            style: TextStyle(
                fontSize: 10,
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
                        3: FlexColumnWidth(2.2), // Period
                        4: FlexColumnWidth(1.4), // Status
                        5: FixedColumnWidth(90), // Amount
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
          Icon(Icons.weekend_outlined, color: _kPrimary, size: 20),
          SizedBox(width: 10),
          Text(
            'Rental Reservation List',
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
        _headerCell('Period'),
        _headerCell('Status'),
        _headerCell('Amount'),
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

  TableRow _buildDataRow(RentalReservation r) {
    final fmtDate = DateFormat('dd.MM.yyyy');
    final startLocal = r.startDateUtc.toLocal();
    final endLocal = r.endDateUtc.toLocal();

    return TableRow(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      children: [
        _dataCell(Text(r.reservationNumber,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
                fontFamily: 'monospace'))),
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
            Text(fmtDate.format(startLocal),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text('→ ${fmtDate.format(endLocal)}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        )),
        _dataCell(_buildStatusBadge(r.status)),
        _dataCell(Text(
            '${r.totalAmount.toStringAsFixed(2)} ${r.currency}',
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
        return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Approved');
      case 3:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Rejected');
      case 4:
        return (Colors.amber.shade800, const Color(0xFFFFF8E1), 'Awaiting Payment');
      case 5:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Paid');
      case 6:
        return (Colors.indigo.shade700, const Color(0xFFE8EAF6), 'Ready for Pickup');
      case 7:
        return (Colors.teal.shade700, const Color(0xFFE0F2F1), 'Picked Up');
      case 8:
        return (Colors.cyan.shade800, const Color(0xFFE0F7FA), 'Returned');
      case 9:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Completed');
      case 11:
        return (Colors.purple.shade700, const Color(0xFFF3E5F5), 'Refunded');
      case 10:
      case 12:
      case 13:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Cancelled');
      default:
        return (Colors.grey.shade600, const Color(0xFFF5F5F5), 'Unknown');
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.weekend_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No rental reservations found',
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

// ── Rental Detail Dialog ──────────────────────────────────────────────────

class _RentalDetailDialog extends StatefulWidget {
  final RentalReservation reservation;
  final RentalReservationProvider provider;

  const _RentalDetailDialog({
    required this.reservation,
    required this.provider,
  });

  @override
  State<_RentalDetailDialog> createState() => _RentalDetailDialogState();
}

class _RentalDetailDialogState extends State<_RentalDetailDialog> {
  RentalReservation? _current;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFull();
  }

  Future<void> _loadFull() async {
    setState(() => _loading = true);
    try {
      final full =
          await widget.provider.getReservationById(widget.reservation.id);
      if (mounted) setState(() => _current = full);
    } catch (_) {
      if (mounted) setState(() => _current = widget.reservation);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performAction(
      String actionLabel, Future<RentalReservation> Function() action) async {
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
      Future<RentalReservation> Function() action) async {
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
    if (confirmed == true && mounted) {
      await _performAction(title, action);
    }
  }

  Future<void> _handleMarkReturned(RentalReservation r) async {
    final result = await showDialog<_ReturnDialogResult>(
      context: context,
      builder: (_) => const ReturnDialog(),
    );
    if (result != null && mounted) {
      await _performAction(
        'Mark Returned',
        () => widget.provider.markReturned(
          r.id,
          lateFeeAmount: result.lateFeeAmount,
          damageFeeAmount: result.damageFeeAmount,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _current ?? widget.reservation;
    final fmtDate = DateFormat('dd.MM.yyyy');
    final fmtDateTime = DateFormat('dd.MM.yyyy HH:mm');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 700,
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
                      _buildInfoRow('Customer',
                          '${r.customerName} (${r.customerEmail})'),
                      _buildInfoRow(
                          'Dress', '${r.dressCode} – ${r.dressName}'),
                      _buildInfoRow(
                        'Rental Period',
                        '${fmtDate.format(r.startDateUtc.toLocal())} → ${fmtDate.format(r.endDateUtc.toLocal())}',
                      ),
                      _buildInfoRow('Base Amount',
                          '${r.baseAmount.toStringAsFixed(2)} ${r.currency}'),
                      if (r.discountAmount > 0)
                        _buildInfoRow('Discount',
                            '–${r.discountAmount.toStringAsFixed(2)} ${r.currency}'),
                      if (r.depositAmount > 0)
                        _buildInfoRow('Deposit',
                            '${r.depositAmount.toStringAsFixed(2)} ${r.currency}'),
                      if (r.lateFeeAmount > 0)
                        _buildInfoRow('Late Fee',
                            '${r.lateFeeAmount.toStringAsFixed(2)} ${r.currency}'),
                      if (r.damageFeeAmount > 0)
                        _buildInfoRow('Damage Fee',
                            '${r.damageFeeAmount.toStringAsFixed(2)} ${r.currency}'),
                      _buildInfoRow('Total Amount',
                          '${r.totalAmount.toStringAsFixed(2)} ${r.currency}'),
                      if (r.notes != null && r.notes!.isNotEmpty)
                        _buildInfoRow('Notes', r.notes!),
                      if (r.cancellationReason != null &&
                          r.cancellationReason!.isNotEmpty)
                        _buildInfoRow(
                            'Cancellation Reason', r.cancellationReason!),
                      if (r.approvedAtUtc != null)
                        _buildInfoRow('Approved At',
                            fmtDateTime.format(r.approvedAtUtc!.toLocal())),
                      if (r.pickedUpAtUtc != null)
                        _buildInfoRow('Picked Up At',
                            fmtDateTime.format(r.pickedUpAtUtc!.toLocal())),
                      if (r.returnedAtUtc != null)
                        _buildInfoRow('Returned At',
                            fmtDateTime.format(r.returnedAtUtc!.toLocal())),
                      if (r.completedAtUtc != null)
                        _buildInfoRow('Completed At',
                            fmtDateTime.format(r.completedAtUtc!.toLocal())),
                      if (r.cancelledAtUtc != null)
                        _buildInfoRow('Cancelled At',
                            fmtDateTime.format(r.cancelledAtUtc!.toLocal())),
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
                    onPressed: () => Navigator.pop(
                        context, _current != widget.reservation),
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

  Widget _buildDialogHeader(RentalReservation r) {
    final cfg = _statusConfig(r.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.weekend_outlined,
                color: _kPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rental Reservation Details',
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
            onPressed: () => Navigator.pop(
                context, _current != widget.reservation),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
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

  Widget _buildStatusHistory(RentalReservation r) {
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

  Widget _buildActions(RentalReservation r) {
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
            if (r.isPending) ...[
              _actionButton(
                label: 'Approve',
                icon: Icons.check_circle_outline_rounded,
                color: Colors.blue.shade600,
                onTap: () => _confirmAction(
                  'Approve Reservation',
                  'Approve rental reservation ${r.reservationNumber}?',
                  () => widget.provider.approve(r.id),
                ),
              ),
              _actionButton(
                label: 'Reject',
                icon: Icons.cancel_outlined,
                color: Colors.orange.shade700,
                onTap: () => _confirmAction(
                  'Reject Reservation',
                  'Reject rental reservation ${r.reservationNumber}?',
                  () => widget.provider.reject(r.id),
                ),
              ),
            ],
            if (r.isPaid)
              _actionButton(
                label: 'Ready for Pickup',
                icon: Icons.local_shipping_outlined,
                color: Colors.indigo.shade600,
                onTap: () => _confirmAction(
                  'Mark Ready for Pickup',
                  'Mark ${r.reservationNumber} as ready for customer pickup?',
                  () => widget.provider.markReadyForPickup(r.id),
                ),
              ),
            if (r.isReadyForPickup)
              _actionButton(
                label: 'Mark Picked Up',
                icon: Icons.shopping_bag_outlined,
                color: Colors.teal.shade600,
                onTap: () => _confirmAction(
                  'Mark Picked Up',
                  'Confirm that the customer has picked up ${r.reservationNumber}?',
                  () => widget.provider.markPickedUp(r.id),
                ),
              ),
            if (r.isPickedUp)
              _actionButton(
                label: 'Mark Returned',
                icon: Icons.assignment_return_outlined,
                color: Colors.cyan.shade700,
                onTap: () => _handleMarkReturned(r),
              ),
            if (r.isReturned)
              _actionButton(
                label: 'Complete',
                icon: Icons.task_alt_rounded,
                color: Colors.green.shade600,
                onTap: () => _confirmAction(
                  'Complete Rental',
                  'Mark rental ${r.reservationNumber} as completed?',
                  () => widget.provider.complete(r.id),
                ),
              ),
            if (r.isPending || r.isApproved)
              _actionButton(
                label: 'Cancel',
                icon: Icons.block_outlined,
                color: Colors.red.shade600,
                onTap: () => _confirmAction(
                  'Cancel Reservation',
                  'Cancel rental reservation ${r.reservationNumber}?',
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
        return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Approved');
      case 3:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Rejected');
      case 4:
        return (Colors.amber.shade800, const Color(0xFFFFF8E1), 'Awaiting Payment');
      case 5:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Paid');
      case 6:
        return (Colors.indigo.shade700, const Color(0xFFE8EAF6), 'Ready for Pickup');
      case 7:
        return (Colors.teal.shade700, const Color(0xFFE0F2F1), 'Picked Up');
      case 8:
        return (Colors.cyan.shade800, const Color(0xFFE0F7FA), 'Returned');
      case 9:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Completed');
      case 11:
        return (Colors.purple.shade700, const Color(0xFFF3E5F5), 'Refunded');
      case 10:
      case 12:
      case 13:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Cancelled');
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
        return Colors.red.shade700;
      case 4:
        return Colors.amber.shade800;
      case 5:
        return Colors.green.shade700;
      case 6:
        return Colors.indigo.shade700;
      case 7:
        return Colors.teal.shade700;
      case 8:
        return Colors.cyan.shade800;
      case 9:
        return Colors.green.shade700;
      case 11:
        return Colors.purple.shade700;
      case 10:
      case 12:
      case 13:
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}

// ── Return Dialog ─────────────────────────────────────────────────────────

class _ReturnDialogResult {
  final double? lateFeeAmount;
  final double? damageFeeAmount;

  const _ReturnDialogResult({this.lateFeeAmount, this.damageFeeAmount});
}

class ReturnDialog extends StatefulWidget {
  const ReturnDialog({super.key});

  @override
  State<ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<ReturnDialog> {
  final _lateCtrl = TextEditingController();
  final _damageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _lateCtrl.dispose();
    _damageCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final late = _lateCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_lateCtrl.text.trim());
    final damage = _damageCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_damageCtrl.text.trim());

    Navigator.pop(
      context,
      _ReturnDialogResult(lateFeeAmount: late, damageFeeAmount: damage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _kPrimaryLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_return_outlined,
                        color: _kPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mark as Returned',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Form
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 340) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildFeeField(
                            controller: _lateCtrl,
                            label: 'Late Fee',
                            hint: '0.00',
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _buildFeeField(
                            controller: _damageCtrl,
                            label: 'Damage Fee',
                            hint: '0.00',
                          )),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildFeeField(
                          controller: _lateCtrl,
                          label: 'Late Fee',
                          hint: '0.00',
                        ),
                        const SizedBox(height: 16),
                        _buildFeeField(
                          controller: _damageCtrl,
                          label: 'Damage Fee',
                          hint: '0.00',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.assignment_return_outlined, size: 16),
                    label: const Text('Confirm Return'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: 'EUR',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPrimary),
        ),
        labelStyle:
            const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        helperText: 'Leave blank if none',
        helperStyle:
            TextStyle(fontSize: 11, color: Colors.grey.shade400),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final parsed = double.tryParse(v.trim());
        if (parsed == null || parsed < 0) return 'Enter a valid amount';
        return null;
      },
    );
  }
}
