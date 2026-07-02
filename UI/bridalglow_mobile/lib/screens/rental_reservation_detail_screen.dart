import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/rental_reservation.dart';
import 'package:bridalglow_mobile/models/review.dart';
import 'package:bridalglow_mobile/providers/rental_reservation_provider.dart';
import 'package:bridalglow_mobile/providers/review_provider.dart';
import 'package:bridalglow_mobile/screens/my_reviews_screen.dart';
import 'package:bridalglow_mobile/screens/stripe_payment_screen.dart';
import 'package:bridalglow_mobile/widgets/refund_status_section.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class RentalReservationDetailScreen extends StatefulWidget {
  final int reservationId;

  const RentalReservationDetailScreen({super.key, required this.reservationId});

  @override
  State<RentalReservationDetailScreen> createState() =>
      _RentalReservationDetailScreenState();
}

class _RentalReservationDetailScreenState
    extends State<RentalReservationDetailScreen> {
  late RentalReservationProvider _provider;
  late ReviewProvider _reviewProvider;
  RentalReservation? _reservation;
  List<RentalReservationStatusHistory> _timeline = [];
  Review? _existingReview;
  bool _loading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<RentalReservationProvider>();
      _reviewProvider = context.read<ReviewProvider>();
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _provider.getById(widget.reservationId),
        _provider.getTimeline(widget.reservationId),
      ]);
      final reservation = results[0] as RentalReservation?;
      final timeline = results[1] as List<RentalReservationStatusHistory>;
      if (mounted) {
        setState(() {
          _reservation = reservation;
          _timeline = timeline;
        });
      }
      // Load existing review only if reservation is Completed
      if (reservation != null && reservation.isCompleted && mounted) {
        await _loadExistingReview();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadExistingReview() async {
    try {
      final reviews = await _reviewProvider.getMyReviews();
      final match = reviews.where(
        (r) => r.rentalReservationId == widget.reservationId,
      );
      if (mounted) setState(() => _existingReview = match.isNotEmpty ? match.first : null);
    } catch (_) {}
  }

  Future<void> _openWriteReview() async {
    final submitted = await showWriteReviewSheet(
      context,
      rentalReservationId: widget.reservationId,
      provider: _reviewProvider,
    );
    if (submitted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your review has been submitted for moderation. Thank you!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      await _loadExistingReview();
    }
  }

  Future<void> _cancelReservation() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 22),
            SizedBox(width: 10),
            Text('Cancel Rental',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this rental reservation?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Reservation',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel Rental'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final updated = await _provider.cancelReservation(
        widget.reservationId,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      final timeline = await _provider.getTimeline(widget.reservationId);
      if (mounted) {
        setState(() {
          _reservation = updated;
          _timeline = timeline;
          _hasChanges = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rental reservation cancelled successfully.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: AppBar(
        title: const Text('Rental Details'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _reservation == null
              ? const Center(child: Text('Reservation not found.'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final r = _reservation!;
    final fmtDate = DateFormat('dd.MM.yyyy');
    final fmtDateTime = DateFormat('dd.MM.yyyy HH:mm');
    final history = _timeline.isNotEmpty ? _timeline : r.statusHistory;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusBanner(r),
        const SizedBox(height: 16),
        _buildInfoCard(r, fmtDate, fmtDateTime),
        const SizedBox(height: 12),
        if (r.notes != null && r.notes!.isNotEmpty) ...[
          _buildSimpleCard(
            icon: Icons.notes_outlined,
            title: 'Notes',
            content: r.notes!,
          ),
          const SizedBox(height: 12),
        ],
        if (r.cancellationReason != null &&
            r.cancellationReason!.isNotEmpty) ...[
          _buildSimpleCard(
            icon: Icons.info_outline_rounded,
            title: 'Cancellation Reason',
            content: r.cancellationReason!,
            contentColor: Colors.red.shade700,
          ),
          const SizedBox(height: 12),
        ],
        _buildStatusTimeline(history),
        const SizedBox(height: 12),
        RefundStatusSection(
          rentalReservationId: r.id,
          showWhenEmpty: r.isRefunded || r.isPaid,
          reservationIsPaid: r.isPaid,
        ),
        if (r.isCompleted) ...[
          const SizedBox(height: 12),
          _buildReviewSection(),
        ],
        const SizedBox(height: 16),
        if (r.canPay) _buildPayNowButton(),
        if (r.canCancel) ...[
          if (r.canPay) const SizedBox(height: 12),
          _buildCancelButton(),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildReviewSection() {
    if (_existingReview != null) {
      final r = _existingReview!;
      return _card(
        icon: Icons.star_rounded,
        title: 'Your review',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < r.rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                _reviewStatusBadge(r.status),
              ],
            ),
            if (r.title != null && r.title!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.title!,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937))),
            ],
            if (r.comment != null && r.comment!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.comment!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.5)),
            ],
            if (r.moderationNote != null &&
                r.moderationNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.moderationNote!,
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade700),
                ),
              ),
            ],
            if (r.staffReply != null && r.staffReply!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Salon reply',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _kPrimary)),
                    const SizedBox(height: 2),
                    Text(r.staffReply!,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _card(
      icon: Icons.rate_review_outlined,
      title: 'Ostavite recenziju',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your rental is complete. Share your experience with others!',
            style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWriteReview,
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text('Write a review'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewStatusBadge(int status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatusBanner(RentalReservation r) {
    final cfg = _statusConfig(r.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cfg.$1.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(r.status), color: cfg.$1, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.statusLabel.isNotEmpty ? r.statusLabel : cfg.$3,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cfg.$1),
                ),
                Text(
                  r.reservationNumber,
                  style: TextStyle(
                      fontSize: 12,
                      color: cfg.$1.withValues(alpha: 0.8),
                      fontFamily: 'monospace'),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusMessage(r.status),
                  style: TextStyle(
                      fontSize: 13,
                      color: cfg.$1.withValues(alpha: 0.85),
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      RentalReservation r, DateFormat fmtDate, DateFormat fmtDateTime) {
    return _card(
      icon: Icons.info_outline_rounded,
      title: 'Reservation Details',
      child: Column(
        children: [
          _infoRow('Dress', '${r.dressCode} – ${r.dressName}'),
          _infoRow(
            'Rental Period',
            '${fmtDate.format(r.startDateUtc.toLocal())} → '
                '${fmtDate.format(r.endDateUtc.toLocal())}',
          ),
          _infoRow('Base Amount', '${r.baseAmount.toStringAsFixed(2)} BAM'),
          if (r.discountAmount > 0)
            _infoRow('Discount', '–${r.discountAmount.toStringAsFixed(2)} BAM'),
          if (r.depositAmount > 0)
            _infoRow('Deposit', '${r.depositAmount.toStringAsFixed(2)} BAM'),
          if (r.lateFeeAmount > 0)
            _infoRow('Late Fee', '${r.lateFeeAmount.toStringAsFixed(2)} BAM'),
          if (r.damageFeeAmount > 0)
            _infoRow(
                'Damage Fee', '${r.damageFeeAmount.toStringAsFixed(2)} BAM'),
          _infoRow('Total', '${r.totalAmount.toStringAsFixed(2)} BAM'),
          if (r.approvedAtUtc != null)
            _infoRow('Approved at',
                fmtDateTime.format(r.approvedAtUtc!.toLocal())),
          if (r.pickedUpAtUtc != null)
            _infoRow('Picked up at',
                fmtDateTime.format(r.pickedUpAtUtc!.toLocal())),
          if (r.returnedAtUtc != null)
            _infoRow('Returned at',
                fmtDateTime.format(r.returnedAtUtc!.toLocal())),
          if (r.completedAtUtc != null)
            _infoRow('Completed at',
                fmtDateTime.format(r.completedAtUtc!.toLocal())),
          if (r.cancelledAtUtc != null)
            _infoRow('Cancelled at',
                fmtDateTime.format(r.cancelledAtUtc!.toLocal())),
          _infoRow('Created at',
              fmtDateTime.format(r.createdAtUtc.toLocal())),
        ],
      ),
    );
  }

  Widget _buildSimpleCard({
    required IconData icon,
    required String title,
    required String content,
    Color? contentColor,
  }) {
    return _card(
      icon: icon,
      title: title,
      child: Text(
        content,
        style: TextStyle(
            fontSize: 14,
            color: contentColor ?? const Color(0xFF374151),
            height: 1.5),
      ),
    );
  }

  Widget _buildStatusTimeline(List<RentalReservationStatusHistory> history) {
    if (history.isEmpty) return const SizedBox.shrink();

    return _card(
      icon: Icons.timeline_outlined,
      title: 'Status Timeline',
      child: Column(
        children: history.asMap().entries.map((entry) {
          final h = entry.value;
          final isLast = entry.key == history.length - 1;
          final statusCfg = _statusConfig(h.toStatus);

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusCfg.$1,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: statusCfg.$1.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.grey.shade200,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.toStatusLabel,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: statusCfg.$1),
                        ),
                        if (h.reason != null && h.reason!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              h.reason!,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            DateFormat('dd.MM.yyyy HH:mm')
                                .format(h.changedAtUtc.toLocal()),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openPayment() async {
    final r = _reservation;
    if (r == null || !r.canPay) return;

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StripePaymentScreen(reservation: r),
      ),
    );

    if (paid == true && mounted) {
      setState(() => _hasChanges = true);
      await _load();
    }
  }

  Widget _buildPayNowButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _openPayment,
        icon: const Icon(Icons.payments_outlined, size: 20),
        label: const Text(
          'Pay Now',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _cancelReservation,
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text('Cancel',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1F2937))),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: _kPrimaryLight,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: _kPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _statusMessage(int status) {
    switch (status) {
      case 1:
        return 'Your rental request is awaiting approval from salon staff.';
      case 2:
        return 'Your rental has been approved. Complete payment to confirm your booking.';
      case 3:
        return 'Unfortunately, your rental request was rejected by the salon.';
      case 4:
        return 'Your rental is awaiting payment. Complete payment to confirm your booking.';
      case 5:
        return 'Payment received. Salon staff will prepare your dress for pickup.';
      case 6:
        return 'Your dress is ready for pickup at the salon.';
      case 7:
        return 'You have picked up the dress. Enjoy your special day!';
      case 8:
        return 'The dress has been returned. The salon is processing the completion.';
      case 9:
        return 'Your rental has been successfully completed. Thank you!';
      case 11:
        return 'This rental has been refunded.';
      case 10:
      case 12:
      case 13:
        return 'This rental reservation has been cancelled.';
      default:
        return 'Track your rental status updates below.';
    }
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
        return (Colors.indigo.shade700, const Color(0xFFE8EAF6),
            'Ready for Pickup');
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

  IconData _statusIcon(int status) {
    switch (status) {
      case 1:
        return Icons.hourglass_top_rounded;
      case 2:
        return Icons.check_circle_outline_rounded;
      case 3:
        return Icons.block_rounded;
      case 4:
        return Icons.payment_outlined;
      case 5:
        return Icons.paid_outlined;
      case 6:
        return Icons.storefront_outlined;
      case 7:
        return Icons.shopping_bag_outlined;
      case 8:
        return Icons.assignment_return_outlined;
      case 9:
        return Icons.task_alt_rounded;
      case 11:
        return Icons.replay_rounded;
      case 10:
      case 12:
      case 13:
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
