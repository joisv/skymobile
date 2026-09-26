import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../models/receipt_format_settings.dart';
import '../../models/receipt_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/printer_storage_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../payment/payment_deposit_screen.dart';
import 'widgets/extend_duration_modal.dart';

class BookingDetailScreen extends StatelessWidget {
  final BookingModel booking;
  final BookingRepository? repository;
  final VoidCallback? onPickupPressed;
  final VoidCallback? onReturnPressed;

  const BookingDetailScreen({
    super.key,
    required this.booking,
    this.repository,
    this.onPickupPressed,
    this.onReturnPressed,
  });

  String get _storeName {
    final outlet = AuthService().currentUser?.outletName.trim();
    if (outlet != null && outlet.isNotEmpty) {
      return outlet;
    }
    return 'Store Pusat';
  }

  void _openExtendDurationModal(BuildContext context) {
    if (repository == null) return;
    ExtendDurationModal.show(
      context,
      booking: booking,
      repository: repository!,
      onExtended: () {
        Navigator.pop(context, true);
      },
    );
  }

  ReceiptModel _createReceiptFromBooking() {
    final now = DateTime.now();
    final isPaid = booking.paymentStatus == PaymentStatus.paid;
    final calculatedDiscount = booking.discount > 0
        ? booking.discount
        : ((booking.price + booking.deposit) - booking.totalBill);
    final discountVal = calculatedDiscount > 0 ? calculatedDiscount : 0.0;

    return ReceiptModel(
      receiptNumber: 'STR-${booking.bookingCode}',
      date: now,
      adminName: 'Staff Operasional',
      branchName: _storeName,
      type: booking.status == BookingStatus.rented || booking.status == BookingStatus.returned
          ? ReceiptType.returnUnit
          : ReceiptType.pickup,
      bookingCode: booking.bookingCode,
      customerName: booking.customerName,
      customerPhone: booking.customerPhone,
      unitName: booking.iphone.fullName,
      serialNumber: booking.iphone.serialNumber,
      assetCode: booking.iphone.assetCode,
      rentalDuration: '${booking.durationDays} Jam',
      rentalDates: '${Formatters.date(booking.startDate)} - ${Formatters.date(booking.endDate)}',
      rentFee: booking.price,
      depositFee: booking.deposit,
      finesFee: 0,
      discountFee: discountVal,
      totalAmount: booking.totalBill,
      paidAmount: isPaid ? booking.totalBill : booking.downPayment,
      remainingAmount: isPaid ? 0 : (booking.totalBill - booking.downPayment).clamp(0.0, double.infinity),
      paymentMethod: 'Tunai / QRIS',
      paymentStatus: isPaid ? 'Lunas' : 'Belum Lunas',
      depositStatus: booking.deposit > 0 ? 'Ditahan (Aktif)' : 'Tanpa Deposit',
      notes: booking.notes,
    );
  }

  void _handleReturnAction(BuildContext context) {
    if (onReturnPressed != null) {
      onReturnPressed!();
      return;
    }

    // Jika telat dan ada denda keterlambatan: proses pembayaran di kasir
    if (booking.isCurrentlyLate && booking.estimatedLateFee > 0) {
      Navigator.pushNamed(
        context,
        AppRoutes.paymentDeposit,
        arguments: {
          'booking': booking,
          'initialPaymentType': PaymentTypeOption.penalty,
          'initialAmount': booking.estimatedLateFee,
          'isReturnFlow': true,
        },
      ).then((val) {
        if (val == true && context.mounted) {
          Navigator.pop(context, true);
        }
      });
      return;
    }

    // Jika tepat waktu / bebas denda: dialog konfirmasi cepat dan selesaikan pengembalian
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Text('Konfirmasi Pengembalian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Unit ${booking.iphone.fullName} dikembalikan tepat waktu tanpa denda. Selesaikan pengembalian unit dan ubah status unit menjadi Tersedia (Ready)?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await repository?.completeReturn(
                  bookingCode: booking.bookingCode,
                  physicalCondition: 'Baik / Sempurna',
                  batteryHealthFinal: booking.iphone.batteryHealth,
                  lateFee: 0,
                  damageFee: 0,
                  depositRefunded: 0,
                  refundMethod: 'Tanpa Denda',
                  accessoriesReturned: ['Lengkap'],
                  staffNotes: 'Pengembalian unit tepat waktu diselesaikan langsung.',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pengembalian unit berhasil diselesaikan! Status unit kembali Tersedia.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menyelesaikan pengembalian: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );
  }

  void _handlePenaltyAction(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.paymentDeposit,
      arguments: {
        'booking': booking,
        'initialPaymentType': PaymentTypeOption.penalty,
        'initialAmount': booking.estimatedLateFee > 0 ? booking.estimatedLateFee : null,
        'isReturnFlow': true,
      },
    ).then((val) {
      if (val == true && context.mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  Widget _buildDeviceThumbnail(
    IphoneModel iphone, {
    double size = 56,
    double radius = 10,
  }) {
    final photo = iphone.resolvedPhotoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: (photo != null && photo.isNotEmpty)
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(Icons.phone_iphone_rounded, color: AppTheme.secondary, size: size * 0.5),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: size * 0.35,
                      height: size * 0.35,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              )
            : Center(
                child: Icon(Icons.phone_iphone_rounded, color: AppTheme.secondary, size: size * 0.5),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTabletLandscape = constraints.maxWidth >= 900 && constraints.maxWidth > constraints.maxHeight;
        if (isTabletLandscape) {
          return _buildTabletLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildTabletAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (~66% width)
            Expanded(
              flex: 66,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabletCustomerSection(context),
                  const SizedBox(height: 16),
                  _buildTabletHardwareSection(context),
                  const SizedBox(height: 16),
                  _buildTabletScheduleSection(context),
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
                  _buildTabletFinancialSection(context),
                  const SizedBox(height: 16),
                  _buildTabletPrinterCard(context),
                  const SizedBox(height: 16),
                  _buildTabletReceiptSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildTabletBottomNav(context),
    );
  }

  Widget _buildTabletBottomNav(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTabletNavItem(Icons.dashboard_outlined, 'Dashboard', false, () {
            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (route) => false);
          }),
          _buildTabletNavItem(Icons.assessment_outlined, 'Report', false, () {
            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.salesReport, (route) => false);
          }),
          _buildTabletNavItem(Icons.phone_iphone_rounded, 'Unit iPhone', false, () {
            Navigator.pushNamed(context, AppRoutes.unitStatus);
          }),
          _buildTabletNavItem(Icons.print_outlined, 'Printer & Shift', false, () {
            Navigator.pushNamed(context, AppRoutes.printerSettings);
          }),
        ],
      ),
    );
  }

  Widget _buildTabletNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  PreferredSizeWidget _buildTabletAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 10,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Antrean Transaksi back button
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 16, color: Color(0xFF1E293B)),
                    SizedBox(width: 8),
                    Text(
                      'Antrean Transaksi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Booking code with copy icon
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: booking.bookingCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kode booking #${booking.bookingCode} berhasil disalin'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${booking.bookingCode}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy_rounded, size: 15, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Outlet badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 15, color: Color(0xFF475569)),
                  const SizedBox(width: 6),
                  Text(
                    _storeName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Delete button (red trash)
            InkWell(
              onTap: () => _confirmDelete(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletCustomerSection(BuildContext context) {
    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'IDENTITAS PENYEWA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Informasi Pelanggan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // 2x2 Grid cards
          Row(
            children: [
              // Card 1: Nama Lengkap
              Expanded(
                child: _buildTabletCustomerInfoCard(
                  title: 'Nama Lengkap',
                  content: Text(
                    booking.customerName,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Card 2: Nomor WhatsApp / Seluler
              Expanded(
                child: _buildTabletCustomerInfoCard(
                  title: 'Nomor WhatsApp / Seluler',
                  content: Row(
                    children: [
                      Expanded(
                        child: Text(
                          booking.customerPhone,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _openWhatsApp(context, booking.customerPhone),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _callPhone(context, booking.customerPhone),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF0284C7)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              // Card 3: Email Terdaftar
              Expanded(
                child: _buildTabletCustomerInfoCard(
                  title: 'Email Terdaftar',
                  content: Text(
                    booking.customerEmail,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Card 4: JAMINAN FISIK DISERAHKAN
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'JAMINAN FISIK DISERAHKAN',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.jaminanType.contains('Fisik')
                                  ? booking.jaminanType
                                  : '${booking.jaminanType} Fisik',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Alamat Domisili KTP
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Text(
                      'ALAMAT DOMISILI KTP / DOMISILI PENGANTARAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.4,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Terverifikasi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  (booking.address != null && booking.address!.trim().isNotEmpty)
                      ? booking.address!
                      : 'Jl. Radio Dalam No. 14, RT 004 / RW 012, Kel. Gandaria Utara, Kec. Kebayoran Baru, Jakarta Selatan, 12140',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletCustomerInfoCard({
    required String title,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          content,
        ],
      ),
    );
  }

  Widget _buildTabletHardwareSection(BuildContext context) {
    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SPESIFIKASI INVENTARIS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Unit iPhone & Hardware',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // Device Unit Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phone Thumbnail with Storage Badge
                Stack(
                  children: [
                    _buildDeviceThumbnail(booking.iphone, size: 60, radius: 10),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          booking.iphone.storage,
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Model Name + Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              booking.iphone.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              if (booking.status == BookingStatus.rented) {
                                _handleReturnAction(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Kondisi fisik: Mulus / Siap Pakai (BH: ${booking.iphone.batteryHealth}%)'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Log Fisik',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Varian Warna: ${booking.iphone.color} • Grade A+ (Mulus / Siap Pakai)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Sub Bar: Serial (SN) & ID Aset
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'SERIAL (SN): ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              booking.iphone.serialNumber,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'ID ASET: ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              booking.iphone.assetCode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'KELENGKAPAN PAKET DISERAHKAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),

          // 3 Accessories Cards Row
          Row(
            children: [
              Expanded(
                child: _buildTabletAccessoryCard(
                  title: 'Kabel Data C-Lightning',
                  subtitle: 'Original Apple Foxconn',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTabletAccessoryCard(
                  title: 'Adaptor 20W PD',
                  subtitle: 'Fast Charging Bersertifikat',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTabletAccessoryCard(
                  title: 'Clear Case & Tempered',
                  subtitle: 'Terpasang Presisi',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletAccessoryCard({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletScheduleSection(BuildContext context) {
    final durationText = booking.durationDays % 24 == 0
        ? '${booking.durationDays ~/ 24} Hari'
        : '${booking.durationDays} Hari';

    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DURASI PEMAKAIAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jadwal & Durasi Rental',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // 3 Schedule Cards Row
          Row(
            children: [
              // Mulai Sewa
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mulai Sewa (Handover)',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.date(booking.startDate),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.startDate.hour.toString().padLeft(2, '0')}:${booking.startDate.minute.toString().padLeft(2, '0')} WIB',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Batas Kembali
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Batas Kembali (Deadline)',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatters.date(booking.endDate),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.endDate.hour.toString().padLeft(2, '0')}:${booking.endDate.minute.toString().padLeft(2, '0')} WIB',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Total Durasi
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL DURASI',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _openExtendDurationModal(context),
                        child: Row(
                          children: [
                            Text(
                              durationText,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Paket Reguler Liburan',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Keterlambatan banner if late
          if (booking.isCurrentlyLate || booking.currentLateHours > 0 || booking.currentLateMinutes > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terlambat: ${booking.lateDurationFormatted} • Estimasi Denda: ${Formatters.currency(booking.estimatedLateFee)}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Waktu sewa telah melewati batas toleransi 90 menit. Selesaikan pembayaran denda di kasir.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Tombol Pengembalian dan Denda
          Row(
            children: [
              // Tombol Pengembalian Unit
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    key: const Key('btn_tablet_return'),
                    onPressed: booking.status == BookingStatus.returned
                        ? null
                        : () => _handleReturnAction(context),
                    icon: Icon(
                      booking.status == BookingStatus.returned
                          ? Icons.check_circle_rounded
                          : Icons.assignment_turned_in_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      booking.status == BookingStatus.returned
                          ? 'Unit Sudah Dikembalikan'
                          : 'Pengembalian Unit',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: booking.status == BookingStatus.returned
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF10B981),
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Tombol Denda
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    key: const Key('btn_tablet_penalty'),
                    onPressed: () => _handlePenaltyAction(context),
                    icon: Icon(
                      booking.isCurrentlyLate && booking.estimatedLateFee > 0
                          ? Icons.point_of_sale_rounded
                          : Icons.gavel_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      booking.estimatedLateFee > 0
                          ? 'Bayar Denda (${Formatters.currency(booking.estimatedLateFee)})'
                          : 'Denda Keterlambatan',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: booking.isCurrentlyLate && booking.estimatedLateFee > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabletFinancialSection(BuildContext context) {
    final isPaid = booking.paymentStatus == PaymentStatus.paid;
    final durationText = booking.durationDays % 24 == 0
        ? '${booking.durationDays ~/ 24} Hari'
        : '${booking.durationDays} Hari';

    return _buildTabletSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KEUANGAN & KASIR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Rincian Tagihan & Deposit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isPaid ? '✓ LUNAS' : 'Belum Lunas',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Line item tarif sewa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tarif Sewa ${booking.iphone.fullName} ($durationText)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@ ${Formatters.formatCurrency(booking.iphone.dailyRate)} / 24 Jam',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.formatCurrency(booking.price),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Highlight Box: TOTAL TERBAYAR LUNAS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL TERBAYAR LUNAS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'QRIS Dinamis POS #01',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  Formatters.formatCurrency(booking.totalBill),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Settlement note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF0284C7)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transaksi tercatat pada settlement BCA QRIS Merchant ID: SKY-JKT-0982.',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletPrinterCard(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThermalPrintService().isConnectedNotifier,
      builder: (context, isConnected, _) {
        return _buildTabletSectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: const Icon(Icons.print_outlined, size: 20, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'VSC MP-58C Kasir',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? 'Bluetooth POS • Kertas 58mm Siap' : 'Bluetooth POS • Siap Terhubung',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  final receipt = _createReceiptFromBooking();
                  _printDirectly(context, receipt);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Test Roll',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletReceiptSection(BuildContext context) {
    final receipt = _createReceiptFromBooking();

    return _buildTabletSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRATINJAU NOTA KASIR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Preview Struk (58mm Thermal)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('● ', style: TextStyle(color: Color(0xFF16A34A), fontSize: 8)),
                    Text(
                      'Siap Cetak',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Real Thermal Receipt Paper Preview
          FutureBuilder<ReceiptFormatSettings>(
            future: PrinterStorageService().getReceiptFormatSettings(),
            builder: (context, snapshot) {
              final formatSettings = snapshot.data ?? const ReceiptFormatSettings();
              return _buildAuthenticThermalReceipt(receipt, formatSettings);
            },
          ),

          const SizedBox(height: 14),

          // Action Buttons: Cetak Nota & Pengaturan Format Resi
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => _printDirectly(context, receipt),
                    icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Cetak Nota',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.receiptFormatSettings);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Realistic Physical Thermal Receipt Preview
  Widget _buildAuthenticThermalReceipt(ReceiptModel receipt, ReceiptFormatSettings formatSettings) {
    final rawText = receipt.toEscPos58mm(formatSettings: formatSettings);
    final hasBarcodeTag = rawText.contains(RegExp(r'\[BARCODE:.*?\]'));

    const monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11.5,
      height: 1.35,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0F172A),
    );

    Widget buildSegment(String text) {
      if (!text.contains('[STORE_NAME:')) {
        return SelectableText(text, style: monoStyle);
      }

      final storeRegex = RegExp(r'\[STORE_NAME:(.*?):(.*?):(.*?):(.*?)\]');
      final match = storeRegex.firstMatch(text);
      if (match == null) {
        return SelectableText(text, style: monoStyle);
      }

      final before = text.substring(0, match.start);
      final size = match.group(1) ?? 'large';
      final weight = match.group(2) ?? 'bold';
      final align = match.group(3) ?? 'center';
      final storeName = match.group(4) ?? '';
      final after = text.substring(match.end);

      double titleFontSize = 15;
      if (size == 'small') titleFontSize = 11.5;
      if (size == 'medium') titleFontSize = 13.5;
      if (size == 'large') titleFontSize = 16;
      if (size == 'extraLarge') titleFontSize = 19;

      FontWeight titleFontWeight = FontWeight.bold;
      if (weight == 'normal') titleFontWeight = FontWeight.normal;
      if (weight == 'bold') titleFontWeight = FontWeight.bold;
      if (weight == 'extraBold') titleFontWeight = FontWeight.w900;

      TextAlign titleAlign = align == 'left' ? TextAlign.left : TextAlign.center;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (before.isNotEmpty) SelectableText(before.trimRight(), style: monoStyle),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              storeName,
              textAlign: titleAlign,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: titleFontSize,
                fontWeight: titleFontWeight,
                letterSpacing: 0.8,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          if (after.isNotEmpty) SelectableText(after.trimLeft(), style: monoStyle),
        ],
      );
    }

    Widget contentWidget;
    if (hasBarcodeTag && formatSettings.showBarcode) {
      final parts = rawText.split(RegExp(r'\[BARCODE:.*?\]\n?'));
      final bookingCode = receipt.bookingCode;

      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSegment(parts[0]),
          _buildReceiptBarcodeVisual(bookingCode, formatSettings),
          if (parts.length > 1) buildSegment(parts[1]),
        ],
      );
    } else {
      final cleanText = rawText.replaceAll(RegExp(r'\[BARCODE:.*?\]\n?'), '');
      contentWidget = buildSegment(cleanText);
    }

    return Column(
      children: [
        // Top jagged edge / paper feeder teeth
        _buildReceiptJaggedEdge(isTop: true),

        // Paper Body
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFDFB),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: contentWidget,
        ),

        // Bottom jagged edge
        _buildReceiptJaggedEdge(isTop: false),
        const SizedBox(height: 8),
        Text(
          '— Lebar Kertas Standar VSC MP-58C (32 Karakter) —',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildReceiptBarcodeVisual(String code, ReceiptFormatSettings formatSettings) {
    final type = formatSettings.barcodeType;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'code128' || type == 'both') ...[
              BarcodeWidget(
                barcode: Barcode.code128(),
                data: code,
                width: 200,
                height: 48,
                drawText: formatSettings.showBarcodeHri,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (type == 'both') const SizedBox(height: 8),
            ],
            if (type == 'qrcode' || type == 'both') ...[
              BarcodeWidget(
                barcode: Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium),
                data: code,
                width: 90,
                height: 90,
              ),
              const SizedBox(height: 4),
              Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptJaggedEdge({required bool isTop}) {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: CustomPaint(
        painter: _ReceiptJaggedEdgePainter(isTop: isTop, color: const Color(0xFFFCFDFB)),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28, color: Color(0xFF0F172A)),
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Detail Booking',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-Header Strip (Outlet Pill + Action Buttons)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '● ',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          _storeName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCircleActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Hapus Booking',
                        onTap: () => _confirmDelete(context),
                      ),
                      const SizedBox(width: 8),
                      _buildCircleActionButton(
                        icon: Icons.print_outlined,
                        tooltip: 'Cetak Resi',
                        onTap: () => _showPrintOptions(context),
                      ),
                      const SizedBox(width: 8),
                      _buildCircleActionButton(
                        icon: Icons.share_outlined,
                        tooltip: 'Bagikan',
                        onTap: () => _handleShare(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Card Container List
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Card: Booking Code & Badges
                  _buildHeroCard(context),
                  const SizedBox(height: 14),

                  // 2. Customer Information Card
                  _buildCustomerCard(context),
                  const SizedBox(height: 14),

                  // 3. iPhone Unit Information Card
                  _buildIphoneCard(context),
                  const SizedBox(height: 14),

                  // 4. Schedule & Rental Duration Card
                  _buildScheduleCard(context),
                  const SizedBox(height: 14),

                  // 5. Payment & Financial Summary Card
                  _buildFinancialCard(context),
                  const SizedBox(height: 14),

                  // 6. Return & Completion Section (Sesuai detail-booking.blade.php)
                  _buildReturnSection(context),

                  // 7. Notes & Instructions Card (if any)
                  if (booking.notes != null && booking.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildNotesCard(context),
                  ],

                  const SizedBox(height: 120), // Spacing for sticky bottom action bar
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomActionBar(context),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: AppTheme.cardBorder,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF475569)),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final isConfirmed = booking.status == BookingStatus.confirmed;
    final isPaid = booking.paymentStatus == PaymentStatus.paid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KODE BOOKING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: booking.bookingCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Kode booking ${booking.bookingCode} berhasil disalin'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          booking.bookingCode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0284C7)),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      isConfirmed ? 'Dikonfirmasi' : booking.status.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Pembayaran',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? 'LUNAS' : booking.paymentStatus.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Informasi Pelanggan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Terverifikasi',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Nama Lengkap', booking.customerName, isBold: true),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                width: 120,
                child: Text(
                  'Nomor Telepon',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      booking.customerPhone,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openWhatsApp(context, booking.customerPhone),
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(Icons.chat_outlined, size: 14, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _callPhone(context, booking.customerPhone),
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: Icon(Icons.phone_outlined, size: 14, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Email', booking.customerEmail),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 120,
                child: Text(
                  'Alamat Domisili',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
              Expanded(
                child: Text(
                  booking.address != null && booking.address!.isNotEmpty
                      ? booking.address!
                      : 'Jl. Radio Dalam No. 14, Gandaria Utara, Kebayoran Baru',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jaminan Dititipkan',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.credit_card_outlined, size: 13, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(
                      booking.jaminanType.isNotEmpty ? booking.jaminanType : 'KTP Asli',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIphoneCard(BuildContext context) {
    final iphone = booking.iphone;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Unit iPhone & Hardware',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '● ',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 9),
                    ),
                    Text(
                      iphone.status.isNotEmpty ? iphone.status.toUpperCase() : 'READY',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Model Unit', iphone.fullName, isBold: true),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Varian Warna',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getColorVariantDot(iphone.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatVariantColor(iphone.color),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('No. Seri (SN)', iphone.serialNumber, isBold: true),
          const SizedBox(height: 10),
          _buildInfoRow('Kode Aset Unit', iphone.assetCode, isHighlight: true),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Battery Health',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${iphone.batteryHealth}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (iphone.batteryHealth / 100.0).clamp(0.0, 1.0),
                        backgroundColor: AppTheme.cardBorder,
                        color: const Color(0xFF059669),
                        minHeight: 7,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Jadwal & Durasi Rental',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF0284C7)),
                    SizedBox(width: 4),
                    Text(
                      'Terjadwal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Mulai Sewa', Formatters.dateTime(booking.startDate), isBold: true),
          const SizedBox(height: 10),
          _buildInfoRow('Batas Kembali', Formatters.dateTime(booking.endDate), isBold: true),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Durasi',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${booking.durationDays} Jam',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  if (booking.canExtend) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openExtendDurationModal(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.more_time_rounded, size: 13, color: Color(0xFFEA580C)),
                            SizedBox(width: 4),
                            Text(
                              '+ Tambah Jam',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(BuildContext context) {
    final isPaid = booking.paymentStatus == PaymentStatus.paid;
    final calculatedDiscount = booking.discount > 0
        ? booking.discount
        : ((booking.price + booking.deposit) - booking.totalBill);
    final hasDiscount = calculatedDiscount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    booking.deposit > 0 ? 'Ringkasan Biaya & Deposit' : 'Ringkasan Biaya Sewa',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? 'LUNAS' : booking.paymentStatus.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isPaid ? const Color(0xFF10B981) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFinancialRow(
            'Tarif Sewa (${booking.durationDays} Jam)',
            Formatters.currency(booking.price),
            isBold: true,
          ),
          if (booking.deposit > 0) ...[
            const SizedBox(height: 8),
            _buildFinancialRow(
              'Deposit Jaminan Fisik',
              Formatters.currency(booking.deposit),
              isBold: true,
            ),
          ],
          if (hasDiscount) ...[
            const SizedBox(height: 8),
            _buildFinancialRow(
              'Diskon Promo Early Bird',
              '- ${Formatters.currency(calculatedDiscount)}',
              isBold: true,
              color: const Color(0xFF10B981),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Dibayarkan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                Formatters.currency(booking.totalBill),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0284C7),
                ),
                ),
              ],
            ),
          ],
        ),
      );
    }

  Widget _buildNotesCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, size: 18, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Text(
                'Catatan Khusus',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            booking.notes!,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF78350F),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnSection(BuildContext context) {
    final isReturned = booking.status == BookingStatus.returned;
    final isLate = booking.isCurrentlyLate;
    final isOverdue = booking.isCurrentlyOverdue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReturned ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReturned ? const Color(0xFFBBF7D0) : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isReturned ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isReturned ? Icons.assignment_turned_in_rounded : Icons.assignment_return_rounded,
                      color: isReturned ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pengembalian Perangkat',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isReturned
                      ? const Color(0xFFDCFCE7)
                      : (isLate ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isReturned
                      ? 'SUDAH KEMBALI'
                      : (isLate ? 'TELAT' : 'TEPAT WAKTU'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isReturned
                        ? const Color(0xFF16A34A)
                        : (isLate ? const Color(0xFFDC2626) : const Color(0xFF10B981)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isReturned) ...[
            _buildInfoRow('Waktu Pengembalian', Formatters.dateTime(booking.endDate), isBold: true),
            const SizedBox(height: 8),
            _buildInfoRow('Status Unit', 'Telah Dikembalikan (Ready)', isBold: true, color: const Color(0xFF16A34A)),
            const SizedBox(height: 8),
            _buildInfoRow('Kondisi Fisik', 'Mulus / Pengembalian Berhasil'),
          ] else ...[
            _buildInfoRow('Batas Akhir Sewa', Formatters.dateTime(booking.endDate), isBold: true),
            if (isOverdue || isLate) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                'Durasi Keterlambatan',
                booking.lateDurationFormatted,
                isBold: true,
                color: isLate ? const Color(0xFFDC2626) : const Color(0xFFD97706),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Estimasi Denda',
                Formatters.currency(booking.estimatedLateFee),
                isBold: true,
                color: booking.estimatedLateFee > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLate ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isLate ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLate ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: isLate ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isLate
                            ? 'Waktu sewa telah melewati toleransi 90 menit. Denda dihitung otomatis berdasarkan tarif paket sewa iPhone.'
                            : 'Waktu sewa telah melewati tenggat jadwal namun masih dalam masa toleransi 1 jam.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isLate ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              const SizedBox(height: 8),
              _buildInfoRow('Status Waktu', 'Sesuai Jadwal (Tepat Waktu)', color: const Color(0xFF10B981)),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                if (booking.canExtend) ...[
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => _openExtendDurationModal(context),
                        icon: const Icon(
                          Icons.more_time_rounded,
                          size: 16,
                          color: Color(0xFFEA580C),
                        ),
                        label: const Text(
                          'Tambah Durasi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFDBA74)),
                          backgroundColor: const Color(0xFFFFF7ED),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleReturnAction(context),
                      icon: Icon(
                        isLate && booking.estimatedLateFee > 0
                            ? Icons.point_of_sale_rounded
                            : Icons.assignment_turned_in_outlined,
                        size: 16,
                        color: isLate && booking.estimatedLateFee > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF0F172A),
                      ),
                      label: Text(
                        isLate && booking.estimatedLateFee > 0
                            ? 'Bayar Denda'
                            : 'Tandai Selesai',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isLate && booking.estimatedLateFee > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isLate && booking.estimatedLateFee > 0
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFCBD5E1),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (booking.paymentStatus != PaymentStatus.paid) ...[
              // 1. Primary Button (Bayar)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.paymentDeposit, arguments: booking).then((val) {
                      if (val == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    });
                  },
                  icon: const Icon(Icons.point_of_sale_rounded, size: 18, color: Colors.white),
                  label: const Text('Proses Pembayaran di Kasir',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (booking.canReturn) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _handleReturnAction(context),
                  icon: Icon(
                    booking.isCurrentlyLate && booking.estimatedLateFee > 0
                        ? Icons.point_of_sale_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    booking.isCurrentlyLate && booking.estimatedLateFee > 0
                        ? 'Bayar Denda (${Formatters.currency(booking.estimatedLateFee)}) & Selesai'
                        : 'Tandai Selesai (Pengembalian)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: booking.isCurrentlyLate && booking.estimatedLateFee > 0
                        ? AppTheme.primary
                        : const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // 2. Secondary Button (Light Blue - Lihat & Cetak Struk)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _openReceiptScreen(context),
                icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF0284C7)),
                label: const Text(
                  'Lihat & Cetak Struk',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  foregroundColor: const Color(0xFF0284C7),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : (isHighlight ? FontWeight.w700 : FontWeight.w500),
            color: color ??
                (isHighlight
                    ? const Color(0xFF0284C7)
                    : (isBold ? const Color(0xFF0F172A) : const Color(0xFF334155))),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  String _formatVariantColor(String rawColor) {
    if (rawColor.isEmpty || rawColor == '-') return 'Default (Pink)';
    if (rawColor.toLowerCase().startsWith('default')) return rawColor;
    return 'Default ($rawColor)';
  }

  Color _getColorVariantDot(String color) {
    final c = color.toLowerCase();
    if (c.contains('pink') || c.contains('merah muda')) return const Color(0xFFF472B6);
    if (c.contains('blue') || c.contains('biru')) return const Color(0xFF38BDF8);
    if (c.contains('green') || c.contains('hijau')) return const Color(0xFF4ADE80);
    if (c.contains('gold') || c.contains('emas')) return const Color(0xFFFBBF24);
    if (c.contains('silver') || c.contains('putih') || c.contains('starlight') || c.contains('white')) {
      return const Color(0xFFCBD5E1);
    }
    if (c.contains('black') || c.contains('hitam') || c.contains('midnight') || c.contains('space')) {
      return const Color(0xFF334155);
    }
    if (c.contains('purple') || c.contains('ungu')) return const Color(0xFFA855F7);
    if (c.contains('red') || c.contains('merah')) return const Color(0xFFEF4444);
    return const Color(0xFFF472B6);
  }

  void _openWhatsApp(BuildContext context, String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Nomor WhatsApp $phone disalin ke clipboard')),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _callPhone(BuildContext context, String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.phone_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Nomor telepon $phone disalin ke clipboard')),
          ],
        ),
        backgroundColor: const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleShare(BuildContext context) {
    final summary = 'SKYRental Booking #${booking.bookingCode}\n'
        'Pelanggan: ${booking.customerName} (${booking.customerPhone})\n'
        'Unit: ${booking.iphone.fullName}\n'
        'Jadwal: ${Formatters.date(booking.startDate)} s/d ${Formatters.date(booking.endDate)} (${booking.durationDays} Jam)\n'
        'Total: ${Formatters.currency(booking.totalBill)} (${booking.paymentStatus.label})';
    Clipboard.setData(ClipboardData(text: summary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ringkasan booking #${booking.bookingCode} berhasil disalin ke clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openReceiptScreen(BuildContext context) {
    final receipt = _createReceiptFromBooking();
    Navigator.pushNamed(context, AppRoutes.receiptPreview, arguments: receipt);
  }

  void _showPrintOptions(BuildContext context) {
    final receipt = _createReceiptFromBooking();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.print_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cetak Resi Booking',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '#${booking.bookingCode} - ${booking.customerName}',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bluetooth_connected_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: const Text('Cetak Langsung ke Thermal Printer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Kirim payload ESC/POS 58mm ke printer utama', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _printDirectly(context, receipt);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0284C7), size: 20),
                ),
                title: const Text('Buka Pratinjau & Atur Format Resi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Lihat tata letak digital / struk fisik sebelum cetak', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppRoutes.receiptPreview, arguments: receipt);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _printDirectly(BuildContext context, ReceiptModel receipt) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Menghubungi Thermal Printer...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final service = ThermalPrintService();
    final result = await service.printReceipt(receipt);

    if (!context.mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resi #${receipt.receiptNumber} berhasil dicetak! (${result.bytesSent} byte)'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.error,
          action: SnackBarAction(
            label: 'Atur Printer',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.printerSettings);
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 22),
            SizedBox(width: 8),
            Text('Hapus Booking?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus booking #${booking.bookingCode} atas nama ${booking.customerName}?\n\nData booking akan dihapus dari antrean dan database.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repo = repository ?? BookingRepository();
      final success = await repo.deleteBooking(booking.bookingCode);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Booking #${booking.bookingCode} berhasil dihapus.'
                : 'Gagal menghapus booking #${booking.bookingCode}.'),
            backgroundColor: success ? const Color(0xFF047857) : AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (success) {
          Navigator.pop(context, true);
        }
      }
    }
  }
}

/// Custom painter untuk gerigi kertas thermal resi fisik
class _ReceiptJaggedEdgePainter extends CustomPainter {
  final bool isTop;
  final Color color;

  _ReceiptJaggedEdgePainter({required this.isTop, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    const teethWidth = 8.0;
    final teethCount = (size.width / teethWidth).ceil();

    if (isTop) {
      path.moveTo(0, size.height);
      for (int i = 0; i < teethCount; i++) {
        final x = i * teethWidth;
        path.lineTo(x + teethWidth / 2, 0);
        path.lineTo(x + teethWidth, size.height);
      }
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      for (int i = 0; i < teethCount; i++) {
        final x = i * teethWidth;
        path.lineTo(x + teethWidth / 2, size.height);
        path.lineTo(x + teethWidth, 0);
      }
      path.lineTo(size.width, 0);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

