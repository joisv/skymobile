import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class ReturnSummaryScreen extends StatefulWidget {
  final BookingModel booking;
  final BookingRepository repository;

  const ReturnSummaryScreen({
    super.key,
    required this.booking,
    required this.repository,
  });

  @override
  State<ReturnSummaryScreen> createState() => _ReturnSummaryScreenState();
}

class _ReturnSummaryScreenState extends State<ReturnSummaryScreen> {
  DateTime get _now => DateTime.now();

  BookingModel get b => widget.booking;

  bool get _isOverdue => b.isCurrentlyOverdue || b.isCurrentlyLate;

  int get _daysLate => b.currentLateHours ~/ 24;

  double get _lateFee => b.estimatedLateFee;

  void _onProceedToInspection() {
    Navigator.pushNamed(
      context,
      AppRoutes.returnInspection,
      arguments: {
        'booking': b,
        'daysLate': _daysLate,
        'lateFee': _lateFee,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ringkasan Sewa Pengembalian'),
        actions: [
          IconButton(
            tooltip: 'Detail Booking',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.bookingDetail, arguments: b);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Step Progress Header
          _buildStepIndicator(),

          // 2. Main Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Alert banner jika terlambat
                      if (_isOverdue) _buildOverdueAlertBanner(),
                      if (!_isOverdue) _buildOnTimeBanner(),
                      const SizedBox(height: 14),

                      // Card 1: Data Pelanggan & Jaminan Fisik
                      _buildCustomerAndCollateralCard(),
                      const SizedBox(height: 14),

                      // Card 2: Detail Unit iPhone yang Disewa
                      _buildIphoneUnitCard(),
                      const SizedBox(height: 14),

                      // Card 3: Waktu Sewa & Durasi
                      _buildTimelineCard(),
                      const SizedBox(height: 14),

                      // Card 4: Rincian Keuangan & Deposit
                      _buildFinancialSummaryCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Sticky Bottom Action Bar
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStepItem(1, 'Ringkasan Sewa', isActive: true, isDone: false),
          _buildStepDivider(),
          _buildStepItem(2, 'Pemeriksaan Unit', isActive: false, isDone: false),
          _buildStepDivider(),
          _buildStepItem(3, 'Selesai & Struk', isActive: false, isDone: false),
        ],
      ),
    );
  }

  Widget _buildStepItem(int stepNumber, String title, {required bool isActive, required bool isDone}) {
    final color = isActive
        ? AppTheme.primary
        : isDone
            ? const Color(0xFF047857)
            : const Color(0xFF94A3B8);

    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: isDone
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider() {
    return Container(
      width: 16,
      height: 1,
      color: const Color(0xFFCBD5E1),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildOverdueAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERINGATAN: PENGEMBALIAN TERLAMBAT $_daysLate HARI',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Batas pengembalian adalah ${Formatters.dateTime(b.endDate)}. Denda keterlambatan sebesar ${Formatters.currency(_lateFee)} akan diperhitungkan dari deposit jaminan.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnTimeBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PENGEMBALIAN TEPAT WAKTU',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                ),
                Text(
                  'Batas pengembalian: ${Formatters.dateTime(b.endDate)}. Tidak dikenakan denda waktu.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAndCollateralCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                  Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text('Data Pelanggan & Jaminan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.bookingCode,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildKeyValueRow('Nama Pelanggan', b.customerName),
          _buildKeyValueRow('Nomor Telepon', b.customerPhone),
          _buildKeyValueRow('Email Pelanggan', b.customerEmail.isNotEmpty ? b.customerEmail : '-'),
          if (b.address != null && b.address!.isNotEmpty)
            _buildKeyValueRow('Alamat', b.address!),
          const Divider(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Jaminan Fisik Ditahan:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    b.jaminanType,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '*Pastikan jaminan fisik ini siap dikembalikan kepada penyewa setelah pemeriksaan unit selesai.',
            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildIphoneUnitCard() {
    final unit = b.iphone;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                  Icon(Icons.phone_iphone_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text('Unit iPhone yang Disewa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  unit.assetCode,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.phone_iphone_rounded, size: 36, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.fullName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Warna: ${unit.color}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      'S/N: ${unit.serialNumber}',
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Battery Health Awal:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                Text('${unit.batteryHealth}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Waktu & Durasi Sewa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 20),
          _buildKeyValueRow('Mulai Sewa', Formatters.dateTime(b.startDate)),
          _buildKeyValueRow('Batas Pengembalian', Formatters.dateTime(b.endDate)),
          _buildKeyValueRow('Durasi Pemakaian', '${b.durationDays} Hari'),
          _buildKeyValueRow('Metode Pengambilan', b.pickupType),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Waktu Proses Sekarang:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text(
                Formatters.dateTime(_now),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
              Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Rincian Biaya Sewa & Denda', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 20),
          _buildKeyValueRow('Total Biaya Sewa (${b.durationDays} Jam)', Formatters.currency(b.price)),
          _buildKeyValueRow('Status Pembayaran Sewa', b.paymentStatus.label, valueColor: const Color(0xFF047857)),
          if (b.deposit > 0)
            _buildKeyValueRow('Deposit Ditahan', Formatters.currency(b.deposit)),
          if (_isOverdue || _lateFee > 0) ...[
            const Divider(height: 16),
            _buildKeyValueRow(
              'Denda Keterlambatan (${b.lateDurationFormatted})',
              Formatters.currency(_lateFee),
              valueColor: const Color(0xFFDC2626),
              isBold: true,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                '*Denda keterlambatan dihitung otomatis sesuai durasi dan tarif paket sewa.',
                style: TextStyle(fontSize: 10, color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(String key, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lateFee > 0 ? 'Denda Keterlambatan:' : 'Status Pengembalian:',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
                Text(
                  _lateFee > 0 ? Formatters.currency(_lateFee) : 'Tepat Waktu',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _lateFee > 0 ? const Color(0xFFDC2626) : const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _onProceedToInspection,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              _lateFee > 0 ? 'Proses Denda & Return' : 'Selesaikan Pengembalian',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _lateFee > 0 ? AppTheme.primary : const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
