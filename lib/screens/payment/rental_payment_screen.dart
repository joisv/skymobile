import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/receipt_model.dart';
import '../receipt/widgets/post_transaction_print_dialog.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class RentalPaymentScreen extends StatefulWidget {
  final BookingModel? booking;
  final PaymentTransactionModel? transaction;
  final BookingRepository repository;

  const RentalPaymentScreen({
    super.key,
    this.booking,
    this.transaction,
    required this.repository,
  });

  @override
  State<RentalPaymentScreen> createState() => _RentalPaymentScreenState();
}

class _RentalPaymentScreenState extends State<RentalPaymentScreen> {
  String _selectedMethod = 'QRIS';
  bool _isFullPayment = true;
  bool _isSubmitting = false;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late double _remainingAmount;
  late double _rentTotal;
  late double _paidAmount;
  late String _bookingCode;
  late String _customerName;
  late String _customerPhone;
  late String _iphoneName;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _bookingCode = tx.bookingCode;
      _customerName = tx.customerName;
      _customerPhone = tx.customerPhone;
      _iphoneName = tx.iphoneName;
      _rentTotal = tx.rentTotal;
      _paidAmount = tx.paidAmount;
      _remainingAmount = tx.remainingAmount;
    } else if (widget.booking != null) {
      final b = widget.booking!;
      _bookingCode = b.bookingCode;
      _customerName = b.customerName;
      _customerPhone = b.customerPhone;
      _iphoneName = b.iphone.fullName;
      _rentTotal = b.price;
      _paidAmount = b.paymentStatus == PaymentStatus.paid ? b.price : (b.paymentStatus == PaymentStatus.partial ? b.price / 2 : 0);
      _remainingAmount = (_rentTotal - _paidAmount).clamp(0.0, double.infinity);
    } else {
      _bookingCode = '-';
      _customerName = 'Pelanggan';
      _customerPhone = '-';
      _iphoneName = 'iPhone';
      _rentTotal = 0;
      _paidAmount = 0;
      _remainingAmount = 0;
    }

    _amountController.text = _remainingAmount.toInt().toString();
    _cashReceivedController.text = _remainingAmount.toInt().toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cashReceivedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _enteredAmount {
    if (_isFullPayment) return _remainingAmount;
    return double.tryParse(_amountController.text.trim()) ?? 0.0;
  }

  double get _cashReceived {
    return double.tryParse(_cashReceivedController.text.trim()) ?? 0.0;
  }

  double get _cashChange {
    if (_selectedMethod != 'Tunai') return 0.0;
    final change = _cashReceived - _enteredAmount;
    return change > 0 ? change : 0.0;
  }

  Future<void> _submitPayment() async {
    if (_enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal pembayaran harus lebih dari Rp 0.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedMethod == 'Tunai' && _cashReceived < _enteredAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uang tunai yang diterima kurang dari nominal tagihan.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final updated = await widget.repository.submitPayment(
      bookingCode: _bookingCode,
      amountPaid: _enteredAmount,
      paymentMethod: _selectedMethod,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (updated != null) {
      _showSuccessDialog(updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembayaran berhasil dicatat di sistem!'),
          backgroundColor: Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showSuccessDialog(PaymentTransactionModel tx) {
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
      type: ReceiptType.paymentSettlement,
      bookingCode: tx.bookingCode,
      customerName: tx.customerName,
      customerPhone: tx.customerPhone,
      unitName: tx.iphoneName,
      rentalDuration: widget.booking != null ? '${widget.booking!.durationDays} Hari' : '1 Hari',
      rentalDates: widget.booking != null ? '${Formatters.date(widget.booking!.startDate)} - ${Formatters.date(widget.booking!.endDate)}' : null,
      rentFee: tx.rentTotal,
      depositFee: tx.depositAmount,
      totalAmount: tx.rentTotal + tx.depositAmount,
      paidAmount: tx.paidAmount,
      remainingAmount: tx.remainingAmount,
      paymentMethod: _selectedMethod,
      paymentStatus: tx.paymentStatus,
      cashGiven: _cashReceived,
      cashChange: _cashChange,
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
        title: const Text('Penerimaan Pembayaran Sewa'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Booking Summary Banner
                  _buildBookingCard(),
                  const SizedBox(height: 16),

                  // 2. Billing Breakdown (Backend calculation rule)
                  _buildBillingBreakdownCard(),
                  const SizedBox(height: 16),

                  // 3. Payment Mode & Amount Input
                  _buildPaymentAmountCard(),
                  const SizedBox(height: 16),

                  // 4. Payment Method Selection (QRIS, Tunai, Transfer)
                  _buildPaymentMethodSection(),
                  const SizedBox(height: 16),

                  // 5. Staff Notes
                  _buildNotesInput(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 6. Sticky Submit Bar
          _buildBottomSubmitBar(),
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
                style: TextStyle(fontSize: 13,
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
          Row(
            children: [
              Icon(Icons.person_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(_customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('•  $_customerPhone', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillingBreakdownCard() {
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
              Icon(Icons.receipt_outlined, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Rincian Tagihan Sewa',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 10),
          _buildDetailRow('Total Biaya Sewa Unit', Formatters.currency(_rentTotal)),
          _buildDetailRow('Telah Dibayar Sebelumnya', Formatters.currency(_paidAmount), color: const Color(0xFF047857)),
          const SizedBox(height: 4),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 6),
          _buildDetailRow('SISA TAGIHAN HARUS DIBAYAR', Formatters.currency(_remainingAmount),
              isBold: true, color: _remainingAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF047857)),
        ],
      ),
    );
  }

  Widget _buildPaymentAmountCard() {
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
          Text('Nominal Pembayaran Diterima:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 10),

          // Radio choices: Pelunasan Penuh vs Nominal Kustom
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Pelunasan Penuh')),
                  selected: _isFullPayment,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: _isFullPayment ? Colors.white : AppTheme.textPrimary,
                    fontWeight: _isFullPayment ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _isFullPayment = true;
                        _amountController.text = _remainingAmount.toInt().toString();
                        _cashReceivedController.text = _remainingAmount.toInt().toString();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Nominal Kustom (DP)')),
                  selected: !_isFullPayment,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: !_isFullPayment ? Colors.white : AppTheme.textPrimary,
                    fontWeight: !_isFullPayment ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _isFullPayment = false);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_isFullPayment) ...[
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ketikkan Nominal Pembayaran (Rp)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
          ],

          // Display active nominal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nominal yang Akan Dicatat:', style: TextStyle(fontSize: 12)),
                Text(
                  Formatters.currency(_enteredAmount),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
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
          Text('Metode Pembayaran:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            children: ['QRIS', 'Tunai', 'Transfer Bank'].map((m) {
              final isSelected = _selectedMethod == m;
              return ChoiceChip(
                label: Text(m),
                selected: isSelected,
                selectedColor: AppTheme.accent,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedMethod = m);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Conditional UI based on method
          if (_selectedMethod == 'QRIS') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 48, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('QRIS Statis Toko Siap Di-scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'Arahkan kamera smartphone pelanggan untuk scan kode QRIS SKYRental.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_selectedMethod == 'Tunai') ...[
            TextField(
              controller: _cashReceivedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal Uang Tunai Diterima dari Pelanggan',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            // Kembalian calculation
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _cashChange >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cashChange >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian untuk Pelanggan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                    Formatters.currency(_cashChange),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _cashChange >= 0 ? const Color(0xFF047857) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_selectedMethod == 'Transfer Bank') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rekening Resmi SKYRental:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                  SizedBox(height: 4),
                  Text('BCA: 873-019-2811  (a/n SKYRental Indonesia)', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  Text('Mandiri: 137-00-1928-1110 (a/n SKYRental Indonesia)', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesInput() {
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
          Text('Catatan Kasir (Opsional):',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Misal: Pelunasan tunai kasir shift siang, uang pas.',
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
                onPressed: _isSubmitting ? null : _submitPayment,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  _isSubmitting
                      ? 'Menyimpan Pembayaran...'
                      : 'Terima Pembayaran ${Formatters.currency(_enteredAmount)}',
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}