import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/dress_price_rule.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/dress_price_rule_provider.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class DressPriceRulesScreen extends StatefulWidget {
  const DressPriceRulesScreen({super.key});

  @override
  State<DressPriceRulesScreen> createState() => _DressPriceRulesScreenState();
}

class _DressPriceRulesScreenState extends State<DressPriceRulesScreen> {
  late DressPriceRuleProvider _ruleProvider;
  late DressProvider _dressProvider;

  List<DressListItem> _dresses = [];
  int? _selectedDressId;
  bool? _activeFilter; // null = all
  SearchResult<DressPriceRule>? _result;
  bool _loading = false;

  static const List<Map<String, dynamic>> _activeOptions = [
    {'label': 'All Rules', 'value': null},
    {'label': 'Active Only', 'value': true},
    {'label': 'Inactive Only', 'value': false},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _ruleProvider = context.read<DressPriceRuleProvider>();
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
        'pageSize': 100,
        'page': 0,
        'includeTotalCount': true,
        if (_activeFilter != null) 'isActive': _activeFilter,
      };
      final result = await _ruleProvider.get(filter: filter);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddDialog() async {
    if (_selectedDressId == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PriceRuleDialog(
        dressId: _selectedDressId!,
        ruleProvider: _ruleProvider,
      ),
    );
    if (saved == true) await _search();
  }

  Future<void> _openEditDialog(DressPriceRule rule) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PriceRuleDialog(
        dressId: rule.dressId,
        ruleProvider: _ruleProvider,
        existing: rule,
      ),
    );
    if (saved == true) await _search();
  }

  Future<void> _confirmDelete(DressPriceRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.red, size: 22),
          SizedBox(width: 10),
          Text('Delete Rule', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          'Are you sure you want to delete the ${rule.ruleTypeName} rule '
          'with priority ${rule.priority}?',
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
        await _ruleProvider.deleteRule(rule.id);
        if (mounted) {
          _showSnackBar('Rule deleted successfully.', Colors.green);
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
          child: const Icon(Icons.price_change_outlined,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pricing Rules',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              Text(
                'Manage dress pricing rules and discounts',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _selectedDressId != null ? _openAddDialog : null,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Rule'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
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
        Expanded(
          flex: 2,
          child: _buildDropdown<bool?>(
            value: _activeFilter,
            hint: 'All Rules',
            icon: Icons.filter_list_outlined,
            items: _activeOptions
                .map((o) => DropdownMenuItem<bool?>(
                      value: o['value'],
                      child: Text(o['label'] as String),
                    ))
                .toList(),
            onChanged: (v) async {
              setState(() => _activeFilter = v);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
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
          Text(hint, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
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
            Icon(Icons.checkroom_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Select a dress to view its pricing rules',
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

    final rules = _result?.items ?? [];
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
            child: rules.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.5), // Type
                        1: FlexColumnWidth(1.5), // Price
                        2: FlexColumnWidth(2.0), // Period
                        3: FixedColumnWidth(70), // Priority
                        4: FixedColumnWidth(80), // Status
                        5: FixedColumnWidth(100), // Actions
                      },
                      children: [
                        _buildHeaderRow(),
                        ...rules.map(_buildDataRow),
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
                    '${_result!.totalCount ?? rules.length} rule(s) found',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.price_change_outlined, color: _kPrimary, size: 20),
          const SizedBox(width: 10),
          Text(
            _selectedDressId != null
                ? 'Rules for ${_dresses.firstWhere((d) => d.id == _selectedDressId, orElse: () => _dresses.first).name}'
                : 'Pricing Rules',
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
        _headerCell('Type'),
        _headerCell('Price / Discount'),
        _headerCell('Valid Period'),
        _headerCell('Priority'),
        _headerCell('Status'),
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

  TableRow _buildDataRow(DressPriceRule rule) {
    final fmt = DateFormat('dd.MM.yyyy');

    return TableRow(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      children: [
        _dataCell(_buildTypeBadge(rule.ruleType)),
        _dataCell(_buildPriceCell(rule)),
        _dataCell(Text(
          rule.endDateUtc != null
              ? '${fmt.format(rule.startDateUtc.toLocal())} – ${fmt.format(rule.endDateUtc!.toLocal())}'
              : 'From ${fmt.format(rule.startDateUtc.toLocal())}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        )),
        _dataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6)),
          child: Text('#${rule.priority}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151))),
        )),
        _dataCell(_buildStatusBadge(rule.isActive)),
        _dataCell(Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: _kPrimary, size: 18),
              tooltip: 'Edit rule',
              onPressed: () => _openEditDialog(rule),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              tooltip: 'Delete rule',
              onPressed: () => _confirmDelete(rule),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        )),
      ],
    );
  }

  Widget _dataCell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: child,
      );

  Widget _buildPriceCell(DressPriceRule rule) {
    if (rule.percent != null) {
      return Text(
        '−${rule.percent!.toStringAsFixed(1)}%',
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.green),
      );
    }
    return Text(
      '${rule.amount.toStringAsFixed(2)} KM',
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937)),
    );
  }

  Widget _buildTypeBadge(int ruleType) {
    final configs = {
      1: (_kPrimary, _kPrimaryLight, 'Seasonal'),
      2: (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Weekend'),
      3: (Colors.green.shade700, const Color(0xFFE8F5E9), 'Promotion'),
      4: (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Custom'),
    };
    final cfg = configs[ruleType] ??
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

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.shade50
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.green.shade700 : Colors.grey.shade600),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.price_change_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No pricing rules found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('Use the button above to add a pricing rule.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// ── Add / Edit Dialog ─────────────────────────────────────────────────────────

class _PriceRuleDialog extends StatefulWidget {
  final int dressId;
  final DressPriceRuleProvider ruleProvider;
  final DressPriceRule? existing;

  const _PriceRuleDialog({
    required this.dressId,
    required this.ruleProvider,
    this.existing,
  });

  @override
  State<_PriceRuleDialog> createState() => _PriceRuleDialogState();
}

class _PriceRuleDialogState extends State<_PriceRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _percentController = TextEditingController();
  final _priorityController = TextEditingController();

  int _ruleType = 1;
  bool _usePercent = false;
  bool _isActive = true;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _ruleType = e.ruleType;
      _isActive = e.isActive;
      _startDate = e.startDateUtc.toLocal();
      _endDate = e.endDateUtc?.toLocal();
      _usePercent = e.percent != null;
      if (_usePercent) {
        _percentController.text = e.percent!.toStringAsFixed(2);
        _amountController.text = '0';
      } else {
        _amountController.text = e.amount.toStringAsFixed(2);
      }
      _priorityController.text = e.priority.toString();
    } else {
      _amountController.text = '0';
      _priorityController.text = '1';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _percentController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : (_endDate ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate != null && !_endDate!.isAfter(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('End date must be after start date.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final int priority = int.tryParse(_priorityController.text.trim()) ?? 1;
    final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final double? percent = _usePercent
        ? double.tryParse(_percentController.text.trim())
        : null;

    final request = <String, dynamic>{
      'ruleType': _getRuleTypeName(_ruleType),
      'amount': _usePercent ? 0.0 : amount,
      'percent': percent,
      'startDateUtc': _startDate.toUtc().toIso8601String(),
      'endDateUtc': _endDate?.toUtc().toIso8601String(),
      'priority': priority,
      'isActive': _isActive,
    };

    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await widget.ruleProvider.updateRule(widget.existing!.id, request);
      } else {
        request['dressId'] = widget.dressId;
        await widget.ruleProvider.createRule(request);
      }
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

  String _getRuleTypeName(int value) {
    return kPriceRuleTypeLabels[value] ?? 'Custom';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    final title = _isEdit ? 'Edit Pricing Rule' : 'Add Pricing Rule';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 540,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                          color: _kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.price_change_outlined,
                            color: _kPrimary, size: 22),
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

                  // Rule type
                  const Text('Rule Type',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<int>(
                      value: _ruleType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: kPriceRuleTypeLabels.entries
                          .map((e) => DropdownMenuItem<int>(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _ruleType = v!),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price: Amount or Percent toggle
                  Row(
                    children: [
                      const Text('Pricing Mode',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF374151))),
                      const Spacer(),
                      Text('Flat Amount',
                          style: TextStyle(
                              fontSize: 12,
                              color: !_usePercent
                                  ? _kPrimary
                                  : Colors.grey.shade500)),
                      Switch(
                        value: _usePercent,
                        activeThumbColor: _kPrimary,
                        onChanged: (v) => setState(() => _usePercent = v),
                      ),
                      Text('Percent Discount',
                          style: TextStyle(
                              fontSize: 12,
                              color: _usePercent
                                  ? _kPrimary
                                  : Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (!_usePercent)
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Flat Price (KM)',
                        suffixText: 'KM',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = double.tryParse(v.trim());
                        if (val == null || val < 0) return 'Enter a valid amount';
                        return null;
                      },
                    )
                  else
                    TextFormField(
                      controller: _percentController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Discount Percent (%)',
                        suffixText: '%',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0 || val > 100) {
                          return 'Enter a value between 0.01 and 100';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),

                  // Priority
                  TextFormField(
                    controller: _priorityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Priority (higher = applied first)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final val = int.tryParse(v.trim());
                      if (val == null || val < 1) return 'Priority must be at least 1';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date range
                  const Text('Valid Period',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: 'From: ${fmt.format(_startDate)}',
                          icon: Icons.calendar_today_outlined,
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _endDate != null
                            ? _DateButton(
                                label: 'To: ${fmt.format(_endDate!)}',
                                icon: Icons.calendar_today_outlined,
                                onTap: () => _pickDate(false),
                              )
                            : OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today_outlined,
                                    size: 16, color: _kPrimary),
                                label: const Text('Set End Date',
                                    style: TextStyle(color: _kPrimary)),
                                onPressed: () => _pickDate(false),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _kPrimary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                      ),
                      if (_endDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade500, size: 18),
                          tooltip: 'Remove end date',
                          onPressed: () => setState(() => _endDate = null),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Active toggle
                  Row(
                    children: [
                      const Text('Active',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF374151))),
                      const Spacer(),
                      Switch(
                        value: _isActive,
                        activeThumbColor: _kPrimary,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
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
                          backgroundColor: _kPrimary,
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
                            : Text(_isEdit ? 'Save Changes' : 'Add Rule'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.icon, required this.onTap});

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
            Icon(icon, color: _kPrimary, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }
}
