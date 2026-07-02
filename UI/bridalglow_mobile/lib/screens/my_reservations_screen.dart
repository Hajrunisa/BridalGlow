import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/rental_reservation.dart';
import 'package:bridalglow_mobile/models/try_on_reservation.dart';
import 'package:bridalglow_mobile/providers/rental_reservation_provider.dart';
import 'package:bridalglow_mobile/providers/try_on_reservation_provider.dart';
import 'package:bridalglow_mobile/screens/rental_reservation_detail_screen.dart';
import 'package:bridalglow_mobile/screens/reservation_detail_screen.dart';

const _kPrimary = Color(0xFFC2778A);

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TryOnReservationProvider _tryOnProvider;
  late RentalReservationProvider _rentalProvider;
  late TabController _tabController;

  List<TryOnReservation> _tryOnAll = [];
  List<RentalReservation> _rentalAll = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryOnProvider = context.read<TryOnReservationProvider>();
      _rentalProvider = context.read<RentalReservationProvider>();
      _load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _tryOnProvider.getMyReservations(),
        _rentalProvider.getMyReservations(),
      ]);
      if (mounted) {
        setState(() {
          _tryOnAll = results[0] as List<TryOnReservation>;
          _rentalAll = results[1] as List<RentalReservation>;
        });
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

  List<TryOnReservation> get _activeTryOn =>
      _tryOnAll.where((r) => r.isActive).toList();
  List<TryOnReservation> get _pastTryOn =>
      _tryOnAll.where((r) => r.isCompleted || r.isNoShow).toList();
  List<TryOnReservation> get _cancelledTryOn =>
      _tryOnAll.where((r) => r.isCancelled).toList();

  List<RentalReservation> get _activeRentals =>
      _rentalAll.where((r) => r.isActive).toList();
  List<RentalReservation> get _completedRentals => _rentalAll
      .where((r) => r.isCompleted || r.isRejected || r.isRefunded)
      .toList();
  List<RentalReservation> get _cancelledRentals =>
      _rentalAll.where((r) => r.isCancelled).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: AppBar(
        title: const Text('My Reservations'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kPrimary,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: _kPrimary,
          isScrollable: true,
          tabs: [
            Tab(text: 'Active Try-On (${_activeTryOn.length})'),
            Tab(text: 'Past Try-On (${_pastTryOn.length})'),
            Tab(text: 'Cancelled Try-On (${_cancelledTryOn.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Rentals (${_activeRentals.length})'),
                  if (_activeRentals.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_activeRentals.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTryOnList(_activeTryOn),
                _buildTryOnList(_pastTryOn),
                _buildTryOnList(_cancelledTryOn),
                _buildRentalsTab(),
              ],
            ),
    );
  }

  Widget _buildTryOnList(List<TryOnReservation> items) {
    if (items.isEmpty) {
      return _buildEmptyState('No try-on reservations here');
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildTryOnCard(items[i]),
      ),
    );
  }

  Widget _buildRentalsTab() {
    if (_rentalAll.isEmpty) {
      return _buildEmptyState('No rental reservations yet');
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_activeRentals.isNotEmpty) ...[
            _sectionHeader('Active', _activeRentals.length),
            ..._activeRentals.map(_buildRentalCard),
            if (_activeRentals.any((r) => r.canPay)) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Tap a reservation with "Awaiting Payment" or "Approved" to pay.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
          if (_completedRentals.isNotEmpty) ...[
            _sectionHeader('Completed & Rejected', _completedRentals.length),
            ..._completedRentals.map(_buildRentalCard),
            const SizedBox(height: 8),
          ],
          if (_cancelledRentals.isNotEmpty) ...[
            _sectionHeader('Cancelled', _cancelledRentals.length),
            ..._cancelledRentals.map(_buildRentalCard),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildTryOnCard(TryOnReservation r) {
    final fmt = DateFormat('dd.MM.yyyy');
    final fmtTime = DateFormat('HH:mm');
    final statusCfg = _tryOnStatusConfig(r.status);

    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ReservationDetailScreen(reservationId: r.id),
          ),
        );
        if (updated == true) await _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reservationHeader(r.reservationNumber, statusCfg),
            const SizedBox(height: 10),
            _dressRow(r.dressName),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  '${fmt.format(r.startAtUtc.toLocal())} · '
                  '${fmtTime.format(r.startAtUtc.toLocal())} – '
                  '${fmtTime.format(r.endAtUtc.toLocal())}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${r.priceAmount.toStringAsFixed(2)} BAM',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3AF), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentalCard(RentalReservation r) {
    final fmt = DateFormat('dd.MM.yyyy');
    final statusCfg = _rentalStatusConfig(r.status);

    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                RentalReservationDetailScreen(reservationId: r.id),
          ),
        );
        if (updated == true) await _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reservationHeader(r.reservationNumber, statusCfg),
            const SizedBox(height: 10),
            _dressRow(r.dressName),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.date_range_outlined,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  '${fmt.format(r.startDateUtc.toLocal())} → '
                  '${fmt.format(r.endDateUtc.toLocal())}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${r.totalAmount.toStringAsFixed(2)} BAM',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5B8DB8)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3AF), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3)),
      ],
    );
  }

  Widget _reservationHeader(String number, (Color, Color, String) statusCfg) {
    return Row(
      children: [
        Expanded(
          child: Text(
            number,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
                fontFamily: 'monospace'),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: statusCfg.$2, borderRadius: BorderRadius.circular(20)),
          child: Text(statusCfg.$3,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusCfg.$1)),
        ),
      ],
    );
  }

  Widget _dressRow(String dressName) {
    return Row(
      children: [
        const Icon(Icons.checkroom_outlined,
            size: 16, color: Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(dressName,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  (Color, Color, String) _tryOnStatusConfig(int status) {
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

  (Color, Color, String) _rentalStatusConfig(int status) {
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
}
