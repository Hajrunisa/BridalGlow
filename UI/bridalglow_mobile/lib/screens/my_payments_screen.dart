import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/payment.dart';
import 'package:bridalglow_mobile/providers/payment_provider.dart';

const _kPrimary = Color(0xFFC2778A);

class MyPaymentsScreen extends StatefulWidget {
  const MyPaymentsScreen({super.key});

  @override
  State<MyPaymentsScreen> createState() => _MyPaymentsScreenState();
}

class _MyPaymentsScreenState extends State<MyPaymentsScreen> {
  late PaymentProvider _provider;
  List<Payment> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<PaymentProvider>();
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _provider.getMine(pageSize: 100);
      if (mounted) {
        setState(() => _payments = result.items);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
        title: const Text('My Payments'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _payments.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: _kPrimary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payments.length,
                    itemBuilder: (_, i) => _buildPaymentCard(_payments[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No payments yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final statusCfg = _statusConfig(payment.status);
    final when = payment.paidAtUtc ?? payment.createdAtUtc;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.reservationNumber ?? 'Payment #${payment.id}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusCfg.$2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  payment.statusLabel.isNotEmpty
                      ? payment.statusLabel
                      : statusCfg.$3,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusCfg.$1,
                  ),
                ),
              ),
            ],
          ),
          if (payment.dressName != null && payment.dressName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.checkroom_outlined,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    payment.dressName!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${payment.amount.toStringAsFixed(2)} ${payment.currency.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                ),
              ),
              Text(
                fmt.format(when.toLocal()),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          if (payment.failedReason != null &&
              payment.failedReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payment.failedReason!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color, String) _statusConfig(int status) {
    switch (status) {
      case 4:
        return (Colors.green.shade700, const Color(0xFFE8F5E9), 'Succeeded');
      case 5:
        return (Colors.red.shade700, const Color(0xFFFFEBEE), 'Failed');
      case 6:
        return (Colors.grey.shade700, const Color(0xFFF5F5F5), 'Cancelled');
      case 7:
        return (Colors.grey.shade700, const Color(0xFFF5F5F5), 'Expired');
      case 3:
        return (Colors.blue.shade700, const Color(0xFFE3F2FD), 'Processing');
      case 2:
        return (Colors.orange.shade700, const Color(0xFFFFF3E0), 'Requires Action');
      default:
        return (Colors.amber.shade800, const Color(0xFFFFF8E1), 'Created');
    }
  }
}
