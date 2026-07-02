import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/refund.dart';
import 'package:bridalglow_mobile/providers/payment_provider.dart';
import 'package:bridalglow_mobile/providers/refund_provider.dart';

const _kPrimary = Color(0xFFC2778A);

// Reason codes that a customer can choose when requesting a refund.
const _kReasonOptions = [
  {'label': 'Customer Cancellation', 'value': 1},
  {'label': 'Service Issue', 'value': 4},
  {'label': 'Other', 'value': 5},
];

class RefundStatusSection extends StatefulWidget {
  final int rentalReservationId;
  final bool showWhenEmpty;
  final bool reservationIsPaid;

  const RefundStatusSection({
    super.key,
    required this.rentalReservationId,
    this.showWhenEmpty = false,
    this.reservationIsPaid = false,
  });

  @override
  State<RefundStatusSection> createState() => _RefundStatusSectionState();
}

class _RefundStatusSectionState extends State<RefundStatusSection> {
  List<Refund> _refunds = [];
  List<int> _succeededPaymentIds = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final paymentProvider = context.read<PaymentProvider>();
      final refundProvider = context.read<RefundProvider>();

      final payments = await paymentProvider.getMine(
        rentalReservationId: widget.rentalReservationId,
        pageSize: 20,
      );

      final succeededPayments =
          payments.items.where((p) => p.isSucceeded).toList();
      final paymentIds = succeededPayments.map((p) => p.id).toList();

      final refunds =
          await refundProvider.getRefundsForReservationPayments(paymentIds);

      if (mounted) {
        setState(() {
          _succeededPaymentIds = paymentIds;
          _refunds = refunds;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _refunds = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canRequestRefund =>
      widget.reservationIsPaid &&
      _succeededPaymentIds.isNotEmpty &&
      !_refunds.any((r) => r.status == 1 || r.status == 2 || r.status == 3);

  Future<void> _openRequestRefundDialog() async {
    int selectedReasonCode = _kReasonOptions.first['value'] as int;
    final reasonTextController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.replay_outlined, color: _kPrimary, size: 22),
              SizedBox(width: 10),
              Text('Request Refund',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a reason for your refund request.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DropdownButton<int>(
                  value: selectedReasonCode,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: _kReasonOptions
                      .map((o) => DropdownMenuItem<int>(
                            value: o['value'] as int,
                            child: Text(o['label'] as String),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedReasonCode = v);
                    }
                  },
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonTextController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Additional notes (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _kPrimary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final refundProvider = context.read<RefundProvider>();
      await refundProvider.requestRefund(
        paymentId: _succeededPaymentIds.first,
        reasonCode: selectedReasonCode,
        reasonText: reasonTextController.text.trim().isEmpty
            ? null
            : reasonTextController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Refund request submitted successfully.'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        await _load();
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
          ),
        ),
      );
    }

    if (_refunds.isEmpty && !widget.showWhenEmpty) {
      return const SizedBox.shrink();
    }

    return _card(
      icon: Icons.replay_outlined,
      title: 'Refund Status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_refunds.isEmpty)
            Text(
              'No refund requests for this reservation.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            )
          else
            ..._refunds.map(_buildRefundTile),
          if (_canRequestRefund) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : _openRequestRefundDialog,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kPrimary),
                      )
                    : const Icon(Icons.replay_outlined, size: 18),
                label: const Text(
                  'Request Refund',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundTile(Refund refund) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final cfg = _refundStatusConfig(refund.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cfg.$1.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  refund.statusLabel.isNotEmpty
                      ? refund.statusLabel
                      : cfg.$3,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cfg.$1,
                  ),
                ),
              ),
              Text(
                '${refund.amount.toStringAsFixed(2)} ${refund.currency.toUpperCase()}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cfg.$1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Requested: ${fmt.format(refund.requestedAtUtc.toLocal())}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          if (refund.reasonCodeLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${refund.reasonCodeLabel}'
                  '${refund.reasonText != null && refund.reasonText!.isNotEmpty ? ' — ${refund.reasonText}' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          if (refund.processedAtUtc != null) ...[
            const SizedBox(height: 4),
            Text(
              'Processed: ${fmt.format(refund.processedAtUtc!.toLocal())}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          if (refund.failureReason != null &&
              refund.failureReason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              refund.failureReason!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
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
            offset: const Offset(0, 3),
          ),
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
                  color: const Color(0xFFFFF0F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _kPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  (Color, Color, String) _refundStatusConfig(int status) {
    switch (status) {
      case 4:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Succeeded');
      case 5:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Rejected');
      case 6:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Failed');
      case 2:
        return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Approved');
      case 3:
        return (Colors.indigo.shade700, const Color(0xFFE8EAF6), 'Processing');
      default:
        return (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Requested');
    }
  }
}
