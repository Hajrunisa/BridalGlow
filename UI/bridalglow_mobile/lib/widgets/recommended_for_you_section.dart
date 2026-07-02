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

/// Horizontal "Recommended for you" section with loading, empty and error states.
class RecommendedForYouSection extends StatefulWidget {
  const RecommendedForYouSection({super.key});

  @override
  State<RecommendedForYouSection> createState() =>
      _RecommendedForYouSectionState();
}

class _RecommendedForYouSectionState extends State<RecommendedForYouSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final provider = context.read<RecommendationProvider>();
    await provider.loadForMe(limit: 12, force: force);
    if (!mounted) return;
    if (provider.forMeItems.isEmpty && provider.forMeError == null) {
      await provider.loadColdStart(limit: 12, force: force);
    }
  }

  List<RecommendationItem> _displayItems(RecommendationProvider provider) {
    if (provider.forMeItems.isNotEmpty) return provider.forMeItems;
    return provider.coldStartItems;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecommendationProvider>(
      builder: (context, provider, _) {
        final loading = provider.forMeLoading || provider.coldStartLoading;
        final error = provider.forMeError ?? provider.coldStartError;
        final items = _displayItems(provider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kPrimary.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: _kPrimary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recommended for you',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                    ),
                  ),
                  if (!loading)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      color: _kPrimary,
                      tooltip: 'Refresh recommendations',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _load(force: true),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              SizedBox(
                height: _kSectionHeight,
                child: Center(
                  child: CircularProgressIndicator(color: _kPrimary),
                ),
              )
            else if (error != null)
              _buildMessageCard(
                icon: Icons.error_outline_rounded,
                text: error,
                actionLabel: 'Try again',
                onAction: () => _load(force: true),
              )
            else if (items.isEmpty)
              _buildMessageCard(
                icon: Icons.checkroom_outlined,
                text:
                    'No recommendations yet. Browse the catalogue and mark your favourite dresses.',
              )
            else
              SizedBox(
                height: _kSectionHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  clipBehavior: Clip.none,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) {
                    final item = items[index];
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
                          if (item.reason.isNotEmpty)
                            SizedBox(
                              height: _kReasonHeight,
                              width: _kCardWidth,
                              child: Text(
                                item.reason,
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
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: _kPrimary, size: 28),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}
