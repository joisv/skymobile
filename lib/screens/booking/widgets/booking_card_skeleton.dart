import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/skeleton_loading.dart';

/// Skeleton loader for BookingListScreen.
class BookingListSkeleton extends StatelessWidget {
  final int itemCount;

  const BookingListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 4),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
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
                    SkeletonText(width: 100, height: 12),
                    SkeletonBox(width: 80, height: 22, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonText(width: 140, height: 16),
                    SkeletonText(width: 90, height: 14),
                  ],
                ),
                const SizedBox(height: 8),
                const SkeletonText(width: 170, height: 12),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppTheme.cardBorder),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonText(width: 110, height: 12),
                    SkeletonBox(width: 90, height: 32, borderRadius: 8),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
