import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class UnitStatusFilterChips extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusSelected;
  final Map<String, int> counts;

  const UnitStatusFilterChips({
    super.key,
    required this.selectedStatus,
    required this.onStatusSelected,
    required this.counts,
  });

  static const List<String> statusList = [
    'Semua',
    'Tersedia',
    'Disewa',
    'Terlambat',
    'Perawatan',
    'Dibooking',
  ];

  int _getCountForStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'semua') return counts['total'] ?? 0;
    if (s == 'tersedia') return counts['tersedia'] ?? 0;
    if (s == 'disewa') return counts['disewa'] ?? 0;
    if (s == 'terlambat' || s == 'overdue') return counts['terlambat'] ?? counts['overdue'] ?? 0;
    if (s == 'perawatan' || s == 'maintenance') {
      return counts['maintenance'] ?? counts['perawatan'] ?? 0;
    }
    if (s == 'dibooking') return counts['dibooking'] ?? 0;
    return counts[s] ?? 0;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
        return const Color(0xFF10B981); // Emerald Green
      case 'disewa':
        return const Color(0xFFF59E0B); // Amber / Orange
      case 'terlambat':
      case 'overdue':
        return const Color(0xFFDC2626); // Crimson Red
      case 'perawatan':
      case 'maintenance':
        return const Color(0xFF6B7280); // Gray / Muted
      case 'dibooking':
        return const Color(0xFF3B82F6); // Sky Blue
      case 'semua':
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: statusList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = statusList[index];
          final count = _getCountForStatus(status);
          final isSelected = selectedStatus.toLowerCase() == status.toLowerCase();
          final statusColor = _getStatusColor(status);

          return _buildChip(
            label: status,
            count: count,
            isSelected: isSelected,
            activeColor: statusColor,
            onTap: () => onStatusSelected(status),
          );
        },
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required int count,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.cardBorder,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
                  fontSize: 11,
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
