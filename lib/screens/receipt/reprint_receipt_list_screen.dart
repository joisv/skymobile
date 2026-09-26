import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/booking_repository.dart';
import '../../models/receipt_model.dart';
import '../../routes/app_routes.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class ReprintReceiptListScreen extends StatefulWidget {
  final BookingRepository repository;
  final bool isEmbedded;

  const ReprintReceiptListScreen({
    super.key,
    required this.repository,
    this.isEmbedded = false,
  });

  @override
  State<ReprintReceiptListScreen> createState() => _ReprintReceiptListScreenState();
}

class _ReprintReceiptListScreenState extends State<ReprintReceiptListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ReceiptModel> _receipts = [];
  bool _isLoading = true;
  ReceiptType? _selectedTypeFilter;
  String _selectedDateFilter = 'Semua';
  DateTimeRange? _customRange;
  String? _printingReceiptNumber;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);

    DateTime? start;
    DateTime? end;
    final now = DateTime.now();

    if (_selectedDateFilter == 'Hari Ini') {
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedDateFilter == '7 Hari') {
      start = now.subtract(const Duration(days: 7));
      end = now;
    } else if (_selectedDateFilter == 'Kustom' && _customRange != null) {
      start = _customRange!.start;
      end = _customRange!.end;
    }

    final results = await widget.repository.getReceiptHistory(
      query: _searchController.text.trim(),
      typeFilter: _selectedTypeFilter,
      startDate: start,
      endDate: end,
    );

    if (!mounted) return;
    setState(() {
      _receipts = results;
      _isLoading = false;
    });
  }

  Future<void> _reprintReceipt(ReceiptModel r) async {
    setState(() => _printingReceiptNumber = r.receiptNumber);

    final result = await ThermalPrintService().printReceipt(r);

    if (!mounted) return;
    setState(() => _printingReceiptNumber = null);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Struk ${r.receiptNumber} (${r.bookingCode}) berhasil dicetak ulang via ${result.deviceName ?? 'printer'}!',
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

  void _copyReceiptText(ReceiptModel r) {
    final text = r.toEscPos58mm();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Teks format ESC/POS untuk ${r.receiptNumber} berhasil disalin!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      helpText: 'PILIH TANGGAL TRANSAKSI RESI',
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedDateFilter = 'Kustom';
      });
      _loadReceipts();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildEmbeddedLayout(context);
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Daftar Struk Cetak Ulang',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.cardBorder, height: 1),
        ),
        actions: [
          IconButton(
            tooltip: 'Pratinjau Resi Baru',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.receiptPreview);
            },
          ),
          IconButton(
            tooltip: 'Pengaturan & Uji Printer',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.printerSettings);
            },
          ),
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReceipts,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search & Filter Bar
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari No. Struk, Kode Booking, Pelanggan, Unit...',
                    hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadReceipts();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppTheme.background,
                  ),
                  onChanged: (val) {
                    setState(() {});
                    _loadReceipts();
                  },
                ),
                const SizedBox(height: 10),

                // Horizontal Type Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeFilterChip(null, 'Semua Resi'),
                      const SizedBox(width: 6),
                      _buildTypeFilterChip(ReceiptType.pickup, 'Pickup'),
                      const SizedBox(width: 6),
                      _buildTypeFilterChip(ReceiptType.returnUnit, 'Return & Refund'),
                      const SizedBox(width: 6),
                      _buildTypeFilterChip(ReceiptType.paymentSettlement, 'Pelunasan Kasir'),
                      const SizedBox(width: 6),
                      _buildTypeFilterChip(ReceiptType.depositRefund, 'Refund Deposit'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Horizontal Date Period Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDateChip('Semua'),
                      const SizedBox(width: 6),
                      _buildDateChip('Hari Ini'),
                      const SizedBox(width: 6),
                      _buildDateChip('7 Hari'),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.date_range_rounded, size: 14),
                        label: Text(
                          _selectedDateFilter == 'Kustom' && _customRange != null
                              ? '${Formatters.date(_customRange!.start)} - ${Formatters.date(_customRange!.end)}'
                              : 'Kustom Tanggal...',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: _selectedDateFilter == 'Kustom' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: _selectedDateFilter == 'Kustom'
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : Colors.white,
                        side: BorderSide(
                          color: _selectedDateFilter == 'Kustom' ? AppTheme.primary : AppTheme.cardBorder,
                        ),
                        onPressed: _pickDateRange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Summary & Hardware Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBorder,
              border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.print_outlined, size: 15, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${_receipts.length} Struk Tersedia untuk Dicetak Ulang',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VSC MP-58C READY',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                  ),
                ),
              ],
            ),
          ),

          // 3. Receipt List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _receipts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadReceipts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: _receipts.length,
                          itemBuilder: (context, index) {
                            return _buildReceiptCard(_receipts[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header matching tablet design
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Cetak & Cetak Ulang Struk',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Daftar resi transaksi serah-terima dan pembayaran kasir yang dapat dicetak ulang via printer thermal.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _loadReceipts,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Segarkan Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search & Filter Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari No. Struk, Kode Booking, Pelanggan, Unit...',
                  hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _loadReceipts();
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppTheme.background,
                ),
                onChanged: (val) {
                  setState(() {});
                  _loadReceipts();
                },
              ),
              const SizedBox(height: 10),

              // Type Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeFilterChip(null, 'Semua Resi'),
                    const SizedBox(width: 6),
                    _buildTypeFilterChip(ReceiptType.pickup, 'Pickup'),
                    const SizedBox(width: 6),
                    _buildTypeFilterChip(ReceiptType.returnUnit, 'Return & Refund'),
                    const SizedBox(width: 6),
                    _buildTypeFilterChip(ReceiptType.paymentSettlement, 'Pelunasan Kasir'),
                    const SizedBox(width: 6),
                    _buildTypeFilterChip(ReceiptType.depositRefund, 'Refund Deposit'),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Date Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDateChip('Semua'),
                    const SizedBox(width: 6),
                    _buildDateChip('Hari Ini'),
                    const SizedBox(width: 6),
                    _buildDateChip('7 Hari'),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 14),
                      label: Text(
                        _selectedDateFilter == 'Kustom' && _customRange != null
                            ? '${Formatters.date(_customRange!.start)} - ${Formatters.date(_customRange!.end)}'
                            : 'Kustom Tanggal...',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: _selectedDateFilter == 'Kustom' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      backgroundColor: _selectedDateFilter == 'Kustom'
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : Colors.white,
                      side: BorderSide(
                        color: _selectedDateFilter == 'Kustom' ? AppTheme.primary : AppTheme.cardBorder,
                      ),
                      onPressed: _pickDateRange,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Summary Ribbon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.print_outlined, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${_receipts.length} Struk Tersedia untuk Dicetak Ulang',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'THERMAL ESC/POS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Receipt List
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_receipts.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _receipts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildReceiptCard(_receipts[index]);
            },
          ),
      ],
    );
  }

  Widget _buildTypeFilterChip(ReceiptType? type, String label) {
    final isSelected = _selectedTypeFilter == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
      ),
      onSelected: (val) {
        setState(() => _selectedTypeFilter = val ? type : null);
        _loadReceipts();
      },
    );
  }

  Widget _buildDateChip(String label) {
    final isSelected = _selectedDateFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 10,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
      ),
      onSelected: (val) {
        setState(() {
          _selectedDateFilter = label;
          if (label != 'Kustom') _customRange = null;
        });
        _loadReceipts();
      },
    );
  }

  Widget _buildReceiptCard(ReceiptModel r) {
    final isPrinting = _printingReceiptNumber == r.receiptNumber;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Receipt Number & Type Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.receiptNumber,
                        style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildReceiptTypeBadge(r.type),
                  ],
                ),
                Text(
                  Formatters.date(r.date),
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Customer & Unit Details
            Text(
              '${r.customerName} • ${r.customerPhone}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Unit: ${r.unitName} (Kode: ${r.bookingCode})',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            Divider(height: 16, color: AppTheme.cardBorder),

            // Financial Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildValueItem('Total Transaksi', Formatters.currency(r.totalAmount)),
                _buildValueItem('Terbayar', Formatters.currency(r.paidAmount), color: const Color(0xFF047857)),
                _buildValueItem('Metode', r.paymentMethod),
                _buildValueItem(
                  'Status',
                  r.paymentStatus.toUpperCase(),
                  color: r.remainingAmount == 0 ? const Color(0xFF047857) : const Color(0xFFB45309),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions Row: Reprint, Full Preview, Copy Text
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Salin Teks ESC/POS',
                  icon: Icon(Icons.copy_rounded, size: 18, color: AppTheme.textSecondary),
                  onPressed: () => _copyReceiptText(r),
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.receiptPreview,
                      arguments: r,
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('Pratinjau', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isPrinting ? null : () => _reprintReceipt(r),
                  icon: isPrinting
                      ? const SizedBox(width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_rounded, size: 14),
                  label: Text(
                    isPrinting ? 'Mencetak...' : 'Cetak Ulang',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueItem(String label, String val, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptTypeBadge(ReceiptType type) {
    Color bg;
    Color text;

    switch (type) {
      case ReceiptType.pickup:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF047857);
        break;
      case ReceiptType.returnUnit:
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1D4ED8);
        break;
      case ReceiptType.paymentSettlement:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        break;
      case ReceiptType.depositRefund:
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF7C3AED);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.print_disabled_rounded, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Tidak Ditemukan Struk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Tidak ada data transaksi yang cocok dengan kata kunci atau filter yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedTypeFilter = null;
                  _selectedDateFilter = 'Semua';
                  _customRange = null;
                });
                _loadReceipts();
              },
              child: const Text('Reset Filter Pencarian'),
            ),
          ],
        ),
      ),
    );
  }
}
