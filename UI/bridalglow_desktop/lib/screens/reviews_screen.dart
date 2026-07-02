import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/review.dart';
import 'package:bridalglow_desktop/models/search_result.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/providers/notification_refresh_coordinator.dart';
import 'package:bridalglow_desktop/providers/review_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);
final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late ReviewProvider _provider;
  late DressProvider _dressProvider;

  List<DressListItem> _dresses = [];
  int? _filterDressId;
  int? _filterStatus;
  SearchResult<Review>? _result;
  bool _loading = false;
  NotificationRefreshCoordinator? _refreshCoordinator;

  static const _statusFilters = [
    {'label': 'All Statuses', 'value': null},
    {'label': 'Pending Moderation', 'value': 1},
    {'label': 'Published', 'value': 2},
    {'label': 'Hidden', 'value': 3},
    {'label': 'Rejected', 'value': 4},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _provider = context.read<ReviewProvider>();
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
    if (NotificationRefreshCoordinator.affectsReviews(entityType)) {
      _search();
    }
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
      };
      final r = await _provider.getAll(filter: filter);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _publish(Review review) async {
    try {
      await _provider.publish(review.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review published.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _search();
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _hide(Review review) async {
    try {
      await _provider.hide(review.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review hidden.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _search();
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showRejectDialog(Review review) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Odbij recenziju',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: noteCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Moderation note (optional)',
              border: OutlineInputBorder(),
            ),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Odbij'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _provider.reject(review.id,
            moderationNote: noteCtrl.text.trim().isEmpty
                ? null
                : noteCtrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review rejected.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _search();
        }
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _showStaffReplyDialog(Review review) async {
    final replyCtrl =
        TextEditingController(text: review.staffReply ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.reply_rounded, color: _kPrimary, size: 22),
            SizedBox(width: 8),
            Text('Staff reply',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: replyCtrl,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Staff reply',
              border: OutlineInputBorder(),
            ),
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
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final reply = replyCtrl.text.trim();
      if (reply.isEmpty) return;
      try {
        await _provider.setStaffReply(review.id, reply);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff reply saved.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await _search();
        }
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showDetailDialog(Review review) {
    showDialog(
      context: context,
      builder: (ctx) => _ReviewDetailDialog(review: review),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
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
          const SizedBox(height: 20),
          _buildFilters(),
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimary, Color(0xFFD4889A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reviews',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D1B2E))),
              Text(
                _result != null
                    ? '${_result!.totalCount ?? _result!.items.length} recenzija'
                    : 'Browse and moderate customer reviews',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Responsive filter row ─────────────────────────────────────────────────

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return _buildFiltersWide();
        }
        return _buildFiltersNarrow();
      },
    );
  }

  Widget _buildFiltersWide() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildDressDropdown()),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _buildStatusDropdown()),
        const SizedBox(width: 10),
        _buildSearchButton(),
      ],
    );
  }

  Widget _buildFiltersNarrow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDressDropdown(),
        const SizedBox(height: 10),
        _buildStatusDropdown(),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _buildSearchButton(),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return ElevatedButton.icon(
      onPressed: _search,
      icon: const Icon(Icons.search_rounded, size: 18),
      label: const Text('Search'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDressDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Dress',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _filterDressId,
          isDense: true,
          isExpanded: true,
          items: [
            const DropdownMenuItem<int?>(
                value: null, child: Text('All dresses')),
            ..._dresses.map((d) => DropdownMenuItem<int?>(
                value: d.id,
                child: Text('[${d.code}] ${d.name}',
                    overflow: TextOverflow.ellipsis, maxLines: 1))),
          ],
          onChanged: (v) {
            setState(() => _filterDressId = v);
            _search();
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _filterStatus,
          isDense: true,
          isExpanded: true,
          items: _statusFilters
              .map((s) => DropdownMenuItem<int?>(
                  value: s['value'] as int?,
                  child: Text(s['label'] as String)))
              .toList(),
          onChanged: (v) {
            setState(() => _filterStatus = v);
            _search();
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    final items = _result?.items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No reviews',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
    }
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
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.8),
              1: FlexColumnWidth(1.8),
              2: FixedColumnWidth(70),
              3: FlexColumnWidth(2),
              4: FixedColumnWidth(110),
              5: FixedColumnWidth(130),
              6: FixedColumnWidth(200),
            },
            children: [
              _tableHeader(),
              ...items.map(_tableRow),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _tableHeader() {
    const style = TextStyle(
        fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF6B5860));
    return TableRow(
      decoration: const BoxDecoration(color: _kPrimaryLight),
      children: [
        _th('Customer', style),
        _th('Dress', style),
        _th('Rating', style),
        _th('Title', style),
        _th('Status', style),
        _th('Created', style),
        _th('Actions', style),
      ],
    );
  }

  TableRow _tableRow(Review r) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.08))),
      ),
      children: [
        _td(r.customerName),
        _td('[${r.dressCode}] ${r.dressName}'),
        _tdWidget(_buildStars(r.rating)),
        _td(r.title ?? '—'),
        _tdWidget(_buildStatusBadge(r.status)),
        _td(_dateFmt.format(r.createdAtUtc.toLocal())),
        _tdWidget(_buildActions(r)),
      ],
    );
  }

  Widget _buildStars(int rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 2),
          Text('$rating', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(int status) {
    Color bg;
    Color fg;
    switch (status) {
      case 1:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        break;
      case 2:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 3:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        break;
      case 4:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(kReviewStatusLabels[status] ?? '$status',
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildActions(Review r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _actionBtn(
              Icons.info_outline_rounded, 'Detalji', Colors.blue,
              () => _showDetailDialog(r)),
          if (r.isPendingModeration)
            _actionBtn(Icons.check_circle_outline_rounded, 'Objavi',
                Colors.green, () => _publish(r)),
          if (r.isPublished)
            _actionBtn(Icons.visibility_off_outlined, 'Sakrij',
                Colors.grey, () => _hide(r)),
          if (r.isPendingModeration)
            _actionBtn(Icons.block_rounded, 'Odbij', Colors.red,
                () => _showRejectDialog(r)),
          if (r.isPublished)
            _actionBtn(Icons.reply_rounded, 'Reply', _kPrimary,
                () => _showStaffReplyDialog(r)),
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

  Widget _th(String text, TextStyle style) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(text, style: style),
      );

  Widget _td(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 2),
      );

  Widget _tdWidget(Widget child) => child;
}

// ── Detail dialog ─────────────────────────────────────────────────────────

class _ReviewDetailDialog extends StatelessWidget {
  final Review review;
  const _ReviewDetailDialog({required this.review});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.star_rounded, color: _kPrimary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              review.title ?? 'Review #${review.id}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Customer', review.customerName),
              _row('Dress',
                  '[${review.dressCode}] ${review.dressName}'),
              _row('Rating', '${review.rating} / 5'),
              _row('Status', kReviewStatusLabels[review.status] ?? ''),
              if (review.comment != null && review.comment!.isNotEmpty)
                _row('Comment', review.comment!),
              if (review.moderationNote != null &&
                  review.moderationNote!.isNotEmpty)
                _row('Moderation note', review.moderationNote!,
                    color: Colors.red.shade700),
              if (review.staffReply != null && review.staffReply!.isNotEmpty)
                _row('Staff reply', review.staffReply!,
                    color: Colors.green.shade700),
              if (review.publishedAtUtc != null)
                _row('Published',
                    _dateFmt.format(review.publishedAtUtc!.toLocal())),
              _row('Created',
                  _dateFmt.format(review.createdAtUtc.toLocal())),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zatvori'),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
              fontSize: 13.5, color: Color(0xFF333333)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: color ?? const Color(0xFF333333)),
            ),
          ],
        ),
      ),
    );
  }
}
