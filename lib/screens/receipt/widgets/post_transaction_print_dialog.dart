import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../../models/receipt_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/thermal_print_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';

class PostTransactionPrintDialog extends StatefulWidget {
  final ReceiptModel receipt;
  final VoidCallback? onFinish;

  const PostTransactionPrintDialog({
    super.key,
    required this.receipt,
    this.onFinish,
  });

  static Future<void> show(
    BuildContext context, {
    required ReceiptModel receipt,
    VoidCallback? onFinish,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PostTransactionPrintDialog(
        receipt: receipt,
        onFinish: onFinish,
      ),
    );
  }

  @override
  State<PostTransactionPrintDialog> createState() => _PostTransactionPrintDialogState();
}

class _PostTransactionPrintDialogState extends State<PostTransactionPrintDialog> {
  bool _isPrinting = false;
  bool _hasPrinted = false;

  ReceiptModel get r => widget.receipt;

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);

    final result = await ThermalPrintService().printReceipt(r);

    if (!mounted) return;
    setState(() {
      _isPrinting = false;
      if (result.isSuccess) {
        _hasPrinted = true;
      }
    });

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resi ${r.receiptNumber} berhasil dicetak ke ${result.deviceName ?? 'Printer Thermal'} (${result.bytesSent} byte)!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
          content: Text(result.message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Pengaturan',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.printerSettings);
            },
          ),
        ),
      );
    }
  }

  void _handleShareWhatsApp() {
    final String text;
    if (r.type == ReceiptType.returnUnit) {
      text = '''
*SKYRENTAL - STRUK PENGEMBALIAN IPHONE*
No. Struk    : ${r.receiptNumber}
Pelanggan    : ${r.customerName}
Kontak       : ${r.customerPhone}
Unit iPhone  : ${r.unitName}
Kode Booking : ${r.bookingCode}
-----------------------------
Status Unit  : KEMBALI (TERSEDIA)
Jaminan      : TELAH DISERAHKAN BALIK
-----------------------------
Deposit Awal : ${Formatters.currency(r.depositFee)}
Potongan Denda: ${r.finesFee > 0 ? '-${Formatters.currency(r.finesFee)}' : 'Rp 0'}
Refund Deposit: ${Formatters.currency(r.refundAmount)}
Metode Refund: ${r.paymentMethod}
Status       : SELESAI / LUNAS
-----------------------------
Terima kasih telah menyewa iPhone di SKYRental!
'''.trim();
    } else {
      text = '''
*SKYRENTAL - BUKTI TRANSAKSI*
No. Struk: ${r.receiptNumber}
Pelanggan: ${r.customerName}
Unit: ${r.unitName}
Kode Booking: ${r.bookingCode}
-----------------------------
Total: ${Formatters.currency(r.totalAmount)}
Terbayar: ${Formatters.currency(r.paidAmount)}
Metode: ${r.paymentMethod}
Status: ${r.paymentStatus.toUpperCase()}
-----------------------------
Terima kasih telah mempercayai SKYRental. Simpan pesan ini sebagai bukti transaksi.
'''.trim();
    }

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Teks bukti transaksi disalin! Siap dikirim ke WA ${r.customerPhone}.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleOpenFullPreview() {
    Navigator.pushNamed(
      context,
      AppRoutes.receiptPreview,
      arguments: r,
    );
  }

  void _handleDismiss() {
    Navigator.pop(context);
    if (widget.onFinish != null) {
      widget.onFinish!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF047857), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.type == ReceiptType.returnUnit ? 'Pengembalian Selesai!' : 'Transaksi Selesai!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                Text(
                  '${r.type.label} • ${r.bookingCode}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 16),

            // Hardware Connection Info Ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(children: [
                  Icon(Icons.print_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Printer Siap: VSC MP-58C (Thermal 58mm)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Mini Thermal Receipt Preview Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCFDFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'SKYRENTAL - ${r.branchName}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      'No. Struk: ${r.receiptNumber}',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ),
                  const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
                  if (r.type == ReceiptType.returnUnit) ...[
                    _buildMiniRow('Pelanggan', r.customerName),
                    _buildMiniRow('Unit', r.unitName),
                    _buildMiniRow('Deposit Awal', Formatters.currency(r.depositFee)),
                    if (r.finesFee > 0) _buildMiniRow('Pot. Denda', '-${Formatters.currency(r.finesFee)}'),
                    _buildMiniRow('Refund Dep.', Formatters.currency(r.refundAmount)),
                    _buildMiniRow('Metode', r.paymentMethod),
                    _buildMiniRow('Status Unit', 'TERSEDIA'),
                  ] else ...[
                    _buildMiniRow('Pelanggan', r.customerName),
                    _buildMiniRow('Unit', r.unitName),
                    _buildMiniRow('Total', Formatters.currency(r.totalAmount)),
                    _buildMiniRow('Terbayar', Formatters.currency(r.paidAmount)),
                    _buildMiniRow('Metode', r.paymentMethod),
                    _buildMiniRow('Status', r.paymentStatus.toUpperCase()),
                  ],
                  const SizedBox(height: 6),
                  Center(
                    child: BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: r.bookingCode,
                      width: 140,
                      height: 32,
                      drawText: true,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 10)),
                  Center(
                    child: Text(
                      _hasPrinted ? '✓ STRUK SUDAH DICETAK' : 'SIAP CETAK (32 KOLOM)',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _hasPrinted ? const Color(0xFF047857) : AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Primary Print Button
            ElevatedButton.icon(
              onPressed: _isPrinting ? null : _handlePrint,
              icon: _isPrinting
                  ? const SizedBox(width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_hasPrinted ? Icons.replay_rounded : Icons.print_rounded, size: 18),
              label: Text(
                _isPrinting
                    ? 'Mencetak ke VSC MP-58C...'
                    : _hasPrinted
                        ? 'Cetak Ulang Struk'
                        : 'Cetak Struk Thermal Sekarang',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasPrinted ? const Color(0xFF047857) : AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Secondary Option: Full Receipt Preview Screen
            OutlinedButton.icon(
              onPressed: _handleOpenFullPreview,
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: const Text('Lihat Pratinjau Resi Lengkap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: Color(0xFF94A3B8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 6),

            // 3. Third Option: WhatsApp / Share
            TextButton.icon(
              onPressed: _handleShareWhatsApp,
              icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF047857)),
              label: const Text(
                'Kirim Salinan ke WhatsApp Pelanggan',
                style: TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _handleDismiss,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              foregroundColor: AppTheme.textSecondary,
            ),
            child: const Text('Selesai / Tutup Dialog', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textSecondary)),
          Text(val, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
