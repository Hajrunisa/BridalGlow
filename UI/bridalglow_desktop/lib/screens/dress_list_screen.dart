import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/dress_category.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';
import 'package:bridalglow_desktop/providers/dress_category_provider.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/screens/dress_detail_screen.dart';
import 'package:bridalglow_desktop/screens/dress_form_screen.dart';

/// Converts a relative path like "/uploads/…" to a full URL.
/// Absolute URLs (http/https) are returned unchanged.
String _resolveImageUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${BaseProvider.serverOrigin}$url';
}

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class DressListScreen extends StatefulWidget {
  const DressListScreen({super.key});

  @override
  State<DressListScreen> createState() => _DressListScreenState();
}

class _DressListScreenState extends State<DressListScreen> {
  late DressProvider _provider;
  late DressCategoryProvider _categoryProvider;

  final _nameController = TextEditingController();

  SearchResult<DressListItem>? _result;
  List<DressCategory> _categories = [];
  int? _selectedCategoryId;
  int? _selectedStatus;
  int _currentPage = 0;
  int _pageSize = 10;
  bool _loading = false;

  static const List<int> _pageSizeOptions = [5, 10, 20, 50];

  static const List<Map<String, dynamic>> _statusOptions = [
    {'label': 'All Statuses', 'value': null},
    {'label': 'Draft', 'value': 1},
    {'label': 'Active', 'value': 2},
    {'label': 'Reserved', 'value': 3},
    {'label': 'Out of Service', 'value': 4},
    {'label': 'Archived', 'value': 5},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _provider = context.read<DressProvider>();
      _categoryProvider = context.read<DressCategoryProvider>();
      await Future.wait([
        _loadCategories(),
        _performSearch(page: 0),
      ]);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _categoryProvider.get(filter: {
        'page': 0,
        'pageSize': 200,
        'includeTotalCount': false,
      });
      if (mounted) setState(() => _categories = result.items);
    } catch (_) {}
  }

  Future<void> _performSearch({int? page, int? pageSize}) async {
    final pageToFetch = page ?? _currentPage;
    final sizeToUse = pageSize ?? _pageSize;
    setState(() => _loading = true);
    try {
      final filter = <String, dynamic>{
        if (_nameController.text.trim().isNotEmpty)
          'name': _nameController.text.trim(),
        if (_selectedCategoryId != null) 'categoryId': _selectedCategoryId,
        if (_selectedStatus != null) 'status': _selectedStatus,
        'page': pageToFetch,
        'pageSize': sizeToUse,
        'includeTotalCount': true,
      };
      final result = await _provider.get(filter: filter);
      if (mounted) {
        setState(() {
          _result = result;
          _currentPage = pageToFetch;
          _pageSize = sizeToUse;
        });
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({DressListItem? item}) async {
    DressDetail? detail;
    if (item != null) {
      try {
        detail = await _provider.getDressById(item.id);
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
        return;
      }
    }
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DressFormScreen(dress: detail),
      ),
    );
    if (saved == true) await _performSearch();
  }

  Future<void> _openDetail(DressListItem item) async {
    final refreshNeeded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DressDetailScreen(dressId: item.id),
      ),
    );
    if (refreshNeeded == true) await _performSearch();
  }

  Future<void> _confirmArchive(DressListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.archive_outlined,
                  color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Archive Dress',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
            children: [
              const TextSpan(text: 'Are you sure you want to archive '),
              TextSpan(
                text: '"${item.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '?\n\nThe dress will be marked as Archived and '
                    'will not appear in active listings. '
                    'This action cannot be undone if there are active reservations.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _provider.archiveDress(item.id);
        if (mounted) {
          _showSnackBar('Dress "${item.name}" archived.', Colors.orange);
          await _performSearch();
        }
      } catch (e) {
        if (mounted) {
          _showError(e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
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
          child:
              const Icon(Icons.checkroom_outlined, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dresses',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                'Manage wedding dress catalogue',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Dress'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        // Name search
        Expanded(
          flex: 3,
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Search by name...',
              prefixIcon: const Icon(Icons.search, color: _kPrimary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _performSearch(page: 0),
          ),
        ),
        const SizedBox(width: 10),
        // Category filter
        Expanded(
          flex: 2,
          child: _buildDropdown<int?>(
            value: _selectedCategoryId,
            hint: 'All Categories',
            icon: Icons.category_outlined,
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('All Categories')),
              ..._categories.map((c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(c.name,
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                  )),
            ],
            onChanged: (v) {
              setState(() => _selectedCategoryId = v);
              _performSearch(page: 0);
            },
          ),
        ),
        const SizedBox(width: 10),
        // Status filter
        Expanded(
          flex: 2,
          child: _buildDropdown<int?>(
            value: _selectedStatus,
            hint: 'All Statuses',
            icon: Icons.filter_list_outlined,
            items: _statusOptions
                .map((s) => DropdownMenuItem<int?>(
                      value: s['value'],
                      child: Text(s['label'] as String),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedStatus = v);
              _performSearch(page: 0);
            },
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _performSearch(page: 0),
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('Search'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    final items = _result?.items ?? [];
    final totalCount = _result?.totalCount ?? 0;
    final totalPages = _pageSize > 0 ? (totalCount / _pageSize).ceil() : 0;

    return Column(
      children: [
        Expanded(child: _buildTable(items)),
        const SizedBox(height: 16),
        _buildPagination(totalPages),
      ],
    );
  }

  Widget _buildTable(List<DressListItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableTopBar(),
          Expanded(
            child: items.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(64),    // thumbnail
                        1: FlexColumnWidth(2.2),    // name/code
                        2: FlexColumnWidth(1.5),    // category
                        3: FixedColumnWidth(70),    // size
                        4: FlexColumnWidth(1.2),    // price
                        5: FlexColumnWidth(1.4),    // status
                        6: FlexColumnWidth(1.2),    // rating (flex – avoids fixed-width overflow)
                        7: FixedColumnWidth(52),    // featured (icon only)
                        8: FixedColumnWidth(114),   // actions (3 × 28 px + 2 × 4 px gaps + 20 px padding)
                      },
                      children: [
                        _buildHeaderRow(),
                        ...items.map(_buildDataRow),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _kPrimaryLight,
        borderRadius:
            const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.checkroom_outlined, color: _kPrimary, size: 20),
          const SizedBox(width: 10),
          const Text('Dress Catalogue',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1F2937))),
          const Spacer(),
          if (_result != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_result!.totalCount ?? _result!.items.length} total',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kPrimary),
              ),
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
        _headerCell(''),
        _headerCell('Name / Code'),
        _headerCell('Category'),
        _headerCell('Size'),
        _headerCell('Price'),
        _headerCell('Status'),
        _headerCell('Rating'),
        _headerCell('Featured'),
        _headerCell('Actions'),
      ],
    );
  }

  Widget _headerCell(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFF6B7280),
              letterSpacing: 0.5),
        ),
      );

  TableRow _buildDataRow(DressListItem item) {
    return TableRow(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      children: [
        _dataCell(_buildThumbnail(item.primaryImageUrl)),
        _dataCell(_buildNameCell(item)),
        _dataCell(Text(item.primaryCategoryName,
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
        _dataCell(Text(item.sizeLabel,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)))),
        _dataCell(_buildPriceCell(item)),
        _dataCell(_buildStatusBadge(item.status)),
        _dataCell(_buildRatingCell(item)),
        _dataCell(item.isFeatured
            ? const Icon(Icons.star_rounded, color: Colors.amber, size: 20)
            : const Icon(Icons.star_outline, color: Color(0xFFD1D5DB), size: 20)),
        _dataCell(_buildActions(item)),
      ],
    );
  }

  Widget _dataCell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: child,
      );

  Widget _buildThumbnail(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url != null && url.isNotEmpty
          ? Image.network(
              _resolveImageUrl(url),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderIcon(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _loadingPlaceholder(),
            )
          : _placeholderIcon(),
    );
  }

  Widget _placeholderIcon() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6)),
        child: Icon(Icons.checkroom_outlined,
            color: Colors.grey.shade400, size: 24),
      );

  Widget _loadingPlaceholder() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFF0F3),
              Colors.grey.shade100,
            ],
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFC2778A),
                ))),
      );

  Widget _buildNameCell(DressListItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF1F2937)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          item.code,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildPriceCell(DressListItem item) {
    final fmt = NumberFormat.currency(symbol: 'BAM ', decimalDigits: 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fmt.format(item.baseRentalPrice),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937))),
        if (item.tryOnPrice != null)
          Text('Try-on: ${fmt.format(item.tryOnPrice!)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }

  Widget _buildStatusBadge(int status) {
    final colors = {
      1: (const Color(0xFF6B7280), const Color(0xFFF3F4F6)), // Draft
      2: (const Color(0xFF16A34A), const Color(0xFFDCFCE7)), // Active
      3: (const Color(0xFF2563EB), const Color(0xFFDBEAFE)), // Reserved
      4: (const Color(0xFFD97706), const Color(0xFFFEF3C7)), // OutOfService
      5: (const Color(0xFF9CA3AF), const Color(0xFFF9FAFB)), // Archived
    };
    final pair = colors[status] ?? (const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    final label = kDressStatusLabels[status] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: pair.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: pair.$1),
      ),
    );
  }

  Widget _buildRatingCell(DressListItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
        const SizedBox(width: 2),
        Text(
          item.averageRating.toStringAsFixed(1),
          style:
              const TextStyle(fontSize: 12, color: Color(0xFF374151)),
        ),
        Text(' (${item.ratingCount})',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ],
    );
  }

  Widget _buildActions(DressListItem item) {
    final isArchived = item.status == 5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          icon: Icons.info_outline_rounded,
          color: _kPrimary,
          tooltip: 'Details',
          onTap: () => _openDetail(item),
        ),
        const SizedBox(width: 4),
        _actionButton(
          icon: Icons.edit_outlined,
          color: Colors.orange,
          tooltip: 'Edit',
          onTap: () => _openForm(item: item),
        ),
        const SizedBox(width: 4),
        _actionButton(
          icon: Icons.archive_outlined,
          color: isArchived ? Colors.grey : Colors.red.shade700,
          tooltip: isArchived ? 'Already archived' : 'Archive',
          onTap: isArchived ? null : () => _confirmArchive(item),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: onTap != null
                  ? color.withValues(alpha: 0.08)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                  color: onTap != null
                      ? color.withValues(alpha: 0.25)
                      : Colors.grey.shade200),
            ),
            child: Icon(icon,
                color: onTap != null ? color : Colors.grey.shade400, size: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checkroom_outlined,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No dresses found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('Try adjusting your search filters or add a new dress.',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    final isFirst = _currentPage == 0;
    final isLast = _currentPage >= totalPages - 1 || totalPages == 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('Rows per page:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(width: 10),
            DropdownButton<int>(
              value: _pageSize,
              underline: const SizedBox(),
              items: _pageSizeOptions
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text('$s')))
                  .toList(),
              onChanged: (v) {
                if (v != null && v != _pageSize) {
                  _performSearch(page: 0, pageSize: v);
                }
              },
            ),
          ],
        ),
        Row(
          children: [
            Text(
              totalPages > 0
                  ? 'Page ${_currentPage + 1} of $totalPages'
                  : 'No results',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 16),
            _pageButton(
                icon: Icons.chevron_left_rounded,
                enabled: !isFirst,
                onTap: () => _performSearch(page: _currentPage - 1)),
            const SizedBox(width: 8),
            _pageButton(
                icon: Icons.chevron_right_rounded,
                enabled: !isLast,
                onTap: () => _performSearch(page: _currentPage + 1)),
          ],
        ),
      ],
    );
  }

  Widget _pageButton(
      {required IconData icon,
      required bool enabled,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: enabled
                    ? Colors.grey.shade300
                    : Colors.grey.shade200),
          ),
          child: Icon(icon,
              size: 20,
              color: enabled
                  ? const Color(0xFF374151)
                  : Colors.grey.shade400),
        ),
      ),
    );
  }
}
