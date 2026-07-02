import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/ledger_report.dart';
import 'package:bridalglow_desktop/models/payment.dart';
import 'package:bridalglow_desktop/models/refund.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/finance_provider.dart';
import 'package:bridalglow_desktop/providers/notification_refresh_coordinator.dart';
import 'package:bridalglow_desktop/providers/payment_provider.dart';
import 'package:bridalglow_desktop/providers/refund_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const SizedBox(height: 16),
            const Expanded(
              child: TabBarView(
                children: [
                  FinancePaymentsTab(),
                  FinanceRefundsTab(),
                  FinanceLedgerTab(),
                ],
              ),
            ),
          ],
        ),
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
          child: const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finance',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              Text(
                'Payments, refunds and financial ledger overview',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
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
      child: const TabBar(
        labelColor: _kPrimary,
        unselectedLabelColor: Color(0xFF6B7280),
        indicatorColor: _kPrimary,
        indicatorWeight: 3,
        tabs: [
          Tab(
            icon: Icon(Icons.payments_outlined, size: 20),
            text: 'Payments',
          ),
          Tab(
            icon: Icon(Icons.replay_outlined, size: 20),
            text: 'Refunds',
          ),
          Tab(
            icon: Icon(Icons.receipt_long_outlined, size: 20),
            text: 'Ledger',
          ),
        ],
      ),
    );
  }
}

// ── Payments Tab ──────────────────────────────────────────────────────────

class FinancePaymentsTab extends StatefulWidget {
  const FinancePaymentsTab({super.key});

  @override
  State<FinancePaymentsTab> createState() => _FinancePaymentsTabState();
}

class _FinancePaymentsTabState extends State<FinancePaymentsTab> {
  late PaymentProvider _provider;
  int? _selectedStatusFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  SearchResult<Payment>? _result;
  bool _loading = false;
  NotificationRefreshCoordinator? _refreshCoordinator;

  static const _statusFilters = [
    {'label': 'All Statuses', 'value': null},
    {'label': 'Created', 'value': 1},
    {'label': 'Processing', 'value': 3},
    {'label': 'Succeeded', 'value': 4},
    {'label': 'Failed', 'value': 5},
    {'label': 'Cancelled', 'value': 6},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<PaymentProvider>();
      _refreshCoordinator = context.read<NotificationRefreshCoordinator>();
      _refreshCoordinator!.addListener(_onRealtimeRefresh);
      _search();
    });
  }

  @override
  void dispose() {
    _refreshCoordinator?.removeListener(_onRealtimeRefresh);
    super.dispose();
  }

  void _onRealtimeRefresh() {
    final entityType = _refreshCoordinator?.lastRelatedEntityType;
    if (NotificationRefreshCoordinator.affectsFinance(entityType)) {
      _search();
    }
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final filter = <String, dynamic>{
        'pageSize': 100,
        'page': 0,
        'includeTotalCount': true,
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
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final payments = _result?.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPaymentFilters(fmt),
        const SizedBox(height: 16),
        Expanded(
          child: _FinanceTableCard(
            title: 'Payment List',
            icon: Icons.payments_outlined,
            loading: _loading,
            emptyMessage: 'No payments found',
            footer: _result != null
                ? '${_result!.totalCount ?? payments.length} payment(s) found'
                : null,
            child: payments.isEmpty && !_loading
                ? null
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 900),
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(70),
                          1: FixedColumnWidth(140),
                          2: FixedColumnWidth(160),
                          3: FixedColumnWidth(120),
                          4: FixedColumnWidth(100),
                          5: FixedColumnWidth(140),
                          6: FixedColumnWidth(130),
                        },
                        children: [
                          _tableHeaderRow([
                            'ID',
                            'Reservation',
                            'Customer',
                            'Amount',
                            'Status',
                            'Paid At',
                            'Created',
                          ]),
                          ...payments.map((p) => TableRow(
                                decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey.shade100))),
                                children: [
                                  _cell(p.id.toString()),
                                  _cell(p.reservationNumber ?? '—'),
                                  _cellColumn(
                                      p.customerName, p.customerEmail),
                                  _cell(
                                      '${p.amount.toStringAsFixed(2)} ${p.currency}'),
                                  _cellWidget(_paymentStatusBadge(p.status)),
                                  _cell(p.paidAtUtc != null
                                      ? fmt.format(p.paidAtUtc!.toLocal())
                                      : '—'),
                                  _cell(fmt.format(p.createdAtUtc.toLocal())),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentFilters(DateFormat fmt) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _filterDropdown<int?>(
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
          label: _fromDate != null
              ? 'From: ${fmt.format(_fromDate!)}'
              : 'From Date',
          onTap: _pickFromDate,
        ),
        const SizedBox(width: 10),
        _dateButton(
          label:
              _toDate != null ? 'To: ${fmt.format(_toDate!)}' : 'To Date',
          onTap: _pickToDate,
        ),
        if (_fromDate != null || _toDate != null) ...[
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: () async {
              setState(() {
                _fromDate = null;
                _toDate = null;
              });
              await _search();
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
          ),
        ],
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _search,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
          style: _refreshButtonStyle(),
        ),
      ],
    );
  }
}

// ── Refunds Tab ───────────────────────────────────────────────────────────

class FinanceRefundsTab extends StatefulWidget {
  const FinanceRefundsTab({super.key});

  @override
  State<FinanceRefundsTab> createState() => _FinanceRefundsTabState();
}

class _FinanceRefundsTabState extends State<FinanceRefundsTab> {
  late RefundProvider _provider;
  int? _selectedStatusFilter;
  SearchResult<Refund>? _result;
  bool _loading = false;
  int? _actionId;
  NotificationRefreshCoordinator? _refreshCoordinator;

  static const _statusFilters = [
    {'label': 'All Statuses', 'value': null},
    {'label': 'Requested', 'value': 1},
    {'label': 'Approved', 'value': 2},
    {'label': 'Processing', 'value': 3},
    {'label': 'Succeeded', 'value': 4},
    {'label': 'Rejected', 'value': 5},
    {'label': 'Failed', 'value': 6},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<RefundProvider>();
      _refreshCoordinator = context.read<NotificationRefreshCoordinator>();
      _refreshCoordinator!.addListener(_onRealtimeRefresh);
      _search();
    });
  }

  @override
  void dispose() {
    _refreshCoordinator?.removeListener(_onRealtimeRefresh);
    super.dispose();
  }

  void _onRealtimeRefresh() {
    final entityType = _refreshCoordinator?.lastRelatedEntityType;
    if (NotificationRefreshCoordinator.affectsFinance(entityType)) {
      _search();
    }
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final filter = <String, dynamic>{
        'pageSize': 100,
        'page': 0,
        'includeTotalCount': true,
        if (_selectedStatusFilter != null) 'status': _selectedStatusFilter,
      };
      final result = await _provider.get(filter: filter);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Refund r) async {
    final ok = await _confirm('Approve Refund',
        'Approve refund #${r.id} for ${r.amount.toStringAsFixed(2)} ${r.currency}?');
    if (!ok) return;
    setState(() => _actionId = r.id);
    try {
      await _provider.approve(r.id);
      await _search();
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  Future<void> _reject(Refund r) async {
    final reason = await _promptReason('Reject Refund');
    if (reason == null) return;
    setState(() => _actionId = r.id);
    try {
      await _provider.reject(r.id, reason: reason.isEmpty ? null : reason);
      await _search();
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  Future<void> _process(Refund r) async {
    final ok = await _confirm('Process Refund',
        'Execute Stripe refund for #${r.id} (${r.amount.toStringAsFixed(2)} ${r.currency})?');
    if (!ok) return;
    setState(() => _actionId = r.id);
    try {
      await _provider.process(r.id);
      await _search();
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _promptReason(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final refunds = _result?.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _filterDropdown<int?>(
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
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: _refreshButtonStyle(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _FinanceTableCard(
            title: 'Refund Requests',
            icon: Icons.replay_outlined,
            loading: _loading,
            emptyMessage: 'No refund requests found',
            footer: _result != null
                ? '${_result!.totalCount ?? refunds.length} refund(s) found'
                : null,
            child: refunds.isEmpty && !_loading
                ? null
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1050),
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(60),
                          1: FixedColumnWidth(80),
                          2: FixedColumnWidth(100),
                          3: FixedColumnWidth(110),
                          4: FixedColumnWidth(120),
                          5: FixedColumnWidth(140),
                          6: FixedColumnWidth(220),
                        },
                        children: [
                          _tableHeaderRow([
                            'ID',
                            'Payment',
                            'Amount',
                            'Status',
                            'Reason',
                            'Requested',
                            'Actions',
                          ]),
                          ...refunds.map((r) {
                            final busy = _actionId == r.id;
                            return TableRow(
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey.shade100))),
                              children: [
                                _cell(r.id.toString()),
                                _cell('#${r.paymentId}'),
                                _cell(
                                    '${r.amount.toStringAsFixed(2)} ${r.currency}'),
                                _cellWidget(_refundStatusBadge(r.status)),
                                _cellColumn(r.reasonCodeLabel, r.reasonText),
                                _cell(fmt.format(r.requestedAtUtc.toLocal())),
                                _cellWidget(_refundActions(r, busy)),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _refundActions(Refund r, bool busy) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (r.status == 1)
          _smallAction(
            label: 'Approve',
            color: Colors.green.shade700,
            icon: Icons.check_rounded,
            busy: busy,
            onTap: () => _approve(r),
          ),
        if (r.status == 1)
          _smallAction(
            label: 'Reject',
            color: Colors.red.shade700,
            icon: Icons.close_rounded,
            busy: busy,
            onTap: () => _reject(r),
          ),
        if (r.status == 2)
          _smallAction(
            label: 'Process',
            color: Colors.indigo.shade700,
            icon: Icons.play_arrow_rounded,
            busy: busy,
            onTap: () => _process(r),
          ),
        if (r.status != 1 && r.status != 2)
          Text(
            r.failureReason ?? '—',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
      ],
    );
  }
}

// ── Ledger Tab ────────────────────────────────────────────────────────────

class FinanceLedgerTab extends StatefulWidget {
  const FinanceLedgerTab({super.key});

  @override
  State<FinanceLedgerTab> createState() => _FinanceLedgerTabState();
}

class _FinanceLedgerTabState extends State<FinanceLedgerTab> {
  late FinanceProvider _provider;
  DateTime? _fromDate;
  DateTime? _toDate;
  LedgerReport? _report;
  bool _loading = false;
  NotificationRefreshCoordinator? _refreshCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<FinanceProvider>();
      _refreshCoordinator = context.read<NotificationRefreshCoordinator>();
      _refreshCoordinator!.addListener(_onRealtimeRefresh);
      _load();
    });
  }

  @override
  void dispose() {
    _refreshCoordinator?.removeListener(_onRealtimeRefresh);
    super.dispose();
  }

  void _onRealtimeRefresh() {
    final entityType = _refreshCoordinator?.lastRelatedEntityType;
    if (NotificationRefreshCoordinator.affectsFinance(entityType)) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final report = await _provider.getLedger(
        from: _fromDate,
        to: _toDate?.add(const Duration(hours: 23, minutes: 59)),
      );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
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
      await _load();
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
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final dateFmt = DateFormat('dd.MM.yyyy');
    final summary = _report?.summary;
    final entries = _report?.entries ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _dateButton(
              label: _fromDate != null
                  ? 'From: ${dateFmt.format(_fromDate!)}'
                  : 'From Date',
              onTap: _pickFromDate,
            ),
            const SizedBox(width: 10),
            _dateButton(
              label: _toDate != null
                  ? 'To: ${dateFmt.format(_toDate!)}'
                  : 'To Date',
              onTap: _pickToDate,
            ),
            if (_fromDate != null || _toDate != null) ...[
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: () async {
                  setState(() {
                    _fromDate = null;
                    _toDate = null;
                  });
                  await _load();
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
              ),
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: _refreshButtonStyle(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (summary != null) _buildSummaryCards(summary),
        const SizedBox(height: 16),
        Expanded(
          child: _FinanceTableCard(
            title: 'Ledger Entries',
            icon: Icons.receipt_long_outlined,
            loading: _loading,
            emptyMessage: 'No ledger entries for selected period',
            footer: '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
            child: entries.isEmpty && !_loading
                ? null
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 950),
                      child: Table(
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
                          _tableHeaderRow([
                            'Date',
                            'Type',
                            'Direction',
                            'Amount',
                            'Reservation',
                            'Customer',
                            'Reference',
                          ]),
                          ...entries.map((e) => TableRow(
                                decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Colors.grey.shade100))),
                                children: [
                                  _cell(fmt.format(e.occurredAtUtc.toLocal())),
                                  _cell(e.entryTypeLabel),
                                  _cellWidget(_directionBadge(e)),
                                  _cell(
                                    '${e.isDebit ? '−' : '+'}${e.amount.toStringAsFixed(2)} ${e.currency}',
                                    color: e.isDebit
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                  _cell(e.reservationNumber ?? '—'),
                                  _cell(e.customerName ?? '—'),
                                  _cell(e.externalReference ?? '—'),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(LedgerPeriodSummary summary) {
    return Row(
      children: [
        _summaryCard(
          label: 'Total Received',
          value:
              '${summary.totalReceivedAmount.toStringAsFixed(2)} ${summary.currency}',
          icon: Icons.trending_up_rounded,
          color: Colors.green.shade700,
        ),
        const SizedBox(width: 12),
        _summaryCard(
          label: 'Capture Count',
          value: summary.transactionCount.toString(),
          icon: Icons.receipt_outlined,
          color: Colors.blue.shade700,
        ),
        const SizedBox(width: 12),
        _summaryCard(
          label: 'Currency',
          value: summary.currency,
          icon: Icons.euro_rounded,
          color: _kPrimary,
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────

class _FinanceTableCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool loading;
  final String emptyMessage;
  final String? footer;
  final Widget? child;

  const _FinanceTableCard({
    required this.title,
    required this.icon,
    required this.loading,
    required this.emptyMessage,
    this.footer,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: _kPrimary, size: 20),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: _kPrimary))
                : child == null
                    ? Center(
                        child: Text(emptyMessage,
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : child!,
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(footer!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }
}

TableRow _tableHeaderRow(List<String> headers) {
  return TableRow(
    decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
    children: headers
        .map((h) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(h,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5)),
            ))
        .toList(),
  );
}

Widget _cell(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text,
          style: TextStyle(fontSize: 13, color: color ?? const Color(0xFF1F2937))),
    );

Widget _cellWidget(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: child,
    );

Widget _cellColumn(String primary, String? secondary) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(primary,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          if (secondary != null && secondary.isNotEmpty)
            Text(secondary,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );

Widget _filterDropdown<T>({
  required T value,
  required String hint,
  required IconData icon,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return InputDecorator(
    decoration: InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        hint: Text(hint),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

Widget _dateButton({required String label, required VoidCallback onTap}) {
  return OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today_outlined, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 13)),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

ButtonStyle _refreshButtonStyle() => ElevatedButton.styleFrom(
      backgroundColor: Colors.grey.shade800,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
    );

Widget _paymentStatusBadge(int status) {
  final (color, bg, label) = _paymentStatusConfig(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

(Color, Color, String) _paymentStatusConfig(int status) {
  switch (status) {
    case 4:
      return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Succeeded');
    case 5:
      return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Failed');
    case 3:
      return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Processing');
    case 6:
      return (Colors.grey.shade700, const Color(0xFFF5F5F5), 'Cancelled');
    default:
      return (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Created');
  }
}

Widget _refundStatusBadge(int status) {
  final (color, bg, label) = _refundStatusConfig(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

(Color, Color, String) _refundStatusConfig(int status) {
  switch (status) {
    case 1:
      return (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Requested');
    case 2:
      return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Approved');
    case 3:
      return (Colors.indigo.shade700, const Color(0xFFE8EAF6), 'Processing');
    case 4:
      return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Succeeded');
    case 5:
      return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Rejected');
    case 6:
      return (Colors.red.shade800, const Color(0xFFFFEBEE), 'Failed');
    default:
      return (Colors.grey.shade600, const Color(0xFFF5F5F5), 'Unknown');
  }
}

Widget _directionBadge(TransactionLedgerEntry entry) {
  final isCredit = entry.isCredit;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(entry.directionLabel,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isCredit ? Colors.green.shade700 : Colors.red.shade700)),
  );
}

Widget _smallAction({
  required String label,
  required Color color,
  required IconData icon,
  required bool busy,
  required VoidCallback onTap,
}) {
  return ElevatedButton.icon(
    onPressed: busy ? null : onTap,
    icon: busy
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white.withValues(alpha: 0.8)),
          )
        : Icon(icon, size: 14),
    label: Text(label, style: const TextStyle(fontSize: 11)),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      elevation: 0,
    ),
  );
}
