import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/payment.dart';
import 'package:bridalglow_mobile/models/rental_reservation.dart';
import 'package:bridalglow_mobile/providers/payment_provider.dart';
import 'package:bridalglow_mobile/providers/user_provider.dart';
import 'package:bridalglow_mobile/screens/payment_success_screen.dart';
import 'package:bridalglow_mobile/utils/payment_intent_cache.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryDark = Color(0xFFA85F72);

class StripePaymentScreen extends StatefulWidget {
  final RentalReservation reservation;

  const StripePaymentScreen({super.key, required this.reservation});

  @override
  State<StripePaymentScreen> createState() => _StripePaymentScreenState();
}

class _StripePaymentScreenState extends State<StripePaymentScreen> {
  final formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  int? _paymentId;

  final _inputDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kPrimary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fillDemoData,
            icon: const Icon(Icons.auto_fix_high_rounded, color: _kPrimary),
            tooltip: 'Fill demo data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _kPrimary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: FormBuilder(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAmountCard(),
                    const SizedBox(height: 24),
                    _buildReservationDetails(),
                    const SizedBox(height: 24),
                    _buildBillingSection(),
                    const SizedBox(height: 32),
                    _buildPayButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAmountCard() {
    final currency = widget.reservation.currency.toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payments_outlined, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                'Total Amount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.reservation.totalAmount.toStringAsFixed(2)} $currency',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.reservation.reservationNumber,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationDetails() {
    final fmt = DateFormat('dd.MM.yyyy');
    return _sectionCard(
      icon: Icons.checkroom_outlined,
      title: 'Rental Details',
      child: Column(
        children: [
          _detailRow('Dress', widget.reservation.dressName),
          _detailRow('Code', widget.reservation.dressCode),
          _detailRow(
            'Period',
            '${fmt.format(widget.reservation.startDateUtc.toLocal())} → '
                '${fmt.format(widget.reservation.endDateUtc.toLocal())}',
          ),
        ],
      ),
    );
  }

  Widget _buildBillingSection() {
    final user = UserProvider.currentUser;
    return _sectionCard(
      icon: Icons.receipt_long_outlined,
      title: 'Billing Information',
      child: Column(
        children: [
          FormBuilderTextField(
            name: 'name',
            initialValue: user?.fullName ?? '',
            decoration: _inputDecoration.copyWith(labelText: 'Full Name'),
            validator: FormBuilderValidators.required(),
          ),
          const SizedBox(height: 14),
          FormBuilderTextField(
            name: 'address',
            decoration: _inputDecoration.copyWith(labelText: 'Address'),
            validator: FormBuilderValidators.required(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FormBuilderTextField(
                  name: 'city',
                  decoration: _inputDecoration.copyWith(labelText: 'City'),
                  validator: FormBuilderValidators.required(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormBuilderTextField(
                  name: 'state',
                  decoration: _inputDecoration.copyWith(labelText: 'State'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FormBuilderTextField(
                  name: 'country',
                  decoration: _inputDecoration.copyWith(labelText: 'Country'),
                  validator: FormBuilderValidators.required(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormBuilderTextField(
                  name: 'pincode',
                  decoration: _inputDecoration.copyWith(labelText: 'ZIP Code'),
                  validator: FormBuilderValidators.required(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
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
              Icon(icon, color: _kPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        icon: const Icon(Icons.lock_outline_rounded),
        label: const Text(
          'Proceed to Payment',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          if (formKey.currentState?.saveAndValidate() ?? false) {
            await _processPayment();
          }
        },
      ),
    );
  }

  Future<PaymentIntentData> _resolvePaymentIntent(
    PaymentProvider paymentProvider,
  ) async {
    final reservationId = widget.reservation.id;
    final isApproved = widget.reservation.status == 2;
    final isAwaitingPayment = widget.reservation.status == 4;

    if (isApproved) {
      final data = await paymentProvider.createPaymentIntent(reservationId);
      await PaymentIntentCache.save(reservationId, data);
      return data;
    }

    if (isAwaitingPayment) {
      final cached = await PaymentIntentCache.load(reservationId);
      if (cached != null) return cached;

      final pending =
          await paymentProvider.getPendingPaymentForReservation(reservationId);
      if (pending != null) {
        final sync = await paymentProvider.syncPayment(pending.id);
        if (sync.isPaymentSucceeded || sync.isRentalPaid) {
          throw _PaymentAlreadyCompletedException();
        }
      }

      throw Exception(
        'Payment session expired. Please contact salon staff to reset the payment.',
      );
    }

    throw Exception('This reservation is not eligible for payment.');
  }

  Future<void> _initPaymentSheet(PaymentIntentData data) async {
    _paymentId = data.paymentId;
    await stripe.Stripe.instance.initPaymentSheet(
      paymentSheetParameters: stripe.SetupPaymentSheetParameters(
        customFlow: false,
        merchantDisplayName: 'BridalGlow',
        paymentIntentClientSecret: data.clientSecret,
        customerEphemeralKeySecret: data.ephemeralKey,
        customerId: data.customerId,
        style: ThemeMode.light,
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);
    final paymentProvider = context.read<PaymentProvider>();

    try {
      final intentData = await _resolvePaymentIntent(paymentProvider);
      await _initPaymentSheet(intentData);
      await stripe.Stripe.instance.presentPaymentSheet();

      if (_paymentId != null) {
        await paymentProvider.syncPayment(_paymentId!);
      }

      await PaymentIntentCache.clear(widget.reservation.id);

      if (!mounted) return;
      setState(() => _isLoading = false);

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            reservationNumber: widget.reservation.reservationNumber,
            dressName: widget.reservation.dressName,
            amount: widget.reservation.totalAmount,
            currency: widget.reservation.currency,
          ),
        ),
      );

      if (mounted) Navigator.pop(context, paid ?? true);
    } on _PaymentAlreadyCompletedException {
      await PaymentIntentCache.clear(widget.reservation.id);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop(true);
      }
    } on stripe.StripeException catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (e.error.code == stripe.FailureCode.Canceled) {
        _showSnack('Payment was canceled.', Colors.amber.shade800);
      } else {
        _showSnack(
          'Payment failed: ${e.error.localizedMessage ?? e.error.message}',
          Colors.red.shade700,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        Colors.red.shade700,
      );
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _fillDemoData() {
    final formState = formKey.currentState;
    if (formState == null) return;

    final user = UserProvider.currentUser;
    formState.fields['name']?.didChange(user?.fullName ?? 'Jane Doe');
    formState.fields['address']?.didChange('123 Bridal Street');
    formState.fields['city']?.didChange('Sarajevo');
    formState.fields['state']?.didChange('KS');
    formState.fields['country']?.didChange('Bosnia and Herzegovina');
    formState.fields['pincode']?.didChange('71000');
    formState.save();
  }
}

class _PaymentAlreadyCompletedException implements Exception {}
