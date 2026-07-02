import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/availability_slot.dart';
import 'package:bridalglow_mobile/models/dress.dart';
import 'package:bridalglow_mobile/models/try_on_reservation.dart';
import 'package:bridalglow_mobile/providers/dress_availability_slot_provider.dart';
import 'package:bridalglow_mobile/providers/try_on_reservation_provider.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class TryOnBookingScreen extends StatefulWidget {
  final DressDetail dress;

  const TryOnBookingScreen({super.key, required this.dress});

  @override
  State<TryOnBookingScreen> createState() => _TryOnBookingScreenState();
}

class _TryOnBookingScreenState extends State<TryOnBookingScreen> {
  late DressAvailabilitySlotProvider _slotProvider;
  late TryOnReservationProvider _reservationProvider;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<AvailabilitySlot> _freeSlots = [];
  AvailabilitySlot? _selectedSlot;
  bool _loadingSlots = false;
  bool _submitting = false;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slotProvider = context.read<DressAvailabilitySlotProvider>();
      _reservationProvider = context.read<TryOnReservationProvider>();
      _loadFreeSlots();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadFreeSlots() async {
    setState(() {
      _loadingSlots = true;
      _freeSlots = [];
      _selectedSlot = null;
    });
    try {
      final slots = await _slotProvider.getFreeSlots(
          widget.dress.id, _selectedDate);
      if (mounted) setState(() => _freeSlots = slots);
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      await _loadFreeSlots();
    }
  }

  Future<void> _submitReservation() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time slot.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Reservation',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Dress', widget.dress.name),
            _confirmRow(
                'Date',
                DateFormat('dd.MM.yyyy').format(_selectedDate)),
            _confirmRow(
                'Time',
                '${DateFormat('HH:mm').format(_selectedSlot!.startAtUtc.toLocal())} – '
                    '${DateFormat('HH:mm').format(_selectedSlot!.endAtUtc.toLocal())}'),
            _confirmRow('Price',
                '${widget.dress.tryOnPrice?.toStringAsFixed(2) ?? '—'} BAM'),
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
            child: const Text('Reserve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final reservation = await _reservationProvider.createReservation(
        dressId: widget.dress.id,
        availabilitySlotId: _selectedSlot!.id,
        appointmentDate: _selectedDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _ReservationSuccessScreen(reservation: reservation),
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
        duration: const Duration(seconds: 4),
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
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[600]))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: AppBar(
        title: const Text('Book Try-On'),
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
          _buildDateSelector(),
          const SizedBox(height: 16),
          _buildSlotSelector(),
          const SizedBox(height: 16),
          _buildNotesField(),
          const SizedBox(height: 24),
          _buildBookButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

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
              offset: const Offset(0, 3))
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
          if (widget.dress.tryOnPrice != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Try-on price',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF))),
                Text(
                  '${widget.dress.tryOnPrice!.toStringAsFixed(2)} BAM',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _kPrimary),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return _card(
      icon: Icons.calendar_today_outlined,
      title: 'Select Date',
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _kPrimaryLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kPrimary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  color: _kPrimary, size: 20),
              const SizedBox(width: 12),
              Text(
                DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937)),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  color: _kPrimary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotSelector() {
    return _card(
      icon: Icons.access_time_outlined,
      title: 'Available Time Slots',
      child: _loadingSlots
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kPrimary),
              ),
            )
          : _freeSlots.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_outlined,
                          size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'No available slots for this date.',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please try a different date.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: _freeSlots.map((slot) {
                    final isSelected = _selectedSlot?.id == slot.id;
                    final start =
                        DateFormat('HH:mm').format(slot.startAtUtc.toLocal());
                    final end =
                        DateFormat('HH:mm').format(slot.endAtUtc.toLocal());
                    final duration =
                        slot.endAtUtc.difference(slot.startAtUtc);
                    final durationLabel =
                        duration.inHours > 0
                            ? '${duration.inHours}h ${duration.inMinutes % 60}m'
                            : '${duration.inMinutes}m';

                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedSlot = slot),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _kPrimary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? _kPrimary
                                : Colors.grey.shade200,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _kPrimary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              color: isSelected
                                  ? Colors.white
                                  : _kPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$start – $end',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1F2937),
                                    ),
                                  ),
                                  Text(
                                    durationLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? Colors.white70
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }

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

  Widget _buildBookButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : _submitReservation,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.bookmark_add_outlined, size: 20),
        label: Text(
          _submitting ? 'Booking...' : 'Book Try-On Appointment',
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
}

// ── Booking Success Screen ────────────────────────────────────────────────

class _ReservationSuccessScreen extends StatelessWidget {
  final TryOnReservation reservation;

  const _ReservationSuccessScreen({required this.reservation});

  @override
  Widget build(BuildContext context) {
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
                'Reservation Created!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
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
                        'Date',
                        DateFormat('dd.MM.yyyy').format(
                            reservation.startAtUtc.toLocal())),
                    _row(
                        'Time',
                        '${DateFormat('HH:mm').format(reservation.startAtUtc.toLocal())} – '
                            '${DateFormat('HH:mm').format(reservation.endAtUtc.toLocal())}'),
                    _row('Status', 'Pending confirmation'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your appointment is pending confirmation by salon staff.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
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
                      fontSize: 13, color: Color(0xFF6B7280)))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
