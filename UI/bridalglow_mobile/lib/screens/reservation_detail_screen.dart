import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/try_on_reservation.dart';
import 'package:bridalglow_mobile/providers/try_on_reservation_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class ReservationDetailScreen extends StatefulWidget {
  final int reservationId;

  const ReservationDetailScreen({super.key, required this.reservationId});

  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  late TryOnReservationProvider _provider;
  TryOnReservation? _reservation;
  bool _loading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<TryOnReservationProvider>();
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _provider.getReservationById(widget.reservationId);
      if (mounted) setState(() => _reservation = r);
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
            Text('Cancel Reservation',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this reservation? The time slot will be released.',
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
            child: const Text('Cancel Reservation'),
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
      if (mounted) {
        setState(() {
          _reservation = updated;
          _hasChanges = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reservation cancelled successfully.'),
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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // Signal to parent that something changed
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F4F5),
        appBar: AppBar(
          title: const Text('Reservation Details'),
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
            ? const Center(
                child: CircularProgressIndicator(color: _kPrimary))
            : _reservation == null
                ? const Center(child: Text('Reservation not found.'))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final r = _reservation!;
    final fmt = DateFormat('dd.MM.yyyy HH:mm');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusBanner(r),
        const SizedBox(height: 16),
        _buildInfoCard(r, fmt),
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
        _buildStatusHistory(r),
        const SizedBox(height: 16),
        if (r.canCancel) _buildCancelButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatusBanner(TryOnReservation r) {
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
                  cfg.$3,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(TryOnReservation r, DateFormat fmt) {
    return _card(
      icon: Icons.info_outline_rounded,
      title: 'Reservation Details',
      child: Column(
        children: [
          _infoRow(
              'Dress', '${r.dressCode} – ${r.dressName}'),
          _infoRow('Date & Time',
              '${fmt.format(r.startAtUtc.toLocal())} → ${DateFormat('HH:mm').format(r.endAtUtc.toLocal())}'),
          _infoRow('Price', '${r.priceAmount.toStringAsFixed(2)} BAM'),
          if (r.depositAmount != null)
            _infoRow('Deposit',
                '${r.depositAmount!.toStringAsFixed(2)} BAM'),
          if (r.confirmedAtUtc != null)
            _infoRow('Confirmed at',
                DateFormat('dd.MM.yyyy HH:mm')
                    .format(r.confirmedAtUtc!.toLocal())),
          if (r.completedAtUtc != null)
            _infoRow('Completed at',
                DateFormat('dd.MM.yyyy HH:mm')
                    .format(r.completedAtUtc!.toLocal())),
          if (r.cancelledAtUtc != null)
            _infoRow('Cancelled at',
                DateFormat('dd.MM.yyyy HH:mm')
                    .format(r.cancelledAtUtc!.toLocal())),
          _infoRow('Created at',
              DateFormat('dd.MM.yyyy HH:mm')
                  .format(r.createdAtUtc.toLocal())),
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

  Widget _buildStatusHistory(TryOnReservation r) {
    if (r.statusHistory.isEmpty) return const SizedBox.shrink();

    return _card(
      icon: Icons.timeline_outlined,
      title: 'Status History',
      child: Column(
        children: r.statusHistory.asMap().entries.map((entry) {
          final h = entry.value;
          final isLast = entry.key == r.statusHistory.length - 1;
          final statusCfg = _statusConfig(h.toStatus);

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                          color: Colors.grey.shade100)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5, right: 12),
                  decoration: BoxDecoration(
                    color: statusCfg.$1,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.toStatusLabel,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: statusCfg.$1)),
                      if (h.reason != null &&
                          h.reason!.isNotEmpty)
                        Text(h.reason!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280))),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(h.changedAtUtc.toLocal()),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _cancelReservation,
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text('Cancel Reservation',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
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
            width: 100,
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

  (Color, Color, String) _statusConfig(int status) {
    switch (status) {
      case 1:
        return (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Pending');
      case 2:
        return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Confirmed');
      case 3:
        return (Colors.teal.shade700, const Color(0xFFE0F2F1), 'Checked In');
      case 4:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Completed');
      case 5:
      case 6:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Cancelled');
      case 7:
        return (Colors.grey.shade700, const Color(0xFFF5F5F5), 'No Show');
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
        return Icons.login_rounded;
      case 4:
        return Icons.task_alt_rounded;
      case 5:
      case 6:
        return Icons.cancel_rounded;
      case 7:
        return Icons.person_off_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
