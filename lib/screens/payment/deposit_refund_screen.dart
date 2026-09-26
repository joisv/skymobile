import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/receipt_model.dart';
import '../receipt/widgets/post_transaction_print_dialog.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class DepositRefundScreen extends StatefulWidget {
  final PaymentTransactionModel? transaction;
  final BookingModel? booking;
  final BookingRepository repository;

  const DepositRefundScreen({
    super.key,
    this.transaction,
    this.booking,
    required this.repository,
  });

  @override
  State<DepositRefundScreen> createState() => _DepositRefundScreenState();
}

class _DepositRefundScreenState extends State<DepositRefundScreen> {
  late String _bookingCode;
  late String _customerName;
  late String _customerPhone;
  late String _iphoneName;
  late double _depositAmount;
  late double _deductionAmount;
  late double _refundAmount;
  late DepositStatus _currentStatus;

  String _selectedRefundMethod = 'Transfer Bank';
  String _selectedBank = 'BCA';
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountHolderController = TextEditingController();
  final TextEditingController _refNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _isCashConfirmed = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _bookingCode = tx.bookingCode;
      _customerName = tx.customerName;
      _customerPhone = tx.customerPhone;
      _iphoneName = tx.iphoneName;
      _depositAmount = tx.depositAmount;
      _deductionAmount = tx.deductionAmount;
      _refundAmount = tx.refundAmount > 0 ? tx.refundAmount : (_depositAmount - _deductionAmount).clamp(0.0, double.infinity);
      _currentStatus = tx.depositStatus;
    } else if (widget.booking != null) {
      final b = widget.booking!;
      _bookingCode = b.bookingCode;
      _customerName = b.customerName;
      _customerPhone = b.customerPhone;
      _iphoneName = b.iphone.fullName;
      _depositAmount = b.deposit;
      _deductionAmount = 0;
      _refundAmount = b.deposit;
      _currentStatus = DepositStatus.readyRefund;
    } else {
      _bookingCode = '-';
      _customerName = 'Pelanggan';
      _customerPhone = '-';
      _iphoneName = 'iPhone';
      _depositAmount = 0;
      _deductionAmount = 0;
      _refundAmount = 0;
      _currentStatus = DepositStatus.readyRefund;
    }

    _accountHolderController.text = _customerName;
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isAlreadyRefunded => _currentStatus == DepositStatus.refunded;

  bool get _canSubmit {
    if (_isAlreadyRefunded || _isSubmitting || _refundAmount <= 0) return false;
    if (_selectedRefundMethod == 'Transfer Bank') {
      return _accountNumberController.text.trim().isNotEmpty &&
          _accountHolderController.text.trim().isNotEmpty;
    } else if (_selectedRefundMethod == 'Tunai') {
      return _isCashConfirmed;
    } else if (_selectedRefundMethod == 'E-Wallet') {
      return _accountNumberController.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _executeRefund() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      final updated = await widget.repository.executeRefund(
        bookingCode: _bookingCode,
        refundAmount: _refundAmount,
        refundMethod: _selectedRefundMethod,
        bankName: _selectedRefundMethod == 'Transfer Bank' ? _selectedBank : null,
        accountNumber: _accountNumberController.text.trim(),
        accountHolder: _accountHolderController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        if (updated != null) _currentStatus = updated.depositStatus;
      });

      if (updated != null) {
        _showSuccessReceiptDialog(updated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund deposit berhasil dicatat!'),
            backgroundColor: Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessReceiptDialog(PaymentTransactionModel tx) {
    final currentUser = AuthService().currentUser;
    final cashierName = (currentUser != null && currentUser.name.isNotEmpty) ? currentUser.name : 'Kasir Toko';
    final branchName = (currentUser != null && currentUser.outletName.isNotEmpty)
        ? 'SKYRENTAL ${currentUser.outletName.toUpperCase()}'
        : 'SKYRENTAL PUSAT';

    final receipt = ReceiptModel(
      receiptNumber: 'STR-202609-0${tx.id}',
      date: DateTime.now(),
      adminName: cashierName,
      branchName: branchName,
      type: ReceiptType.depositRefund,
      bookingCode: tx.bookingCode,
      customerName: tx.customerName,
      customerPhone: tx.customerPhone,
      unitName: tx.iphoneName,
      rentalDuration: widget.booking != null ? '${widget.booking!.durationDays} Hari' : '1 Hari',
      rentalDates: widget.booking != null ? '${Formatters.date(widget.booking!.startDate)} - ${Formatters.date(widget.booking!.endDate)}' : null,
      rentFee: tx.rentTotal,
      depositFee: tx.depositAmount,
      finesFee: tx.deductionAmount,
      totalAmount: tx.depositAmount,
      paidAmount: tx.paidAmount,
      remainingAmount: 0,
      refundAmount: tx.refundAmount,
      depositStatus: tx.depositStatus.label,
      paymentMethod: _selectedRefundMethod,
      paymentStatus: 'Lunas',
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : tx.notes,
    );

    PostTransactionPrintDialog.show(
      context,
      receipt: receipt,
      onFinish: () => Navigator.pop(context, true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Alur Refund Deposit'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Status & Double Refund Protection Banner
                  if (_isAlreadyRefunded) ...[
                    _buildAlreadyRefundedBanner(),
                    const SizedBox(height: 16),
                  ],

                  // 2. Booking Summary Card
                  _buildBookingCard(),
                  const SizedBox(height: 16),

                  // 3. Refund Financial Breakdown Card
                  _buildFinancialBreakdownCard(),
                  const SizedBox(height: 16),

                  // 4. Refund Method Selector
                  if (!_isAlreadyRefunded) ...[
                    _buildRefundMethodCard(),
                    const SizedBox(height: 16),
                  ],

                  // 5. Notes Card
                  _buildNotesCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 6. Bottom Submit Bar
          if (!_isAlreadyRefunded) _buildBottomSubmitBar(),
        ],
      ),
    );
  }

  Widget _buildAlreadyRefundedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFFDC2626), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEPOSIT TELAH DIREFUND SEBELUMNYA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                ),
                SizedBox(height: 2),
                Text(
                  'Sistem perlindungan ganda aktif: transaksi ini telah diproses dan tidak dapat direfund kembali untuk menghindari duplikasi kas.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _bookingCode,
                style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: AppTheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _iphoneName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 8),
          Text(
            '$_customerName • $_customerPhone',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialBreakdownCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Perhitungan Bersih Refund Deposit',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),
          _buildRow('Nilai Deposit Ditahan', Formatters.currency(_depositAmount)),
          _buildRow('Potongan Denda / Kerusakan', '- ${Formatters.currency(_deductionAmount)}',
              color: _deductionAmount > 0 ? const Color(0xFFDC2626) : AppTheme.textSecondary),
          const SizedBox(height: 6),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL DANA DIREFUND:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                ),
                Text(
                  Formatters.currency(_refundAmount),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundMethodCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Metode Penyaluran Dana Refund:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            children: ['Transfer Bank', 'Tunai', 'E-Wallet'].map((m) {
              final isSelected = _selectedRefundMethod == m;
              return ChoiceChip(
                label: Text(m),
                selected: isSelected,
                selectedColor: AppTheme.accent,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedRefundMethod = m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Method details input
          if (_selectedRefundMethod == 'Transfer Bank') ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedBank,
              decoration: const InputDecoration(
                labelText: 'Bank Tujuan Pelanggan',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: ['BCA', 'Mandiri', 'BNI', 'BRI', 'Bank Jago', 'CIMB Niaga'].map((b) {
                return DropdownMenuItem(value: b, child: Text(b));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedBank = val);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nomor Rekening Pelanggan',
                hintText: 'Contoh: 8730192811',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountHolderController,
              decoration: const InputDecoration(
                labelText: 'Nama Pemilik Rekening',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ] else if (_selectedRefundMethod == 'Tunai') ...[
            Container(
              decoration: BoxDecoration(
                color: _isCashConfirmed
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                        : const Color(0xFFF0FDF4))
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: CheckboxListTile(
                title: const Text('Konfirmasi Serah Terima Tunai', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Uang tunai sebesar ${Formatters.currency(_refundAmount)} telah dihitung dan diserahkan ke tangan pelanggan.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                value: _isCashConfirmed,
                activeColor: const Color(0xFF047857),
                onChanged: (val) => setState(() => _isCashConfirmed = val ?? false),
              ),
            ),
          ] else if (_selectedRefundMethod == 'E-Wallet') ...[
            TextField(
              controller: _accountNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Nomor HP E-Wallet Pelanggan (GoPay / OVO / Dana)',
                hintText: _customerPhone,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Catatan Eksekusi Refund (Opsional):',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Misal: Transfer berhasil, bukti telah diverifikasi kasir shift sore.',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSubmitBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _canSubmit ? _executeRefund : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.outbox_rounded, size: 20),
                label: Text(
                  _isSubmitting
                      ? 'Memproses Refund...'
                      : 'Eksekusi Refund ${Formatters.currency(_refundAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: color ?? AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}