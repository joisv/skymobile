import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class DepositStatusScreen extends StatefulWidget {
  final PaymentTransactionModel? transaction;
  final BookingModel? booking;
  final BookingRepository repository;

  const DepositStatusScreen({
    super.key,
    this.transaction,
    this.booking,
    required this.repository,
  });

  @override
  State<DepositStatusScreen> createState() => _DepositStatusScreenState();
}

class _DepositStatusScreenState extends State<DepositStatusScreen> {
  late String _bookingCode;
  late String _customerName;
  late String _customerPhone;
  late String _iphoneName;
  late double _depositAmount;
  late DepositStatus _currentStatus;
  late DepositStatus _selectedNewStatus;

  double _deductionAmount = 0;
  final TextEditingController _deductionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

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
      _currentStatus = tx.depositStatus;
      _selectedNewStatus = tx.depositStatus;
      _deductionAmount = tx.deductionAmount;
    } else if (widget.booking != null) {
      final b = widget.booking!;
      _bookingCode = b.bookingCode;
      _customerName = b.customerName;
      _customerPhone = b.customerPhone;
      _iphoneName = b.iphone.fullName;
      _depositAmount = b.deposit;
      _currentStatus = DepositStatus.held;
      _selectedNewStatus = DepositStatus.held;
      _deductionAmount = 0;
    } else {
      _bookingCode = '-';
      _customerName = 'Pelanggan';
      _customerPhone = '-';
      _iphoneName = 'iPhone';
      _depositAmount = 0;
      _currentStatus = DepositStatus.held;
      _selectedNewStatus = DepositStatus.held;
      _deductionAmount = 0;
    }

    if (_deductionAmount > 0) {
      _deductionController.text = _deductionAmount.toInt().toString();
    }
  }

  @override
  void dispose() {
    _deductionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _netRefundAmount {
    final net = _depositAmount - _deductionAmount;
    return net > 0 ? net : 0.0;
  }

  Future<void> _submitDepositStatusChange() async {
    setState(() => _isSubmitting = true);

    final updated = await widget.repository.updateDepositStatus(
      bookingCode: _bookingCode,
      newStatus: _selectedNewStatus,
      deductionAmount: _deductionAmount,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status deposit $_bookingCode berhasil diperbarui menjadi "${_selectedNewStatus.label}"!'),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status deposit berhasil disimpan.'),
          backgroundColor: Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Kelola Status Deposit'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Booking Summary
                  _buildHeaderCard(),
                  const SizedBox(height: 16),

                  // 2. Deposit Financial Card
                  _buildDepositValueCard(),
                  const SizedBox(height: 16),

                  // 3. Status Transition Choices
                  _buildStatusSelectionCard(),
                  const SizedBox(height: 16),

                  // 4. Deduction & Refund Details (if applicable)
                  if (_selectedNewStatus == DepositStatus.deducted ||
                      _selectedNewStatus == DepositStatus.readyRefund) ...[
                    _buildDeductionDetailsCard(),
                    const SizedBox(height: 16),
                  ],

                  // 5. Notes Input
                  _buildNotesCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 6. Bottom Submit Bar
          _buildBottomSubmitBar(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
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
              _buildDepositStatusBadge(_currentStatus),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 8),
          Text(
            '$_customerName • $_customerPhone',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Unit: $_iphoneName',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositValueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Uang Jaminan (Deposit):', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF))),
              SizedBox(height: 2),
              Text('Tersimpan di Kas/Brankas Toko', style: TextStyle(fontSize: 10, color: Color(0xFF3B82F6))),
            ],
          ),
          Text(
            Formatters.currency(_depositAmount),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelectionCard() {
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
          Text('Pilih Status Deposit Baru:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),

          RadioGroup<DepositStatus>(
            groupValue: _selectedNewStatus,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedNewStatus = val;
                  if (val == DepositStatus.readyRefund) {
                    _deductionAmount = 0;
                    _deductionController.text = '0';
                  }
                });
              }
            },
            child: Column(
              children: [
                _buildRadioOption(
                  status: DepositStatus.held,
                  title: 'Ditahan (Masa Sewa Berjalan)',
                  subtitle: 'Unit iPhone masih disewa atau belum selesai diperiksa pengembaliannya.',
                ),
                const SizedBox(height: 8),
                _buildRadioOption(
                  status: DepositStatus.readyRefund,
                  title: 'Siap Refund (Pengembalian Selesai)',
                  subtitle: 'Unit iPhone telah kembali normal dan diverifikasi, siap dikembalikan ke pelanggan.',
                ),
                const SizedBox(height: 8),
                _buildRadioOption(
                  status: DepositStatus.deducted,
                  title: 'Dipotong Sebagian / Denda Kerusakan',
                  subtitle: 'Dikenakan denda keterlambatan atau kerusakan minor sesuai hasil inspeksi.',
                ),
                const SizedBox(height: 8),
                _buildRadioOption(
                  status: DepositStatus.refunded,
                  title: 'Telah Direfund (Selesai Dikembalikan)',
                  subtitle: 'Uang deposit telah resmi ditransfer atau diserahkan tunai ke pelanggan.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required DepositStatus status,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedNewStatus == status;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                : const Color(0xFFF0FDF4))
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF047857) : AppTheme.cardBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: RadioListTile<DepositStatus>(
        value: status,
        activeColor: const Color(0xFF047857),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ),
    );
  }

  Widget _buildDeductionDetailsCard() {
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
          Text('Kalkulasi Potongan Denda & Sisa Refund:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 10),

          // Quick Denda Presets
          Text('Preset Denda / Kerusakan Cepat:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              _buildPresetChip('Tanpa Denda (Rp 0)', 0),
              _buildPresetChip('Terlambat (+Rp 50.000)', 50000),
              _buildPresetChip('Kabel Rusak (+Rp 75.000)', 75000),
              _buildPresetChip('Lecet Body (+Rp 100.000)', 100000),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _deductionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal Potongan Denda (Rp)',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) {
              setState(() {
                _deductionAmount = double.tryParse(val.trim()) ?? 0.0;
              });
            },
          ),
          const SizedBox(height: 12),

          // Net Refund Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                _buildRow('Nilai Deposit Awal', Formatters.currency(_depositAmount)),
                _buildRow('Potongan Denda', '- ${Formatters.currency(_deductionAmount)}', color: const Color(0xFFDC2626)),
                const Divider(height: 12),
                _buildRow('SISA REFUND PELANGGAN', Formatters.currency(_netRefundAmount), isBold: true, color: const Color(0xFF047857)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, double amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _deductionAmount = amount;
          _deductionController.text = amount.toInt().toString();
        });
      },
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
          Text('Catatan Status Deposit:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Misal: Kondisi pengembalian diperiksa oleh staf Budi, tidak ada goresan.',
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
                onPressed: _isSubmitting ? null : _submitDepositStatusChange,
                icon: _isSubmitting
                    ? const SizedBox(width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  _isSubmitting ? 'Menyimpan...' : 'Perbarui Status Deposit',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
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

  Widget _buildDepositStatusBadge(DepositStatus status) {
    Color bg;
    Color text;

    switch (status) {
      case DepositStatus.readyRefund:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        break;
      case DepositStatus.refunded:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF047857);
        break;
      case DepositStatus.deducted:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        break;
      case DepositStatus.held:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }
}
