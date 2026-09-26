import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/booking_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';
import 'booking_status_badge.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;
  final VoidCallback? onPickupAction;
  final VoidCallback? onReturnAction;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
    this.onPickupAction,
    this.onReturnAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDelivery = booking.pickupType.toLowerCase() == 'delivery';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header: Booking Code + Pickup Type + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: booking.bookingCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kode booking ${booking.bookingCode} disalin'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Text(
                              booking.bookingCode,
                              style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: AppTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDelivery ? const Color(0xFFFEF3C7) : AppTheme.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDelivery ? Icons.delivery_dining_rounded : Icons.store_rounded,
                              size: 11,
                              color: isDelivery ? const Color(0xFFB45309) : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              booking.pickupType,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDelivery ? const Color(0xFFB45309) : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  BookingStatusBadge(status: booking.status),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 10),

              // Customer & Device Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                booking.customerName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 13, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              booking.customerPhone,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_iphone_rounded, size: 14, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          booking.iphone.fullName,
                          style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Rental Schedule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${Formatters.dateTime(booking.startDate)} → ${Formatters.dateTime(booking.endDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '(${booking.durationDays} Hari)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Footer: Financial Summary & Quick Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            Formatters.currency(booking.price),
                            style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          PaymentStatusBadge(status: booking.paymentStatus),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deposit: ${Formatters.currency(booking.deposit)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),

                  // Action Buttons based on status
                  if (booking.canPickup)
                    ElevatedButton.icon(
                      onPressed: onPickupAction ?? onTap,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: const Text('Pickup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else if (booking.canReturn)
                    ElevatedButton.icon(
                      onPressed: onReturnAction ?? onTap,
                      icon: const Icon(Icons.assignment_return_rounded, size: 14),
                      label: const Text('Return'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: BorderSide(color: AppTheme.cardBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Detail'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
