import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_desktop/models/dress.dart';
import 'package:bridalglow_desktop/models/dress_image.dart';
import 'package:bridalglow_desktop/providers/base_provider.dart';
import 'package:bridalglow_desktop/providers/dress_image_provider.dart';
import 'package:bridalglow_desktop/providers/dress_provider.dart';
import 'package:bridalglow_desktop/screens/dress_form_screen.dart';

/// Converts a relative path like "/uploads/…" to a full URL.
/// Absolute URLs (http/https) are returned unchanged.
String _resolveImageUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${BaseProvider.serverOrigin}$url';
}

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);

class DressDetailScreen extends StatefulWidget {
  final int dressId;

  const DressDetailScreen({super.key, required this.dressId});

  @override
  State<DressDetailScreen> createState() => _DressDetailScreenState();
}

class _DressDetailScreenState extends State<DressDetailScreen> {
  late DressProvider _dressProvider;
  late DressImageProvider _imageProvider;

  DressDetail? _dress;
  List<DressImage> _images = [];
  bool _loadingDress = true;
  bool _loadingImages = false;
  bool _actionInProgress = false;

  bool _changed = false; // track if list screen should refresh

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _dressProvider = context.read<DressProvider>();
      _imageProvider = context.read<DressImageProvider>();
      await Future.wait([_loadDress(), _loadImages()]);
    });
  }

  Future<void> _loadDress() async {
    setState(() => _loadingDress = true);
    try {
      final dress = await _dressProvider.getDressById(widget.dressId);
      if (mounted) setState(() => _dress = dress);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingDress = false);
    }
  }

  Future<void> _loadImages() async {
    setState(() => _loadingImages = true);
    try {
      final images = await _imageProvider.getByDressId(widget.dressId);
      if (mounted) setState(() => _images = images);
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _openEdit() async {
    if (_dress == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DressFormScreen(dress: _dress)),
    );
    if (saved == true) {
      _changed = true;
      await _loadDress();
    }
  }

  // ── Image actions ─────────────────────────────────────────────────────────

  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final mimeType = _mimeFromExtension(file.extension ?? 'jpg');

    setState(() => _actionInProgress = true);
    try {
      await _imageProvider.uploadImage(
        dressId: widget.dressId,
        bytes: file.bytes!,
        filename: file.name,
        mimeType: mimeType,
        isPrimary: _images.isEmpty,
        sortOrder: _images.length,
      );
      await _loadImages();
      _changed = true;
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _linkImageByUrl() async {
    final result = await showDialog<_LinkResult>(
      context: context,
      builder: (_) => const _LinkImageDialog(),
    );
    if (result == null) return;

    setState(() => _actionInProgress = true);
    try {
      await _imageProvider.linkImage(
        dressId: widget.dressId,
        url: result.url,
        altText: result.altText,
        isPrimary: _images.isEmpty,
        sortOrder: _images.length,
      );
      await _loadImages();
      _changed = true;
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _setPrimary(DressImage image) async {
    setState(() => _actionInProgress = true);
    try {
      await _imageProvider.setPrimary(image.id);
      await _loadImages();
      _changed = true;
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _moveImage(DressImage image, int direction) async {
    final idx = _images.indexOf(image);
    final newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= _images.length) return;

    setState(() => _actionInProgress = true);
    try {
      // Swap sort orders
      await Future.wait([
        _imageProvider.reorderImage(image.id, _images[newIdx].sortOrder),
        _imageProvider.reorderImage(
            _images[newIdx].id, _images[idx].sortOrder),
      ]);
      await _loadImages();
      _changed = true;
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _deleteImage(DressImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Image',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            'Are you sure you want to delete this image?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _actionInProgress = true);
    try {
      await _imageProvider.deleteImage(image.id);
      await _loadImages();
      _changed = true;
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 22),
            SizedBox(width: 10),
            Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F5),
      appBar: _buildAppBar(),
      body: _loadingDress
          ? const Center(
              child: CircularProgressIndicator(color: _kPrimary))
          : _dress == null
              ? const Center(child: Text('Dress not found.'))
              : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kPrimary, size: 18),
        ),
        onPressed: () => Navigator.pop(context, _changed),
      ),
      title: Text(
        _dress?.name ?? 'Dress Details',
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937)),
      ),
      actions: [
        if (_dress != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    final dress = _dress!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: dress info (~50%)
          Expanded(
            child: Column(
              children: [
                _buildInfoCard(dress),
                const SizedBox(height: 20),
                _buildMetricsCard(dress),
                const SizedBox(height: 20),
                _buildMeasurementsInfoCard(dress),
                const SizedBox(height: 20),
                _buildTagsInfoCard(dress),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right column: image gallery (~50%)
          Expanded(
            child: _buildImageGallery(),
          ),
        ],
      ),
    );
  }

  // ── Info cards ────────────────────────────────────────────────────────────

  Widget _buildInfoCard(DressDetail dress) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.checkroom_outlined, 'Dress Information'),
          const SizedBox(height: 16),
          _infoRow('Name', dress.name),
          _infoRow('Code', dress.code),
          _infoRow('Color', dress.color),
          if (dress.brand != null) _infoRow('Brand', dress.brand!),
          if (dress.material != null) _infoRow('Material', dress.material!),
          if (dress.silhouette != null) _infoRow('Silhouette', dress.silhouette!),
          if (dress.neckline != null) _infoRow('Neckline', dress.neckline!),
          if (dress.sleeveType != null) _infoRow('Sleeve Type', dress.sleeveType!),
          if (dress.trainLength != null) _infoRow('Train Length', dress.trainLength!),
          if (dress.description != null && dress.description!.isNotEmpty)
            _infoRowMultiLine('Description', dress.description!),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _badgeRow('Status', dress.statusLabel, _statusColor(dress.status)),
              ),
              Expanded(
                child: _badgeRow('Condition', dress.conditionLabel, Colors.blue.shade700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _badgeRow('Category', dress.primaryCategoryName, _kPrimary),
              ),
              if (dress.isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text('Featured',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(DressDetail dress) {
    final fmt = NumberFormat.currency(symbol: 'BAM ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.bar_chart_rounded, 'Metrics & Pricing'),
          const SizedBox(height: 16),
          _infoRow('Added on', dateFmt.format(dress.createdAtUtc.toLocal())),
          if (dress.updatedAtUtc != null)
            _infoRow('Last updated',
                dateFmt.format(dress.updatedAtUtc!.toLocal())),
          _infoRow('Images', _images.length.toString()),
          _infoRow('Rating',
              '${dress.averageRating.toStringAsFixed(1)} ★  (${dress.ratingCount} reviews)'),
          const Divider(height: 24),
          _infoRow('Rental price', fmt.format(dress.baseRentalPrice)),
          if (dress.tryOnPrice != null)
            _infoRow('Try-on price', fmt.format(dress.tryOnPrice!)),
          if (dress.depositAmount != null)
            _infoRow('Deposit', fmt.format(dress.depositAmount!)),
          if (dress.acquisitionCost != null)
            _infoRow('Acquisition cost', fmt.format(dress.acquisitionCost!)),
          if (dress.replacementValue != null)
            _infoRow('Replacement value', fmt.format(dress.replacementValue!)),
        ],
      ),
    );
  }

  Widget _buildMeasurementsInfoCard(DressDetail dress) {
    final hasMeasurements = dress.bustCm != null ||
        dress.waistCm != null ||
        dress.hipCm != null ||
        dress.lengthCm != null;
    if (!hasMeasurements && dress.sizeLabel.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.straighten_outlined, 'Measurements'),
          const SizedBox(height: 16),
          _infoRow('Size Label', dress.sizeLabel),
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

  Widget _buildTagsInfoCard(DressDetail dress) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.sell_outlined, 'Tags'),
          const SizedBox(height: 12),
          dress.tags.isEmpty
              ? Text('No tags assigned.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dress.tags
                      .map((t) => Chip(
                            label: Text(t.name,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor:
                                _kPrimary.withValues(alpha: 0.1),
                            side: BorderSide(
                                color: _kPrimary.withValues(alpha: 0.3)),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  // ── Image gallery ─────────────────────────────────────────────────────────

  Widget _buildImageGallery() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _cardHeader(Icons.photo_library_outlined, 'Image Gallery'),
              const Spacer(),
              if (_actionInProgress)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _actionInProgress ? null : _uploadImage,
                icon: const Icon(Icons.upload_outlined, size: 16),
                label: const Text('Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _actionInProgress ? null : _linkImageByUrl,
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Add URL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _actionInProgress ? null : _loadImages,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Gallery grid
          _loadingImages
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _kPrimary),
                ))
              : _images.isEmpty
                  ? _buildEmptyGallery()
                  : _buildImageGrid(),
        ],
      ),
    );
  }

  Widget _buildEmptyGallery() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.photo_library_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No images yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Text('Upload a file or add an image by URL.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: _images.length,
      itemBuilder: (_, idx) => _buildImageTile(_images[idx], idx),
    );
  }

  Widget _buildImageTile(DressImage image, int idx) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: image.isPrimary
              ? _kPrimary
              : Colors.grey.shade200,
          width: image.isPrimary ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Image thumbnail
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _resolveImageUrl(image.url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade100,
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.grey.shade400, size: 32),
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
                                  Colors.grey.shade100,
                                ],
                              ),
                            ),
                            child: const Center(
                                child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _kPrimary,
                              ),
                            )),
                          ),
                  ),
                  if (image.isPrimary)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Primary',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Controls
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Move up
                _imgButton(
                  icon: Icons.arrow_upward_rounded,
                  tooltip: 'Move up',
                  enabled: idx > 0 && !_actionInProgress,
                  onTap: () => _moveImage(image, -1),
                  color: Colors.blueGrey,
                ),
                // Move down
                _imgButton(
                  icon: Icons.arrow_downward_rounded,
                  tooltip: 'Move down',
                  enabled: idx < _images.length - 1 && !_actionInProgress,
                  onTap: () => _moveImage(image, 1),
                  color: Colors.blueGrey,
                ),
                // Set primary
                _imgButton(
                  icon: Icons.star_outline_rounded,
                  tooltip: image.isPrimary ? 'Already primary' : 'Set as primary',
                  enabled: !image.isPrimary && !_actionInProgress,
                  onTap: () => _setPrimary(image),
                  color: Colors.amber.shade700,
                ),
                // Delete
                _imgButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete image',
                  enabled: !_actionInProgress,
                  onTap: () => _deleteImage(image),
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? color : Colors.grey.shade300,
        ),
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _kPrimary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937))),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280))),
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

  Widget _infoRowMultiLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937))),
        ],
      ),
    );
  }

  Widget _badgeRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280))),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(int status) {
    switch (status) {
      case 1:
        return const Color(0xFF6B7280); // Draft
      case 2:
        return const Color(0xFF16A34A); // Active
      case 3:
        return const Color(0xFF2563EB); // Reserved
      case 4:
        return const Color(0xFFD97706); // OutOfService
      case 5:
        return const Color(0xFF9CA3AF); // Archived
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ── Link Image Dialog ─────────────────────────────────────────────────────

class _LinkResult {
  final String url;
  final String? altText;

  const _LinkResult({required this.url, this.altText});
}

class _LinkImageDialog extends StatefulWidget {
  const _LinkImageDialog();

  @override
  State<_LinkImageDialog> createState() => _LinkImageDialogState();
}

class _LinkImageDialogState extends State<_LinkImageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _altCtrl = TextEditingController();

  @override
  void dispose() {
    _urlCtrl.dispose();
    _altCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.link_rounded, color: _kPrimary, size: 22),
          SizedBox(width: 10),
          Text('Add Image by URL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  labelText: 'Image URL *',
                  hintText: 'https://...',
                  prefixIcon:
                      const Icon(Icons.link_rounded, color: _kPrimary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _kPrimary, width: 1.5)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'URL is required.';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'Enter a valid URL.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _altCtrl,
                decoration: InputDecoration(
                  labelText: 'Alt Text (optional)',
                  hintText: 'Describe the image...',
                  prefixIcon: const Icon(Icons.text_fields_rounded,
                      color: _kPrimary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _kPrimary, width: 1.5)),
                ),
                maxLength: 200,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: Colors.grey.shade600)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(
                context,
                _LinkResult(
                  url: _urlCtrl.text.trim(),
                  altText: _altCtrl.text.trim().isEmpty
                      ? null
                      : _altCtrl.text.trim(),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Add Image'),
        ),
      ],
    );
  }
}
