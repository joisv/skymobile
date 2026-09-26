import 'package:flutter/material.dart';
import '../../../models/booking_model.dart';
import '../../../theme/app_theme.dart';

class BookingStatusBadge extends StatelessWidget {
  final BookingStatus status;

  const BookingStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;
    IconData icon;

    switch (status) {
      case BookingStatus.pending:
        textColor = AppTheme.statusPendingText;
        bgColor = AppTheme.statusPendingBg;
        icon = Icons.hourglass_top_rounded;
        break;
      case BookingStatus.confirmed:
        textColor = AppTheme.statusConfirmedText;
        bgColor = AppTheme.statusConfirmedBg;
        icon = Icons.check_circle_outline_rounded;
        break;
      case BookingStatus.rented:
        textColor = AppTheme.statusRentedText;
        bgColor = AppTheme.statusRentedBg;
        icon = Icons.phone_iphone_rounded;
        break;
      case BookingStatus.returned:
        textColor = AppTheme.statusReturnedText;
        bgColor = AppTheme.statusReturnedBg;
        icon = Icons.assignment_turned_in_outlined;
        break;
      case BookingStatus.cancelled:
        textColor = AppTheme.statusCancelledText;
        bgColor = AppTheme.statusCancelledBg;
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;

  const PaymentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;

    switch (status) {
      case PaymentStatus.paid:
        textColor = const Color(0xFF047857);
        bgColor = const Color(0xFFD1FAE5);
        break;
      case PaymentStatus.partial:
        textColor = const Color(0xFFB45309);
        bgColor = const Color(0xFFFEF3C7);
        break;
      case PaymentStatus.unpaid:
        textColor = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEE2E2);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
