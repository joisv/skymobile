import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/skeleton_loading.dart';

/// Skeleton loading layout for SalesReportScreen.
/// Adapts responsively between Single-Column Mobile Layout and 2-Column POS Tablet Layout.
class SalesReportSkeleton extends StatelessWidget {
  final bool isTablet;

  const SalesReportSkeleton({
    super.key,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub Header & Filter Bar Skeleton
            if (isTablet) _buildTabletFilterSkeleton() else _buildMobileFilterSkeleton(),
            const SizedBox(height: 20),

            // Content Skeleton
            if (isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column (~38%)
                  Expanded(
                    flex: 38,
                    child: Column(
                      children: [
                        _buildHeroOmzetCardSkeleton(),
                        const SizedBox(height: 16),
                        _buildCardContainerSkeleton(height: 160),
                        const SizedBox(height: 16),
                        _buildCardContainerSkeleton(height: 140),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right Column (~62%)
                  Expanded(
                    flex: 62,
                    child: Column(
                      children: [
                        _buildMetricsGridSkeleton(),
                        const SizedBox(height: 16),
                        _buildCardContainerSkeleton(height: 150),
                        const SizedBox(height: 16),
                        _buildCardContainerSkeleton(height: 280),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildHeroOmzetCardSkeleton(),
                  const SizedBox(height: 16),
                  _buildMetricsGridSkeleton(),
                  const SizedBox(height: 16),
                  _buildCardContainerSkeleton(height: 180),
                  const SizedBox(height: 16),
                  _buildCardContainerSkeleton(height: 240),
                ],
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletFilterSkeleton() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonText(width: 240, height: 22),
            SizedBox(height: 6),
            SkeletonText(width: 380, height: 12),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonBox(width: 280, height: 38, borderRadius: 20),
            SizedBox(width: 10),
            SkeletonBox(width: 150, height: 38, borderRadius: 10),
            SizedBox(width: 10),
            SkeletonBox(width: 120, height: 38, borderRadius: 10),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFilterSkeleton() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonText(width: 200, height: 20),
        SizedBox(height: 4),
        SkeletonText(width: 260, height: 11),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 38, borderRadius: 20)),
            SizedBox(width: 8),
            SkeletonBox(width: 40, height: 38, borderRadius: 10),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroOmzetCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 120, height: 13),
              SkeletonBox(width: 80, height: 24, borderRadius: 12),
            ],
          ),
          SizedBox(height: 14),
          SkeletonText(width: 220, height: 28),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 52, borderRadius: 10)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 52, borderRadius: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGridSkeleton() {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 72, borderRadius: 12)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 72, borderRadius: 12)),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 72, borderRadius: 12)),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 72, borderRadius: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildCardContainerSkeleton({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonText(width: 140, height: 16),
          SizedBox(height: 12),
          Expanded(child: SkeletonBox(borderRadius: 8)),
        ],
      ),
    );
  }
}
