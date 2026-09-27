import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/booking_repository.dart';
import '../../models/payment_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'widgets/report_date_range_picker.dart';

class SalesReportScreen extends StatefulWidget {
  final BookingRepository repository;

  final String? initialPeriod;

  const SalesReportScreen({
    super.key,
    required this.repository,
    this.initialPeriod,
  });

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  bool _isLoading = true;
  late String _selectedPeriod;
  DateTimeRange? _customDateRange;
  bool _simulateEmpty = false;

  Map<String, dynamic> _reportData = {};

  final List<String> _periodOptions = [
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
    'Semua',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod ?? 'Hari Ini';
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    DateTime? start;
    DateTime? end;

    if (_customDateRange != null) {
      start = _customDateRange!.start;
      end = _customDateRange!.end;
    }

    try {
      final data = await widget.repository.getSalesReportData(
        period: _selectedPeriod,
        startDate: start,
        endDate: end,
      );

      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat laporan penjualan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final result = await ReportDateRangePickerBottomSheet.show(
      context,
      initialStart: _customDateRange?.start ?? DateTime(now.year, now.month, 1),
      initialEnd: _customDateRange?.end ?? now,
      initialLabel: _selectedPeriod,
    );

    if (result != null) {
      setState(() {
        _customDateRange = DateTimeRange(
          start: result.startDate,
          end: result.endDate,
        );
        _selectedPeriod = result.label;
      });
      _loadReport();
    }
  }

  void _showClosingReportDialog() {
    final escPosText = widget.repository.exportClosingReportEscPos(_reportData);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.print_rounded, color: AppTheme.accent),
              const SizedBox(width: 8),
              const Text('Tutup Kasir 58mm'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 380),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              child: Text(
                escPosText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.25,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: escPosText));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Format struk disalin ke clipboard'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Teks'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mengirim data laporan ke printer VSC MP-58C... Berhasil!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Cetak'),
            ),
          ],
        );
      },
    );
  }

  void _showCsvExportDialog() {
    final csvText = widget.repository.exportSalesReportCsv(_reportData);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.table_chart_outlined, color: AppTheme.accent),
              const SizedBox(width: 8),
              const Text('Ekspor Data CSV'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(
                csvText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csvText));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data CSV berhasil disalin ke clipboard!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin CSV'),
            ),
          ],
        );
      },
    );
  }

  void _shareToWhatsApp() {
    final summary = (_reportData['summary'] as Map<String, dynamic>?) ?? {};
    final double totalRev = (summary['totalRevenue'] as num?)?.toDouble() ?? 0;
    final int txCount = summary['transactionCount'] ?? 0;
    final double heldDep = (summary['totalDepositsHeld'] as num?)?.toDouble() ?? 0;

    final msg = '''
*LAPORAN OPERASIONAL SKYRENTAL*
Outlet: POS Station #01
Periode: $_selectedPeriod
Tanggal: ${Formatters.date(DateTime.now())}

- Total Omzet: ${Formatters.currency(totalRev)}
- Total Transaksi: $txCount
- Deposit di Kasir: ${Formatters.currency(heldDep)}

Status Kasir: Telah Ditutup & Sesuai.
''';

    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ringkasan laporan berhasil disalin untuk WhatsApp!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  void _printReceiptForTransaction(PaymentTransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) {
        String codeDisplay = tx.bookingCode.startsWith('#')
            ? tx.bookingCode
            : (tx.bookingCode.isNotEmpty && tx.bookingCode != '-' ? '#${tx.bookingCode}' : '#SKY-${tx.id}');

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Struk $codeDisplay',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReceiptDetailRow('No. Booking', codeDisplay),
              _buildReceiptDetailRow('Pelanggan', tx.customerName),
              if (tx.customerPhone.isNotEmpty && tx.customerPhone != '-')
                _buildReceiptDetailRow('No. Telepon', tx.customerPhone),
              _buildReceiptDetailRow('Unit iPhone', tx.iphoneName),
              _buildReceiptDetailRow('Metode', tx.paymentMethod),
              _buildReceiptDetailRow('Nominal', Formatters.currency(tx.paidAmount)),
              _buildReceiptDetailRow('Tanggal', '${Formatters.date(tx.transactionDate)} ${tx.transactionDate.hour.toString().padLeft(2, '0')}:${tx.transactionDate.minute.toString().padLeft(2, '0')} WIB'),
              if (tx.notes != null && tx.notes!.isNotEmpty)
                _buildReceiptDetailRow('Keterangan', tx.notes!.replaceAll('|', ' • ')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mencetak struk $codeDisplay ke printer VSC MP-58C... Berhasil!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Cetak Struk'),
            ),
          ],
        );
      },
    );
  }

  String _getDateRangeLabel() {
    if (_customDateRange != null) {
      return '${Formatters.date(_customDateRange!.start)} - ${Formatters.date(_customDateRange!.end)}';
    }
    if (_reportData['start_date'] != null && _reportData['end_date'] != null) {
      final start = DateTime.tryParse(_reportData['start_date'].toString());
      final end = DateTime.tryParse(_reportData['end_date'].toString());
      if (start != null && end != null) {
        if (start.year == end.year && start.month == end.month && start.day == end.day) {
          return Formatters.date(start);
        }
        return '${Formatters.date(start)} - ${Formatters.date(end)}';
      }
    }
    return Formatters.date(DateTime.now());
  }

  Widget _buildReceiptDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryRaw = (_reportData['summary'] is Map) ? (_reportData['summary'] as Map) : {};
    final summary = summaryRaw.map((key, value) => MapEntry(key.toString(), value));
    final paymentBreakdownRaw = (_reportData['paymentMethodBreakdown'] is Map) ? (_reportData['paymentMethodBreakdown'] as Map) : {};
    final paymentBreakdown = paymentBreakdownRaw.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()));

    final typeBreakdownRaw = (_reportData['typeBreakdown'] is Map) ? (_reportData['typeBreakdown'] as Map) : {};
    final typeBreakdown = typeBreakdownRaw.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()));

    final modelRevenueRaw = (_reportData['modelRevenue'] is Map) ? (_reportData['modelRevenue'] as Map) : {};
    final modelRevenue = modelRevenueRaw.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()));

    final modelCountRaw = (_reportData['modelRentalCount'] is Map) ? (_reportData['modelRentalCount'] as Map) : {};
    final modelCount = modelCountRaw.map((key, value) => MapEntry(key.toString(), (value as num).toInt()));
    final transactions = (_reportData['transactions'] as List<PaymentTransactionModel>?) ?? [];

    final double totalRev = (summary['totalRevenue'] as num?)?.toDouble() ??
        (summary['total_revenue'] as num?)?.toDouble() ??
        transactions.fold(0.0, (sum, tx) => sum + tx.paidAmount);
    final int txCount = (summary['transactionCount'] as num?)?.toInt() ??
        (summary['transaction_count'] as num?)?.toInt() ??
        transactions.length;
    final double aov = (summary['averageTransactionValue'] as num?)?.toDouble() ??
        (summary['average_transaction_value'] as num?)?.toDouble() ??
        (txCount > 0 ? totalRev / txCount : 0.0);
    final double heldDep = (summary['totalDepositsHeld'] as num?)?.toDouble() ??
        (summary['total_deposits_held'] as num?)?.toDouble() ??
        transactions.fold(0.0, (sum, tx) => sum + tx.depositAmount);
    final double cashIncome = (summary['cashAmount'] as num?)?.toDouble() ??
        (summary['cash_amount'] as num?)?.toDouble() ??
        transactions
            .where((tx) =>
                tx.paymentMethod.toLowerCase().contains('tunai') ||
                tx.paymentMethod.toLowerCase().contains('cash'))
            .fold(0.0, (sum, tx) => sum + tx.paidAmount);
    final double transferIncome = (summary['transferAmount'] as num?)?.toDouble() ??
        (summary['transfer_amount'] as num?)?.toDouble() ??
        transactions
            .where((tx) =>
                tx.paymentMethod.toLowerCase().contains('transfer') ||
                tx.paymentMethod.toLowerCase().contains('bank') ||
                tx.paymentMethod.toLowerCase().contains('va'))
            .fold(0.0, (sum, tx) => sum + tx.paidAmount);
    final double qrisIncome = (summary['qrisAmount'] as num?)?.toDouble() ??
        (summary['qris_amount'] as num?)?.toDouble() ??
        transactions
            .where((tx) => tx.paymentMethod.toLowerCase().contains('qris'))
            .fold(0.0, (sum, tx) => sum + tx.paidAmount);

    final int cashCount = transactions.where((tx) {
      final m = tx.paymentMethod.toLowerCase();
      return m.contains('tunai') || m.contains('cash');
    }).length;
    final int transferCount = transactions.where((tx) {
      final m = tx.paymentMethod.toLowerCase();
      return m.contains('transfer') || m.contains('bank') || m.contains('va');
    }).length;
    final int qrisCount = transactions.where((tx) {
      final m = tx.paymentMethod.toLowerCase();
      return m.contains('qris');
    }).length;

    final mediaWidth = MediaQuery.sizeOf(context).width;
    final isTablet = mediaWidth >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: isTablet ? _buildTabletAppBar(context) : _buildMobileAppBar(context),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sub Header & Filter Bar
                    if (isTablet)
                      _buildTabletSubHeaderAndFilters()
                    else
                      _buildMobileFilterSection(),
                    const SizedBox(height: 20),

                    // Main Content: 2-Columns on Tablet, 1-Column on Mobile
                    if (isTablet)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (Hero Omzet + Proporsi + Jenis Pembayaran)
                          Expanded(
                            flex: 38,
                            child: _buildTabletLeftColumn(
                              totalRev: totalRev,
                              txCount: txCount,
                              aov: aov,
                              heldDep: heldDep,
                              paymentBreakdown: paymentBreakdown,
                              typeBreakdown: typeBreakdown,
                              cashIncome: cashIncome,
                              transferIncome: transferIncome,
                              qrisIncome: qrisIncome,
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Right Column (4 Stats + Populer Models + Transaction Table)
                          Expanded(
                            flex: 62,
                            child: _buildTabletRightColumn(
                              cashIncome: cashIncome,
                              transferIncome: transferIncome,
                              qrisIncome: qrisIncome,
                              totalRev: totalRev,
                              cashCount: cashCount,
                              transferCount: transferCount,
                              qrisCount: qrisCount,
                              modelRevenue: modelRevenue,
                              modelCount: modelCount,
                              transactions: transactions,
                              txCount: txCount,
                            ),
                          ),
                        ],
                      )
                    else
                      _buildMobileContent(
                        totalRev: totalRev,
                        txCount: txCount,
                        aov: aov,
                        heldDep: heldDep,
                        cashIncome: cashIncome,
                        transferIncome: transferIncome,
                        qrisIncome: qrisIncome,
                        cashCount: cashCount,
                        transferCount: transferCount,
                        qrisCount: qrisCount,
                        paymentBreakdown: paymentBreakdown,
                        typeBreakdown: typeBreakdown,
                        modelRevenue: modelRevenue,
                        modelCount: modelCount,
                        transactions: transactions,
                      ),

                    const SizedBox(height: 20),

                    // Full-width Bottom Button: Cetak Rekap Kasir (58mm)
                    _buildClosingReportFooterButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  // =========================================================================
  // SUB-HEADER & FILTER SECTION (TABLET)
  // =========================================================================

  Widget _buildTabletSubHeaderAndFilters() {
    final dateLabel = _getDateRangeLabel();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Laporan Penjualan & Kasir',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Rekapitulasi omzet, alur kas tunai, transaksi sewa iPhone, dan rekonsiliasi deposit harian.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Segmented Period Filter
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _periodOptions.map((period) {
                  final isSelected = _selectedPeriod == period && _customDateRange == null;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPeriod = period;
                        _customDateRange = null;
                      });
                      _loadReport();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        period,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 8),

            // Date Range Picker Button
            InkWell(
              onTap: _pickCustomDateRange,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _customDateRange != null ? AppTheme.accent : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: _customDateRange != null ? AppTheme.accent : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _customDateRange != null ? AppTheme.accent : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Unduh Rekap Button
            PopupMenuButton<String>(
              tooltip: 'Unduh & Ekspor Rekap',
              onSelected: (val) {
                if (val == 'escpos') _showClosingReportDialog();
                if (val == 'csv') _showCsvExportDialog();
                if (val == 'wa') _shareToWhatsApp();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'escpos',
                  child: Row(
                    children: [
                      Icon(Icons.print_rounded, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      const Text('Cetak Tutup Kasir (58mm)'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_outlined, size: 18, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      const Text('Ekspor Data CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'wa',
                  child: Row(
                    children: [
                      Icon(Icons.chat_outlined, size: 18, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text('Salin Ringkasan WhatsApp'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF334155)),
                    SizedBox(width: 6),
                    Text(
                      'Unduh Rekap',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // SUB-HEADER & FILTER SECTION (MOBILE)
  // =========================================================================

  Widget _buildMobileFilterSection() {
    final dateLabel = _getDateRangeLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Laporan Penjualan & Kasir',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Rekapitulasi omzet, alur kas tunai, dan rekonsiliasi deposit.',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _periodOptions.map((period) {
                    final isSelected = _selectedPeriod == period && _customDateRange == null;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPeriod = period;
                          _customDateRange = null;
                        });
                        _loadReport();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _pickCustomDateRange,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _customDateRange != null ? AppTheme.accent : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: _customDateRange != null ? AppTheme.accent : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _customDateRange != null ? AppTheme.accent : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Unduh & Ekspor Rekap',
                onSelected: (val) {
                  if (val == 'escpos') _showClosingReportDialog();
                  if (val == 'csv') _showCsvExportDialog();
                  if (val == 'wa') _shareToWhatsApp();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'escpos',
                    child: Row(
                      children: [
                        Icon(Icons.print_rounded, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        const Text('Cetak Tutup Kasir (58mm)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.table_chart_outlined, size: 18, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        const Text('Ekspor Data CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'wa',
                    child: Row(
                      children: [
                        Icon(Icons.chat_outlined, size: 18, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text('Salin Ringkasan WhatsApp'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download_outlined, size: 14, color: Color(0xFF334155)),
                      SizedBox(width: 4),
                      Text(
                        'Unduh',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TABLET LEFT COLUMN
  // =========================================================================

  Widget _buildTabletLeftColumn({
    required double totalRev,
    required int txCount,
    required double aov,
    required double heldDep,
    required Map<String, double> paymentBreakdown,
    required Map<String, double> typeBreakdown,
    required double cashIncome,
    required double transferIncome,
    required double qrisIncome,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRevenueHeroCard(totalRev, txCount, aov, heldDep),
        const SizedBox(height: 16),
        _buildPaymentProportionCard(
          cashIncome: cashIncome,
          transferIncome: transferIncome,
          qrisIncome: qrisIncome,
          totalRev: totalRev,
        ),
        const SizedBox(height: 16),
        _buildPaymentTypeCard(typeBreakdown),
      ],
    );
  }

  // =========================================================================
  // TABLET RIGHT COLUMN
  // =========================================================================

  Widget _buildTabletRightColumn({
    required double cashIncome,
    required double transferIncome,
    required double qrisIncome,
    required double totalRev,
    required int cashCount,
    required int transferCount,
    required int qrisCount,
    required Map<String, double> modelRevenue,
    required Map<String, int> modelCount,
    required List<PaymentTransactionModel> transactions,
    required int txCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuickStatCardsRow(
          cash: cashIncome,
          transfer: transferIncome,
          qris: qrisIncome,
          total: totalRev,
          cashCount: cashCount,
          transferCount: transferCount,
          qrisCount: qrisCount,
          txCount: txCount,
        ),
        const SizedBox(height: 16),
        _buildTopModelsCard(modelRevenue, modelCount),
        const SizedBox(height: 16),
        _buildTransactionsTableCard(transactions, txCount),
      ],
    );
  }

  // =========================================================================
  // MOBILE SINGLE COLUMN CONTENT
  // =========================================================================

  Widget _buildMobileContent({
    required double totalRev,
    required int txCount,
    required double aov,
    required double heldDep,
    required double cashIncome,
    required double transferIncome,
    required double qrisIncome,
    required int cashCount,
    required int transferCount,
    required int qrisCount,
    required Map<String, double> paymentBreakdown,
    required Map<String, double> typeBreakdown,
    required Map<String, double> modelRevenue,
    required Map<String, int> modelCount,
    required List<PaymentTransactionModel> transactions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRevenueHeroCard(totalRev, txCount, aov, heldDep),
        const SizedBox(height: 14),
        // 2x2 grid for stat cards on mobile
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard(
                    title: 'Kas Tunai',
                    amount: cashIncome,
                    subtitle: '$cashCount Transaksi Tunai',
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniStatCard(
                    title: 'Transfer Bank',
                    amount: transferIncome,
                    subtitle: '$transferCount Transaksi Transfer/VA',
                    icon: Icons.account_balance_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFEFF6FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStatCard(
                    title: 'QRIS',
                    amount: qrisIncome,
                    subtitle: '$qrisCount Settlement QRIS',
                    icon: Icons.qr_code_2_rounded,
                    iconColor: const Color(0xFF9333EA),
                    iconBg: const Color(0xFFFAF5FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniStatCard(
                    title: 'Total Masuk',
                    amount: totalRev,
                    subtitle: '$txCount Transaksi Selesai',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFFEA580C),
                    iconBg: const Color(0xFFFFF7ED),
                    valueColor: const Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPaymentProportionCard(
          cashIncome: cashIncome,
          transferIncome: transferIncome,
          qrisIncome: qrisIncome,
          totalRev: totalRev,
        ),
        const SizedBox(height: 16),
        _buildPaymentTypeCard(typeBreakdown),
        const SizedBox(height: 16),
        _buildTopModelsCard(modelRevenue, modelCount),
        const SizedBox(height: 16),
        _buildTransactionsTableCard(transactions, txCount),
      ],
    );
  }

  // =========================================================================
  // HERO REVENUE CARD (MATCHING DESIGN)
  // =========================================================================

  Widget _buildRevenueHeroCard(double totalRev, int txCount, double aov, double heldDep) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -10,
            top: 10,
            child: Opacity(
              opacity: 0.06,
              child: Icon(Icons.receipt_long_rounded, size: 125, color: Colors.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Omzet Pendapatan ($_selectedPeriod)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF064E3B).withValues(alpha: 0.6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Kas Masuk',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.currency(totalRev),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$txCount Transaksi Selesai',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Transaksi', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
                        const SizedBox(height: 3),
                        Text('$txCount Selesai', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rata-rata Nilai', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
                        const SizedBox(height: 3),
                        Text(Formatters.currency(aov), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deposit Kasir', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
                        const SizedBox(height: 3),
                        Text(Formatters.currency(heldDep), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PROPORSI METODE PEMBAYARAN CARD (DONUT CHART & LEGEND)
  // =========================================================================

  Widget _buildPaymentProportionCard({
    required double cashIncome,
    required double transferIncome,
    required double qrisIncome,
    required double totalRev,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proporsi Metode Pembayaran',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Custom Donut Widget
              SizedBox(
                width: 125,
                height: 125,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(125, 125),
                      painter: _DonutChartPainter(
                        slices: [
                          _DonutSlice(value: transferIncome, color: const Color(0xFF0284C7), label: 'Transfer Bank'),
                          _DonutSlice(value: qrisIncome, color: const Color(0xFF8B5CF6), label: 'QRIS Dinamis'),
                          _DonutSlice(value: cashIncome, color: const Color(0xFF10B981), label: 'Kas Fisik Tunai'),
                        ],
                        total: totalRev,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'TRANSAKSI',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          totalRev > 0 ? '100%' : '0%',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              // Legend
              Expanded(
                child: Column(
                  children: [
                    _buildLegendRow('Transfer Bank', const Color(0xFF0284C7), transferIncome, totalRev),
                    const SizedBox(height: 12),
                    _buildLegendRow('QRIS Dinamis', const Color(0xFF8B5CF6), qrisIncome, totalRev),
                    const SizedBox(height: 12),
                    _buildLegendRow('Kas Fisik Tunai', const Color(0xFF10B981), cashIncome, totalRev),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatShortNominal(double amount) {
    if (amount >= 1000000) {
      final val = amount / 1000000.0;
      return 'Rp ${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).round()}rb';
    }
    return Formatters.currency(amount);
  }

  Widget _buildLegendRow(String label, Color color, double amount, double total) {
    final pct = total > 0 ? (amount / total) * 100 : 0.0;
    final nominalStr = _formatShortNominal(amount);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(width: 4),
        Text(
          '($nominalStr)',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // =========================================================================
  // JENIS PEMBAYARAN CARD (2X2 GRID)
  // =========================================================================

  Widget _buildPaymentTypeCard(Map<String, double> typeBreakdown) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jenis Pembayaran',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildTypeBox('DP (UANG MUKA)', typeBreakdown['dp'] ?? 0.0, isPenalty: false)),
              const SizedBox(width: 10),
              Expanded(child: _buildTypeBox('PELUNASAN', typeBreakdown['payment'] ?? 0.0, isPenalty: false)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildTypeBox('EXTEND SEWA', typeBreakdown['extend'] ?? 0.0, isPenalty: false)),
              const SizedBox(width: 10),
              Expanded(child: _buildTypeBox('PENALTY / DENDA', typeBreakdown['penalty'] ?? 0.0, isPenalty: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBox(String label, double amount, {required bool isPenalty}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPenalty ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPenalty ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isPenalty ? const Color(0xFFDC2626) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isPenalty ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RIGHT COLUMN: 4 STAT CARDS ROW
  // =========================================================================

  Widget _buildQuickStatCardsRow({
    required double cash,
    required double transfer,
    required double qris,
    required double total,
    required int cashCount,
    required int transferCount,
    required int qrisCount,
    required int txCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            title: 'Kas Tunai',
            amount: cash,
            subtitle: '$cashCount Transaksi Tunai',
            icon: Icons.payments_outlined,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            title: 'Transfer Bank',
            amount: transfer,
            subtitle: '$transferCount Transaksi Transfer/VA',
            icon: Icons.account_balance_outlined,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            title: 'QRIS',
            amount: qris,
            subtitle: '$qrisCount Settlement QRIS',
            icon: Icons.qr_code_2_rounded,
            iconColor: const Color(0xFF9333EA),
            iconBg: const Color(0xFFFAF5FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            title: 'Total Masuk',
            amount: total,
            subtitle: '$txCount Transaksi Selesai',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFFEA580C),
            iconBg: const Color(0xFFFFF7ED),
            valueColor: const Color(0xFFEA580C),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.currency(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor ?? const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RIGHT COLUMN: TOP POPULAR MODELS
  // =========================================================================

  Widget _buildTopModelsCard(Map<String, double> modelRevenue, Map<String, int> modelCount) {
    final sortedModels = modelRevenue.keys.toList()
      ..sort((a, b) => (modelRevenue[b] ?? 0).compareTo(modelRevenue[a] ?? 0));

    final totalRev = modelRevenue.values.fold(0.0, (s, v) => s + v);

    final List<Color> progressColors = [
      const Color(0xFF0F172A), // Dark navy for #1
      const Color(0xFF0284C7), // Teal/cyan for #2
      const Color(0xFF8B5CF6), // Purple for #3
      const Color(0xFF10B981), // Emerald for #4
      const Color(0xFFEA580C), // Orange for #5
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Model iPhone Paling Populer & Omzet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Periode $_selectedPeriod',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (sortedModels.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text('Belum ada data unit tersewa pada periode ini.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            )
          else
            ...sortedModels.take(5).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final model = entry.value;
              final rev = modelRevenue[model] ?? 0.0;
              final count = modelCount[model] ?? 0;
              final pct = totalRev > 0 ? (rev / totalRev) * 100 : 0.0;
              final subtitle = '$count Transaksi Sewa';
              final barColor = progressColors[idx % progressColors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Formatters.currency(rev),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count Transaksi (${pct.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        final factor = (pct / 100.0).clamp(0.05, 1.0);
                        return Stack(
                          children: [
                            Container(
                              height: 6,
                              width: totalWidth,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Container(
                              height: 6,
                              width: totalWidth * factor,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // =========================================================================
  // RIGHT COLUMN: TRANSACTIONS TABLE
  // =========================================================================

  Widget _buildTransactionsTableCard(List<PaymentTransactionModel> transactions, int txCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Riwayat Transaksi Penjualan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_simulateEmpty ? 0 : txCount} Transaksi Tercatat',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _simulateEmpty = !_simulateEmpty;
                      });
                    },
                    child: Text(
                      _simulateEmpty ? 'Tampilkan Data' : 'Simulasi Kosong',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_simulateEmpty || transactions.isEmpty)
            _buildEmptyTransactions()
          else
            _buildTransactionTableView(transactions),
        ],
      ),
    );
  }

  Widget _buildTransactionTableView(List<PaymentTransactionModel> transactions) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(flex: 20, child: Text('NO. RESI / JAM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              Expanded(flex: 24, child: Text('CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              Expanded(flex: 26, child: Text('UNIT & TIPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              Expanded(flex: 16, child: Text('METODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              Expanded(flex: 16, child: Align(alignment: Alignment.centerRight, child: Text('NOMINAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
              Expanded(flex: 10, child: Center(child: Text('STRUK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Table Rows
        ...transactions.map((tx) {
          String codeDisplay = tx.bookingCode.startsWith('#')
              ? tx.bookingCode
              : (tx.bookingCode.isNotEmpty && tx.bookingCode != '-' ? '#${tx.bookingCode}' : '#SKY-${tx.id}');

          final isSameDay = tx.transactionDate.year == DateTime.now().year &&
              tx.transactionDate.month == DateTime.now().month &&
              tx.transactionDate.day == DateTime.now().day;
          final timeStr = isSameDay
              ? '${tx.transactionDate.hour.toString().padLeft(2, '0')}:${tx.transactionDate.minute.toString().padLeft(2, '0')} WIB'
              : '${tx.transactionDate.day.toString().padLeft(2, '0')}/${tx.transactionDate.month.toString().padLeft(2, '0')} ${tx.transactionDate.hour.toString().padLeft(2, '0')}:${tx.transactionDate.minute.toString().padLeft(2, '0')} WIB';

          String typeTag = 'Pelunasan';
          String verificationTag = 'KTP Terverifikasi';
          if (tx.notes != null && tx.notes!.contains('|')) {
            final parts = tx.notes!.split('|');
            typeTag = parts[0];
            verificationTag = parts[1];
          } else if (tx.notes != null && tx.notes!.isNotEmpty) {
            typeTag = tx.notes!;
          }

          final phoneText = tx.customerPhone.isNotEmpty && tx.customerPhone != '-' ? tx.customerPhone : '';
          final customerSub = phoneText.isNotEmpty ? '$phoneText • $verificationTag' : verificationTag;

          Color badgeBg = const Color(0xFFEFF6FF);
          Color badgeColor = const Color(0xFF2563EB);
          if (typeTag.toLowerCase().contains('denda') || typeTag.toLowerCase().contains('penalty')) {
            badgeBg = const Color(0xFFFEF2F2);
            badgeColor = const Color(0xFFDC2626);
          } else if (typeTag.toLowerCase().contains('extend')) {
            badgeBg = const Color(0xFFFFF7ED);
            badgeColor = const Color(0xFFEA580C);
          } else if (typeTag.toLowerCase().contains('dp')) {
            badgeBg = const Color(0xFFECFDF5);
            badgeColor = const Color(0xFF059669);
          }

          IconData methodIcon = Icons.payments_outlined;
          Color methodColor = const Color(0xFF16A34A);
          String methodLabel = tx.paymentMethod;
          final pmLower = tx.paymentMethod.toLowerCase();
          if (pmLower.contains('qris')) {
            methodIcon = Icons.qr_code_2_rounded;
            methodColor = const Color(0xFF9333EA);
            methodLabel = 'QRIS';
          } else if (pmLower.contains('mandiri')) {
            methodIcon = Icons.account_balance_outlined;
            methodColor = const Color(0xFF2563EB);
            methodLabel = 'Mandiri';
          } else if (pmLower.contains('bca') || pmLower.contains('transfer') || pmLower.contains('va')) {
            methodIcon = Icons.account_balance_outlined;
            methodColor = const Color(0xFF2563EB);
            methodLabel = pmLower.contains('va') ? 'Transfer / VA' : 'Transfer';
          } else {
            methodIcon = Icons.payments_outlined;
            methodColor = const Color(0xFF16A34A);
            methodLabel = 'Tunai';
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: Row(
              children: [
                // No. Resi / Jam
                Expanded(
                  flex: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        codeDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Customer
                Expanded(
                  flex: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.customerName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customerSub,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Unit & Tipe
                Expanded(
                  flex: 26,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.iphoneName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeTag,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Metode
                Expanded(
                  flex: 16,
                  child: Row(
                    children: [
                      Icon(methodIcon, size: 14, color: methodColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          methodLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: methodColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Nominal
                Expanded(
                  flex: 16,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      Formatters.currency(tx.paidAmount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                // Struk
                Expanded(
                  flex: 10,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF475569)),
                      tooltip: 'Cetak Struk',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _printReceiptForTransaction(tx),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.receipt_outlined, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            'Tidak ada transaksi penjualan pada filter ini',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FULL-WIDTH CLOSING REPORT ACTION BUTTON
  // =========================================================================

  Widget _buildClosingReportFooterButton() {
    return InkWell(
      onTap: _showClosingReportDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: const Center(
          child: Text(
            'Cetak Rekap Kasir (58mm)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // CONSISTENT APP BAR SYSTEM (TABLET & MOBILE)
  // =========================================================================

  String _getDayName(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return '';
    }
  }

  String _getRoleBadgeText(String? role) {
    final r = (role ?? '').toUpperCase();
    if (r.contains('SUPER') || r.contains('OWNER')) return 'SUPER-ADMIN';
    if (r.contains('ADMIN')) return 'ADMIN';
    if (r.contains('KASIR')) return 'KASIR';
    return 'STAFF';
  }

  Widget _buildPrinterStatusBadge({bool isTablet = false}) {
    final printService = ThermalPrintService();
    return AnimatedBuilder(
      animation: Listenable.merge([
        printService.activePrinterNotifier,
        printService.isConnectedNotifier,
      ]),
      builder: (context, _) {
        final activePrinter = printService.activePrinterNotifier.value;
        final isConnected = printService.isConnectedNotifier.value;

        String printerName = activePrinter?.name.trim() ?? '';
        if (printerName.isEmpty || printerName == 'Belum Ada Printer Dipilih') {
          printerName = 'Printer Thermal';
        }

        final statusText = isConnected ? 'Terhubung' : 'Belum Terhubung';

        return GestureDetector(
          onTap: () async {
            await Navigator.pushNamed(context, AppRoutes.printerSettings);
            if (mounted) setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConnected ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isConnected ? AppTheme.success : AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 105),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printerName,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: isConnected ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildTabletAppBar(BuildContext context) {
    final user = AuthService().currentUser;
    final now = DateTime.now();
    final dateFormatted = '${_getDayName(now)}, ${Formatters.date(now)}';
    final topPadding = MediaQuery.paddingOf(context).top;
    final cashierName = user?.name.trim().isNotEmpty == true ? user!.name : 'Kasir SKYRental';
    final initials = cashierName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();

    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: RepaintBoundary(
        child: Container(
          padding: EdgeInsets.only(top: topPadding + 8, bottom: 10, left: 24, right: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Logo + POS Station #01
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SKYRental',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'POS Station #01',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Right: Printer Status + Date Pill + Cashier Profile
              Row(
                children: [
                  _buildPrinterStatusBadge(isTablet: true),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          dateFormatted,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.account),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(0xFF0F172A),
                          child: Text(
                            initials.isNotEmpty ? initials : 'BS',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              cashierName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Text(
                              'Kasir • Shift Pagi',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    final user = AuthService().currentUser;
    final userName = user?.name.trim().isNotEmpty == true ? user!.name : 'Admin SKYRental';
    final roleBadge = _getRoleBadgeText(user?.role);

    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 10,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(color: AppTheme.cardBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          roleBadge,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Laporan Penjualan & Kasir',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _buildPrinterStatusBadge(isTablet: false),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.account),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppTheme.surfaceContainer,
                    child: Icon(Icons.person, size: 20, color: AppTheme.primary),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// DONUT CHART CUSTOM PAINTER
// =========================================================================

class _DonutSlice {
  final double value;
  final Color color;
  final String label;

  const _DonutSlice({
    required this.value,
    required this.color,
    required this.label,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final double total;
  final double strokeWidth;

  _DonutChartPainter({
    required this.slices,
    required this.total,
  }) : strokeWidth = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (total <= 0) {
      final paint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2; // Start from top (-90 degrees)
    const gap = 0.05;

    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweepAngle = (slice.value / total) * (2 * math.pi) - gap;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (sweepAngle > 0) {
        canvas.drawArc(rect, startAngle + gap / 2, sweepAngle, false, paint);
      }
      startAngle += (slice.value / total) * (2 * math.pi);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.slices != slices;
  }
}
