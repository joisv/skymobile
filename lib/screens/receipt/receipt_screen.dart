import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../data/mock_receipt_data.dart';
import '../../models/receipt_format_settings.dart';
import '../../models/receipt_model.dart';
import '../../models/printer_device_model.dart';
import '../../routes/app_routes.dart';
import '../../services/printer_storage_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class ReceiptScreen extends StatefulWidget {
  final ReceiptModel? initialReceipt;

  const ReceiptScreen({
    super.key,
    this.initialReceipt,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late int _selectedMockIndex;
  late ReceiptModel _currentReceipt;
  bool _isThermalView = true; // true: Thermal Paper (ESC/POS), false: Digital Card
  bool _isPrinting = false;
  PrinterDeviceModel _activePrinter = PrinterDeviceModel.defaultVsc();
  final ThermalPrintService _printService = ThermalPrintService();
  final PrinterStorageService _storage = PrinterStorageService();
  ReceiptFormatSettings _formatSettings = const ReceiptFormatSettings();

  @override
  void initState() {
    super.initState();
    if (widget.initialReceipt != null) {
      _currentReceipt = widget.initialReceipt!;
      _selectedMockIndex = 0;
    } else {
      _selectedMockIndex = 0;
      _currentReceipt = MockReceiptData.items[0];
    }
    _loadActivePrinter();
  }

  Future<void> _loadActivePrinter() async {
    final p = await _printService.ensurePrimaryConnected();
    final fmt = await _storage.getReceiptFormatSettings();
    if (mounted) {
      setState(() {
        _activePrinter = p;
        _formatSettings = fmt;
      });
    }
  }

  void _selectReceipt(int index) {
    setState(() {
      _selectedMockIndex = index;
      _currentReceipt = MockReceiptData.items[index];
    });
  }

  void _copyReceiptText() {
    var text = _currentReceipt.toEscPos58mm(formatSettings: _formatSettings);
    text = text.replaceAllMapped(
      RegExp(r'\[STORE_NAME:.*?:.*?:.*?:(.*?)\]'),
      (m) => m.group(1) ?? '',
    );
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teks format ESC/POS 58mm berhasil disalin ke clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 20),
            Text(
              'Mencetak ke ${_activePrinter.name}...',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Mengirim payload ESC/POS 58mm (32 kolom) via ${_activePrinter.connectionType.toUpperCase()} (${_activePrinter.address})...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );

    final result = await _printService.printReceipt(_currentReceipt, targetPrinter: _activePrinter);

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    setState(() => _isPrinting = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resi ${_currentReceipt.receiptNumber} berhasil dicetak pada printer ${result.deviceName ?? _activePrinter.name} (${result.bytesSent} byte)!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final isConn = await _printService.checkConnection();
      if (mounted) {
        setState(() => _activePrinter = _activePrinter.copyWith(isConnected: isConn));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Pengaturan',
            textColor: Colors.white,
            onPressed: () async {
              final res = await Navigator.pushNamed(context, AppRoutes.printerSettings);
              if (res is PrinterDeviceModel && mounted) {
                setState(() => _activePrinter = res);
              }
              _loadActivePrinter();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cardBorder,
      appBar: AppBar(
        title: const Text('Pratinjau Struk ESC/POS'),
        actions: [
          IconButton(
            tooltip: 'Hubungkan Ulang Printer',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadActivePrinter();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Memeriksa status koneksi printer...'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Salin Teks ESC/POS',
            icon: const Icon(Icons.copy_rounded),
            onPressed: _copyReceiptText,
          ),
          IconButton(
            tooltip: 'Pengaturan Format Resi',
            icon: const Icon(Icons.text_snippet_rounded),
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.receiptFormatSettings);
              _loadActivePrinter(); // Reload format settings setelah kembali
            },
          ),
          IconButton(
            tooltip: 'Pengaturan Printer & Uji Cetak',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              final res = await Navigator.pushNamed(context, AppRoutes.printerSettings);
              if (res is PrinterDeviceModel && mounted) {
                setState(() => _activePrinter = res);
              }
              _loadActivePrinter();
            },
          ),
          IconButton(
            tooltip: 'Cetak ke Thermal Printer',
            icon: const Icon(Icons.print_rounded),
            onPressed: _isPrinting ? null : _handlePrint,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Mock Data Selector Carousel / Tabs
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Data Tiruan Resi:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    // View Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _buildViewToggleItem(
                            title: 'Thermal 58mm',
                            icon: Icons.receipt_long_rounded,
                            isActive: _isThermalView,
                            onTap: () => setState(() => _isThermalView = true),
                          ),
                          _buildViewToggleItem(
                            title: 'Kartu Digital',
                            icon: Icons.dashboard_customize_rounded,
                            isActive: !_isThermalView,
                            onTap: () => setState(() => _isThermalView = false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(MockReceiptData.items.length, (index) {
                      final item = MockReceiptData.items[index];
                      final isSelected = _selectedMockIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            _getTypeIcon(item.type),
                            size: 14,
                            color: isSelected ? Colors.white : AppTheme.primary,
                          ),
                          label: Text(
                            '${item.customerName} (${item.type.label})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          onSelected: (val) {
                            if (val) _selectReceipt(index);
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // 2. Hardware Status Ribbon & Paper Length Meter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppTheme.cardBorder,
            child: Row(
              children: [
                Icon(
                  _activePrinter.isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                  size: 14,
                  color: _activePrinter.isConnected ? const Color(0xFF047857) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                Text(
                  'Printer: ${_activePrinter.name} (58mm)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                const SizedBox(width: 8),
                // Paper Length Meter Badge
                Builder(
                  builder: (context) {
                    final raw = _currentReceipt.toEscPos58mm(formatSettings: _formatSettings);
                    final cm = ReceiptModel.estimatePaperLengthCm(raw, _formatSettings);
                    final isEco = _formatSettings.densityMode == 'compact';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEco ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isEco ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEco ? Icons.eco_rounded : Icons.straighten_rounded,
                            size: 10,
                            color: isEco ? const Color(0xFF047857) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isEco ? '~$cm cm (ECO)' : '~$cm cm',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isEco ? const Color(0xFF047857) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _activePrinter.isConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _activePrinter.isConnected ? 'ONLINE' : 'TERPUTUS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _activePrinter.isConnected ? const Color(0xFF047857) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Main Content: Thermal Paper or Digital Card
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _isThermalView ? _buildThermalPaperView() : _buildDigitalCardView(),
                ),
              ),
            ),
          ),

          // 4. Bottom Sticky Action Bar
          Container(
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
                OutlinedButton.icon(
                  onPressed: _copyReceiptText,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Salin Teks', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _handlePrint,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: Text(
                      _isPrinting ? 'Mencetak...' : 'Cetak Resi (${_activePrinter.name})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleItem({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: isActive ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(ReceiptType type) {
    switch (type) {
      case ReceiptType.pickup:
        return Icons.outbox_rounded;
      case ReceiptType.returnUnit:
        return Icons.move_to_inbox_rounded;
      case ReceiptType.paymentSettlement:
        return Icons.payments_rounded;
      case ReceiptType.depositRefund:
        return Icons.replay_circle_filled_rounded;
    }
  }

  // Realistic Physical Thermal Receipt Preview
  Widget _buildThermalPaperView() {
    final rawText = _currentReceipt.toEscPos58mm(formatSettings: _formatSettings);
    final hasBarcodeTag = rawText.contains(RegExp(r'\[BARCODE:.*?\]'));

    const monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.35,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0F172A),
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

      double titleFontSize = 16;
      if (size == 'small') titleFontSize = 12;
      if (size == 'medium') titleFontSize = 14;
      if (size == 'large') titleFontSize = 17;
      if (size == 'extraLarge') titleFontSize = 21;

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
                letterSpacing: 0.8,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          if (after.isNotEmpty) SelectableText(after.trimLeft(), style: monoStyle),
        ],
      );
    }

    Widget contentWidget;
    if (hasBarcodeTag && _formatSettings.showBarcode) {
      final parts = rawText.split(RegExp(r'\[BARCODE:.*?\]\n?'));
      final bookingCode = _currentReceipt.bookingCode;

      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildSegment(parts[0]),
          _buildBarcodeVisual(bookingCode),
          if (parts.length > 1) buildSegment(parts[1]),
        ],
      );
    } else {
      final cleanText = rawText.replaceAll(RegExp(r'\[BARCODE:.*?\]\n?'), '');
      contentWidget = buildSegment(cleanText);
    }

    return Column(
      children: [
        // Top jagged edge / paper feeder teeth
        _buildJaggedEdge(isTop: true),

        // Paper Body
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

        // Bottom jagged edge
        _buildJaggedEdge(isTop: false),
        const SizedBox(height: 12),
        Text(
          '— Lebar Kertas Standar VSC MP-58C (32 Karakter Monospace) —',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
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

  // Digital Rich Card View
  Widget _buildDigitalCardView() {
    final r = _currentReceipt;

    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.receiptNumber,
                      style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      Formatters.date(r.date),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: r.type == ReceiptType.returnUnit
                        ? const Color(0xFFDCFCE7)
                        : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: r.type == ReceiptType.returnUnit
                        ? Border.all(color: const Color(0xFF86EFAC))
                        : null,
                  ),
                  child: Text(
                    r.type.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: r.type == ReceiptType.returnUnit ? const Color(0xFF047857) : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (r.type == ReceiptType.returnUnit) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF047857)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unit Telah Diterima Kembali • Status: Tersedia di Gudang',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Customer & Booking
            _buildDetailRow('Nama Pelanggan', r.customerName),
            _buildDetailRow('No. WhatsApp', r.customerPhone),
            _buildDetailRow('Kode Booking', r.bookingCode, isMonospace: true),
            _buildDetailRow('Unit iPhone', r.unitName),
            if (r.assetCode != null) _buildDetailRow('Kode Aset Unit', r.assetCode!, isMonospace: true),
            if (r.serialNumber != null) _buildDetailRow('Serial Number', r.serialNumber!, isMonospace: true),
            _buildDetailRow('Durasi Sewa', r.rentalDuration),
            if (r.rentalDates != null) _buildDetailRow('Periode Sewa', r.rentalDates!),
            if (r.type == ReceiptType.returnUnit)
              _buildDetailRow('Status Jaminan', 'Telah Diserahkan Kembali', valueColor: const Color(0xFF047857)),
            const Divider(height: 24),

            // Financial Breakdown
            Text(
              r.type == ReceiptType.returnUnit ? 'Rincian Pengembalian Dana & Deposit' : 'Rincian Transaksi Finansial',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            const SizedBox(height: 8),
            if (r.type == ReceiptType.returnUnit) ...[
              _buildPriceRow('Biaya Sewa Pokok', r.rentFee),
              _buildPriceRow('Deposit Jaminan Awal', r.depositFee),
              if (r.finesFee > 0) _buildPriceRow('Pemotongan Denda/Kerusakan', -r.finesFee, isNegative: true, color: const Color(0xFFDC2626)),
              const Divider(height: 16),
              _buildPriceRow('Deposit Dikembalikan (Refund)', r.refundAmount, color: const Color(0xFF047857), isBold: true),
            ] else ...[
              _buildPriceRow('Biaya Sewa', r.rentFee),
              _buildPriceRow('Deposit Jaminan', r.depositFee),
              if (r.finesFee > 0) _buildPriceRow('Denda / Kerusakan', r.finesFee, isNegative: false),
              if (r.discountFee > 0) _buildPriceRow('Diskon', -r.discountFee, isNegative: true),
              const Divider(height: 16),
              _buildPriceRow('Total Transaksi', r.totalAmount, isBold: true),
              _buildPriceRow('Terbayar', r.paidAmount, color: const Color(0xFF047857), isBold: true),
              if (r.remainingAmount > 0)
                _buildPriceRow('Sisa Tagihan', r.remainingAmount, color: const Color(0xFFDC2626), isBold: true),
              if (r.refundAmount > 0)
                _buildPriceRow('Refund Deposit', r.refundAmount, color: const Color(0xFF7C3AED), isBold: true),
            ],
            const Divider(height: 20),

            // Method & Status Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Metode Bayar', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(r.paymentMethod, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Status Pembayaran', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      r.paymentStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: r.remainingAmount == 0 ? const Color(0xFF047857) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if ((r.paymentMethod.toLowerCase().contains('tunai') || r.paymentMethod.toLowerCase().contains('cash')) && r.cashGiven > 0) ...[
              const SizedBox(height: 10),
              _buildDetailRow('Uang Diterima', Formatters.formatCurrency(r.cashGiven)),
              _buildDetailRow('Kembalian', Formatters.formatCurrency(r.cashChange), valueColor: const Color(0xFF047857)),
            ],

            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  'Catatan: ${r.notes!}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],

            if (_formatSettings.showBarcode) ...[
              const Divider(height: 24),
              Text(
                'Barcode / QR Identifikasi Booking',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              _buildBarcodeVisual(r.bookingCode),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeVisual(String code) {
    final type = _formatSettings.barcodeType;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'code128' || type == 'both') ...[
              BarcodeWidget(
                barcode: Barcode.code128(),
                data: code,
                width: 220,
                height: 54,
                drawText: _formatSettings.showBarcodeHri,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (type == 'both') const SizedBox(height: 12),
            ],
            if (type == 'qrcode' || type == 'both') ...[
              BarcodeWidget(
                barcode: Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium),
                data: code,
                width: 110,
                height: 110,
              ),
              const SizedBox(height: 6),
              Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false, Color? valueColor}) {
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
              fontWeight: FontWeight.w600,
              color: valueColor,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, bool isNegative = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}${Formatters.currency(amount.abs())}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
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
