import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../models/receipt_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class PickupSuccessScreen extends StatefulWidget {
  final BookingModel booking;
  final IphoneModel? assignedIphone;
  final String paymentMethod;
  final String? staffNotes;

  const PickupSuccessScreen({
    super.key,
    required this.booking,
    this.assignedIphone,
    this.paymentMethod = 'QRIS',
    this.staffNotes,
  });

  @override
  State<PickupSuccessScreen> createState() => _PickupSuccessScreenState();
}

class _PickupSuccessScreenState extends State<PickupSuccessScreen> {
  bool _isPrinting = false;
  bool _hasPrinted = false;

  IphoneModel get _unit => widget.assignedIphone ?? widget.booking.iphone;

  String _generateReceiptText() {
    final now = DateTime.now();
    final b = widget.booking;
    final unit = _unit;

    return '''
================================
${'SKYRENTAL'.padLeft(19).padRight(32)}
${'Sewa iPhone Terpercaya'.padLeft(27).padRight(32)}
================================
Tgl       : ${Formatters.date(now)} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}
No. Struk : ${b.bookingCode}
Admin     : Staff Outlet Dipatiukur
Pelanggan : ${b.customerName}
Kontak    : ${b.customerPhone}
Unit      : ${unit.fullName}
Warna     : ${unit.color}
Kode Aset : ${unit.assetCode}
No. Seri  : ${unit.serialNumber}
BH Unit   : ${unit.batteryHealth}%
Durasi    : ${b.durationDays} Hari
Periode   : ${Formatters.date(b.startDate)} - ${Formatters.date(b.endDate)}
Jaminan   : ${b.jaminanType}
--------------------------------
Biaya Sewa: ${Formatters.currency(b.price)}
Deposit   : ${Formatters.currency(b.deposit)}
--------------------------------
TOTAL     : ${Formatters.currency(b.totalBill)}
Metode    : ${widget.paymentMethod}
Status    : PICKUP BERHASIL
================================
${'Syarat & Ketentuan Berlaku'.padLeft(29).padRight(32)}
${'Harap simpan struk ini sebagai'.padLeft(31).padRight(32)}
${'bukti pengembalian unit.'.padLeft(27).padRight(32)}
================================
''';
  }

  Future<void> _printReceipt() async {
    setState(() => _isPrinting = true);

    // Simulate Bluetooth ESC/POS transmission to VSC MP-58C
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() {
      _isPrinting = false;
      _hasPrinted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Struk serah terima berhasil dicetak ke Printer Thermal VSC MP-58C!'),
          ],
        ),
        backgroundColor: Color(0xFF047857),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareDigitalReceipt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Salinan bukti sewa ${widget.booking.bookingCode} dikirim ke WhatsApp ${widget.booking.customerPhone}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final unit = _unit;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.bookingList, (route) => false);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Serah Terima Sukses'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Tutup & Kembali ke Daftar',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.bookingList, (route) => false);
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Success Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF047857),
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Serah Terima Unit Berhasil!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unit ${unit.fullName} telah sah diserahkan kepada ${b.customerName}. Status unit diperbarui menjadi "Disewa".',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Text(
                        'KODE TRANSAKSI: ${b.bookingCode}',
                        style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Transaction Details Card
              _buildTransactionCard(b, unit),
              const SizedBox(height: 16),

              // 3. Thermal Receipt Preview Box (58mm Paper format)
              _buildReceiptBox(),
              const SizedBox(height: 24),

              // 4. Action Buttons
              _buildActionsSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BookingModel b, IphoneModel unit) {
    return Container(
      width: double.infinity,
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
              Icon(Icons.inventory_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Ringkasan Unit & Transaksi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),
          _buildInfoRow('Pelanggan', b.customerName),
          _buildInfoRow('Nomor Kontak', b.customerPhone),
          _buildInfoRow('Unit Fisik', unit.fullName, isBold: true),
          _buildInfoRow('Warna Unit', unit.color),
          _buildInfoRow('Kode Aset Unit', unit.assetCode),
          _buildInfoRow('Nomor Seri (SN)', unit.serialNumber),
          _buildInfoRow('Battery Health', '${unit.batteryHealth}%'),
          _buildInfoRow('Jaminan Fisik', b.jaminanType, isHighlight: true),
          _buildInfoRow('Masa Sewa', '${Formatters.dateTime(b.startDate)} s/d ${Formatters.dateTime(b.endDate)} (${b.durationDays} Hari)'),
          const SizedBox(height: 6),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 6),
          _buildInfoRow('Biaya Rental', Formatters.currency(b.price)),
          _buildInfoRow('Deposit Jaminan', Formatters.currency(b.deposit)),
          _buildInfoRow('Total Diterima', Formatters.currency(b.totalBill), isBold: true, isHighlight: true),
          _buildInfoRow('Metode Pembayaran', widget.paymentMethod),
          if (widget.staffNotes != null && widget.staffNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 6),
            _buildInfoRow('Catatan Staff', widget.staffNotes!),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptBox() {
    return Container(
      width: double.infinity,
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
                  Icon(Icons.print_outlined, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Format Struk Thermal (58mm)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'VSC MP-58C',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(
              _generateReceiptText(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.35,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Column(
      children: [
        // Primary Print Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isPrinting ? null : _printReceipt,
            icon: _isPrinting
                ? const SizedBox(width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_hasPrinted ? Icons.check_circle : Icons.print_rounded, size: 18),
            label: Text(
              _isPrinting
                  ? 'Mencetak ke VSC MP-58C...'
                  : _hasPrinted
                      ? 'Cetak Ulang Struk'
                      : 'Cetak Struk Thermal',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

        // Share Digital Receipt Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _shareDigitalReceipt,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Kirim Struk ke WhatsApp Pelanggan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: BorderSide(color: AppTheme.accent),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Full Receipt Preview Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final b = widget.booking;
              final unit = _unit;
              final receipt = ReceiptModel(
                receiptNumber: 'STR-202609-${b.id}',
                date: DateTime.now(),
                adminName: 'Staff Outlet Dipatiukur',
                branchName: 'SKYRENTAL YOGYAKARTA',
                type: ReceiptType.pickup,
                bookingCode: b.bookingCode,
                customerName: b.customerName,
                customerPhone: b.customerPhone,
                unitName: unit.fullName,
                serialNumber: unit.serialNumber,
                assetCode: unit.assetCode,
                rentalDuration: '${b.durationDays} Hari',
                rentalDates: '${Formatters.date(b.startDate)} - ${Formatters.date(b.endDate)}',
                rentFee: b.price,
                depositFee: b.deposit,
                totalAmount: b.totalBill,
                paidAmount: b.totalBill,
                remainingAmount: 0,
                paymentMethod: widget.paymentMethod,
                paymentStatus: 'Lunas',
                depositStatus: 'Ditahan (Aktif)',
                notes: widget.staffNotes,
              );
              Navigator.pushNamed(context, AppRoutes.receiptPreview, arguments: receipt);
            },
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('Buka Pratinjau Struk Lengkap'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Done / Back to Home
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.bookingList, (route) => false);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Selesai & Kembali ke Daftar Booking'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.w600,
                color: isHighlight ? AppTheme.accent : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
