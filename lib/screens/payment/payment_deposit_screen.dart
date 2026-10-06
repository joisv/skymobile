import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/payment_model.dart';
import '../../models/receipt_format_settings.dart';
import '../../models/receipt_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/printer_storage_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_header.dart';

enum PaymentTypeOption {
  pelunasan(
    id: 'payment',
    label: 'Pelunasan',
    badge: 'LUNAS',
    icon: Icons.check_circle_rounded,
    description: 'Pelunasan seluruh tagihan sewa unit',
    receiptType: ReceiptType.paymentSettlement,
  ),
  dp(
    id: 'dp',
    label: 'DP (Uang Muka)',
    badge: 'DP',
    icon: Icons.hourglass_bottom_rounded,
    description: 'Pembayaran sebagian / uang muka sewa',
    receiptType: ReceiptType.paymentSettlement,
  ),
  penalty(
    id: 'penalty',
    label: 'Penalty / Denda',
    badge: 'DENDA',
    icon: Icons.warning_amber_rounded,
    description: 'Denda keterlambatan atau klaim unit',
    receiptType: ReceiptType.paymentSettlement,
  ),
  extend(
    id: 'extend',
    label: 'Extend',
    badge: 'EXTEND',
    icon: Icons.update_rounded,
    description: 'Biaya perpanjangan masa rental unit',
    receiptType: ReceiptType.paymentSettlement,
  );

  final String id;
  final String label;
  final String badge;
  final IconData icon;
  final String description;
  final ReceiptType receiptType;

  const PaymentTypeOption({
    required this.id,
    required this.label,
    required this.badge,
    required this.icon,
    required this.description,
    required this.receiptType,
  });
}

class CashSuggestionItem {
  final double pay;
  final double change;

  const CashSuggestionItem({required this.pay, required this.change});
}

class CashSuggestion {
  static List<CashSuggestionItem> generate(double totalAmount) {
    final int total = totalAmount.toInt();
    if (total <= 0) return [];

    final Set<int> candidates = {total};
    for (final step in [5000, 10000, 20000, 50000, 100000]) {
      candidates.add(((total / step).ceil()) * step);
      candidates.add((((total / step).floor()) + 1) * step);
    }
    if (total >= 50000) {
      final next100k = (((total / 100000).floor()) + 1) * 100000;
      candidates.add(next100k + 50000);
      candidates.add(next100k + 100000);
    }

    final sorted = candidates.where((p) => p >= total).toList()..sort();
    return sorted.take(6).map((p) => CashSuggestionItem(
      pay: p.toDouble(),
      change: (p - total).toDouble(),
    )).toList();
  }
}

class PaymentDepositScreen extends StatefulWidget {
  final BookingRepository repository;
  final BookingModel? booking;
  final PaymentTypeOption? initialPaymentType;
  final double? initialAmount;
  final bool isReturnFlow;
  final int? extendHours;

  const PaymentDepositScreen({
    super.key,
    required this.repository,
    this.booking,
    this.initialPaymentType,
    this.initialAmount,
    this.isReturnFlow = false,
    this.extendHours,
  });

  @override
  State<PaymentDepositScreen> createState() => _PaymentDepositScreenState();
}

class _PaymentDepositScreenState extends State<PaymentDepositScreen> {
  BookingModel? _activeBooking;
  bool _isLoading = true;

  PaymentTypeOption _paymentType = PaymentTypeOption.pelunasan;
  String _selectedMethod = 'tunai';
  List<PaymentMethodOption> _paymentMethods = PaymentMethodOption.defaultMethods();

  DateTime _selectedPaymentDate = DateTime.now();
  TimeOfDay _selectedPaymentTime = TimeOfDay.now();

  double _amount = 0.0;
  double _pay = 0.0;

  late final TextEditingController _amountController;
  late final TextEditingController _payController;

  List<CashSuggestionItem> _cashSuggestions = [];

  bool _sendWhatsApp = true;
  bool _printReceipt = true;
  bool _isConfirming = false;
  bool _showMobileReceiptPreview = false;
  ReceiptFormatSettings _receiptFormatSettings = const ReceiptFormatSettings();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _payController = TextEditingController();
    _loadBooking();
    _loadPaymentMethods();
    _loadReceiptFormatSettings();
  }

  Future<void> _loadReceiptFormatSettings() async {
    try {
      final s = await PrinterStorageService().getReceiptFormatSettings();
      if (mounted) {
        setState(() => _receiptFormatSettings = s);
      }
    } catch (_) {}
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await widget.repository.getPaymentMethods();
      if (mounted && methods.isNotEmpty) {
        setState(() {
          _paymentMethods = methods;
          final exists = _paymentMethods.any((m) => m.idStr == _selectedMethod || m.slug == _selectedMethod);
          if (!exists) {
            final cashOpt = _paymentMethods.firstWhere(
              (m) => m.isCash,
              orElse: () => _paymentMethods.first,
            );
            _selectedMethod = cashOpt.idStr;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payController.dispose();
    super.dispose();
  }

  Future<void> _loadBooking() async {
    if (widget.booking != null) {
      _activeBooking = widget.booking;
    } else {
      try {
        final bookings = await widget.repository.getBookings();
        final unpaidBookings = bookings.where((b) => b.paymentStatus != PaymentStatus.paid).toList();
        _activeBooking = unpaidBookings.isNotEmpty ? unpaidBookings.first : (bookings.isNotEmpty ? bookings.first : null);
      } catch (_) {}
    }

    if (widget.initialPaymentType != null) {
      _paymentType = widget.initialPaymentType!;
    }

    double initialAmount = _totalAmount;
    if (_paymentType == PaymentTypeOption.penalty) {
      initialAmount = widget.initialAmount ?? (_activeBooking?.estimatedLateFee ?? 0.0);
    } else if (_paymentType == PaymentTypeOption.extend) {
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        initialAmount = widget.initialAmount!;
      } else {
        final daily = (_rentFee / (_activeBooking?.durationDays ?? 1)).roundToDouble();
        initialAmount = daily > 0 ? daily : 50000.0;
      }
    } else if (widget.initialAmount != null && widget.initialAmount! > 0) {
      initialAmount = widget.initialAmount!;
    }

    _amount = initialAmount;
    _pay = initialAmount;
    _amountController.text = Formatters.formatCurrency(_amount);
    _payController.text = Formatters.formatCurrency(_pay);
    _cashSuggestions = CashSuggestion.generate(_amount);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showBookingPicker() async {
    try {
      final allBookings = await widget.repository.getBookings();
      if (!mounted || allBookings.isEmpty) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Transaksi Booking',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: allBookings.length,
                    separatorBuilder: (_, __) => Divider(height: 8, color: AppTheme.cardBorder),
                    itemBuilder: (ctx, index) {
                      final b = allBookings[index];
                      final isCurrent = b.id == _activeBooking?.id;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        leading: CircleAvatar(
                          backgroundColor: isCurrent ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.phone_iphone_rounded, size: 18, color: isCurrent ? Colors.white : AppTheme.primary),
                        ),
                        title: Text('${b.bookingCode} • ${b.customerName}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        subtitle: Text('${b.iphone.fullName} • ${b.paymentStatus.label}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        trailing: Text(Formatters.formatCurrency(b.price), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _activeBooking = b;
                            _onPaymentTypeChanged(_paymentType);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  double get _rentFee => _activeBooking?.price ?? 0.0;
  double get _depositFee => _activeBooking?.deposit ?? 0.0;
  double get _discountFee => _activeBooking?.discount ?? 0.0;
  double get _downPayment => _activeBooking?.downPayment ?? 0.0;
  double get _totalBill => (_rentFee + _depositFee - _discountFee).clamp(0.0, double.infinity);
  double get _totalAmount => (_totalBill - _downPayment).clamp(0.0, double.infinity);

  double get _sisaTagihan {
    if (_paymentType == PaymentTypeOption.dp || _paymentType == PaymentTypeOption.pelunasan) {
      return (_totalAmount - _amount).clamp(0.0, double.infinity);
    }
    return 0.0;
  }

  PaymentMethodOption? get _selectedPaymentMethodObj {
    try {
      return _paymentMethods.firstWhere(
        (m) => m.idStr == _selectedMethod || m.slug == _selectedMethod,
      );
    } catch (_) {
      return null;
    }
  }

  bool get _isCashSelected {
    final obj = _selectedPaymentMethodObj;
    if (obj != null) return obj.isCash;
    return _selectedMethod == 'tunai' || _selectedMethod == 'cash';
  }

  double get _change => (_pay - _amount).clamp(0.0, double.infinity);
  bool get _isPayUnder => _isCashSelected && _pay < _amount;

  DateTime get _paymentDateTime => DateTime(
        _selectedPaymentDate.year,
        _selectedPaymentDate.month,
        _selectedPaymentDate.day,
        _selectedPaymentTime.hour,
        _selectedPaymentTime.minute,
      );

  void _onPaymentTypeChanged(PaymentTypeOption type) {
    setState(() {
      _paymentType = type;
      if (type == PaymentTypeOption.pelunasan) {
        _amount = _totalAmount;
      } else if (type == PaymentTypeOption.dp) {
        const minDp = 50000.0;
        _amount = _totalAmount <= minDp ? _totalAmount : (_totalAmount * 0.5).clamp(minDp, _totalAmount);
      } else if (type == PaymentTypeOption.penalty) {
        _amount = widget.initialAmount ?? (_activeBooking?.estimatedLateFee ?? 0.0);
      } else if (type == PaymentTypeOption.extend) {
        if (widget.initialAmount != null && widget.initialAmount! > 0) {
          _amount = widget.initialAmount!;
        } else {
          final daily = (_rentFee / (_activeBooking?.durationDays ?? 1)).roundToDouble();
          _amount = daily > 0 ? daily : 50000.0;
        }
      }

      _amountController.text = Formatters.formatCurrency(_amount);
      _cashSuggestions = CashSuggestion.generate(_amount);
      _pay = _amount;
      _payController.text = Formatters.formatCurrency(_pay);
    });
  }

  void _onAmountChanged(String val) {
    final cleanDigits = val.replaceAll(RegExp(r'[^0-9]'), '');
    final newAmount = double.tryParse(cleanDigits) ?? 0.0;
    setState(() {
      _amount = newAmount;
      _cashSuggestions = CashSuggestion.generate(_amount);
      if (!_isCashSelected || _pay < _amount) {
        _pay = _amount;
        _payController.text = Formatters.formatCurrency(_pay);
      }
    });
  }

  void _onPayChanged(String val) {
    final cleanDigits = val.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _pay = double.tryParse(cleanDigits) ?? 0.0;
    });
  }

  void _selectCashSuggestion(CashSuggestionItem item) {
    setState(() {
      _pay = item.pay;
      _payController.text = Formatters.formatCurrency(_pay);
    });
  }

  void _addCashIncrement(double increment) {
    setState(() {
      _pay += increment;
      _payController.text = Formatters.formatCurrency(_pay);
    });
  }

  void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;
      if (!_isCashSelected) {
        _pay = _amount;
        _payController.text = Formatters.formatCurrency(_pay);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPaymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedPaymentDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedPaymentTime,
    );
    if (picked != null) {
      setState(() => _selectedPaymentTime = picked);
    }
  }

  ReceiptModel _createReceipt({bool isSample = false}) {
    final booking = _activeBooking;
    final currentUser = AuthService().currentUser;
    final adminName = currentUser != null
        ? '${currentUser.name} (${currentUser.role})'
        : (isSample ? 'Budi Santoso (KASIR)' : 'Staff Kasir');
    final branchName = currentUser?.outletName ?? (isSample ? 'SKYRental - Gandaria' : 'SKYRENTAL YOGYAKARTA');

    final bool isPenalty = _paymentType == PaymentTypeOption.penalty;
    final bool isExtend = _paymentType == PaymentTypeOption.extend;

    final double rentFee = isExtend ? (_rentFee + _amount) : _rentFee;
    final double depositFee = isSample ? 0 : _depositFee;
    final double finesFee = isPenalty ? _amount : 0.0;
    final double discountFee = isSample ? 0 : _discountFee;
    final double totalAmount = isSample
        ? _amount
        : (isPenalty ? _amount : (isExtend ? (_rentFee + _amount + _depositFee - _discountFee) : _totalBill));
    final double paidAmount = isSample ? _amount : (isPenalty ? _amount : (_downPayment + _amount));
    final double remaining = (isSample || isPenalty) ? 0.0 : _sisaTagihan;

    final String durationStr = isSample
        ? '${booking?.durationDays ?? 3} Hari'
        : (isExtend ? '${widget.extendHours ?? 24} Jam (Extend)' : '${booking?.durationDays ?? 1} Hari');

    final String bookingCode = booking?.bookingCode ?? (isSample ? 'BK-8821' : 'BK-0000');
    final String receiptNum = isSample
        ? 'SAMPLE-${DateTime.now().millisecondsSinceEpoch % 10000}'
        : 'STR-${_paymentDateTime.year}${_paymentDateTime.month.toString().padLeft(2, '0')}-${(5000 + (booking?.id ?? 102))}';

    final methodObj = _selectedPaymentMethodObj;
    final methodName = methodObj?.displayName ?? _selectedMethod.toUpperCase();
    final methodUpper = methodName.toUpperCase();

    String customLabel;
    if (isSample) {
      customLabel = 'SAMPLE STRUK THERMAL';
    } else if (widget.isReturnFlow) {
      customLabel = 'TANDA TERIMA PENGEMBALIAN - $methodUpper';
    } else if (isPenalty) {
      customLabel = 'TANDA TERIMA DENDA - $methodUpper';
    } else {
      customLabel = 'TANDA TERIMA - $methodUpper';
    }

    String notes;
    if (isSample) {
      notes = 'Uji cetak struk thermal sample kasir.';
    } else if (widget.isReturnFlow || isPenalty) {
      notes = 'Denda Keterlambatan Pengembalian Unit. Nominal: ${Formatters.formatCurrency(_amount)} via $methodUpper. Tanggal Bayar: ${Formatters.date(_paymentDateTime)} ${Formatters.time(_paymentDateTime)}. WA: ${_sendWhatsApp ? "Terkirim" : "Tidak"}, Cetak: ${_printReceipt ? "Thermal MP-58C" : "Tidak"}';
    } else {
      notes = 'Jenis: ${_paymentType.label}. Dibayar saat ini: ${Formatters.formatCurrency(_amount)} via $methodUpper. Tanggal Bayar: ${Formatters.date(_paymentDateTime)} ${Formatters.time(_paymentDateTime)}. WA: ${_sendWhatsApp ? "Terkirim" : "Tidak"}, Cetak: ${_printReceipt ? "Thermal MP-58C" : "Tidak"}';
    }

    return ReceiptModel(
      receiptNumber: receiptNum,
      date: _paymentDateTime,
      adminName: adminName,
      branchName: branchName,
      type: widget.isReturnFlow ? ReceiptType.returnUnit : _paymentType.receiptType,
      customTypeLabel: customLabel,
      bookingCode: bookingCode,
      customerName: booking?.customerName ?? (isSample ? 'Rian Hidayat' : 'Pelanggan'),
      customerPhone: booking?.customerPhone ?? (isSample ? '+62 812-9876-5432' : '+62'),
      unitName: booking?.iphone.name ?? (isSample ? 'iPhone 15 Pro 128GB' : 'Unit iPhone'),
      serialNumber: booking?.iphone.serialNumber ?? (isSample ? 'SN-PRO-99' : 'SN-17430-ID'),
      assetCode: booking?.iphone.assetCode,
      rentalDuration: durationStr,
      rentalDates: '${Formatters.formatDate(booking?.startDate ?? DateTime.now())} - ${Formatters.formatDate(booking?.endDate ?? DateTime.now().add(const Duration(days: 3)))}',
      rentFee: rentFee,
      depositFee: depositFee,
      finesFee: finesFee,
      discountFee: discountFee,
      totalAmount: totalAmount,
      paidAmount: paidAmount,
      remainingAmount: remaining,
      refundAmount: 0.0,
      paymentMethod: methodUpper,
      paymentStatus: remaining <= 0 ? 'paid' : 'partial',
      cashGiven: _isCashSelected ? _pay : _amount,
      cashChange: _isCashSelected ? _change : 0,
      depositStatus: isSample ? 'Tanpa Deposit' : (depositFee > 0 ? 'Ditahan' : 'Tanpa Deposit'),
      notes: notes,
    );
  }

  Future<void> _confirmPayment() async {
    if (_amount <= 0) {
      _showSnackbar('Nominal pembayaran harus lebih besar dari Rp 0!', isError: true);
      return;
    }
    if (_isPayUnder) {
      _showSnackbar('Uang tunai yang diterima kurang dari nominal yang harus dibayar!', isError: true);
      return;
    }
    if (_activeBooking == null) {
      _showSnackbar('Tidak ada data booking yang dipilih!', isError: true);
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final bookingCode = _activeBooking!.bookingCode;
      final newPaymentStatus = _sisaTagihan <= 0 ? PaymentStatus.paid : PaymentStatus.partial;
      final methodObj = _selectedPaymentMethodObj;
      final methodName = methodObj?.displayName ?? _selectedMethod.toUpperCase();
      final methodToSend = methodObj?.slug.isNotEmpty == true ? methodObj!.slug : _selectedMethod;

      await widget.repository.submitBookingPayment(
        bookingCode: bookingCode,
        amount: _amount,
        pay: _isCashSelected ? _pay : _amount,
        paymentMethod: methodToSend,
        type: _paymentType.id,
        paidAt: _paymentDateTime,
        note: (widget.isReturnFlow || _paymentType == PaymentTypeOption.penalty)
            ? 'Pembayaran Denda Keterlambatan Pengembalian Unit via $methodName'
            : (_paymentType == PaymentTypeOption.extend
                ? 'Pembayaran Tambah Jam (${widget.extendHours ?? 24} Jam) via $methodName'
                : 'Pembayaran ${_paymentType.label} via $methodName'),
        sendWhatsapp: _sendWhatsApp,
      );

      if (_paymentType == PaymentTypeOption.extend) {
        final hoursToExtend = widget.extendHours ?? 24;
        try {
          final updated = await widget.repository.extendBooking(
            bookingCode: bookingCode,
            hours: hoursToExtend,
            price: _amount,
            paymentMethod: methodToSend,
            pay: _isCashSelected ? _pay : _amount,
            note: 'Pembayaran Tambah Jam ($hoursToExtend Jam) via $methodName',
          );
          _activeBooking = updated;
        } catch (_) {}
      }

      if (widget.isReturnFlow) {
        try {
          await widget.repository.completeReturn(
            bookingCode: bookingCode,
            physicalCondition: 'Baik / Sesuai Kesepakatan',
            batteryHealthFinal: _activeBooking?.iphone.batteryHealth ?? 100,
            lateFee: _amount,
            damageFee: 0,
            depositRefunded: 0,
            refundMethod: _isCashSelected ? 'Tunai Kasir' : methodName,
            accessoriesReturned: ['Lengkap'],
            staffNotes: 'Pengembalian unit selesai dengan pelunasan denda keterlambatan Rp ${Formatters.formatCurrency(_amount)}',
          );
        } catch (_) {}
      }

      if (_activeBooking != null && _paymentType != PaymentTypeOption.penalty) {
        _activeBooking = _activeBooking!.copyWith(
          paymentStatus: newPaymentStatus,
          downPayment: (_activeBooking!.downPayment + _amount),
        );
      }

      final receipt = _createReceipt(isSample: false);
      await widget.repository.saveReceipt(receipt);

      if (_printReceipt) {
        try {
          await ThermalPrintService().printReceipt(receipt);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() => _isConfirming = false);
      _showSuccessDialog(receipt);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      _showSnackbar('Gagal konfirmasi pembayaran: $e', isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(ReceiptModel receipt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            SizedBox(width: 10),
            Text('Pembayaran Berhasil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isReturnFlow) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF047857)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pengembalian unit selesai & unit iPhone telah kembali ke status Tersedia.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text('Nomor Resi: ${receipt.receiptNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_paymentType.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
                const SizedBox(width: 8),
                Text(Formatters.formatCurrency(receipt.paidAmount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedMethod == 'tunai') ...[
              Text('Uang Diterima: ${Formatters.formatCurrency(receipt.cashGiven)}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text('Kembalian: ${Formatters.formatCurrency(receipt.cashChange)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success)),
              const SizedBox(height: 8),
            ],
            if (_sisaTagihan > 0) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Text('Sisa Tagihan: ${Formatters.formatCurrency(_sisaTagihan)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text('Waktu: ${Formatters.date(_paymentDateTime)}, ${Formatters.time(_paymentDateTime)} WIB', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            if (_printReceipt)
              Row(
                children: [
                  const Icon(Icons.print_rounded, size: 14, color: AppTheme.success),
                  const SizedBox(width: 6),
                  Text('Terkirim ke Printer Thermal Bluetooth', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            if (_sendWhatsApp) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.chat_rounded, size: 14, color: AppTheme.success),
                  const SizedBox(width: 6),
                  Text('Notifikasi WhatsApp dikirim ke penyewa', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, AppRoutes.receiptPreview, arguments: receipt);
            },
            icon: const Icon(Icons.receipt_rounded, size: 16),
            label: const Text('Lihat Struk Resi', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_activeBooking == null) {
      return _buildEmptyBookingScaffold(context);
    }

    final mediaSize = MediaQuery.sizeOf(context);
    final isLandscape = mediaSize.width > mediaSize.height;
    final isTabletLandscape = mediaSize.width >= 900 && isLandscape;

    return isTabletLandscape ? _buildTabletLayout(context) : _buildMobileLayout(context);
  }

  Widget _buildEmptyBookingScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Text('Konfirmasi Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle, border: Border.all(color: AppTheme.cardBorder)),
                child: Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Text('Tidak Ada Booking yang Dipilih', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Silakan pilih transaksi booking dari daftar untuk memproses pembayaran kasir.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Kembali ke Daftar'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TABLET LANDSCAPE POS LAYOUT (60:40)
  // ===========================================================================
  Widget _buildTabletLayout(BuildContext context) {
    final tabletMediaQuery = MediaQueryData(
      size: MediaQuery.sizeOf(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      textScaler: MediaQuery.textScalerOf(context),
      platformBrightness: MediaQuery.platformBrightnessOf(context),
      padding: MediaQuery.paddingOf(context),
      viewPadding: MediaQuery.viewPaddingOf(context),
      viewInsets: EdgeInsets.zero,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      accessibleNavigation: MediaQuery.accessibleNavigationOf(context),
      invertColors: MediaQuery.invertColorsOf(context),
      highContrast: MediaQuery.highContrastOf(context),
      disableAnimations: MediaQuery.disableAnimationsOf(context),
      boldText: MediaQuery.boldTextOf(context),
    );

    return MediaQuery(
      data: tabletMediaQuery,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        resizeToAvoidBottomInset: false,
        appBar: const AppHeader(isTablet: true),
        body: Column(
          children: [
            _buildTabletSubHeader(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 60,
                      child: RepaintBoundary(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          physics: const ClampingScrollPhysics(),
                          child: _buildTabletLeftColumn(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 40,
                      child: RepaintBoundary(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          physics: const ClampingScrollPhysics(),
                          child: _buildTabletRightColumn(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildTabletBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletSubHeader(BuildContext context) {
    final bookingCode = _activeBooking?.bookingCode ?? 'BK-8821';
    final isPaid = _activeBooking?.paymentStatus == PaymentStatus.paid;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back, size: 14, color: Color(0xFF475569)),
                          SizedBox(width: 4),
                          Text('Antrean Booking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        ],
                      ),
                    ),
                    const Text('  /  Konfirmasi Pembayaran  ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text('#$bookingCode', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Konfirmasi Kasir & Settlement',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                        border: Border.all(color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isPaid ? const Color(0xFF10B981) : const Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPaid ? 'LUNAS' : 'MENUNGGU BAYAR',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPaid ? const Color(0xFF047857) : const Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletSectionCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildTabletLeftColumn(BuildContext context) {
    return Column(
      children: [
        _buildTabletCustomerUnitCard(),
        const SizedBox(height: 16),
        _buildTabletThermalReceiptPreview(),
        const SizedBox(height: 16),
        _buildTabletPrinterStatusCard(),
      ],
    );
  }

  Widget _buildTabletCustomerUnitCard() {
    final booking = _activeBooking!;
    final initials = booking.customerName.trim().isNotEmpty
        ? booking.customerName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'RH';
    final cleanPhone = booking.customerPhone.replaceAll(RegExp(r'^\+?62|^0'), '');

    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('IDENTITAS PELANGGAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 2),
          const Text('Ringkasan Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          // Sub-card Customer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: Text(initials, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(booking.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                            child: const Text('KYC TERVERIFIKASI', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text('NIK: 3174**********0002', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('KONTAK UTAMA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('+62 $cleanPhone', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 8, color: Color(0xFF16A34A)),
                          SizedBox(width: 3),
                          Text('WhatsApp Aktif', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Sub-card Unit iPhone
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: const Icon(Icons.phone_iphone_rounded, size: 22, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(booking.iphone.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              booking.iphone.color.isNotEmpty ? booking.iphone.color : 'Natural Titanium',
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('SN: ${booking.iphone.serialNumber.isNotEmpty ? booking.iphone.serialNumber : "-"}  •  Aset: ${booking.iphone.assetCode.isNotEmpty ? booking.iphone.assetCode : "-"}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 10, color: Color(0xFF2563EB)),
                          const SizedBox(width: 3),
                          Text('${booking.durationDays} JAM SEWA (AKTIF)', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('${Formatters.date(booking.startDate)}, 15:00 WIB', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    Text('s/d ${Formatters.date(booking.endDate)}, 15:00 WIB', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeVisual(String code) {
    final type = _receiptFormatSettings.barcodeType;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(6),
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
                width: 180,
                height: 44,
                drawText: _receiptFormatSettings.showBarcodeHri,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
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
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 4),
              Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJaggedEdge({required bool isTop}) {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: CustomPaint(
        painter: _JaggedEdgePainter(isTop: isTop, color: const Color(0xFFFCFDFB)),
      ),
    );
  }

  Widget _buildRealisticThermalPaper(ReceiptModel receipt, {bool isMobile = false}) {
    final receiptText = receipt.toEscPos58mm(formatSettings: _receiptFormatSettings);
    final estCm = ReceiptModel.estimatePaperLengthCm(receiptText, _receiptFormatSettings);
    final hasBarcodeTag = receiptText.contains(RegExp(r'\[BARCODE:.*?\]'));

    final monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: isMobile ? 9.5 : 10.5,
      height: 1.35,
      letterSpacing: 0.3,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF0F172A),
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

      double titleFontSize = isMobile ? 13 : 15;
      if (size == 'small') titleFontSize = isMobile ? 10 : 11.5;
      if (size == 'medium') titleFontSize = isMobile ? 11.5 : 13;
      if (size == 'large') titleFontSize = isMobile ? 13.5 : 15.5;
      if (size == 'extraLarge') titleFontSize = isMobile ? 15 : 18;

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
                letterSpacing: 0.6,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          if (after.isNotEmpty) SelectableText(after.trimLeft(), style: monoStyle),
        ],
      );
    }

    Widget contentWidget;
    if (hasBarcodeTag && _receiptFormatSettings.showBarcode) {
      final parts = receiptText.split(RegExp(r'\[BARCODE:.*?\]\n?'));
      final bookingCode = receipt.bookingCode;

      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSegment(parts[0]),
          _buildBarcodeVisual(bookingCode),
          if (parts.length > 1) buildSegment(parts[1]),
        ],
      );
    } else {
      final cleanText = receiptText.replaceAll(RegExp(r'\[BARCODE:.*?\]\n?'), '');
      contentWidget = buildSegment(cleanText);
    }

    return Column(
      children: [
        _buildJaggedEdge(isTop: true),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 14),
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
        _buildJaggedEdge(isTop: false),
        const SizedBox(height: 10),
        Text(
          '— Lebar Kertas Standar VSC MP-58C (32 Karakter • ~$estCm cm) —',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildTabletThermalReceiptPreview() {
    final receipt = _createReceipt(isSample: false);

    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pratinjau Struk Termal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: const Text('Format 58mm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildRealisticThermalPaper(receipt, isMobile: false),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: _printSampleReceipt,
                            icon: const Icon(Icons.print_outlined, size: 16),
                            label: const Text('Uji Cetak Sample', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF1E293B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                        child: IconButton(
                          icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF475569)),
                          tooltip: 'Pengaturan Format Struk',
                          onPressed: () async {
                            await Navigator.pushNamed(context, AppRoutes.receiptFormatSettings);
                            _loadReceiptFormatSettings();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletPrinterStatusCard() {
    return _buildTabletSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.print_outlined, size: 20, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('VSC MP-58C Kasir', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(width: 6),
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('Bluetooth Online • Kertas 58mm Siap', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: _pingPrinter,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Ping Printer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletRightColumn(BuildContext context) {
    return Column(
      children: [
        _buildTabletBillingHero(),
        const SizedBox(height: 16),
        _buildTabletPaymentMethodSection(),
        const SizedBox(height: 16),
        _buildTabletPostActionSection(),
        const SizedBox(height: 16),
        _buildTabletSubmitButton(),
      ],
    );
  }

  Widget _buildTabletBillingHero() {
    return _buildTabletSectionCard(
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
                    Text('KALKULASI FINAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    SizedBox(height: 2),
                    Text('Rincian Tagihan & Nominal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('Waktu Tagihan: ${Formatters.time(_paymentDateTime)} WIB', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 12),
          // Blue Hero Container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text('TOTAL TAGIHAN SAAT INI', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Wajib Bayar', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Status Pelunasan', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(12)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 3, backgroundColor: Color(0xFF2563EB)),
                                  SizedBox(width: 4),
                                  Text('Menunggu Transaksi', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.formatCurrency(_amount),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // JENIS PEMBAYARAN TRANSAKSI
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('JENIS PEMBAYARAN TRANSAKSI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                const Text('Pilih status tagihan kasir sebelum konfirmasi', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                const SizedBox(height: 10),
                Row(
                  children: PaymentTypeOption.values.map((opt) {
                    final isSelected = _paymentType == opt;
                    final label = opt == PaymentTypeOption.pelunasan
                        ? 'Lunas'
                        : opt == PaymentTypeOption.dp
                            ? 'DP / Uang Muka'
                            : opt == PaymentTypeOption.penalty
                                ? 'Denda'
                                : 'Extend / Sewa';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => _onPaymentTypeChanged(opt),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(Icons.check, size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletPaymentMethodSection() {
    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SISTEM PEMBAYARAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 2),
          const Text('Metode Pembayaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          _paymentMethods.length <= 4
              ? Row(
                  children: [
                    for (int i = 0; i < _paymentMethods.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _buildTabletMethodCard(
                        id: _paymentMethods[i].idStr,
                        label: _paymentMethods[i].displayName,
                        badge: _paymentMethods[i].defaultBadge,
                        subtitle: _paymentMethods[i].description ?? _paymentMethods[i].defaultSubtitle,
                        icon: _paymentMethods[i].iconData,
                        hasGreenDot: _paymentMethods[i].slug.contains('qris') || _paymentMethods[i].name.toLowerCase().contains('qris'),
                      ),
                    ],
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < _paymentMethods.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
                          child: _buildTabletMethodCard(
                            id: _paymentMethods[i].idStr,
                            label: _paymentMethods[i].displayName,
                            badge: _paymentMethods[i].defaultBadge,
                            subtitle: _paymentMethods[i].description ?? _paymentMethods[i].defaultSubtitle,
                            icon: _paymentMethods[i].iconData,
                            hasGreenDot: _paymentMethods[i].slug.contains('qris') || _paymentMethods[i].name.toLowerCase().contains('qris'),
                            isExpanded: false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          if (_isCashSelected) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'SARAN PECAHAN NOMINAL & KEMBALIAN',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF334155), letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Tagihan: ${Formatters.formatCurrency(_amount)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: _buildTabletCashSuggestionChips()),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Uang Tunai Diterima:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(Formatters.formatCurrency(_pay), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('KEMBALIAN KASIR:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              const SizedBox(height: 2),
                              Text(Formatters.formatCurrency(_change), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabletMethodCard({
    required String id,
    required String label,
    String? badge,
    required String subtitle,
    required IconData icon,
    bool hasGreenDot = false,
    bool isExpanded = true,
  }) {
    final isSelected = _selectedMethod == id || (_selectedPaymentMethodObj?.slug == id);
    final cardContent = InkWell(
      onTap: () => _selectMethod(id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: isSelected ? Colors.white : const Color(0xFF0F172A)),
                if (hasGreenDot)
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: isSelected ? Colors.white24 : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                    child: Text(badge, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF475569))),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF0F172A))),
            Text(subtitle, style: TextStyle(fontSize: 9.5, color: isSelected ? Colors.white70 : const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
    return isExpanded ? Expanded(child: cardContent) : cardContent;
  }

  List<Widget> _buildTabletCashSuggestionChips() {
    final List<Widget> chips = [];
    final items = _cashSuggestions.take(4).toList();

    for (int i = 0; i < 4; i++) {
      if (i < items.length) {
        final item = items[i];
        final isSelected = (_pay - item.pay).abs() < 1;
        String chipLabel = '';
        if (i == 0 && item.change == 0) {
          chipLabel = 'UANG PAS';
        } else {
          final nominalK = (item.pay / 1000).round();
          chipLabel = nominalK >= 1000
              ? 'Pecahan ${(nominalK / 1000).toStringAsFixed(nominalK % 1000 == 0 ? 0 : 1)} Juta'
              : 'Pecahan ${nominalK}rb';
        }

        chips.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => _selectCashSuggestion(item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      children: [
                        Text(chipLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: i == 0 ? const Color(0xFF16A34A) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(Formatters.formatCurrency(item.pay), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return chips;
  }

  Widget _buildTabletPostActionSection() {
    final phone = _activeBooking?.customerPhone.replaceAll(RegExp(r'^\+?62|^0'), '') ?? '812-9876-5432';

    Widget actionItem({required bool value, required ValueChanged<bool?> onChanged, required String title, required String subtitle}) {
      return InkWell(
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(value: value, onChanged: onChanged, activeColor: const Color(0xFF0F172A)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OTOMASI SERAH TERIMA & BUKTI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 12),
          actionItem(
            value: _sendWhatsApp,
            onChanged: (v) => setState(() => _sendWhatsApp = v ?? true),
            title: 'Kirim Bukti Pembayaran via WhatsApp',
            subtitle: 'Otomatis kirim PDF invoice ke nomor +62 $phone',
          ),
          const SizedBox(height: 8),
          actionItem(
            value: _printReceipt,
            onChanged: (v) => setState(() => _printReceipt = v ?? true),
            title: 'Cetak Struk Thermal Kasir 2 Rangkap',
            subtitle: 'Format VSC MP-58C (1 Customer, 1 Arsip Kasir)',
          ),
        ],
      ),
    );
  }

  Widget _buildTabletSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        key: const Key('btn_confirm_payment_tablet'),
        onPressed: _isConfirming || _isPayUnder ? null : _confirmPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isConfirming
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _isPayUnder
                          ? 'Uang Diterima Kurang'
                          : (widget.isReturnFlow || _paymentType == PaymentTypeOption.penalty)
                              ? 'Bayar Denda & Selesaikan Pengembalian'
                              : 'Konfirmasi Pembayaran & Cetak Struk',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
      ),
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
      child: Row(
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
    );
  }

  Future<void> _printSampleReceipt() async {
    final receiptToPrint = _activeBooking != null ? _createReceipt(isSample: false) : _createReceipt(isSample: true);
    try {
      await ThermalPrintService().printReceipt(receiptToPrint);
      if (mounted) {
        _showSnackbar('Berhasil mencetak struk thermal ke printer VSC MP-58C.');
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Gagal mencetak struk: $e', isError: true);
      }
    }
  }

  Future<void> _pingPrinter() async {
    final isConnected = await ThermalPrintService().checkConnection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isConnected
              ? 'Printer VSC MP-58C Kasir: Terhubung & Kertas 58mm Siap'
              : 'Printer VSC MP-58C: Belum terhubung. Pastikan Bluetooth aktif.'),
          backgroundColor: isConnected ? AppTheme.success : AppTheme.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===========================================================================
  // MOBILE PORTRAIT LAYOUT
  // ===========================================================================
  Widget _buildMobileLayout(BuildContext context) {
    final booking = _activeBooking!;
    final customerName = booking.customerName;
    final customerPhone = booking.customerPhone;
    final bookingCode = booking.bookingCode;
    final modelName = booking.iphone.modelName;
    final durationText = '${booking.durationDays} Jam (${booking.status.label})';

    final currentUser = AuthService().currentUser;
    final branchName = currentUser?.outletName ?? 'Outlet SKYRental';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfirmasi Pembayaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            Text('Booking $bookingCode • $branchName', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.warningContainer, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.warning, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('MENUNGGU BAYAR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.onWarningContainer, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookingSummaryCard(customerName, customerPhone, modelName, durationText),
            const SizedBox(height: 12),
            _buildBillingHeroCard(),
            const SizedBox(height: 14),
            _buildPaymentTypeSection(),
            const SizedBox(height: 14),
            _buildAmountInputSection(),
            const SizedBox(height: 14),
            _buildPaidAtSection(),
            const SizedBox(height: 14),
            _buildPaymentMethodSection(),
            if (_isCashSelected) ...[
              const SizedBox(height: 14),
              _buildPosCashSection(),
            ],
            const SizedBox(height: 14),
            _buildMobileThermalReceiptPreviewSection(),
            const SizedBox(height: 14),
            _buildPostActionCheckboxes(),
          ],
        ),
      ),
      bottomSheet: _buildStickyBottomDock(),
    );
  }

  Widget _buildMobileThermalReceiptPreviewSection() {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _showMobileReceiptPreview,
            onExpansionChanged: (val) => setState(() => _showMobileReceiptPreview = val),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 20),
            ),
            title: Text(
              'Pratinjau Struk Termal (58mm)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              'Desain siap print sesuai pengaturan printer',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            children: [
              const SizedBox(height: 6),
              _buildRealisticThermalPaper(_createReceipt(isSample: false), isMobile: true),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: _printSampleReceipt,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Tes Cetak Struk Saat Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(color: AppTheme.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingSummaryCard(String customerName, String customerPhone, String modelName, String durationText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.person_rounded, size: 20, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          if (widget.booking == null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showBookingPicker,
                              child: Text(
                                '[Ganti]',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(customerPhone, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.successContainer, borderRadius: BorderRadius.circular(4)),
                child: const Text('KYC Verified', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.onSuccessContainer)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(modelName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(durationText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingHeroCard() {
    final isPenalty = _paymentType == PaymentTypeOption.penalty;
    final isExtend = _paymentType == PaymentTypeOption.extend;
    final heroTitle = isPenalty
        ? 'TOTAL DENDA KETERLAMBATAN'
        : isExtend
            ? 'BIAYA PERPANJANGAN (EXTEND)'
            : 'TOTAL BIAYA SEWA';
    final heroAmount = (isPenalty || isExtend) ? _amount : _totalAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPenalty ? const Color(0xFFFECACA) : AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heroTitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPenalty ? const Color(0xFFDC2626) : AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.formatCurrency(heroAmount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isPenalty ? const Color(0xFFDC2626) : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (isPenalty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                      Text(
                        _activeBooking?.lateDurationFormatted.isNotEmpty == true ? _activeBooking!.lateDurationFormatted : 'TERLAMBAT',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                )
              else if (isExtend)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TAMBAH WAKTU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      Text('${widget.extendHours ?? 24} Jam', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _sisaTagihan <= 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _sisaTagihan <= 0 ? 'SISA TAGIHAN: LUNAS' : 'SISA TAGIHAN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _sisaTagihan <= 0 ? const Color(0xFF047857) : const Color(0xFFD97706),
                        ),
                      ),
                      Text(
                        Formatters.formatCurrency(_sisaTagihan),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _sisaTagihan <= 0 ? const Color(0xFF047857) : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_depositFee > 0 || _discountFee > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_depositFee > 0)
                  Text('Deposit: ${Formatters.formatCurrency(_depositFee)}  ', style: TextStyle(fontSize: 10, color: AppTheme.secondary, fontWeight: FontWeight.w600)),
                if (_discountFee > 0)
                  Text('Diskon: -${Formatters.formatCurrency(_discountFee)}', style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentTypeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isReturnFlow || _paymentType == PaymentTypeOption.penalty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECACA))),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pengembalian Unit: Denda keterlambatan disesuaikan dari kalkulasi durasi ${_activeBooking?.lateDurationFormatted.isNotEmpty == true ? "(${_activeBooking!.lateDurationFormatted})" : ""}.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text('JENIS PEMBAYARAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: PaymentTypeOption.values.map((type) {
              final isSelected = _paymentType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onPaymentTypeChanged(type),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.cardBorder, width: isSelected ? 1.5 : 1),
                    ),
                    child: Center(
                      child: Text(
                        type.badge,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(_paymentType.description, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildAmountInputSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NOMINAL YANG DIBAYARKAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
              if (_paymentType == PaymentTypeOption.dp)
                GestureDetector(
                  onTap: () {
                    final half = (_totalAmount * 0.5);
                    setState(() {
                      _amount = half;
                      _amountController.text = Formatters.formatCurrency(_amount);
                      _cashSuggestions = CashSuggestion.generate(_amount);
                      _pay = _amount;
                      _payController.text = Formatters.formatCurrency(_pay);
                    });
                  },
                  child: Text('Set 50% DP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12, right: 6),
                child: Text('Rp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ),
              hintText: '0',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
              filled: true,
              fillColor: AppTheme.surfaceContainerLow,
            ),
            onChanged: _onAmountChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPaidAtSection() {
    final dateFormatted = Formatters.date(_selectedPaymentDate);
    final timeFormatted = '${_selectedPaymentTime.hour.toString().padLeft(2, '0')}:${_selectedPaymentTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WAKTU PEMBAYARAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.cardBorder)),
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tanggal Bayar', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                            Text(dateFormatted, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.cardBorder)),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 18, color: AppTheme.secondary),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jam Bayar', style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                            Text(timeFormatted, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
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

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('METODE PEMBAYARAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
            Text('Database Aktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
          ],
        ),
        const SizedBox(height: 8),
        _paymentMethods.length <= 4
            ? Row(
                children: [
                  for (int i = 0; i < _paymentMethods.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _buildMethodButton(
                      _paymentMethods[i].idStr,
                      _paymentMethods[i].displayName,
                      _paymentMethods[i].iconData,
                    ),
                  ],
                ],
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _paymentMethods.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      SizedBox(
                        width: 78,
                        child: _buildMethodButton(
                          _paymentMethods[i].idStr,
                          _paymentMethods[i].displayName,
                          _paymentMethods[i].iconData,
                          isExpanded: false,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildMethodButton(String key, String label, IconData icon, {bool isExpanded = true}) {
    final isSelected = _selectedMethod == key || (_selectedPaymentMethodObj?.slug == key);
    final buttonContent = GestureDetector(
      onTap: () => _selectMethod(key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
    return isExpanded ? Expanded(child: buttonContent) : buttonContent;
  }

  Widget _buildPosCashSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SARAN PECAHAN UANG TUNAI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
              Text('Uang Pas / Lebih', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
            ],
          ),
          const SizedBox(height: 10),
          if (_cashSuggestions.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: _cashSuggestions.length,
              itemBuilder: (ctx, idx) {
                final item = _cashSuggestions[idx];
                final isSelected = (_pay == item.pay);
                return InkWell(
                  onTap: () => _selectCashSuggestion(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.cardBorder, width: isSelected ? 1.5 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.formatCurrency(item.pay),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.change == 0 ? 'Uang Pas' : 'Kembali ${Formatters.formatCurrency(item.change)}',
                          style: TextStyle(fontSize: 10, color: isSelected ? Colors.white.withValues(alpha: 0.85) : AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  label: const Text('Uang Pas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: AppTheme.surfaceContainerLow,
                  side: BorderSide(color: AppTheme.cardBorder),
                  onPressed: () {
                    setState(() {
                      _pay = _amount;
                      _payController.text = Formatters.formatCurrency(_pay);
                    });
                  },
                ),
                for (final inc in [10000, 20000, 50000, 100000]) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    label: Text('+${(inc / 1000).round()}rb', style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppTheme.surfaceContainerLow,
                    side: BorderSide(color: AppTheme.cardBorder),
                    onPressed: () => _addCashIncrement(inc.toDouble()),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _payController,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Uang Diterima (Rp)',
              labelStyle: const TextStyle(fontSize: 12),
              prefixIcon: Icon(Icons.payments_rounded, size: 20, color: AppTheme.primary),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
              filled: true,
              fillColor: AppTheme.surfaceContainerLow,
            ),
            onChanged: _onPayChanged,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isPayUnder ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isPayUnder ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isPayUnder ? 'Uang Kurang:' : 'KEMBALIAN:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isPayUnder ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                ),
                Text(
                  _isPayUnder ? Formatters.formatCurrency(_amount - _pay) : Formatters.formatCurrency(_change),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isPayUnder ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostActionCheckboxes() {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.cardBorder)),
        child: Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _sendWhatsApp,
                activeColor: AppTheme.secondary,
                title: const Text('Kirim WA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _sendWhatsApp = v ?? true),
              ),
            ),
            Container(width: 1, height: 24, color: AppTheme.cardBorder),
            Expanded(
              child: CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 10),
                value: _printReceipt,
                activeColor: AppTheme.secondary,
                title: const Text('Cetak Struk (MP-58C)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => setState(() => _printReceipt = v ?? true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Total Bayar: ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(Formatters.formatCurrency(_amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _paymentType == PaymentTypeOption.dp ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _paymentType.badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _paymentType == PaymentTypeOption.dp ? const Color(0xFFD97706) : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isConfirming || _isPayUnder ? null : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isConfirming
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isPayUnder
                            ? 'Uang Diterima Kurang'
                            : (widget.isReturnFlow || _paymentType == PaymentTypeOption.penalty)
                                ? 'Bayar Denda & Selesaikan Pengembalian'
                                : 'Konfirmasi ${_paymentType.label} & Simpan',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for thermal paper teeth / serrated tear edge
class _JaggedEdgePainter extends CustomPainter {
  final bool isTop;
  final Color color;

  _JaggedEdgePainter({required this.isTop, required this.color});

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