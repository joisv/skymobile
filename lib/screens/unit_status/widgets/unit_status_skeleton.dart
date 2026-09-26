import '../../../theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../../../widgets/skeleton_loading.dart';

/// Skeleton loader for UnitStatusListScreen mimicking the real unit cards.
class UnitStatusListSkeleton extends StatelessWidget {
  final int itemCount;

  const UnitStatusListSkeleton({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return const UnitStatusCardSkeleton();
        },
      ),
    );
  }
}

/// A single unit card skeleton mimicking `_buildUnitCard`.
class UnitStatusCardSkeleton extends StatelessWidget {
  const UnitStatusCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Name/Storage + Status Badge
          const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SkeletonBox(width: 38, height: 38, borderRadius: 10),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(width: 140, height: 14),
                    SizedBox(height: 6),
                    SkeletonText(width: 90, height: 11),
                  ],
                ),
              ),
              SkeletonBox(width: 68, height: 22, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 12),

          // Identifiers Row: Asset Code & Serial Number placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SkeletonCircle(size: 14),
                      SizedBox(width: 6),
                      SkeletonText(width: 80, height: 11),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      SkeletonCircle(size: 14),
                      SizedBox(width: 6),
                      SkeletonText(width: 90, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Battery Health Row
          const Row(
            children: [
              SkeletonCircle(size: 16),
              SizedBox(width: 6),
              SkeletonText(width: 48, height: 11),
              SizedBox(width: 8),
              Expanded(
                child: SkeletonBox(height: 6, borderRadius: 4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for top metric summary header
class UnitStatusSummarySkeleton extends StatelessWidget {
  const UnitStatusSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: const Row(
        children: [
          Expanded(child: SkeletonBox(height: 52, borderRadius: 10)),
          SizedBox(width: 8),
          Expanded(child: SkeletonBox(height: 52, borderRadius: 10)),
          SizedBox(width: 8),
          Expanded(child: SkeletonBox(height: 52, borderRadius: 10)),
          SizedBox(width: 8),
          Expanded(child: SkeletonBox(height: 52, borderRadius: 10)),
        ],
      ),
    );
  }
}
