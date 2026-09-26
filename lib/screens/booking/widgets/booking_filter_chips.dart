import 'package:flutter/material.dart';
import '../../../models/booking_model.dart';
import '../../../theme/app_theme.dart';

class BookingFilterChips extends StatelessWidget {
  final BookingStatus? selectedStatus;
  final ValueChanged<BookingStatus?> onStatusSelected;
  final Map<BookingStatus, int> counts;

  const BookingFilterChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusSelected,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = counts.values.fold(0, (sum, count) => sum + count);

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChip(
            label: 'Semua',
            count: totalCount,
            isSelected: selectedStatus == null,
            onTap: () => onStatusSelected(null),
          ),
          const SizedBox(width: 8),
          ...BookingStatus.values.map((status) {
            final count = counts[status] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildChip(
                label: status.label,
                count: count,
                isSelected: selectedStatus == status,
                onTap: () => onStatusSelected(status),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
