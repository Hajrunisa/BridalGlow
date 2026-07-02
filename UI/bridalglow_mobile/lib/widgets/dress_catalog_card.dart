import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/dress.dart';
import 'package:bridalglow_mobile/providers/base_provider.dart';
import 'package:bridalglow_mobile/providers/interaction_provider.dart';
import 'package:bridalglow_mobile/providers/recommendation_provider.dart';
import 'package:bridalglow_mobile/screens/dress_detail_screen.dart';

const kDressCardPrimary = Color(0xFFC2778A);
const kDressCardPrimaryLight = Color(0xFFFFF0F3);

String resolveDressImageUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${BaseProvider.serverOrigin}$url';
}

/// Reusable catalog dress card (grid, horizontal lists, recommendations).
class DressCatalogCard extends StatelessWidget {
  final DressListItem dress;
  final double? width;
  final double height;

  const DressCatalogCard({
    super.key,
    required this.dress,
    this.width,
    this.height = 296,
  });

  static const _cardRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DressDetailScreen(dressId: dress.id),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 13, child: _buildCardImage(context)),
              Expanded(flex: 9, child: _buildCardInfo()),
            ],
          ),
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, height: height, child: card);
    }
    return SizedBox(height: height, child: card);
  }

  Widget _buildCardImage(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_cardRadius),
          ),
          child: dress.primaryImageUrl != null &&
                  dress.primaryImageUrl!.isNotEmpty
              ? Image.network(
                  resolveDressImageUrl(dress.primaryImageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : _imageLoading(progress),
                )
              : _imagePlaceholder(),
        ),
        if (dress.isFeatured)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 11),
                  SizedBox(width: 3),
                  Text(
                    'Featured',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: 10,
          right: 10,
          child: _buildStatusBadge(dress.status),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: _buildFavoriteButton(context, dress.id),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton(BuildContext context, int dressId) {
    return Consumer<InteractionProvider>(
      builder: (context, interactionProvider, _) {
        final isFavorited = interactionProvider.isFavorited(dressId);
        return Material(
          color: Colors.white.withValues(alpha: 0.94),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              try {
                await interactionProvider.toggleFavorite(dressId);
                if (context.mounted) {
                  context
                      .read<RecommendationProvider>()
                      .loadForMe(limit: 12, force: true);
                }
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Could not update favorite.'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                isFavorited
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color:
                    isFavorited ? kDressCardPrimary : const Color(0xFF6B7280),
                size: 18,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dress.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            dress.primaryCategoryName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: kDressCardPrimary,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${dress.baseRentalPrice.toStringAsFixed(0)} BAM',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      dress.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Size: ${dress.sizeLabel}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(int status) {
    final data = {
      1: ('Draft', const Color(0xFF6B7280)),
      2: ('Active', const Color(0xFF16A34A)),
      3: ('Reserved', const Color(0xFF2563EB)),
      4: ('N/A', const Color(0xFFD97706)),
      5: ('Archived', const Color(0xFF9CA3AF)),
    };
    final pair = data[status] ?? ('?', const Color(0xFF6B7280));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        pair.$1,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: pair.$2,
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kDressCardPrimaryLight,
            kDressCardPrimaryLight.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.checkroom_outlined,
          color: kDressCardPrimary,
          size: 40,
        ),
      ),
    );
  }

  Widget _imageLoading(ImageChunkEvent progress) {
    final loaded = progress.expectedTotalBytes != null
        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
        : null;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kDressCardPrimaryLight,
            Colors.white.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: kDressCardPrimary,
                value: loaded,
              ),
            ),
            if (loaded != null) ...[
              const SizedBox(height: 8),
              Text(
                '${(loaded * 100).round()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: kDressCardPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
