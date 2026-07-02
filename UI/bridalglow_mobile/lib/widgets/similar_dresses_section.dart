import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bridalglow_mobile/models/recommendation.dart';
import 'package:bridalglow_mobile/providers/recommendation_provider.dart';
import 'package:bridalglow_mobile/widgets/dress_catalog_card.dart';

const _kPrimary = Color(0xFFC2778A);
const _kPrimaryLight = Color(0xFFFFF0F3);
const _kCardWidth = 168.0;
const _kCardHeight = 288.0;
const _kReasonHeight = 34.0;
const _kSectionHeight = _kCardHeight + 8 + _kReasonHeight;

/// "Similar dresses" section for the dress detail screen.
class SimilarDressesSection extends StatefulWidget {
  final int dressId;

  const SimilarDressesSection({super.key, required this.dressId});

  @override
  State<SimilarDressesSection> createState() => _SimilarDressesSectionState();
}

class _SimilarDressesSectionState extends State<SimilarDressesSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<RecommendationProvider>()
          .loadSimilarDresses(widget.dressId, limit: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecommendationProvider>(
      builder: (context, provider, _) {
        final loading = provider.isSimilarLoading(widget.dressId);
        final error = provider.similarErrorFor(widget.dressId);
        final items = provider.similarDressesFor(widget.dressId);

        if (loading) {
          return _sectionShell(
            child: SizedBox(
              height: _kSectionHeight,
              child: Center(
                child: CircularProgressIndicator(color: _kPrimary),
              ),
            ),
          );
        }

        if (error != null) {
          return _sectionShell(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => provider.loadSimilarDresses(
                      widget.dressId,
                      limit: 10,
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        if (items.isEmpty) {
          return _sectionShell(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No similar dresses in this collection yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          );
        }

        return _sectionShell(
          child: SizedBox(
            height: _kSectionHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => _buildSimilarTile(items[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimilarTile(SimilarDress item) {
    return SizedBox(
      width: _kCardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DressCatalogCard(
            dress: item.dress,
            width: _kCardWidth,
            height: _kCardHeight,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _kReasonHeight,
            width: _kCardWidth,
            child: Text(
              item.reason ??
                  'Similar dress based on browsing patterns in our collection.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionShell({required Widget child}) {
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
                child: const Icon(Icons.compare_arrows_rounded,
                    color: _kPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Similar dresses',
                style: TextStyle(
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
}
