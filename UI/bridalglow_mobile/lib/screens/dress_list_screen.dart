import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/dress.dart';
import 'package:bridalglow_mobile/models/dress_category.dart';
import 'package:bridalglow_mobile/models/dress_tag.dart';
import 'package:bridalglow_mobile/providers/dress_category_provider.dart';
import 'package:bridalglow_mobile/providers/dress_provider.dart';
import 'package:bridalglow_mobile/providers/dress_tag_provider.dart';
import 'package:bridalglow_mobile/widgets/dress_catalog_card.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

// ── Sort option data ─────────────────────────────────────────────────────────

class _SortOption {
  final String label;
  final String sortBy;
  final bool descending;

  const _SortOption(this.label, this.sortBy, this.descending);
}

const _kSortOptions = [
  _SortOption('Newest first', 'CreatedAt', true),
  _SortOption('Price: low → high', 'Price', false),
  _SortOption('Price: high → low', 'Price', true),
  _SortOption('Rating: best first', 'Rating', true),
  _SortOption('Name A → Z', 'Name', false),
];

// ── Filter state ─────────────────────────────────────────────────────────────

class _FilterState {
  int? categoryId;
  int? tagId;
  String? sizeLabel;
  double? minPrice;
  double? maxPrice;
  double? minRating;
  int sortIndex;

  _FilterState({
    this.categoryId,
    this.tagId,
    this.sizeLabel,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.sortIndex = 0,
  });

  _FilterState copyWith({
    Object? categoryId = _sentinel,
    Object? tagId = _sentinel,
    Object? sizeLabel = _sentinel,
    Object? minPrice = _sentinel,
    Object? maxPrice = _sentinel,
    Object? minRating = _sentinel,
    int? sortIndex,
  }) {
    return _FilterState(
      categoryId: categoryId == _sentinel ? this.categoryId : categoryId as int?,
      tagId: tagId == _sentinel ? this.tagId : tagId as int?,
      sizeLabel: sizeLabel == _sentinel ? this.sizeLabel : sizeLabel as String?,
      minPrice: minPrice == _sentinel ? this.minPrice : minPrice as double?,
      maxPrice: maxPrice == _sentinel ? this.maxPrice : maxPrice as double?,
      minRating:
          minRating == _sentinel ? this.minRating : minRating as double?,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  bool get hasActiveFilters =>
      categoryId != null ||
      tagId != null ||
      sizeLabel != null ||
      minPrice != null ||
      maxPrice != null ||
      minRating != null;
}

const _sentinel = Object();

// ── DressListScreen ───────────────────────────────────────────────────────────

class DressListScreen extends StatefulWidget {
  const DressListScreen({super.key});

  @override
  State<DressListScreen> createState() => _DressListScreenState();
}

class _DressListScreenState extends State<DressListScreen> {
  late DressProvider _dressProvider;
  late DressCategoryProvider _categoryProvider;
  late DressTagProvider _tagProvider;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<DressListItem> _items = [];
  int _totalCount = 0;
  int _currentPage = 0;
  static const int _pageSize = 10;

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;

  _FilterState _filters = _FilterState();

  List<DressCategory> _categories = [];
  List<DressTag> _tags = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _dressProvider = context.read<DressProvider>();
      _categoryProvider = context.read<DressCategoryProvider>();
      _tagProvider = context.read<DressTagProvider>();
      await Future.wait([
        _loadCategories(),
        _loadTags(),
        _loadPage(reset: true),
      ]);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final result = await _categoryProvider.get(
          filter: {'page': 0, 'pageSize': 200, 'includeTotalCount': false});
      if (mounted) setState(() => _categories = result.items);
    } catch (_) {}
  }

  Future<void> _loadTags() async {
    try {
      final result = await _tagProvider.get(
          filter: {'page': 0, 'pageSize': 200, 'includeTotalCount': false});
      if (mounted) setState(() => _tags = result.items);
    } catch (_) {}
  }

  Map<String, dynamic> _buildFilter(int page) {
    final sort = _kSortOptions[_filters.sortIndex];
    return {
      if (_searchController.text.trim().isNotEmpty)
        'fts': _searchController.text.trim(),
      if (_filters.categoryId != null) 'categoryId': _filters.categoryId,
      if (_filters.tagId != null) 'tagId': _filters.tagId,
      if (_filters.sizeLabel != null && _filters.sizeLabel!.isNotEmpty)
        'sizeLabel': _filters.sizeLabel,
      if (_filters.minPrice != null) 'minPrice': _filters.minPrice,
      if (_filters.maxPrice != null) 'maxPrice': _filters.maxPrice,
      if (_filters.minRating != null) 'minRating': _filters.minRating,
      'sortBy': sort.sortBy,
      'descending': sort.descending,
      'page': page,
      'pageSize': _pageSize,
      'includeTotalCount': true,
    };
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result =
          await _dressProvider.get(filter: _buildFilter(0));
      if (mounted) {
        setState(() {
          _items = result.items;
          _totalCount = result.totalCount ?? 0;
          _currentPage = 0;
          _hasMore = result.items.length >= _pageSize &&
              _items.length < _totalCount;
        });
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final result = await _dressProvider.get(filter: _buildFilter(nextPage));
      if (mounted) {
        setState(() {
          _items.addAll(result.items);
          _currentPage = nextPage;
          _hasMore = _items.length < (_totalCount);
        });
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterPanel(
        initial: _filters,
        categories: _categories,
        tags: _tags,
      ),
    );
    if (result != null && mounted) {
      setState(() => _filters = result);
      await _loadPage(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildActiveFiltersChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Dress Catalogue',
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937)),
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: _kPrimary),
              tooltip: 'Filters',
              onPressed: _openFilters,
            ),
            if (_filters.hasActiveFilters)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _kPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search dresses…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: _kPrimary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                  onPressed: () {
                    _searchController.clear();
                    _loadPage(reset: true);
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF9F5F6),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _loadPage(reset: true),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    final chips = <Widget>[];

    if (_filters.sortIndex != 0) {
      chips.add(_filterChip(
        _kSortOptions[_filters.sortIndex].label,
        Icons.sort_rounded,
        onRemove: () {
          setState(() => _filters = _filters.copyWith(sortIndex: 0));
          _loadPage(reset: true);
        },
      ));
    }
    if (_filters.categoryId != null) {
      final cat = _categories.where((c) => c.id == _filters.categoryId).firstOrNull;
      chips.add(_filterChip(
        cat?.name ?? 'Category',
        Icons.category_outlined,
        onRemove: () {
          setState(() => _filters = _filters.copyWith(categoryId: null));
          _loadPage(reset: true);
        },
      ));
    }
    if (_filters.tagId != null) {
      final tag = _tags.where((t) => t.id == _filters.tagId).firstOrNull;
      chips.add(_filterChip(
        tag?.name ?? 'Tag',
        Icons.sell_outlined,
        onRemove: () {
          setState(() => _filters = _filters.copyWith(tagId: null));
          _loadPage(reset: true);
        },
      ));
    }
    if (_filters.sizeLabel != null) {
      chips.add(_filterChip(
        'Size: ${_filters.sizeLabel}',
        Icons.straighten_outlined,
        onRemove: () {
          setState(() => _filters = _filters.copyWith(sizeLabel: null));
          _loadPage(reset: true);
        },
      ));
    }
    if (_filters.minPrice != null || _filters.maxPrice != null) {
      final label = [
        if (_filters.minPrice != null)
          'Min ${_filters.minPrice!.toStringAsFixed(0)} BAM',
        if (_filters.maxPrice != null)
          'Max ${_filters.maxPrice!.toStringAsFixed(0)} BAM',
      ].join(' – ');
      chips.add(_filterChip(
        label,
        Icons.attach_money_rounded,
        onRemove: () {
          setState(
              () => _filters = _filters.copyWith(minPrice: null, maxPrice: null));
          _loadPage(reset: true);
        },
      ));
    }
    if (_filters.minRating != null) {
      chips.add(_filterChip(
        '≥ ${_filters.minRating!.toStringAsFixed(1)} ★',
        Icons.star_outlined,
        onRemove: () {
          setState(() => _filters = _filters.copyWith(minRating: null));
          _loadPage(reset: true);
        },
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 12, bottom: 10),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: chips,
        ),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon,
      {required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label,
            style: const TextStyle(
                fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w500)),
        avatar: Icon(icon, size: 14, color: _kPrimary),
        deleteIcon: const Icon(Icons.close, size: 14, color: _kPrimary),
        onDeleted: onRemove,
        backgroundColor: _kPrimaryLight,
        side: const BorderSide(color: _kPrimary, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_items.isEmpty) {
      return _buildEmptyState();
    }
    return _buildGrid();
  }

  Widget _buildGrid() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, idx) => DressCatalogCard(dress: _items[idx]),
              childCount: _items.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 296,
            ),
          ),
        ),
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(color: _kPrimary)),
            ),
          ),
        if (!_hasMore && _items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'All $_totalCount dresses loaded',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_outlined,
                size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(
              'No dresses found',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _filters = _FilterState());
                _loadPage(reset: true);
              },
              icon: const Icon(Icons.refresh_rounded, color: _kPrimary),
              label: const Text('Clear filters',
                  style: TextStyle(color: _kPrimary)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPrimary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter Panel ──────────────────────────────────────────────────────────────

class _FilterPanel extends StatefulWidget {
  final _FilterState initial;
  final List<DressCategory> categories;
  final List<DressTag> tags;

  const _FilterPanel({
    required this.initial,
    required this.categories,
    required this.tags,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late _FilterState _state;
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _sizeLabelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _state = widget.initial;
    _minPriceCtrl.text = _state.minPrice?.toStringAsFixed(0) ?? '';
    _maxPriceCtrl.text = _state.maxPrice?.toStringAsFixed(0) ?? '';
    _sizeLabelCtrl.text = _state.sizeLabel ?? '';
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _sizeLabelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildPanelHeader(),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  _buildSectionLabel('Sort by'),
                  _buildSortOptions(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Category'),
                  _buildCategoryDropdown(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Tag'),
                  _buildTagDropdown(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Size'),
                  _buildSizeField(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Price range (BAM)'),
                  _buildPriceRange(),
                  const SizedBox(height: 20),
                  _buildSectionLabel('Minimum rating'),
                  _buildRatingSelector(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            _buildApplyBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, color: _kPrimary, size: 22),
          const SizedBox(width: 10),
          const Text('Filters & Sort',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const Spacer(),
          TextButton(
            onPressed: _resetAll,
            child: const Text('Reset all',
                style: TextStyle(color: _kPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _resetAll() {
    setState(() {
      _state = _FilterState();
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _sizeLabelCtrl.clear();
    });
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
    );
  }

  Widget _buildSortOptions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_kSortOptions.length, (i) {
        final selected = _state.sortIndex == i;
        return ChoiceChip(
          label: Text(_kSortOptions[i].label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : const Color(0xFF374151))),
          selected: selected,
          onSelected: (_) => setState(() => _state = _state.copyWith(sortIndex: i)),
          selectedColor: _kPrimary,
          backgroundColor: Colors.grey.shade100,
          side: BorderSide(color: selected ? _kPrimary : Colors.grey.shade300),
        );
      }),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int?>(
      initialValue: _state.categoryId,
      decoration: _inputDecoration(Icons.category_outlined, 'All categories'),
      items: [
        const DropdownMenuItem<int?>(
            value: null, child: Text('All categories')),
        ...widget.categories.map((c) => DropdownMenuItem<int?>(
              value: c.id,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (v) => setState(() => _state = _state.copyWith(categoryId: v)),
    );
  }

  Widget _buildTagDropdown() {
    return DropdownButtonFormField<int?>(
      initialValue: _state.tagId,
      decoration: _inputDecoration(Icons.sell_outlined, 'All tags'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('All tags')),
        ...widget.tags.map((t) => DropdownMenuItem<int?>(
              value: t.id,
              child: Text(t.name, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (v) => setState(() => _state = _state.copyWith(tagId: v)),
    );
  }

  Widget _buildSizeField() {
    return TextFormField(
      controller: _sizeLabelCtrl,
      decoration: _inputDecoration(Icons.straighten_outlined, 'e.g. S, M, L, 38, 40…'),
      onChanged: (v) => _state =
          _state.copyWith(sizeLabel: v.trim().isEmpty ? null : v.trim()),
    );
  }

  Widget _buildPriceRange() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _minPriceCtrl,
            decoration: _inputDecoration(Icons.attach_money_rounded, 'Min'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final d = double.tryParse(v.trim());
              _state = _state.copyWith(minPrice: d);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('–', style: TextStyle(color: Colors.grey.shade500)),
        ),
        Expanded(
          child: TextFormField(
            controller: _maxPriceCtrl,
            decoration: _inputDecoration(Icons.attach_money_rounded, 'Max'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final d = double.tryParse(v.trim());
              _state = _state.copyWith(maxPrice: d);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSelector() {
    return Wrap(
      spacing: 8,
      children: [null, 1.0, 2.0, 3.0, 4.0, 4.5].map((r) {
        final selected = _state.minRating == r;
        final label = r == null ? 'Any' : '≥ ${r.toStringAsFixed(1)} ★';
        return ChoiceChip(
          label: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : const Color(0xFF374151))),
          selected: selected,
          onSelected: (_) =>
              setState(() => _state = _state.copyWith(minRating: r)),
          selectedColor: _kPrimary,
          backgroundColor: Colors.grey.shade100,
          side: BorderSide(color: selected ? _kPrimary : Colors.grey.shade300),
        );
      }).toList(),
    );
  }

  InputDecoration _inputDecoration(IconData icon, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: _kPrimary, size: 20),
      filled: true,
      fillColor: const Color(0xFFF9F5F6),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
    );
  }

  Widget _buildApplyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _state),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Apply filters',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
