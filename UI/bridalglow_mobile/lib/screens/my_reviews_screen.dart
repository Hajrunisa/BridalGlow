import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/review.dart';
import 'package:bridalglow_mobile/providers/review_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);
final _dateFmt = DateFormat('dd.MM.yyyy');

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  List<Review> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<ReviewProvider>();
      final items = await provider.getMyReviews();
      if (mounted) setState(() => _reviews = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEditDialog(Review review) async {
    if (!review.isPendingModeration) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewFormSheet(
        title: 'Edit review',
        initialRating: review.rating,
        initialTitle: review.title ?? '',
        initialComment: review.comment ?? '',
        onSubmit: (rating, title, comment) async {
          await context.read<ReviewProvider>().updateReview(review.id, {
            'rating': rating,
            if (title != null) 'title': title,
            if (comment != null) 'comment': comment,
          });
        },
      ),
    );
    if (saved == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _kPrimary,
                  child: _reviews.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reviews.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _ReviewCard(
                                review: _reviews[i],
                                onEdit: () => _showEditDialog(_reviews[i]),
                              ),
                        ),
                ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_border_rounded,
                  size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'You have no reviews',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'You can leave a review after your rental is completed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade500, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onEdit;

  const _ReviewCard({required this.review, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: dress + status badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.dressName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937)),
                    ),
                    Text(
                      review.dressCode,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              _statusBadge(review.status),
            ],
          ),
          const SizedBox(height: 10),
          // Stars
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < review.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: Colors.amber,
                size: 20,
              ),
            ),
          ),
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.title!,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
          ],
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.comment!,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.5),
            ),
          ],
          // Moderation note
          if (review.moderationNote != null &&
              review.moderationNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.red.shade600, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      review.moderationNote!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Staff reply
          if (review.staffReply != null &&
              review.staffReply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kPrimaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.reply_rounded,
                      color: _kPrimary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Salon reply',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          review.staffReply!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF374151)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_outlined,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                _dateFmt.format(review.createdAtUtc.toLocal()),
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
              const Spacer(),
              if (review.isPendingModeration)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit',
                      style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(int status) {
    Color bg, fg;
    String label;
    switch (status) {
      case 1:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        label = 'Pending';
        break;
      case 2:
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        label = 'Published';
        break;
      case 3:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        label = 'Hidden';
        break;
      case 4:
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        label = 'Rejected';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        label = '$status';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Review Form Bottom Sheet ───────────────────────────────────────────────

class _ReviewFormSheet extends StatefulWidget {
  final String title;
  final int initialRating;
  final String initialTitle;
  final String initialComment;
  final Future<void> Function(
    int rating,
    String? title,
    String? comment,
  ) onSubmit;

  const _ReviewFormSheet({
    required this.title,
    required this.initialRating,
    this.initialTitle = '',
    this.initialComment = '',
    required this.onSubmit,
  });

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  late int _selectedRating;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _commentCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialRating;
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _commentCtrl = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final title = _titleCtrl.text.trim();
      final comment = _commentCtrl.text.trim();
      await widget.onSubmit(
        _selectedRating,
        title.isEmpty ? null : title,
        comment.isEmpty ? null : comment,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Rating *',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  final starVal = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRating = starVal),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        starVal <= _selectedRating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Comment (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  counterText: '',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit review',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Public helper: show write-review bottom sheet ─────────────────────────

/// Opens the review form as a modal bottom sheet.
/// Returns true if the review was successfully submitted.
Future<bool> showWriteReviewSheet(
  BuildContext context, {
  required int rentalReservationId,
  required ReviewProvider provider,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewFormSheet(
      title: 'Write a review',
      initialRating: 5,
      onSubmit: (rating, title, comment) async {
        await provider.createReview({
          'rentalReservationId': rentalReservationId,
          'rating': rating,
          if (title != null) 'title': title,
          if (comment != null) 'comment': comment,
        });
      },
    ),
  );
  return saved == true;
}
