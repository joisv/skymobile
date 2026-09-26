import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/receipt_model.dart';
import '../../routes/app_routes.dart';
import '../../screens/payment/payment_deposit_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class ReturnInspectionScreen extends StatefulWidget {
  final BookingModel? booking;
  final BookingRepository repository;
  final double initialLateFee;
  final int daysLate;

  const ReturnInspectionScreen({
    super.key,
    this.booking,
    required this.repository,
    this.initialLateFee = 0.0,
    this.daysLate = 0,
  });

  @override
  State<ReturnInspectionScreen> createState() => _ReturnInspectionScreenState();
}

class _ReturnInspectionScreenState extends State<ReturnInspectionScreen> {
  BookingModel? _activeBooking;
  bool _isLoading = true;
  bool _isSubmitting = false;

  double _apiLateFee = 0.0;
  int _apiHoursLate = 0;
  String? _apiDurationText;
  bool? _apiIsLate;
  double? _customLateFee;
  bool _hasFetchedApi = false;

  @override
  void initState() {
    super.initState();
    _loadBookingData();
  }

  Future<void> _loadBookingData() async {
    if (widget.booking != null) {
      _activeBooking = widget.booking;
    } else {
      try {
        final rentals = await widget.repository.getRentals();
        if (rentals.isNotEmpty) {
          _activeBooking = rentals.first;
        }
      } catch (_) {}
    }

    if (_activeBooking != null) {
      _apiLateFee = _activeBooking!.estimatedLateFee;
      _apiHoursLate = _activeBooking!.currentLateHours;
      _apiDurationText = _activeBooking!.lateDurationFormatted;
      _apiIsLate = _activeBooking!.isCurrentlyLate;

      // Fetch data kalkulasi denda dari backend
      try {
        final inspectData = await widget.repository.getInspectionPreview(_activeBooking!.bookingCode);
        if (inspectData != null && inspectData['status'] == 'success') {
          final data = inspectData['data'];
          if (mounted) {
            setState(() {
              _apiLateFee = (data['estimated_late_fee'] as num?)?.toDouble() ??
                  (data['late_fee'] as num?)?.toDouble() ??
                  0.0;
              _apiHoursLate = (data['hours_late'] as num?)?.toInt() ??
                  (data['late_hours'] as num?)?.toInt() ??
                  0;
              if (data['duration_text'] != null) {
                _apiDurationText = data['duration_text'].toString();
              }
              if (data['is_late'] != null) {
                _apiIsLate = data['is_late'] == true;
              }
              _hasFetchedApi = true;
            });
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _isLate => _apiIsLate ?? _activeBooking?.isCurrentlyLate ?? false;
  String get _durationText =>
      _apiDurationText ??
      _activeBooking?.lateDurationFormatted ??
      '${_apiHoursLate > 0 ? _apiHoursLate : widget.daysLate * 24} Jam';

  double get _lateFee =>
      _customLateFee ??
      (_hasFetchedApi ? _apiLateFee : (_activeBooking?.estimatedLateFee ?? widget.initialLateFee));

  Future<void> _editLateFeeDialog() async {
    final controller = TextEditingController(text: _lateFee.toInt().toString());
    final newFee = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Penyesuaian Denda Keterlambatan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Durasi Keterlambatan: $_durationText',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            const Text('Nominal Denda (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
              Navigator.pop(ctx, val);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newFee != null) {
      setState(() {
        _customLateFee = newFee;
      });
    }
  }

  void _onPayFineAtCashier() {
    if (_activeBooking == null) return;

    Navigator.pushNamed(
      context,
      AppRoutes.paymentDeposit,
      arguments: {
        'booking': _activeBooking,
        'initialPaymentType': PaymentTypeOption.penalty,
        'initialAmount': _lateFee,
        'isReturnFlow': true,
      },
    ).then((val) {
      if (val == true && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  Future<void> _completeOnTimeReturn() async {
    if (_activeBooking == null) return;

    final confirm = await showDialog<bool>(
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
          'Unit ${_activeBooking!.iphone.fullName} dikembalikan tepat waktu tanpa denda. Selesaikan pengembalian unit dan ubah status unit menjadi Tersedia?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final completed = await widget.repository.completeReturn(
        bookingCode: _activeBooking!.bookingCode,
        physicalCondition: 'Baik / Sempurna',
        batteryHealthFinal: _activeBooking!.iphone.batteryHealth,
        lateFee: 0,
        damageFee: 0,
        depositRefunded: 0,
        refundMethod: 'Tanpa Denda',
        accessoriesReturned: ['Lengkap'],
        staffNotes: 'Pengembalian unit tepat waktu diselesaikan langsung.',
      );

      final returnReceipt = ReceiptModel(
        receiptNumber:
            'STR-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${(4000 + _activeBooking!.id)}',
        date: DateTime.now(),
        adminName: 'Budi (Staff Kasir)',
        branchName: 'Outlet Jakarta Selatan - Gandaria',
        type: ReceiptType.returnUnit,
        bookingCode: _activeBooking!.bookingCode,
        customerName: _activeBooking!.customerName,
        customerPhone: _activeBooking!.customerPhone,
        unitName: _activeBooking!.iphone.modelName,
        serialNumber: _activeBooking!.iphone.serialNumber,
        assetCode: _activeBooking!.iphone.assetCode,
        rentalDuration: '${_activeBooking!.durationDays} Jam',
        rentalDates:
            '${Formatters.formatDate(_activeBooking!.startDate)} - ${Formatters.formatDate(_activeBooking!.endDate)}',
        rentFee: _activeBooking!.price,
        depositFee: 0.0,
        finesFee: 0.0,
        discountFee: 0,
        totalAmount: _activeBooking!.price,
        paidAmount: _activeBooking!.price,
        remainingAmount: 0,
        refundAmount: 0.0,
        paymentMethod: 'Tepat Waktu',
        paymentStatus: 'paid',
        depositStatus: 'Tanpa Deposit',
        notes: 'Pengembalian unit selesai tepat waktu tanpa denda.',
      );

      await widget.repository.saveReceipt(returnReceipt);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.returnSuccess,
        arguments: {
          'booking': completed,
          'receipt': returnReceipt,
          'depositRefunded': 0.0,
          'lateFee': 0.0,
          'damageFee': 0.0,
          'condition': 'Baik / Sempurna',
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyelesaikan pengembalian: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final booking = _activeBooking;
    final customerName = booking?.customerName ?? 'Pelanggan';
    final customerPhone = booking?.customerPhone ?? '-';
    final bookingCode = booking?.bookingCode ?? '#BK-0001';
    final modelName = booking?.iphone.modelName ?? 'iPhone Unit';
    final colorSN =
        '${booking?.iphone.color ?? 'Titanium'} • SN: ${booking?.iphone.serialNumber ?? 'SN-UNKNOWN'}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/brand_logo.png',
              height: 28,
              width: 28,
              errorBuilder: (_, __, ___) => Icon(Icons.phone_iphone, size: 24, color: AppTheme.secondary),
            ),
            const SizedBox(width: 8),
            Text('Pengembalian Unit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Context header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_turned_in, size: 16, color: AppTheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      bookingCode,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isLate ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isLate ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isLate ? 'TERLAMBAT' : 'TEPAT WAKTU',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isLate ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Detail Pengembalian & Kalkulasi Denda',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 14),

            // Device & Customer Overview Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.phone_iphone_rounded, size: 28, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              modelName,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              colorSN,
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (booking?.iphone.assetCode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            booking!.iphone.assetCode,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Customer & Schedule Pill
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_rounded, size: 15, color: AppTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text(customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text(
                              customerPhone,
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Batas Akhir Sewa:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            Text(
                              booking != null ? Formatters.dateTime(booking.endDate) : '-',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Kalkulasi Keterlambatan & Denda Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _lateFee > 0 ? const Color(0xFFFECACA) : AppTheme.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                          Icon(Icons.schedule_rounded, size: 18, color: AppTheme.secondary),
                          const SizedBox(width: 8),
                          Text(
                            'Kalkulasi Keterlambatan',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isLate ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isLate ? 'DIKENAI DENDA' : 'BEBAS DENDA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isLate ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder),
                  _buildDetailRow('Durasi Keterlambatan', _durationText, isBold: true, color: _isLate ? const Color(0xFFDC2626) : null),
                  const SizedBox(height: 8),
                  _buildDetailRow('Toleransi Keterlambatan', '1 Jam (Bebas Biaya)'),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Tarif Sewa Pokok',
                    Formatters.currency(booking?.price ?? 0),
                  ),
                  Divider(height: 20, color: AppTheme.cardBorder),

                  // Total Denda Keterlambatan Tile
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('Denda Keterlambatan',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Sesuaikan Nominal Denda',
                            child: GestureDetector(
                              onTap: _editLateFeeDialog,
                              child: Icon(Icons.edit_outlined, size: 15, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _lateFee > 0 ? Formatters.currency(_lateFee) : 'Rp 0',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _lateFee > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info Notice Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _lateFee > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _lateFee > 0 ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _lateFee > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _lateFee > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lateFee > 0
                                ? 'Penyewa terlambat mengembalikan perangkat. Pembayaran denda sebesar ${Formatters.currency(_lateFee)} akan diproses langsung di Kasir Pembayaran.'
                                : 'Perangkat dikembalikan tepat waktu atau masih dalam masa toleransi. Pengembalian dapat langsung diselesaikan tanpa denda.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: _lateFee > 0 ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                            ),
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
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.cardBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: _lateFee > 0
                ? ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _onPayFineAtCashier,
                    icon: const Icon(Icons.point_of_sale_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Bayar Denda (${Formatters.currency(_lateFee)}) di Kasir',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _completeOnTimeReturn,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Selesaikan Pengembalian Unit',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
