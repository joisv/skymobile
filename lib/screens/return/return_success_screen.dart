import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../models/receipt_model.dart';
import '../../routes/app_routes.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class ReturnSuccessScreen extends StatefulWidget {
  final BookingModel booking;
  final ReceiptModel? receipt;
  final double depositRefunded;
  final double lateFee;
  final double damageFee;
  final String condition;

  const ReturnSuccessScreen({
    super.key,
    required this.booking,
    this.receipt,
    this.depositRefunded = 0,
    this.lateFee = 0,
    this.damageFee = 0,
    this.condition = 'Baik / Normal',
  });

  @override
  State<ReturnSuccessScreen> createState() => _ReturnSuccessScreenState();
}

class _ReturnSuccessScreenState extends State<ReturnSuccessScreen> {
  final ThermalPrintService _printService = ThermalPrintService();
  bool _isPrinting = false;
  bool _hasPrinted = false;

  BookingModel get b => widget.booking;

  ReceiptModel get _receipt {
    if (widget.receipt != null) {
      return widget.receipt!;
    }
    // Fallback receipt bila dibuka langsung
    final now = DateTime.now();
    final totalDeductions = widget.lateFee + widget.damageFee;
    return ReceiptModel(
      receiptNumber: 'STR-${now.year}${now.month.toString().padLeft(2, '0')}-${(3000 + b.id)}',
      date: now,
      adminName: 'Staff Admin SKYRental',
      branchName: 'Outlet Malioboro',
      type: ReceiptType.returnUnit,
      bookingCode: b.bookingCode,
      customerName: b.customerName,
      customerPhone: b.customerPhone,
      unitName: b.iphone.fullName,
      serialNumber: b.iphone.serialNumber,
      assetCode: b.iphone.assetCode,
      rentalDuration: '${b.durationDays} Hari',
      rentalDates: '${Formatters.date(b.startDate)} - ${Formatters.date(b.endDate)}',
      rentFee: b.price,
      depositFee: b.deposit,
      finesFee: totalDeductions,
      discountFee: 0,
      totalAmount: b.price + totalDeductions,
      paidAmount: b.price,
      remainingAmount: 0,
      refundAmount: widget.depositRefunded,
      paymentMethod: 'Tunai Kasir',
      paymentStatus: 'refunded',
      depositStatus: 'Telah Direfund',
      notes: 'Pengembalian selesai. Kondisi: ${widget.condition}. Deposit dikembalikan: ${Formatters.currency(widget.depositRefunded)}.',
    );
  }

  Future<void> _handlePrintReceipt() async {
    setState(() => _isPrinting = true);

    try {
      final res = await _printService.printReceipt(_receipt);
      if (!mounted) return;

      setState(() {
        _isPrinting = false;
        if (res.isSuccess) {
          _hasPrinted = true;
        }
      });

      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Struk Pengembalian ${_receipt.receiptNumber} berhasil dicetak ke thermal printer!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(res.message),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'PENGATURAN',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.printerSettings);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mencetak: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _shareViaWhatsApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bukti pengembalian unit ${b.bookingCode} telah dikirimkan ke WhatsApp ${b.customerPhone}.',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _finishAndReturn() {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainNavigation, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _finishAndReturn();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Pengembalian Berhasil'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Tutup & Kembali ke Daftar',
              onPressed: _finishAndReturn,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Step Indicator
              _buildStepProgress(),
              const SizedBox(height: 16),

              // 2. Hero Success Card
              _buildHeroSuccessCard(),
              const SizedBox(height: 16),

              // 3. Status Inventaris & Unit Card
              _buildInventoryUnitCard(),
              const SizedBox(height: 16),

              // 4. Jaminan Fisik Dikembalikan Card
              _buildCollateralReturnCard(),
              const SizedBox(height: 16),

              // 5. Rincian Finansial & Refund Deposit Card
              _buildFinancialSummaryCard(),
              const SizedBox(height: 16),

              // 6. Preview Struk Thermal 58mm (ESC/POS 32 Kolom)
              _buildThermalReceiptPreview(),
              const SizedBox(height: 24),

              // 7. Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepItem('1', 'Ringkasan', isDone: true),
          _buildStepLine(isDone: true),
          _buildStepItem('2', 'Pemeriksaan', isDone: true),
          _buildStepLine(isDone: true),
          _buildStepItem('3', 'Selesai & Struk', isActive: true),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String label, {bool isActive = false, bool isDone = false}) {
    Color bg = AppTheme.cardBorder;
    Color textCol = AppTheme.textSecondary;
    if (isActive) {
      bg = const Color(0xFF047857);
      textCol = Colors.white;
    } else if (isDone) {
      bg = const Color(0xFFDCFCE7);
      textCol = const Color(0xFF047857);
    }

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(
            child: isDone && !isActive
                ? const Icon(Icons.check, size: 14, color: Color(0xFF047857))
                : Text(number, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textCol)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.normal,
            color: isActive ? const Color(0xFF047857) : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isDone}) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDone ? const Color(0xFF10B981) : AppTheme.cardBorder,
    );
  }

  Widget _buildHeroSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF047857),
              size: 48,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Pengembalian iPhone Berhasil!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Unit ${b.iphone.fullName} telah sah diterima kembali oleh kasir/admin. Deposit dan jaminan fisik telah diproses.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'KODE BOOKING: ${b.bookingCode}',
                  style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryUnitCard() {
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
                  Icon(Icons.inventory_2_rounded, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Unit & Pembaruan Stok',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF047857)),
                    SizedBox(width: 4),
                    Text(
                      'Tersedia di Gudang',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),
          _buildInfoRow('Tipe Perangkat', b.iphone.fullName),
          _buildInfoRow('Kode Aset Unit', b.iphone.assetCode, isMonospace: true),
          _buildInfoRow('Nomor Seri (SN)', b.iphone.serialNumber, isMonospace: true),
          _buildInfoRow('Kondisi Fisik', widget.condition),
          _buildInfoRow('Apple ID & iCloud', 'Logout Bersih (Terverifikasi)', valueColor: const Color(0xFF047857)),
          _buildInfoRow('Passcode & Find My', 'Nonaktif (Aman)', valueColor: const Color(0xFF047857)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF047857)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status unit pada katalog sistem telah otomatis diubah kembali menjadi "Tersedia". Unit siap untuk disewakan kepada penyewa berikutnya.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollateralReturnCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
              const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                'Pengembalian Jaminan Fisik',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),
          _buildInfoRow('Jenis Dokumen Jaminan', b.jaminanType, isBold: true),
          _buildInfoRow('Penyewa Penerima', b.customerName),
          _buildInfoRow('No. Telepon Penerima', b.customerPhone),
          _buildInfoRow('Status Jaminan', 'Telah Diserahkan Kembali', valueColor: const Color(0xFF047857)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dokumen jaminan (${b.jaminanType}) telah diserahterimakan kembali kepada ${b.customerName}. Tidak ada jaminan tertahan di outlet.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    final totalDeductions = widget.lateFee + widget.damageFee;
    final hasDeposit = b.deposit > 0 || widget.depositRefunded > 0;

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
            children: [
              Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                hasDeposit ? 'Rincian Keuangan & Refund Deposit' : 'Rincian Pengembalian & Denda',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),
          _buildInfoRow('Tarif Sewa Pokok', Formatters.currency(b.price)),
          if (hasDeposit)
            _buildInfoRow('Deposit Awal Ditahan', Formatters.currency(b.deposit)),
          if (widget.lateFee > 0)
            _buildInfoRow(
              'Denda Keterlambatan',
              Formatters.currency(widget.lateFee),
              valueColor: const Color(0xFFDC2626),
              isBold: true,
            ),
          if (widget.damageFee > 0)
            _buildInfoRow(
              'Biaya Kerusakan / Kelengkapan',
              Formatters.currency(widget.damageFee),
              valueColor: const Color(0xFFDC2626),
            ),
          if (totalDeductions > 0 && hasDeposit)
            _buildInfoRow(
              'Total Pemotongan Denda',
              '-${Formatters.currency(totalDeductions)}',
              valueColor: const Color(0xFFDC2626),
              isBold: true,
            ),
          Divider(height: 16, color: AppTheme.cardBorder),
          if (hasDeposit) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deposit Dikembalikan:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    Text(
                      'Dana yang dikembalikan ke pelanggan',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                Text(
                  Formatters.currency(widget.depositRefunded),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildInfoRow('Metode Pengembalian Dana', _receipt.paymentMethod, isBold: true),
          ],
          _buildInfoRow('Status Transaksi Sewa', 'SELESAI (RETURNED)', valueColor: const Color(0xFF047857)),
        ],
      ),
    );
  }

  Widget _buildThermalReceiptPreview() {
    final receiptText = _receipt.toEscPos58mm();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBorder,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13)),
            ),
            child: Row(children: [
                Icon(Icons.print_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Pratinjau Struk Thermal (VSC MP-58C - 32 Kolom)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: SelectableText(
                receiptText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.3,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isPrinting ? null : _handlePrintReceipt,
            icon: _isPrinting
                ? const SizedBox(width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    _hasPrinted ? Icons.check_circle_outline_rounded : Icons.print_rounded,
                    size: 20,
                  ),
            label: Text(
              _isPrinting
                  ? 'Mentransmisikan ke Printer...'
                  : (_hasPrinted ? 'Cetak Ulang Struk Pengembalian' : 'Cetak Struk Pengembalian (Thermal)'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasPrinted ? const Color(0xFF047857) : AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareViaWhatsApp,
                icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF0284C7)),
                label: const Text(
                  'Kirim ke WA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.receiptPreview,
                    arguments: _receipt,
                  );
                },
                icon: Icon(Icons.fullscreen_rounded, size: 18, color: AppTheme.primary),
                label: Text('Pratinjau Penuh',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _finishAndReturn,
            icon: Icon(Icons.arrow_back_rounded, size: 18, color: AppTheme.textSecondary),
            label: Text(
              'Selesai & Kembali ke Daftar Pengembalian',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
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
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
