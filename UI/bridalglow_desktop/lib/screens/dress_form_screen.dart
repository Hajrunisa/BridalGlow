import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/dress_category.dart';
import 'package:bridalglow_desktop/models/dress_tag.dart';
import 'package:bridalglow_desktop/providers/dress_category_provider.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/providers/dress_tag_provider.dart';

const _kPrimary = Color(0xFFC2778A);

class DressFormScreen extends StatefulWidget {
  /// Pass a [DressDetail] to edit an existing dress; leave null to create new.
  final DressDetail? dress;

  const DressFormScreen({super.key, this.dress});

  @override
  State<DressFormScreen> createState() => _DressFormScreenState();
}

class _DressFormScreenState extends State<DressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool get _isEditing => widget.dress != null;

  // ── Text controllers ──────────────────────────────────────────────────────
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _materialCtrl;
  late final TextEditingController _silhouetteCtrl;
  late final TextEditingController _necklineCtrl;
  late final TextEditingController _sleeveTypeCtrl;
  late final TextEditingController _trainLengthCtrl;
  late final TextEditingController _sizeLabelCtrl;
  late final TextEditingController _bustCtrl;
  late final TextEditingController _waistCtrl;
  late final TextEditingController _hipCtrl;
  late final TextEditingController _lengthCtrl;
  late final TextEditingController _baseRentalPriceCtrl;
  late final TextEditingController _tryOnPriceCtrl;
  late final TextEditingController _depositAmountCtrl;
  late final TextEditingController _acquisitionCostCtrl;
  late final TextEditingController _replacementValueCtrl;

  // ── Enum / dropdown values ─────────────────────────────────────────────────
  int _selectedStatus = 1; // Draft
  int _selectedCondition = 1; // Excellent
  int? _selectedCategoryId;
  bool _isFeatured = false;
  Set<int> _selectedTagIds = {};

  // ── Loaded lookups ─────────────────────────────────────────────────────────
  List<DressCategory> _categories = [];
  List<DressTag> _allTags = [];
  bool _lookupLoading = true;

  static const List<Map<String, dynamic>> _statusOptions = [
    {'label': 'Draft', 'value': 1},
    {'label': 'Active', 'value': 2},
    {'label': 'Reserved', 'value': 3},
    {'label': 'Out of Service', 'value': 4},
    {'label': 'Archived', 'value': 5},
  ];

  static const List<Map<String, dynamic>> _conditionOptions = [
    {'label': 'Excellent', 'value': 1},
    {'label': 'Very Good', 'value': 2},
    {'label': 'Good', 'value': 3},
    {'label': 'Needs Repair', 'value': 4},
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.dress;
    _codeCtrl = TextEditingController(text: d?.code ?? '');
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _descCtrl = TextEditingController(text: d?.description ?? '');
    _brandCtrl = TextEditingController(text: d?.brand ?? '');
    _colorCtrl = TextEditingController(text: d?.color ?? '');
    _materialCtrl = TextEditingController(text: d?.material ?? '');
    _silhouetteCtrl = TextEditingController(text: d?.silhouette ?? '');
    _necklineCtrl = TextEditingController(text: d?.neckline ?? '');
    _sleeveTypeCtrl = TextEditingController(text: d?.sleeveType ?? '');
    _trainLengthCtrl = TextEditingController(text: d?.trainLength ?? '');
    _sizeLabelCtrl = TextEditingController(text: d?.sizeLabel ?? '');
    _bustCtrl = TextEditingController(
        text: d?.bustCm != null ? d!.bustCm!.toStringAsFixed(1) : '');
    _waistCtrl = TextEditingController(
        text: d?.waistCm != null ? d!.waistCm!.toStringAsFixed(1) : '');
    _hipCtrl = TextEditingController(
        text: d?.hipCm != null ? d!.hipCm!.toStringAsFixed(1) : '');
    _lengthCtrl = TextEditingController(
        text: d?.lengthCm != null ? d!.lengthCm!.toStringAsFixed(1) : '');
    _baseRentalPriceCtrl = TextEditingController(
        text: d != null ? d.baseRentalPrice.toStringAsFixed(2) : '');
    _tryOnPriceCtrl = TextEditingController(
        text: d?.tryOnPrice != null ? d!.tryOnPrice!.toStringAsFixed(2) : '');
    _depositAmountCtrl = TextEditingController(
        text: d?.depositAmount != null
            ? d!.depositAmount!.toStringAsFixed(2)
            : '');
    _acquisitionCostCtrl = TextEditingController(
        text: d?.acquisitionCost != null
            ? d!.acquisitionCost!.toStringAsFixed(2)
            : '');
    _replacementValueCtrl = TextEditingController(
        text: d?.replacementValue != null
            ? d!.replacementValue!.toStringAsFixed(2)
            : '');

    if (d != null) {
      _selectedStatus = d.status;
      _selectedCondition = d.condition;
      _selectedCategoryId = d.primaryCategoryId;
      _isFeatured = d.isFeatured;
      _selectedTagIds = d.tags.map((t) => t.id).toSet();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLookups());
  }

  @override
  void dispose() {
    for (final c in [
      _codeCtrl, _nameCtrl, _descCtrl, _brandCtrl, _colorCtrl,
      _materialCtrl, _silhouetteCtrl, _necklineCtrl, _sleeveTypeCtrl,
      _trainLengthCtrl, _sizeLabelCtrl, _bustCtrl, _waistCtrl, _hipCtrl,
      _lengthCtrl, _baseRentalPriceCtrl, _tryOnPriceCtrl, _depositAmountCtrl,
      _acquisitionCostCtrl, _replacementValueCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final catProvider = context.read<DressCategoryProvider>();
      final tagProvider = context.read<DressTagProvider>();
      final results = await Future.wait([
        catProvider.get(filter: {'page': 0, 'pageSize': 200, 'includeTotalCount': false}),
        tagProvider.get(filter: {'page': 0, 'pageSize': 500, 'includeTotalCount': false}),
      ]);
      if (mounted) {
        setState(() {
          _categories = results[0].items as List<DressCategory>;
          _allTags = results[1].items as List<DressTag>;
          // If editing and category was pre-set, keep it; ensure it's in list
          if (_selectedCategoryId == null && _categories.isNotEmpty) {
            _selectedCategoryId = _categories.first.id;
          }
          _lookupLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _lookupLoading = false);
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategoryId == null) {
      _showError('Please select a category.');
      return;
    }
    setState(() => _saving = true);

    final request = {
      'code': _codeCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      'color': _colorCtrl.text.trim(),
      'material': _materialCtrl.text.trim().isEmpty
          ? null
          : _materialCtrl.text.trim(),
      'silhouette': _silhouetteCtrl.text.trim().isEmpty
          ? null
          : _silhouetteCtrl.text.trim(),
      'neckline': _necklineCtrl.text.trim().isEmpty
          ? null
          : _necklineCtrl.text.trim(),
      'sleeveType': _sleeveTypeCtrl.text.trim().isEmpty
          ? null
          : _sleeveTypeCtrl.text.trim(),
      'trainLength': _trainLengthCtrl.text.trim().isEmpty
          ? null
          : _trainLengthCtrl.text.trim(),
      'sizeLabel': _sizeLabelCtrl.text.trim(),
      'bustCm': _bustCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_bustCtrl.text.trim()),
      'waistCm': _waistCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_waistCtrl.text.trim()),
      'hipCm': _hipCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_hipCtrl.text.trim()),
      'lengthCm': _lengthCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_lengthCtrl.text.trim()),
      'condition': _selectedCondition,
      'acquisitionCost': _acquisitionCostCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_acquisitionCostCtrl.text.trim()),
      'replacementValue': _replacementValueCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_replacementValueCtrl.text.trim()),
      'baseRentalPrice': double.tryParse(_baseRentalPriceCtrl.text.trim()) ?? 0,
      'tryOnPrice': _tryOnPriceCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_tryOnPriceCtrl.text.trim()),
      'depositAmount': _depositAmountCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_depositAmountCtrl.text.trim()),
      'status': _selectedStatus,
      'isFeatured': _isFeatured,
      'primaryCategoryId': _selectedCategoryId,
      'tagIds': _selectedTagIds.toList(),
    };

    try {
      final provider = context.read<DressProvider>();
      if (_isEditing) {
        await provider.update(widget.dress!.id, request);
      } else {
        await provider.insert(request);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 22),
            SizedBox(width: 10),
            Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kPrimary, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Dress' : 'Add Dress',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937)),
        ),
      ),
      body: _lookupLoading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 24),
                        _buildBasicInfoCard(),
                        const SizedBox(height: 20),
                        _buildDetailsCard(),
                        const SizedBox(height: 20),
                        _buildMeasurementsCard(),
                        const SizedBox(height: 20),
                        _buildPricingCard(),
                        const SizedBox(height: 20),
                        _buildClassificationCard(),
                        const SizedBox(height: 20),
                        _buildTagsCard(),
                        const SizedBox(height: 32),
                        _buildButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Header card ──────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kPrimary, Color(0xFFD4889A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Icon(
              _isEditing ? Icons.edit_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Dress' : 'New Dress',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditing
                      ? 'Update the dress information below.'
                      : 'Fill in the details to add a new dress to the catalogue.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Basic info ────────────────────────────────────────────────────────────

  Widget _buildBasicInfoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.info_outline, 'Basic Information'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: _codeCtrl,
                  label: 'Code *',
                  hint: 'e.g. DRS-001',
                  icon: Icons.qr_code_outlined,
                  maxLength: 50,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Code is required.';
                    if (v.trim().length > 50) return 'Max 50 characters.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _textField(
                  controller: _nameCtrl,
                  label: 'Name *',
                  hint: 'e.g. Bella Ivory Gown',
                  icon: Icons.checkroom_outlined,
                  maxLength: 200,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required.';
                    if (v.trim().length > 200) return 'Max 200 characters.';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: _colorCtrl,
                  label: 'Color *',
                  hint: 'e.g. Ivory, Champagne',
                  icon: Icons.palette_outlined,
                  maxLength: 50,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Color is required.';
                    if (v.trim().length > 50) return 'Max 50 characters.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _textField(
                  controller: _brandCtrl,
                  label: 'Brand',
                  hint: 'e.g. Maggie Sottero',
                  icon: Icons.store_outlined,
                  maxLength: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _textField(
            controller: _descCtrl,
            label: 'Description',
            hint: 'Detailed description of the dress...',
            icon: Icons.notes_outlined,
            maxLength: 2000,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  // ── Style details ─────────────────────────────────────────────────────────

  Widget _buildDetailsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.style_outlined, 'Style Details'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: _materialCtrl,
                  label: 'Material',
                  hint: 'e.g. Satin, Lace',
                  icon: Icons.texture_outlined,
                  maxLength: 100,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _textField(
                  controller: _silhouetteCtrl,
                  label: 'Silhouette',
                  hint: 'e.g. A-Line, Mermaid',
                  icon: Icons.view_in_ar_outlined,
                  maxLength: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: _necklineCtrl,
                  label: 'Neckline',
                  hint: 'e.g. Sweetheart, V-Neck',
                  icon: Icons.expand_outlined,
                  maxLength: 100,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _textField(
                  controller: _sleeveTypeCtrl,
                  label: 'Sleeve Type',
                  hint: 'e.g. Sleeveless, Long',
                  icon: Icons.straighten_outlined,
                  maxLength: 100,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _textField(
                  controller: _trainLengthCtrl,
                  label: 'Train Length',
                  hint: 'e.g. Chapel, Cathedral',
                  icon: Icons.space_bar_outlined,
                  maxLength: 100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Measurements ──────────────────────────────────────────────────────────

  Widget _buildMeasurementsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.straighten_outlined, 'Measurements'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _textField(
                  controller: _sizeLabelCtrl,
                  label: 'Size Label *',
                  hint: 'e.g. EU 36, S, M, L',
                  icon: Icons.format_size_outlined,
                  maxLength: 20,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Size label is required.';
                    if (v.trim().length > 20) return 'Max 20 characters.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _numberField(
                  controller: _bustCtrl,
                  label: 'Bust (cm)',
                  hint: '80–120',
                  icon: Icons.open_with_outlined,
                  validator: (v) => _validateOptionalRange(v, 0, 500, 'Bust'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _numberField(
                  controller: _waistCtrl,
                  label: 'Waist (cm)',
                  hint: '60–100',
                  icon: Icons.open_with_outlined,
                  validator: (v) => _validateOptionalRange(v, 0, 500, 'Waist'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _numberField(
                  controller: _hipCtrl,
                  label: 'Hip (cm)',
                  hint: '80–130',
                  icon: Icons.open_with_outlined,
                  validator: (v) => _validateOptionalRange(v, 0, 500, 'Hip'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _numberField(
                  controller: _lengthCtrl,
                  label: 'Length (cm)',
                  hint: '100–200',
                  icon: Icons.height_outlined,
                  validator: (v) => _validateOptionalRange(v, 0, 300, 'Length'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pricing ───────────────────────────────────────────────────────────────

  Widget _buildPricingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.attach_money_outlined, 'Pricing'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: _baseRentalPriceCtrl,
                  label: 'Base Rental Price (BAM) *',
                  hint: '0.00',
                  icon: Icons.price_check_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Rental price is required.';
                    }
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be greater than 0.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _numberField(
                  controller: _tryOnPriceCtrl,
                  label: 'Try-On Price (BAM)',
                  hint: '0.00',
                  icon: Icons.local_offer_outlined,
                  validator: (v) => _validateOptionalPositive(v, 'Try-on price'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _numberField(
                  controller: _depositAmountCtrl,
                  label: 'Deposit (BAM)',
                  hint: '0.00',
                  icon: Icons.account_balance_wallet_outlined,
                  validator: (v) => _validateOptionalPositive(v, 'Deposit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: _acquisitionCostCtrl,
                  label: 'Acquisition Cost (BAM)',
                  hint: '0.00',
                  icon: Icons.shopping_cart_outlined,
                  validator: (v) => _validateOptionalPositive(v, 'Acquisition cost'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _numberField(
                  controller: _replacementValueCtrl,
                  label: 'Replacement Value (BAM)',
                  hint: '0.00',
                  icon: Icons.replay_outlined,
                  validator: (v) => _validateOptionalPositive(v, 'Replacement value'),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  // ── Classification ────────────────────────────────────────────────────────

  Widget _buildClassificationCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.tune_outlined, 'Classification'),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<int>(
                        value: _selectedCategoryId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: Row(children: [
                          Icon(Icons.category_outlined,
                              color: _kPrimary, size: 18),
                          const SizedBox(width: 8),
                          const Text('Select Category',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 14)),
                        ]),
                        items: _categories
                            .map((c) => DropdownMenuItem<int>(
                                  value: c.id,
                                  child: Text(c.name,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategoryId = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Status dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<int>(
                        value: _selectedStatus,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _statusOptions
                            .map((s) => DropdownMenuItem<int>(
                                  value: s['value'] as int,
                                  child: Text(s['label'] as String),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedStatus = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Condition dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Condition *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<int>(
                        value: _selectedCondition,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _conditionOptions
                            .map((c) => DropdownMenuItem<int>(
                                  value: c['value'] as int,
                                  child: Text(c['label'] as String),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCondition = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // IsFeatured checkbox
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Featured',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() => _isFeatured = !_isFeatured),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: _isFeatured
                            ? Colors.amber.withValues(alpha: 0.08)
                            : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _isFeatured
                                ? Colors.amber.withValues(alpha: 0.4)
                                : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _isFeatured,
                            onChanged: (v) =>
                                setState(() => _isFeatured = v ?? false),
                            activeColor: Colors.amber.shade700,
                          ),
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          const Text('Featured',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF374151))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tags ─────────────────────────────────────────────────────────────────

  Widget _buildTagsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionLabel(Icons.sell_outlined, 'Tags'),
              const Spacer(),
              TextButton.icon(
                onPressed: _openTagSelector,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Select Tags'),
                style: TextButton.styleFrom(foregroundColor: _kPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _selectedTagIds.isEmpty
              ? Text('No tags selected.',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade500))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allTags
                      .where((t) => _selectedTagIds.contains(t.id))
                      .map((t) => Chip(
                            label: Text(t.name,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor:
                                _kPrimary.withValues(alpha: 0.1),
                            deleteIconColor: _kPrimary,
                            side: BorderSide(
                                color: _kPrimary.withValues(alpha: 0.3)),
                            onDeleted: () =>
                                setState(() => _selectedTagIds.remove(t.id)),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  void _openTagSelector() async {
    final tempSelection = Set<int>.from(_selectedTagIds);

    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _TagSelectorDialog(
        allTags: _allTags,
        selected: tempSelection,
      ),
    );
    if (result != null) setState(() => _selectedTagIds = result);
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.grey.shade800,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: const Text('Cancel',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _saving ? Colors.grey.shade300 : _kPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(
                  _isEditing ? 'Save Changes' : 'Create Dress',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _kPrimary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937))),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _kPrimary, size: 20),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      counterStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration:
          _inputDecoration(label: label, hint: hint, icon: icon),
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration:
          _inputDecoration(label: label, hint: hint, icon: icon),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      validator: validator,
    );
  }

  // ── Validators ────────────────────────────────────────────────────────────

  String? _validateOptionalRange(
      String? v, double min, double max, String field) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.trim());
    if (n == null) return '$field must be a number.';
    if (n < min || n > max) return '$field must be $min–$max.';
    return null;
  }

  String? _validateOptionalPositive(String? v, String field) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.trim());
    if (n == null) return '$field must be a number.';
    if (n < 0) return '$field must be ≥ 0.';
    return null;
  }
}

// ── Tag selector dialog ───────────────────────────────────────────────────

class _TagSelectorDialog extends StatefulWidget {
  final List<DressTag> allTags;
  final Set<int> selected;

  const _TagSelectorDialog({required this.allTags, required this.selected});

  @override
  State<_TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<_TagSelectorDialog> {
  late Set<int> _selection;

  @override
  void initState() {
    super.initState();
    _selection = Set.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.sell_outlined, color: _kPrimary, size: 22),
          SizedBox(width: 10),
          Text('Select Tags',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            children: widget.allTags
                .map((tag) => CheckboxListTile(
                      title: Text(tag.name),
                      value: _selection.contains(tag.id),
                      activeColor: _kPrimary,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selection.add(tag.id);
                          } else {
                            _selection.remove(tag.id);
                          }
                        });
                      },
                    ))
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selection),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
