import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/availability_slot.dart';
import 'package:bridalglow_mobile/models/dress.dart';
import 'package:bridalglow_mobile/models/dress_image.dart';
import 'package:bridalglow_mobile/models/review.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';
import 'package:bridalglow_mobile/providers/dress_availability_slot_provider.dart';
import 'package:bridalglow_mobile/providers/dress_image_provider.dart';
import 'package:bridalglow_mobile/providers/dress_provider.dart';
import 'package:bridalglow_mobile/providers/interaction_provider.dart';
import 'package:bridalglow_mobile/providers/review_provider.dart';
import 'package:bridalglow_mobile/widgets/similar_dresses_section.dart';
import 'package:bridalglow_mobile/screens/rental_booking_screen.dart';
import 'package:bridalglow_mobile/screens/try_on_booking_screen.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

String _resolveImageUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${BaseProvider.serverOrigin}$url';
}

class DressDetailScreen extends StatefulWidget {
  final int dressId;

  const DressDetailScreen({super.key, required this.dressId});

  @override
  State<DressDetailScreen> createState() => _DressDetailScreenState();
}

final _reviewDateFmt = DateFormat('dd.MM.yyyy');

class _DressDetailScreenState extends State<DressDetailScreen> {
  late DressProvider _dressProvider;
  late DressImageProvider _imageProvider;
  late ReviewProvider _reviewProvider;
  late DressAvailabilitySlotProvider _slotProvider;

  DressDetail? _dress;
  List<DressImage> _images = [];
  List<Review> _reviews = [];
  List<AvailabilitySlot> _rentalSlots = [];
  bool _loading = true;
  bool _loadingImages = true;
  bool _loadingRentalSlots = true;
  int _currentImageIndex = 0;

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _dressProvider = context.read<DressProvider>();
      _imageProvider = context.read<DressImageProvider>();
      _reviewProvider = context.read<ReviewProvider>();
      _slotProvider = context.read<DressAvailabilitySlotProvider>();
      _recordViewInteraction();
      await Future.wait([_loadDress(), _loadImages(), _loadRentalAvailability()]);
      await _loadReviews();
    });
  }

  void _recordViewInteraction() {
    context.read<InteractionProvider>().recordView(widget.dressId).catchError((_) {});
  }

  Future<void> _loadReviews() async {
    try {
      final reviews =
          await _reviewProvider.getPublishedByDress(widget.dressId);
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDress() async {
    setState(() => _loading = true);
    try {
      final dress = await _dressProvider.getDressById(widget.dressId);
      if (mounted) setState(() => _dress = dress);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadImages() async {
    setState(() => _loadingImages = true);
    try {
      final images = await _imageProvider.getByDressId(widget.dressId);
      if (mounted) setState(() => _images = images);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _loadRentalAvailability() async {
    setState(() => _loadingRentalSlots = true);
    try {
      final slots =
          await _slotProvider.getRentalAvailability(widget.dressId);
      if (mounted) setState(() => _rentalSlots = slots);
    } catch (_) {
      if (mounted) setState(() => _rentalSlots = []);
    } finally {
      if (mounted) setState(() => _loadingRentalSlots = false);
    }
  }

  /// Mirrors [RentalBookingScreen._isDaySelectable]: at least one future day
  /// inside an Available slot and not covered by a blocking slot.
  bool get _hasRentableAvailability {
    final available = _rentalSlots.where((s) => s.isAvailable).toList();
    final blocking = _rentalSlots.where((s) => !s.isAvailable).toList();
    if (available.isEmpty) return false;

    final today = DateTime.now();
    for (int i = 1; i <= 365; i++) {
      final day = DateTime.utc(today.year, today.month, today.day)
          .add(Duration(days: i));
      final dayEnd = day.add(const Duration(days: 1));

      final inAvailable = available.any((s) =>
          s.startAtUtc.isBefore(dayEnd) && s.endAtUtc.isAfter(day));
      if (!inAvailable) continue;

      final blocked = blocking.any((s) =>
          s.startAtUtc.isBefore(dayEnd) && s.endAtUtc.isAfter(day));
      if (!blocked) return true;
    }
    return false;
  }

  /// Mirrors [DressAvailabilitySlotService.GetFreeSlotsAsync]: at least one future
  /// day with a non-blocked Available slot within the try-on booking window.
  bool get _hasTryOnAvailability {
    if (_rentalSlots.isEmpty) return false;

    final today = DateTime.now();
    for (int i = 1; i <= 90; i++) {
      final day = DateTime.utc(today.year, today.month, today.day)
          .add(Duration(days: i));
      if (_dayHasFreeTryOnSlots(day)) return true;
    }
    return false;
  }

  bool _dayHasFreeTryOnSlots(DateTime day) {
    final dayEnd = day.add(const Duration(days: 1));
    final onDay = _rentalSlots
        .where((s) => s.startAtUtc.isBefore(dayEnd) && s.endAtUtc.isAfter(day))
        .toList();
    final available = onDay.where((s) => s.isAvailable).toList();
    if (available.isEmpty) return false;

    final blocking = onDay.where((s) => !s.isAvailable).toList();
    return available.any((slot) {
      final effectiveStart =
          slot.startAtUtc.isBefore(day) ? day : slot.startAtUtc;
      final effectiveEnd =
          slot.endAtUtc.isAfter(dayEnd) ? dayEnd : slot.endAtUtc;
      final blocked = blocking.any((b) =>
          b.startAtUtc.isBefore(effectiveEnd) &&
          b.endAtUtc.isAfter(effectiveStart));
      return !blocked;
    });
  }

  bool get _canRentDress {
    final dress = _dress;
    if (dress == null || _loadingRentalSlots) return false;
    return dress.isActiveForRental && _hasRentableAvailability;
  }

  bool get _canBookTryOn {
    if (_dress == null || _loadingRentalSlots) return false;
    return _hasTryOnAvailability;
  }

  String _rentalDisabledMessage(DressDetail dress) {
    if (dress.status == 4) {
      return 'This dress is currently out of service due to maintenance.';
    }
    if (!dress.isActiveForRental) {
      return 'The dress must have Active status to be available for '
          'rental (current status: ${dress.statusLabel}).';
    }
    if (!_hasRentableAvailability) {
      return 'No Available rental slots are defined for the upcoming period.';
    }
    return 'This dress is not currently available for rental.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _jumpToImage(int index) {
    setState(() => _currentImageIndex = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : _dress == null
              ? _buildNotFound()
              : _buildContent(),
    );
  }

  Widget _buildNotFound() {
    return Scaffold(
      appBar: AppBar(title: const Text('Dress Details')),
      body: const Center(child: Text('Dress not found.')),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(child: _buildInfoBody()),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _kPrimary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildGallery(),
      ),
    );
  }

  Widget _buildGallery() {
    if (_loadingImages) {
      return Container(
        color: _kPrimaryLight,
        child:
            const Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }

    if (_images.isEmpty) {
      return Container(
        color: _kPrimaryLight,
        child: const Center(
          child: Icon(Icons.checkroom_outlined, color: _kPrimary, size: 80),
        ),
      );
    }

    return Stack(
      children: [
        // Main swipeable gallery
        PageView.builder(
          controller: _pageController,
          itemCount: _images.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (_, i) => Image.network(
            _resolveImageUrl(_images[i].url),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: _kPrimaryLight,
              child: const Icon(Icons.broken_image_outlined,
                  color: _kPrimary, size: 60),
            ),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _kPrimaryLight,
                          Colors.white.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: _kPrimary,
                          strokeWidth: 2.5,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        // Thumbnail strip at bottom
        if (_images.length > 1)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildThumbnailStrip(),
          ),
        // Page indicator dots
        if (_images.length > 1)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(
                '${_currentImageIndex + 1} / ${_images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnailStrip() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        itemBuilder: (_, i) {
          final isSelected = i == _currentImageIndex;
          return GestureDetector(
            onTap: () => _jumpToImage(i),
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? _kPrimary : Colors.white.withValues(alpha: 0.5),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  _resolveImageUrl(_images[i].url),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image_outlined,
                        size: 16, color: Colors.white),
                  ),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          color: _kPrimaryLight,
                          child: const Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kPrimary,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoBody() {
    final dress = _dress!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleSection(dress),
          const SizedBox(height: 16),
          _buildPriceSection(dress),
          const SizedBox(height: 16),
          _buildDetailsCard(dress),
          const SizedBox(height: 12),
          if (dress.description != null && dress.description!.isNotEmpty) ...[
            _buildDescriptionCard(dress.description!),
            const SizedBox(height: 12),
          ],
          _buildMeasurementsCard(dress),
          const SizedBox(height: 12),
          _buildTagsCard(dress),
          const SizedBox(height: 12),
          if (_reviews.isNotEmpty || dress.ratingCount > 0) ...[
            _buildReviewsCard(),
            const SizedBox(height: 12),
          ],
          SimilarDressesSection(dressId: widget.dressId),
          const SizedBox(height: 12),
          if (dress.status == 4) ...[
            _buildMaintenanceWarning(),
            const SizedBox(height: 12),
          ],
          _buildRentalSection(dress),
          const SizedBox(height: 24),
          _buildReserveButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTitleSection(DressDetail dress) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dress.name,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _kPrimaryLight,
                        borderRadius: BorderRadius.circular(20),
                        border: const BorderSide(color: _kPrimary, width: 0.5)
                            .toBorderSide()),
                    child: Text(
                      dress.primaryCategoryName,
                      style: const TextStyle(
                          fontSize: 12,
                          color: _kPrimary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _statusBgColor(dress.status),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      dress.statusLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: _statusColor(dress.status),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 3),
                Text(
                  dress.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937)),
                ),
              ],
            ),
            Text(
              '${dress.ratingCount} reviews',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            if (dress.isFeatured)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 14),
                    const SizedBox(width: 3),
                    Text('Featured',
                        style: TextStyle(
                            fontSize: 11, color: Colors.amber.shade700)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceSection(DressDetail dress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, Color(0xFFD4889A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rental price',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
                Text(
                  '${dress.baseRentalPrice.toStringAsFixed(2)} BAM',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (dress.tryOnPrice != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Try-on',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
                Text(
                  '${dress.tryOnPrice!.toStringAsFixed(2)} BAM',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(DressDetail dress) {
    return _card(
      icon: Icons.info_outline_rounded,
      title: 'Details',
      child: Column(
        children: [
          _infoRow('Size', dress.sizeLabel),
          _infoRow('Color', dress.color),
          _infoRow('Condition', dress.conditionLabel),
          if (dress.brand != null) _infoRow('Brand', dress.brand!),
          if (dress.material != null) _infoRow('Material', dress.material!),
          if (dress.silhouette != null)
            _infoRow('Silhouette', dress.silhouette!),
          if (dress.neckline != null) _infoRow('Neckline', dress.neckline!),
          if (dress.sleeveType != null)
            _infoRow('Sleeves', dress.sleeveType!),
          if (dress.trainLength != null)
            _infoRow('Train', dress.trainLength!),
          if (dress.depositAmount != null)
            _infoRow('Deposit',
                '${dress.depositAmount!.toStringAsFixed(2)} BAM'),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(String description) {
    return _card(
      icon: Icons.text_snippet_outlined,
      title: 'Description',
      child: Text(
        description,
        style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            height: 1.6),
      ),
    );
  }

  Widget _buildMeasurementsCard(DressDetail dress) {
    final hasMeasurements = dress.bustCm != null ||
        dress.waistCm != null ||
        dress.hipCm != null ||
        dress.lengthCm != null;
    if (!hasMeasurements) return const SizedBox.shrink();

    return _card(
      icon: Icons.straighten_outlined,
      title: 'Measurements',
      child: Column(
        children: [
          if (dress.bustCm != null)
            _infoRow('Bust', '${dress.bustCm!.toStringAsFixed(1)} cm'),
          if (dress.waistCm != null)
            _infoRow('Waist', '${dress.waistCm!.toStringAsFixed(1)} cm'),
          if (dress.hipCm != null)
            _infoRow('Hip', '${dress.hipCm!.toStringAsFixed(1)} cm'),
          if (dress.lengthCm != null)
            _infoRow('Length', '${dress.lengthCm!.toStringAsFixed(1)} cm'),
        ],
      ),
    );
  }

  Widget _buildTagsCard(DressDetail dress) {
    if (dress.tags.isEmpty) return const SizedBox.shrink();

    return _card(
      icon: Icons.sell_outlined,
      title: 'Tags',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: dress.tags
            .map((t) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kPrimaryLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _kPrimary.withValues(alpha: 0.4)),
                  ),
                  child: Text(t.name,
                      style: const TextStyle(
                          fontSize: 12,
                          color: _kPrimary,
                          fontWeight: FontWeight.w500)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMaintenanceWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.build_rounded,
              color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dress currently unavailable',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800),
                ),
                const SizedBox(height: 4),
                Text(
                  'This dress is currently out of service due to maintenance. '
                  'Please check again soon.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsCard() {
    return _card(
      icon: Icons.star_rounded,
      title: 'Customer reviews',
      child: _reviews.isEmpty
          ? Text(
              'No reviews for this dress yet.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.5),
            )
          : Column(
              children: _reviews.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                          height: 24,
                          color: Colors.grey.withValues(alpha: 0.15)),
                    _buildReviewItem(r),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildReviewItem(Review r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Star rating
            ...List.generate(
              5,
              (i) => Icon(
                i < r.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: Colors.amber,
                size: 16,
              ),
            ),
            const Spacer(),
            Text(
              _reviewDateFmt.format(r.createdAtUtc.toLocal()),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          r.customerName,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280)),
        ),
        if (r.title != null && r.title!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            r.title!,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937)),
          ),
        ],
        if (r.comment != null && r.comment!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            r.comment!,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5),
          ),
        ],
        if (r.staffReply != null && r.staffReply!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Salon reply:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  r.staffReply!,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRentalSection(DressDetail dress) {
    return _card(
      icon: Icons.shopping_bag_outlined,
      title: 'Rent This Dress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Base rental price',
              '${dress.baseRentalPrice.toStringAsFixed(2)} BAM'),
          if (dress.depositAmount != null)
            _infoRow('Deposit',
                '${dress.depositAmount!.toStringAsFixed(2)} BAM'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canRentDress
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RentalBookingScreen(dress: dress),
                        ),
                      );
                    }
                  : null,
              icon: _loadingRentalSlots
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.shopping_bag_outlined, size: 20),
              label: const Text('Rent This Dress',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B8DB8),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          if (!_canRentDress && !_loadingRentalSlots)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _rentalDisabledMessage(dress),
                style: TextStyle(
                    fontSize: 12,
                    color: dress.status == 4
                        ? Colors.orange.shade700
                        : Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReserveButton() {
    final dress = _dress;
    if (dress == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _canBookTryOn
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TryOnBookingScreen(dress: dress),
                      ),
                    );
                  }
                : null,
            icon: _loadingRentalSlots
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bookmark_add_outlined, size: 20),
            label: const Text('Book Try-On Appointment',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        if (!_canBookTryOn && !_loadingRentalSlots)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No try-on appointment slots are currently available.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return const Color(0xFF6B7280);
      case 2:
        return const Color(0xFF16A34A);
      case 3:
        return const Color(0xFF2563EB);
      case 4:
        return const Color(0xFFD97706);
      case 5:
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _statusBgColor(int status) {
    switch (status) {
      case 2:
        return const Color(0xFFDCFCE7);
      case 3:
        return const Color(0xFFDBEAFE);
      case 4:
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFF3F4F6);
    }
  }
}

// Extension helper for building a border side inline
extension _BorderSideHelper on BorderSide {
  Border toBorderSide() => Border.fromBorderSide(this);
}
