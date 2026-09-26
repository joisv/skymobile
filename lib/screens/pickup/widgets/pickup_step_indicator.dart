import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class PickupStepIndicator extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int>? onStepTapped;

  const PickupStepIndicator({
    super.key,
    required this.currentStep,
    this.onStepTapped,
  });

  static const List<Map<String, dynamic>> steps = [
    {'title': 'Identitas', 'icon': Icons.badge_outlined},
    {'title': 'Kondisi Unit', 'icon': Icons.checklist_rounded},
    {'title': 'Pembayaran', 'icon': Icons.payments_outlined},
    {'title': 'Konfirmasi', 'icon': Icons.check_circle_outline_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connecting line
            final stepIndex = index ~/ 2;
            final isCompleted = currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted ? AppTheme.accent : AppTheme.cardBorder,
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isCurrent = currentStep == stepIndex;
          final isCompleted = currentStep > stepIndex;

          return InkWell(
            onTap: onStepTapped != null ? () => onStepTapped!(stepIndex) : null,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? const Color(0xFF047857) // Green for done
                        : isCurrent
                            ? AppTheme.accent // Blue for active
                            : AppTheme.cardBorder, // Slate for pending
                    border: Border.all(
                      color: isCurrent
                          ? AppTheme.accent
                          : isCompleted
                              ? const Color(0xFF047857)
                              : AppTheme.cardBorder,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                        : Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[stepIndex]['title'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent
                        ? AppTheme.accent
                        : isCompleted
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}