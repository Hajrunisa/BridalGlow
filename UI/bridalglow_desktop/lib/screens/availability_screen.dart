import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/availability_slot.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/dress_availability_slot_provider.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late DressAvailabilitySlotProvider _slotProvider;
  late DressProvider _dressProvider;

  List<DressListItem> _dresses = [];
  int? _selectedDressId;
  // Match backend rental-availability horizon so staff see all slots that can
  // affect overlap validation, not only the next 30 days.
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now().add(const Duration(days: 365));
  int? _selectedSlotTypeFilter; // null = all
  SearchResult<AvailabilitySlot>? _result;
  bool _loading = false;

  static const List<Map<String, dynamic>> _slotTypeFilterOptions = [
    {'label': 'All Types', 'value': null},
    {'label': 'Available', 'value': 1},
    {'label': 'Blocked', 'value': 2},
    {'label': 'Try-On Hold', 'value': 3},
    {'label': 'Rental Hold', 'value': 4},
    {'label': 'Maintenance', 'value': 5},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _slotProvider = context.read<DressAvailabilitySlotProvider>();
      _dressProvider = context.read<DressProvider>();
      await _loadDresses();
    });
  }

  Future<void> _loadDresses() async {
    try {
      final result = await _dressProvider.get(filter: {
        'pageSize': 200,
        'page': 0,
        'includeTotalCount': false,
      });
      if (mounted) {
        setState(() => _dresses = result.items);
        if (_dresses.isNotEmpty && _selectedDressId == null) {
          _selectedDressId = _dresses.first.id;
          await _search();
        }
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    if (_selectedDressId == null) return;
    setState(() => _loading = true);
    try {
      final filter = <String, dynamic>{
        'dressId': _selectedDressId,
        'from': _fromDate.toUtc().toIso8601String(),
        'to': _toDate.toUtc().add(const Duration(hours: 23, minutes: 59)).toIso8601String(),
        'pageSize': 100,
        'page': 0,
        'includeTotalCount': true,
        if (_selectedSlotTypeFilter != null) 'slotType': _selectedSlotTypeFilter,
      };
      final result = await _slotProvider.get(filter: filter);
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
      initialDate: _fromDate,
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
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _toDate = picked);
      await _search();
    }
  }

  Future<void> _openAddSlotDialog({bool isBlock = false}) async {
    if (_selectedDressId == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AddSlotDialog(
        dressId: _selectedDressId!,
        slotProvider: _slotProvider,
        isBlock: isBlock,
      ),
    );
    if (saved == true) await _search();
  }

  Future<void> _confirmDelete(AvailabilitySlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.red, size: 22),
          SizedBox(width: 10),
          Text('Delete Slot', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Are you sure you want to delete this '
          '${slot.slotTypeLabel} slot?\n\n'
          '${DateFormat('dd.MM.yyyy HH:mm').format(slot.startAtUtc.toLocal())} – '
          '${DateFormat('HH:mm').format(slot.endAtUtc.toLocal())}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _slotProvider.deleteSlot(slot.id);
        if (mounted) {
          _showSnackBar('Slot deleted successfully.', Colors.green);
          await _search();
        }
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    ));
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          child: const Icon(Icons.calendar_month_outlined,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Availability',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              Text(
                'Manage dress availability slots and blocks',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _selectedDressId != null
              ? () => _openAddSlotDialog(isBlock: false)
              : null,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Available Slot'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _selectedDressId != null
              ? () => _openAddSlotDialog(isBlock: true)
              : null,
          icon: const Icon(Icons.block_rounded, size: 18),
          label: const Text('Add Block'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
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

  Widget _buildFilters() {
    final fmt = DateFormat('dd.MM.yyyy');
    return Row(
      children: [
        // Dress selector
        Expanded(
          flex: 3,
          child: _buildDropdown<int?>(
            value: _selectedDressId,
            hint: 'Select Dress',
            icon: Icons.checkroom_outlined,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Select Dress')),
              ..._dresses.map((d) => DropdownMenuItem<int?>(
                    value: d.id,
                    child: Text('${d.code} – ${d.name}',
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  )),
            ],
            onChanged: (v) async {
              setState(() => _selectedDressId = v);
              if (v != null) await _search();
            },
          ),
        ),
        const SizedBox(width: 10),
        // From date
        _dateButton(
          label: 'From: ${fmt.format(_fromDate)}',
          icon: Icons.calendar_today_outlined,
          onTap: _pickFromDate,
        ),
        const SizedBox(width: 10),
        // To date
        _dateButton(
          label: 'To: ${fmt.format(_toDate)}',
          icon: Icons.calendar_today_outlined,
          onTap: _pickToDate,
        ),
        const SizedBox(width: 10),
        // Slot type filter
        Expanded(
          flex: 2,
          child: _buildDropdown<int?>(
            value: _selectedSlotTypeFilter,
            hint: 'All Types',
            icon: Icons.filter_list_outlined,
            items: _slotTypeFilterOptions
                .map((o) => DropdownMenuItem<int?>(
                      value: o['value'],
                      child: Text(o['label'] as String),
                    ))
                .toList(),
            onChanged: (v) async {
              setState(() => _selectedSlotTypeFilter = v);
              await _search();
            },
          ),
        ),
        const SizedBox(width: 10),
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

  Widget _dateButton(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _kPrimary, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
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

  Widget _buildContent() {
    if (_dresses.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_selectedDressId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Select a dress to view its availability',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final slots = _result?.items ?? [];
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
          _buildTableTopBar(),
          Expanded(
            child: slots.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.5), // Date & Time
                        1: FlexColumnWidth(1.5), // Type
                        2: FlexColumnWidth(2.0), // Reason
                        3: FixedColumnWidth(80), // Duration
                        4: FixedColumnWidth(80), // Actions
                      },
                      children: [
                        _buildHeaderRow(),
                        ...slots.map(_buildDataRow),
                      ],
                    ),
                  ),
          ),
          if (_result != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '${_result!.totalCount ?? slots.length} slot(s) found',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _kPrimaryLight,
        borderRadius:
            BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, color: _kPrimary, size: 20),
          const SizedBox(width: 10),
          Text(
            _selectedDressId != null
                ? 'Slots for ${_dresses.firstWhere((d) => d.id == _selectedDressId, orElse: () => _dresses.first).name}'
                : 'Availability Slots',
            style: const TextStyle(
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
        _headerCell('Date & Time'),
        _headerCell('Type'),
        _headerCell('Reason / Notes'),
        _headerCell('Duration'),
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

  TableRow _buildDataRow(AvailabilitySlot slot) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final fmtTime = DateFormat('HH:mm');
    final duration = slot.endAtUtc.difference(slot.startAtUtc);
    final durationLabel = _formatDuration(duration);
    final local = slot.startAtUtc.toLocal();
    final localEnd = slot.endAtUtc.toLocal();

    return TableRow(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      children: [
        _dataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmt.format(local),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937))),
            Text('→ ${fmtTime.format(localEnd)}',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        )),
        _dataCell(_buildTypeBadge(slot.slotType)),
        _dataCell(Text(
          slot.reason?.isNotEmpty == true ? slot.reason! : '—',
          style: TextStyle(
              fontSize: 13,
              color: slot.reason?.isNotEmpty == true
                  ? const Color(0xFF374151)
                  : Colors.grey.shade400),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        )),
        _dataCell(Text(durationLabel,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)))),
        _dataCell(slot.isSystemManaged
            ? Tooltip(
                message: 'System-managed — cannot be deleted manually',
                child: Icon(Icons.lock_outline,
                    color: Colors.grey.shade400, size: 18),
              )
            : IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                tooltip: 'Delete slot',
                onPressed: () => _confirmDelete(slot),
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

  Widget _buildTypeBadge(int slotType) {
    final configs = {
      1: (_kPrimary, const Color(0xFFFFF0F3), 'Available'),
      2: (Colors.red.shade700, const Color(0xFFFFE4E4), 'Blocked'),
      3: (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Try-On Hold'),
      4: (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Rental Hold'),
      5: (Colors.grey.shade700, const Color(0xFFF5F5F5), 'Maintenance'),
    };
    final cfg = configs[slotType] ??
        (Colors.grey.shade600, const Color(0xFFF5F5F5), 'Unknown');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cfg.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(cfg.$3,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: cfg.$1)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No slots found for this period',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('Use the buttons above to add available slots or blocks.',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${d.inMinutes}m';
  }
}

// ── Add Slot Dialog ───────────────────────────────────────────────────────

class _AddSlotDialog extends StatefulWidget {
  final int dressId;
  final DressAvailabilitySlotProvider slotProvider;
  final bool isBlock;

  const _AddSlotDialog({
    required this.dressId,
    required this.slotProvider,
    required this.isBlock,
  });

  @override
  State<_AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends State<_AddSlotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _loading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime get _startDateTime => DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      ).toUtc();

  DateTime get _endDateTime => DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      ).toUtc();

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_endDateTime.isAfter(_startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('End time must be after start time.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.slotProvider.createSlot({
        'dressId': widget.dressId,
        'startAtUtc': _startDateTime.toIso8601String(),
        'endAtUtc': _endDateTime.toIso8601String(),
        'slotType': widget.isBlock ? 'Blocked' : 'Available',
        'reason': _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final isBlock = widget.isBlock;
    final accentColor = isBlock ? Colors.red.shade600 : Colors.green.shade600;
    final title = isBlock ? 'Add Manual Block' : 'Add Available Slot';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isBlock
                            ? Icons.block_rounded
                            : Icons.event_available_rounded,
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Start
                const Text('Start',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF374151))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeButton(
                        label: fmt.format(_startDate),
                        icon: Icons.calendar_today_outlined,
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTimeButton(
                        label: _startTime.format(context),
                        icon: Icons.access_time_outlined,
                        onTap: () => _pickTime(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // End
                const Text('End',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF374151))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeButton(
                        label: fmt.format(_endDate),
                        icon: Icons.calendar_today_outlined,
                        onTap: () => _pickDate(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTimeButton(
                        label: _endTime.format(context),
                        icon: Icons.access_time_outlined,
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Reason
                TextFormField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    labelText:
                        isBlock ? 'Reason for block (optional)' : 'Notes (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: accentColor, width: 1.5)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(isBlock ? 'Add Block' : 'Add Slot'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateTimeButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC2778A), size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }
}
