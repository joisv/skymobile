import 'package:flutter/material.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'widgets/pickup_step_indicator.dart';

class PickupScreen extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onPickupComplete;

  const PickupScreen({
    super.key,
    required this.booking,
    this.onPickupComplete,
  });

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1 State: Identity & Collateral Verification
  bool _isIdVerified = false;
  bool _isCollateralReceived = false;
  final TextEditingController _idNotesController = TextEditingController();

  // Step 2 State: Unit & Accessories Checklist
  late IphoneModel _assignedIphone;
  bool _isUnitChecked = false;
  bool _hasCharger = true;
  bool _hasCable = true;
  bool _hasBoxOrPouch = true;
  bool _hasCase = true;
  bool _hasTemperedGlass = true;
  late int _batteryHealth;

  // Step 3 State: Payment & Deposit
  bool _isDepositConfirmed = false;
  bool _isRentSettled = false;
  String _paymentMethod = 'QRIS';

  // Step 4 State: Final Confirmation
  bool _isStaffConfirmed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _assignedIphone = widget.booking.iphone;
    _batteryHealth = _assignedIphone.batteryHealth;
    // Pre-check rent settlement if already paid
    _isRentSettled = widget.booking.paymentStatus == PaymentStatus.paid;
  }

  Future<void> _changeUnit() async {
    final selected = await Navigator.pushNamed(
      context,
      AppRoutes.unitSelection,
      arguments: widget.booking,
    );

    if (selected is IphoneModel && mounted) {
      setState(() {
        _assignedIphone = selected;
        _batteryHealth = selected.batteryHealth;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit diganti ke ${selected.assetCode} (${selected.fullName})'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _idNotesController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _isIdVerified && _isCollateralReceived;
      case 1:
        return _isUnitChecked && _hasCable;
      case 2:
        return _isDepositConfirmed && _isRentSettled;
      case 3:
        return _isStaffConfirmed && !_isSubmitting;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submitPickup();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitPickup() async {
    setState(() => _isSubmitting = true);

    // Simulate backend API call / double-submission prevention
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    widget.onPickupComplete?.call();

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.pickupSuccess,
      arguments: {
        'booking': widget.booking,
        'iphone': _assignedIphone,
        'paymentMethod': _paymentMethod,
        'notes': _idNotesController.text,
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Alur Serah Terima (Pickup)'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. Step Progress Stepper
          PickupStepIndicator(
            currentStep: _currentStep,
            onStepTapped: (index) {
              if (index < _currentStep) {
                setState(() => _currentStep = index);
              }
            },
          ),

          // 2. Booking Quick Summary Header
          _buildBookingHeader(),

          // 3. Current Step Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStepContent(),
            ),
          ),

          // 4. Sticky Bottom Action Bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBookingHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.cardBorder,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                widget.booking.bookingCode,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                '•  ${widget.booking.customerName}',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          Text(
            widget.booking.iphone.fullName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Identity();
      case 1:
        return _buildStep2UnitCheck();
      case 2:
        return _buildStep3Payment();
      case 3:
        return _buildStep4Confirm();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: Identity & Collateral ---
  Widget _buildStep1Identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Langkah 1: Verifikasi Identitas & Jaminan'),
        Text(
          'Cocokkan kartu identitas asli penyewa dan amankan jaminan fisik sebelum unit diserahkan.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        _buildCardContainer([
          _buildDetailRow('Nama Pelanggan', widget.booking.customerName),
          _buildDetailRow('Nomor HP / WA', widget.booking.customerPhone),
          _buildDetailRow('Tipe Jaminan', widget.booking.jaminanType, isHighlight: true),
          if (widget.booking.address != null)
            _buildDetailRow('Alamat Domisili', widget.booking.address!),
        ]),
        const SizedBox(height: 16),

        _buildCheckItem(
          title: 'KTP / Identitas Asli Telah Dicocokkan',
          subtitle: 'Nama dan foto pada identitas fisik sesuai dengan penyewa yang hadir di outlet.',
          value: _isIdVerified,
          onChanged: (val) => setState(() => _isIdVerified = val ?? false),
        ),
        const SizedBox(height: 8),

        _buildCheckItem(
          title: 'Dokumen Jaminan Fisik Diterima & Disimpan',
          subtitle: 'Jaminan (${widget.booking.jaminanType}) telah diterima lengkap dan disimpan di kotak jaminan.',
          value: _isCollateralReceived,
          onChanged: (val) => setState(() => _isCollateralReceived = val ?? false),
        ),
      ],
    );
  }

  // --- STEP 2: Unit & Accessories Checklist ---
  Widget _buildStep2UnitCheck() {
    final iphone = _assignedIphone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Langkah 2: Pemeriksaan Unit & Kelengkapan Fisik'),
        Text('Periksa nomor seri fisik unit iPhone dan kelengkapan aksesoris bersama penyewa.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        _buildCardContainer([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Unit Fisik yang Diserahkan',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              TextButton.icon(
                onPressed: _changeUnit,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Pilih Unit Lain', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 8),
          _buildDetailRow('Model Unit', iphone.fullName),
          _buildDetailRow('Varian Warna', iphone.color),
          _buildDetailRow('Nomor Seri (SN)', iphone.serialNumber),
          _buildDetailRow('Kode Aset Unit', iphone.assetCode),
          _buildDetailRow('Battery Health', '$_batteryHealth%'),
        ]),
        const SizedBox(height: 16),

        _buildCheckItem(
          title: 'Unit iPhone Fisik Sesuai & Berfungsi Normal',
          subtitle: 'Layar sentuh, kamera depan/belakang, Face ID, speaker, dan wifi berfungsi dengan baik.',
          value: _isUnitChecked,
          onChanged: (val) => setState(() => _isUnitChecked = val ?? false),
        ),
        const SizedBox(height: 16),

        Text('Checklist Kelengkapan yang Diserahkan:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
        const SizedBox(height: 8),

        _buildAccessorySwitch('Kepala Charger Original', _hasCharger, (v) => setState(() => _hasCharger = v)),
        _buildAccessorySwitch('Kabel Data (Lightning / Type-C)', _hasCable, (v) => setState(() => _hasCable = v)),
        _buildAccessorySwitch('Case Pelindung Terpasang', _hasCase, (v) => setState(() => _hasCase = v)),
        _buildAccessorySwitch('Tempered Glass Terpasang', _hasTemperedGlass, (v) => setState(() => _hasTemperedGlass = v)),
        _buildAccessorySwitch('Pouch / Box Penyimpanan Unit', _hasBoxOrPouch, (v) => setState(() => _hasBoxOrPouch = v)),
      ],
    );
  }

  // --- STEP 3: Payment & Deposit ---
  Widget _buildStep3Payment() {
    final deposit = widget.booking.deposit;
    final price = widget.booking.price;
    final totalBill = price + deposit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Langkah 3: Pembayaran Sewa & Uang Jaminan (Deposit)'),
        Text(
          'Pastikan seluruh biaya sewa dan uang jaminan telah diterima sebelum unit diserahkan.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        _buildCardContainer([
          _buildDetailRow('Biaya Sewa (${widget.booking.durationDays} Hari)', Formatters.currency(price)),
          _buildDetailRow('Uang Jaminan (Deposit)', Formatters.currency(deposit)),
          Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 4),
          _buildDetailRow('TOTAL YANG HARUS DITERIMA', Formatters.currency(totalBill), isBold: true),
          _buildDetailRow('Status Pembayaran Saat Ini', widget.booking.paymentStatus.label, isHighlight: true),
        ]),
        const SizedBox(height: 16),

        _buildCheckItem(
          title: 'Biaya Sewa (${Formatters.currency(price)}) Telah Lunas',
          subtitle: 'Pembayaran biaya rental telah diterima lunas di kasir/outlet.',
          value: _isRentSettled,
          onChanged: (val) => setState(() => _isRentSettled = val ?? false),
        ),
        const SizedBox(height: 8),

        _buildCheckItem(
          title: 'Uang Jaminan / Deposit (${Formatters.currency(deposit)}) Diterima',
          subtitle: 'Uang jaminan tunai/transfer telah diterima dan akan dikembalikan saat return unit.',
          value: _isDepositConfirmed,
          onChanged: (val) => setState(() => _isDepositConfirmed = val ?? false),
        ),
        const SizedBox(height: 16),

        const Text('Metode Penerimaan Uang:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['QRIS', 'Tunai (Cash)', 'Transfer Bank'].map((method) {
            final isSelected = _paymentMethod == method;
            return ChoiceChip(
              label: Text(method),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _paymentMethod = method);
              },
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- STEP 4: Final Confirmation ---
  Widget _buildStep4Confirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Langkah 4: Konfirmasi Akhir Serah Terima'),
        Text(
          'Tinjau kembali ringkasan serah terima unit sebelum memvalidasi transaksi di sistem.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        _buildCardContainer([
          _buildDetailRow('Kode Booking', widget.booking.bookingCode, isBold: true),
          _buildDetailRow('Pelanggan', widget.booking.customerName),
          _buildDetailRow('Unit Diserahkan', _assignedIphone.fullName),
          _buildDetailRow('Kode Aset (Asset)', _assignedIphone.assetCode),
          _buildDetailRow('No. Seri (SN)', _assignedIphone.serialNumber),
          _buildDetailRow('Masa Rental', '${Formatters.dateTime(widget.booking.startDate)} s/d ${Formatters.dateTime(widget.booking.endDate)}'),
          _buildDetailRow('Total Tagihan', Formatters.currency(widget.booking.totalBill), isBold: true),
          _buildDetailRow('Status Jaminan', 'Diterima (${widget.booking.jaminanType})'),
          _buildDetailRow('Metode Bayar', _paymentMethod),
        ]),
        const SizedBox(height: 16),

        _buildCheckItem(
          title: 'Saya mengonfirmasi serah terima fisik iPhone ini telah sah',
          subtitle: 'Unit iPhone dalam kondisi baik, aksesoris lengkap, jaminan tersimpan, dan pembayaran lunas.',
          value: _isStaffConfirmed,
          onChanged: (val) => setState(() => _isStaffConfirmed = val ?? false),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final canProceed = _canProceed();
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _prevStep,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(_currentStep == 0 ? 'Batal' : 'Kembali'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: canProceed ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep ? const Color(0xFF047857) : AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isLastStep
                            ? 'Konfirmasi & Serah Terima Unit'
                            : 'Lanjut ke Langkah ${_currentStep + 2}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? AppTheme.accent : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? const Color(0xFF86EFAC) : AppTheme.cardBorder,
          width: value ? 1.5 : 1,
        ),
      ),
      child: CheckboxListTile(
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        value: value,
        activeColor: const Color(0xFF047857),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildAccessorySwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: SwitchListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        value: value,
        activeThumbColor: AppTheme.accent,
        onChanged: onChanged,
      ),
    );
  }
}