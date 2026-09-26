import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/skeleton_loading.dart';

/// Skeleton loading layout for DashboardScreen.
/// Adapts responsively between Single-Column Mobile Layout and 2-Column POS Tablet Layout.
class DashboardSkeleton extends StatelessWidget {
  final bool? isTablet;

  const DashboardSkeleton({
    super.key,
    this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTabletLayout = isTablet ??
            (constraints.maxWidth >= 900 && constraints.maxWidth > constraints.maxHeight);

        return SkeletonShimmer(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: useTabletLayout ? 40 : 100,
              left: useTabletLayout ? 24 : 0,
              right: useTabletLayout ? 24 : 0,
              top: useTabletLayout ? 20 : 0,
            ),
            child: useTabletLayout
                ? _buildTabletSkeleton()
                : _buildMobileSkeleton(),
          ),
        );
      },
    );
  }

  // ==========================================
  // MOBILE SKELETON LAYOUT
  // ==========================================

  Widget _buildMobileSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Welcome & Status Banner Skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _buildMobileWelcomeBannerSkeleton(),
        ),

        // 2. Operational Metrics (2x2 Grid) Skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildMobileMetricsGridSkeleton(),
        ),

        // 3. Transaction Queue Section Skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: _buildMobileTransactionQueueSkeleton(),
        ),
      ],
    );
  }

  Widget _buildMobileWelcomeBannerSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  SkeletonCircle(size: 8),
                  SizedBox(width: 8),
                  SkeletonText(width: 170, height: 11),
                ],
              ),
              SkeletonBox(width: 60, height: 18, borderRadius: 12),
            ],
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 190, height: 15),
                  SizedBox(height: 6),
                  SkeletonText(width: 130, height: 11),
                ],
              ),
              SkeletonBox(width: 72, height: 26, borderRadius: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMetricsGridSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonText(width: 150, height: 15),
            SkeletonText(width: 80, height: 11),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMobileMetricCardSkeleton()),
            const SizedBox(width: 10),
            Expanded(child: _buildMobileMetricCardSkeleton()),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMobileMetricCardSkeleton()),
            const SizedBox(width: 10),
            Expanded(child: _buildMobileMetricCardSkeleton()),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileMetricCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              SkeletonCircle(size: 34),
              SkeletonBox(width: 16, height: 16, borderRadius: 4),
            ],
          ),
          SizedBox(height: 12),
          SkeletonText(width: 90, height: 11),
          SizedBox(height: 8),
          SkeletonText(width: 75, height: 20),
          SizedBox(height: 6),
          SkeletonText(width: 105, height: 10),
        ],
      ),
    );
  }

  Widget _buildMobileTransactionQueueSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonText(width: 140, height: 16),
            SkeletonBox(width: 110, height: 32, borderRadius: 20),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            SkeletonBox(width: 75, height: 30, borderRadius: 20),
            SizedBox(width: 8),
            SkeletonBox(width: 85, height: 30, borderRadius: 20),
            SizedBox(width: 8),
            SkeletonBox(width: 85, height: 30, borderRadius: 20),
          ],
        ),
        const SizedBox(height: 12),
        _buildMobileTransactionCardSkeleton(),
        const SizedBox(height: 10),
        _buildMobileTransactionCardSkeleton(),
        const SizedBox(height: 10),
        _buildMobileTransactionCardSkeleton(),
      ],
    );
  }

  Widget _buildMobileTransactionCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              SkeletonText(width: 90, height: 11),
              SkeletonBox(width: 85, height: 22, borderRadius: 12),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 140, height: 15),
              SkeletonText(width: 90, height: 12),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              SkeletonCircle(size: 16),
              SizedBox(width: 6),
              SkeletonText(width: 160, height: 12),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 90, height: 12),
              Row(
                children: [
                  SkeletonBox(width: 58, height: 32, borderRadius: 8),
                  SizedBox(width: 6),
                  SkeletonBox(width: 34, height: 32, borderRadius: 8),
                  SizedBox(width: 6),
                  SkeletonBox(width: 100, height: 32, borderRadius: 8),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TABLET SKELETON LAYOUT (2-COLUMN POS)
  // ==========================================

  Widget _buildTabletSkeleton() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (~66% width)
        Expanded(
          flex: 66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabletWelcomeBannerSkeleton(),
              const SizedBox(height: 20),
              _buildTabletMetricsRowSkeleton(),
              const SizedBox(height: 24),
              _buildTabletQueueSkeleton(),
            ],
          ),
        ),
        const SizedBox(width: 20),

        // Right Column (~34% width / Sidebar)
        Expanded(
          flex: 34,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabletQuickActionsSkeleton(),
              const SizedBox(height: 16),
              _buildTabletPrinterSkeleton(),
              const SizedBox(height: 16),
              _buildTabletReadyStockSkeleton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletWelcomeBannerSkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 22, borderRadius: 20),
                SizedBox(height: 12),
                Row(
                  children: [
                    SkeletonText(width: 200, height: 22),
                    SizedBox(width: 8),
                    SkeletonBox(width: 52, height: 20, borderRadius: 6),
                  ],
                ),
                SizedBox(height: 8),
                SkeletonText(width: 380, height: 12),
              ],
            ),
          ),
          SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonBox(width: 140, height: 48, borderRadius: 12),
              SizedBox(width: 12),
              SkeletonCircle(size: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletMetricsRowSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonText(width: 180, height: 16),
            SkeletonBox(width: 75, height: 20, borderRadius: 8),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTabletMetricCardSkeleton(hasProgress: false)),
            const SizedBox(width: 10),
            Expanded(child: _buildTabletMetricCardSkeleton(hasProgress: false)),
            const SizedBox(width: 10),
            Expanded(child: _buildTabletMetricCardSkeleton(hasProgress: true)),
            const SizedBox(width: 10),
            Expanded(child: _buildTabletMetricCardSkeleton(hasProgress: false)),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletMetricCardSkeleton({bool hasProgress = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 75, height: 11),
              SkeletonBox(width: 28, height: 28, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonText(width: 65, height: 22),
          const SizedBox(height: 8),
          if (hasProgress) ...[
            const SkeletonBox(width: double.infinity, height: 5, borderRadius: 4),
            const SizedBox(height: 4),
            const SkeletonText(width: 85, height: 10),
          ] else ...[
            const Row(
              children: [
                SkeletonBox(width: 46, height: 16, borderRadius: 4),
                SizedBox(width: 4),
                SkeletonBox(width: 46, height: 16, borderRadius: 4),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabletQueueSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SkeletonText(width: 140, height: 16),
                SizedBox(width: 8),
                SkeletonBox(width: 70, height: 22, borderRadius: 12),
              ],
            ),
            Row(
              children: [
                SkeletonBox(width: 60, height: 26, borderRadius: 16),
                SizedBox(width: 6),
                SkeletonBox(width: 75, height: 26, borderRadius: 16),
                SizedBox(width: 6),
                SkeletonBox(width: 75, height: 26, borderRadius: 16),
                SizedBox(width: 8),
                SkeletonBox(width: 85, height: 26, borderRadius: 16),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildTabletQueueCardSkeleton(),
        const SizedBox(height: 12),
        _buildTabletQueueCardSkeleton(),
        const SizedBox(height: 12),
        _buildTabletQueueCardSkeleton(),
      ],
    );
  }

  Widget _buildTabletQueueCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  SkeletonBox(width: 65, height: 20, borderRadius: 4),
                  SizedBox(width: 8),
                  SkeletonText(width: 90, height: 11),
                ],
              ),
              SkeletonBox(width: 85, height: 20, borderRadius: 4),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonBox(width: 44, height: 44, borderRadius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonText(width: 130, height: 15),
                        SkeletonText(width: 65, height: 12),
                      ],
                    ),
                    SizedBox(height: 4),
                    SkeletonText(width: 180, height: 11),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 120, height: 12),
              Row(
                children: [
                  SkeletonCircle(size: 26),
                  SizedBox(width: 8),
                  SkeletonBox(width: 120, height: 32, borderRadius: 20),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletQuickActionsSkeleton() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonText(width: 120, height: 15),
          SizedBox(height: 14),
          SkeletonBox(width: double.infinity, height: 44, borderRadius: 12),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: SkeletonBox(width: double.infinity, height: 40, borderRadius: 10)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(width: double.infinity, height: 40, borderRadius: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletPrinterSkeleton() {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Row(
                children: [
                  SkeletonBox(width: 18, height: 18, borderRadius: 4),
                  SizedBox(width: 8),
                  SkeletonText(width: 90, height: 15),
                ],
              ),
              SkeletonBox(width: 55, height: 20, borderRadius: 12),
            ],
          ),
          SizedBox(height: 14),
          SkeletonBox(width: double.infinity, height: 60, borderRadius: 12),
          SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 38, borderRadius: 10),
        ],
      ),
    );
  }

  Widget _buildTabletReadyStockSkeleton() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonText(width: 110, height: 15),
              SkeletonBox(width: 70, height: 18, borderRadius: 6),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(
            4,
            (i) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SkeletonBox(width: 36, height: 36, borderRadius: 8),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonText(width: 110, height: 12),
                        SizedBox(height: 4),
                        SkeletonText(width: 80, height: 10),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 48, height: 20, borderRadius: 6),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SkeletonBox(width: double.infinity, height: 38, borderRadius: 10),
        ],
      ),
    );
  }
}
