import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/availability_slot.dart';
import 'package:bridalglow_mobile/models/dress.dart';
import 'package:bridalglow_mobile/models/dress_price_rule.dart';
import 'package:bridalglow_mobile/models/rental_reservation.dart';
import 'package:bridalglow_mobile/providers/dress_availability_slot_provider.dart';
import 'package:bridalglow_mobile/providers/dress_price_rule_provider.dart';
import 'package:bridalglow_mobile/providers/rental_reservation_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class RentalBookingScreen extends StatefulWidget {
  final DressDetail dress;

  const RentalBookingScreen({super.key, required this.dress});

  @override
  State<RentalBookingScreen> createState() => _RentalBookingScreenState();
}

class _RentalBookingScreenState extends State<RentalBookingScreen> {
  late DressPriceRuleProvider _priceProvider;
  late RentalReservationProvider _reservationProvider;
  late DressAvailabilitySlotProvider _slotProvider;

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  EffectivePrice? _effectivePrice;
  bool _loadingPrice = false;
  bool _loadingSlots = true;
  bool _submitting = false;
  final _notesController = TextEditingController();

  List<AvailabilitySlot> _allSlots = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _priceProvider = context.read<DressPriceRuleProvider>();
      _reservationProvider = context.read<RentalReservationProvider>();
      _slotProvider = context.read<DressAvailabilitySlotProvider>();
      _loadData();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ── UTC helpers ────────────────────────────────────────────────────────────

  DateTime get _startUtc =>
      DateTime.utc(_startDate.year, _startDate.month, _startDate.day);

  DateTime get _endUtc =>
      DateTime.utc(_endDate.year, _endDate.month, _endDate.day);

  int get _rentalDays => _endUtc.difference(_startUtc).inDays;

  // ── Availability helpers ───────────────────────────────────────────────────

  List<AvailabilitySlot> get _availableSlots =>
      _allSlots.where((s) => s.isAvailable).toList();

  List<AvailabilitySlot> get _blockingSlots =>
      _allSlots.where((s) => !s.isAvailable).toList();

  List<AvailabilitySlot> _slotsOfType(int type) =>
      _allSlots.where((s) => s.slotType == type).toList();

  bool _isDayWithinAvailable(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    final dEnd = d.add(const Duration(days: 1));
    return _availableSlots
        .any((s) => s.startAtUtc.isBefore(dEnd) && s.endAtUtc.isAfter(d));
  }

  bool _isDayBlocked(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    final dEnd = d.add(const Duration(days: 1));
    return _blockingSlots
        .any((s) => s.startAtUtc.isBefore(dEnd) && s.endAtUtc.isAfter(d));
  }

  /// A day is selectable only when it falls inside an Available slot and is
  /// not covered by any blocking slot (RentalHold / TryOnHold / Blocked /
  /// MaintenanceBlock).  When no Available slots exist at all, every day is
  /// disabled — the backend will also reject such a booking.
  bool _isDaySelectable(DateTime day) {
    if (_availableSlots.isEmpty) return false;
    return _isDayWithinAvailable(day) && !_isDayBlocked(day);
  }

  /// Returns true when every calendar day in the rental window is selectable.
  /// Uses the same day-level overlap rules as the backend
  /// [ValidateRentalPeriodAsync] — not exact timestamp containment.
  bool get _isRangeValid {
    if (_availableSlots.isEmpty || _rentalDays < 1) return false;
    for (int i = 0; i < _rentalDays; i++) {
      final day = DateTime(
              _startDate.year, _startDate.month, _startDate.day)
          .add(Duration(days: i));
      if (!_isDaySelectable(day)) return false;
    }
    return true;
  }

  /// End date is the return day; only the rented days [start, end) must be
  /// within Available and free of blocks — matching backend validation.
  bool _isEndDateSelectable(DateTime day) {
    final startDay = DateTime(
        _startDate.year, _startDate.month, _startDate.day);
    final endDay =
        DateTime(day.year, day.month, day.day);
    if (!endDay.isAfter(startDay)) return false;
    final rentalDays = endDay.difference(startDay).inDays;
    if (rentalDays < 1) return false;
    for (int i = 0; i < rentalDays; i++) {
      if (!_isDaySelectable(startDay.add(Duration(days: i)))) return false;
    }
    return true;
  }

  /// Moves start/end to the first valid selectable range when the current
  /// selection falls outside available periods.
  void _snapDatesToAvailability() {
    if (_availableSlots.isEmpty) return;
    if (_isRangeValid && _isDaySelectable(_startDate)) return;

    final today = DateTime.now();
    for (int i = 1; i <= 365; i++) {
      final day = DateTime(today.year, today.month, today.day)
          .add(Duration(days: i));
      if (_isDaySelectable(day)) {
        setState(() {
          _startDate = day;
          _endDate = day.add(const Duration(days: 1));
        });
        return;
      }
    }
  }

  // ── Price helpers ──────────────────────────────────────────────────────────

  double get _baseAmount =>
      _effectivePrice?.baseRentalPrice ?? widget.dress.baseRentalPrice;

  double get _discountAmount {
    if (_effectivePrice == null) return 0;
    return (_effectivePrice!.baseRentalPrice - _effectivePrice!.effectivePrice)
        .clamp(0, double.infinity);
  }

  double get _rentalTotal =>
      _effectivePrice?.effectivePrice ?? widget.dress.baseRentalPrice;

  double get _depositAmount => widget.dress.depositAmount ?? 0;

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    await _loadSlots();
    if (mounted) await _loadEffectivePrice();
  }

  Future<void> _loadSlots() async {
    setState(() => _loadingSlots = true);
    try {
      final slots = await _slotProvider.getRentalAvailability(widget.dress.id);
      if (mounted) {
        setState(() => _allSlots = slots);
        _snapDatesToAvailability();
      }
    } catch (_) {
      if (mounted) setState(() => _allSlots = []);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _loadEffectivePrice() async {
    if (_rentalDays < 1) {
      setState(() => _effectivePrice = null);
      return;
    }
    setState(() => _loadingPrice = true);
    try {
      final price = await _priceProvider.getEffectivePrice(
        dressId: widget.dress.id,
        startAt: _startUtc,
        endAt: _endUtc,
      );
      if (mounted) setState(() => _effectivePrice = price);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  // ── Date picking ───────────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    final firstSelectable = _firstSelectableDay(today);

    final picked = await showDatePicker(
      context: context,
      initialDate: firstSelectable,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
      selectableDayPredicate: _loadingSlots ? null : _isDaySelectable,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _startDate = picked;
      if (!_endDate.isAfter(_startDate)) {
        _endDate = _startDate.add(const Duration(days: 1));
      }
    });
    await _loadEffectivePrice();
  }

  Future<void> _pickEndDate() async {
    final minEnd = _startDate.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(minEnd) ? minEnd : _endDate,
      firstDate: minEnd,
      lastDate: _startDate.add(const Duration(days: 365)),
      selectableDayPredicate: _loadingSlots ? null : _isEndDateSelectable,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _endDate = picked);
    await _loadEffectivePrice();
  }

  /// Returns the first future day that is selectable, or tomorrow if none.
  DateTime _firstSelectableDay(DateTime today) {
    for (int i = 1; i <= 365; i++) {
      final candidate = today.add(Duration(days: i));
      if (_isDaySelectable(candidate)) return candidate;
    }
    return today.add(const Duration(days: 1));
  }

  // ── Submission ─────────────────────────────────────────────────────────────

  Future<void> _submitReservation() async {
    if (_rentalDays < 1) {
      _showError('Minimum rental period is 1 day.');
      return;
    }
    if (!_isRangeValid) {
      _showError(
          'The selected period is not fully within an available slot. Please select dates within a highlighted available period.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Rental',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Dress', widget.dress.name),
            _confirmRow(
              'Period',
              '${DateFormat('dd.MM.yyyy').format(_startDate)} → '
                  '${DateFormat('dd.MM.yyyy').format(_endDate)}',
            ),
            _confirmRow('Days', '$_rentalDays'),
            _confirmRow('Total', '${_rentalTotal.toStringAsFixed(2)} BAM'),
            if (_depositAmount > 0)
              _confirmRow(
                  'Deposit', '${_depositAmount.toStringAsFixed(2)} BAM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Back', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final reservation = await _reservationProvider.createReservation(
        dressId: widget.dress.id,
        startDateUtc: _startUtc,
        endDateUtc: _endUtc,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _RentalSuccessScreen(reservation: reservation),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: AppBar(
        title: const Text('Rent This Dress'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDressCard(),
          const SizedBox(height: 16),
          _buildAvailabilityCard(),
          const SizedBox(height: 16),
          _buildDateRangeSelector(),
          const SizedBox(height: 16),
          _buildPriceSummary(),
          const SizedBox(height: 16),
          _buildNotesField(),
          const SizedBox(height: 24),
          _buildConfirmButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Dress card ─────────────────────────────────────────────────────────────

  Widget _buildDressCard() {
    return Container(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.checkroom_outlined,
                color: _kPrimary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.dress.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
                Text(widget.dress.code,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Availability card ──────────────────────────────────────────────────────

  Widget _buildAvailabilityCard() {
    return _card(
      icon: Icons.event_available_outlined,
      title: 'Rental Availability',
      child: _loadingSlots
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: _kPrimary),
              ),
            )
          : _availableSlots.isEmpty
              ? Row(
                  children: [
                    Icon(Icons.block_outlined,
                        color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No available periods defined for this dress. Please check back later.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _availabilitySection(
                      title: 'Available periods',
                      color: Colors.green.shade700,
                      bgColor: Colors.green.shade50,
                      dotColor: Colors.green.shade500,
                      slots: _availableSlots,
                    ),
                    if (_slotsOfType(2).isNotEmpty)
                      _availabilitySection(
                        title: 'Blocked',
                        color: Colors.red.shade700,
                        bgColor: Colors.red.shade50,
                        dotColor: Colors.red.shade400,
                        slots: _slotsOfType(2),
                      ),
                    if (_slotsOfType(4).isNotEmpty)
                      _availabilitySection(
                        title: 'Rental Hold (already booked)',
                        color: Colors.orange.shade800,
                        bgColor: Colors.orange.shade50,
                        dotColor: Colors.orange.shade500,
                        slots: _slotsOfType(4),
                      ),
                    if (_slotsOfType(3).isNotEmpty)
                      _availabilitySection(
                        title: 'Try-On Hold',
                        color: Colors.deepPurple.shade700,
                        bgColor: Colors.deepPurple.shade50,
                        dotColor: Colors.deepPurple.shade400,
                        slots: _slotsOfType(3),
                      ),
                    if (_slotsOfType(5).isNotEmpty)
                      _availabilitySection(
                        title: 'Maintenance',
                        color: Colors.grey.shade700,
                        bgColor: Colors.grey.shade100,
                        dotColor: Colors.grey.shade500,
                        slots: _slotsOfType(5),
                      ),
                  ],
                ),
    );
  }

  String _formatSlotRange(AvailabilitySlot s) {
    final fmt = DateFormat('dd MMM yyyy');
    final start = fmt.format(s.startAtUtc.toLocal());
    final end = fmt.format(s.endAtUtc.toLocal());
    return '$start – $end';
  }

  Widget _availabilitySection({
    required String title,
    required Color color,
    required Color bgColor,
    required Color dotColor,
    required List<AvailabilitySlot> slots,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...slots.map((s) => _availabilityChip(
                label: _formatSlotRange(s),
                color: color,
                bgColor: bgColor,
              )),
        ],
      ),
    );
  }

  Widget _availabilityChip(
      {required String label, required Color color, required Color bgColor}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ── Date range selector ────────────────────────────────────────────────────

  Widget _buildDateRangeSelector() {
    final fmt = DateFormat('EEEE, dd MMMM yyyy');
    final rangeError = !_loadingSlots && _rentalDays >= 1 && !_isRangeValid;

    return _card(
      icon: Icons.date_range_outlined,
      title: 'Rental Period',
      child: Column(
        children: [
          if (!_loadingSlots && _availableSlots.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Date selection is disabled — no available periods have been defined for this dress.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          _dateTile(
            label: 'Start date',
            value: fmt.format(_startDate),
            onTap: _loadingSlots ? null : _pickStartDate,
          ),
          const SizedBox(height: 10),
          _dateTile(
            label: 'End date',
            value: fmt.format(_endDate),
            onTap: _loadingSlots ? null : _pickEndDate,
          ),
          if (_rentalDays >= 1) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: rangeError
                    ? Colors.red.shade50
                    : _kPrimaryLight,
                borderRadius: BorderRadius.circular(8),
                border: rangeError
                    ? Border.all(color: Colors.red.shade200)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    rangeError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 16,
                    color: rangeError ? Colors.red.shade700 : _kPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rangeError
                          ? 'The selected period is not within an available slot.'
                          : 'Duration: $_rentalDays day${_rentalDays == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            rangeError ? Colors.red.shade700 : _kPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : _kPrimaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade300
                : _kPrimary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                color: disabled ? Colors.grey.shade400 : _kPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: disabled
                              ? Colors.grey.shade400
                              : Colors.grey.shade600)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: disabled
                              ? Colors.grey.shade500
                              : const Color(0xFF1F2937))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: disabled ? Colors.grey.shade300 : _kPrimary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Price summary ──────────────────────────────────────────────────────────

  Widget _buildPriceSummary() {
    return _card(
      icon: Icons.receipt_long_outlined,
      title: 'Price Summary',
      child: _loadingPrice
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _kPrimary),
              ),
            )
          : Column(
              children: [
                _priceRow('Base Amount', _baseAmount),
                if (_discountAmount > 0)
                  _priceRow('Discount', -_discountAmount, isDiscount: true),
                if (_depositAmount > 0)
                  _priceRow('Deposit', _depositAmount),
                const Divider(height: 20),
                _priceRow('Total', _rentalTotal, isTotal: true),
                if (_effectivePrice?.appliedRule != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_offer_outlined,
                            size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_effectivePrice!.appliedRule!.ruleTypeLabel} price applied',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _priceRow(String label, double amount,
      {bool isDiscount = false, bool isTotal = false}) {
    final prefix = isDiscount ? '–' : '';
    final value = '$prefix${amount.abs().toStringAsFixed(2)} BAM';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal
                  ? const Color(0xFF1F2937)
                  : const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.w700,
              color: isDiscount
                  ? Colors.green.shade700
                  : (isTotal ? _kPrimary : const Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notes field ────────────────────────────────────────────────────────────

  Widget _buildNotesField() {
    return _card(
      icon: Icons.notes_outlined,
      title: 'Notes (optional)',
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Any special requests or notes...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kPrimary, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  // ── Confirm button ─────────────────────────────────────────────────────────

  Widget _buildConfirmButton() {
    final canSubmit = !_submitting &&
        !_loadingPrice &&
        !_loadingSlots &&
        _rentalDays >= 1 &&
        _isRangeValid;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canSubmit ? _submitReservation : null,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.shopping_bag_outlined, size: 20),
        label: Text(
          _submitting ? 'Booking...' : 'Confirm Rental',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Card wrapper ───────────────────────────────────────────────────────────

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
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
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
}

// ── Rental Success Screen ─────────────────────────────────────────────────

class _RentalSuccessScreen extends StatelessWidget {
  final RentalReservation reservation;

  const _RentalSuccessScreen({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    color: Colors.green.shade600, size: 72),
              ),
              const SizedBox(height: 24),
              const Text(
                'Rental Reservation Created!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                reservation.reservationNumber,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _row('Dress', reservation.dressName),
                    _row(
                      'Period',
                      '${fmt.format(reservation.startDateUtc.toLocal())} → '
                          '${fmt.format(reservation.endDateUtc.toLocal())}',
                    ),
                    _row('Total',
                        '${reservation.totalAmount.toStringAsFixed(2)} BAM'),
                    _row('Status', 'Pending approval'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your rental reservation is pending approval by salon staff.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Back to Home',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
