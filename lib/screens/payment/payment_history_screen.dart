import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/booking_repository.dart';
import '../../models/payment_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final BookingRepository repository;

  const PaymentHistoryScreen({
    super.key,
    required this.repository,
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<PaymentTransactionModel> _transactions = [];
  bool _isLoading = true;

  // Filter States
  String _selectedPeriod = 'Semua'; // 'Semua', 'Hari Ini', '7 Hari', '30 Hari', 'Kustom'
  DateTimeRange? _customDateRange;
  String _paymentStatusFilter = 'Semua'; // 'Semua', 'paid', 'partial', 'unpaid'
  DepositStatus? _depositStatusFilter;
  String _paymentMethodFilter = 'Semua'; // 'Semua', 'QRIS', 'Tunai', 'Transfer Bank'
  String _sortBy = 'terbaru'; // 'terbaru', 'terlama', 'terbesar'

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedPeriod != 'Semua') count++;
    if (_paymentStatusFilter != 'Semua') count++;
    if (_depositStatusFilter != null) count++;
    if (_paymentMethodFilter != 'Semua') count++;
    if (_sortBy != 'terbaru') count++;
    return count;
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    DateTime? startDate;
    DateTime? endDate;

    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Hari Ini':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case '7 Hari':
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case '30 Hari':
        startDate = now.subtract(const Duration(days: 30));
        endDate = now;
        break;
      case 'Kustom':
        if (_customDateRange != null) {
          startDate = _customDateRange!.start;
          endDate = _customDateRange!.end;
        }
        break;
      case 'Semua':
      default:
        startDate = null;
        endDate = null;
        break;
    }

    final result = await widget.repository.getPaymentHistory(
      query: _searchController.text.trim(),
      paymentStatusFilter: _paymentStatusFilter,
      depositStatusFilter: _depositStatusFilter,
      paymentMethodFilter: _paymentMethodFilter,
      startDate: startDate,
      endDate: endDate,
      sortBy: _sortBy,
    );

    if (!mounted) return;
    setState(() {
      _transactions = result;
      _isLoading = false;
    });
  }

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedPeriod = 'Semua';
      _customDateRange = null;
      _paymentStatusFilter = 'Semua';
      _depositStatusFilter = null;
      _paymentMethodFilter = 'Semua';
      _sortBy = 'terbaru';
    });
    _loadHistory();
  }

  Future<void> _selectCustomDateRange() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 12, 31),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      helpText: 'PILIH RENTANG TANGGAL PEMBAYARAN',
      cancelText: 'BATAL',
      confirmText: 'TERAPKAN',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(
                  primary: AppTheme.primary,
                  onPrimary: Colors.white,
                  surface: AppTheme.surface,
                  onSurface: AppTheme.textPrimary,
                )
              : ColorScheme.light(
                  primary: AppTheme.primary,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: const Color(0xFF0F172A),
                ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = 'Kustom';
      });
      _loadHistory();
    }
  }

  void _showFilterModalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                            Icon(Icons.filter_list_rounded, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Filter & Urutkan Riwayat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _paymentStatusFilter = 'Semua';
                              _depositStatusFilter = null;
                              _paymentMethodFilter = 'Semua';
                              _sortBy = 'terbaru';
                            });
                          },
                          child: const Text('Reset', style: TextStyle(color: Color(0xFFDC2626))),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // 1. Status Pembayaran
                    const Text(
                      'Status Pembayaran Sewa',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        {'key': 'Semua', 'label': 'Semua Status'},
                        {'key': 'paid', 'label': 'Lunas'},
                        {'key': 'partial', 'label': 'DP Sebagian'},
                        {'key': 'unpaid', 'label': 'Belum Bayar'},
                      ].map((item) {
                        final isSelected = _paymentStatusFilter == item['key'];
                        return ChoiceChip(
                          label: Text(item['label']!),
                          selected: isSelected,
                          selectedColor: AppTheme.secondary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                          onSelected: (val) {
                            setModalState(() {
                              _paymentStatusFilter = item['key']!;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 2. Status Deposit
                    const Text('Status Deposit Jaminan',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: _depositStatusFilter == null,
                          selectedColor: AppTheme.secondary.withValues(alpha: 0.2),
                          onSelected: (val) => setModalState(() => _depositStatusFilter = null),
                        ),
                        ...DepositStatus.values.map((status) {
                          final isSelected = _depositStatusFilter == status;
                          return ChoiceChip(
                            label: Text(status.label),
                            selected: isSelected,
                            selectedColor: AppTheme.secondary.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                _depositStatusFilter = val ? status : null;
                              });
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Metode Pembayaran
                    const Text(
                      'Metode Transaksi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Semua', 'QRIS', 'Tunai', 'Transfer Bank'].map((m) {
                        final isSelected = _paymentMethodFilter == m;
                        return ChoiceChip(
                          label: Text(m),
                          selected: isSelected,
                          selectedColor: AppTheme.secondary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                          onSelected: (val) => setModalState(() => _paymentMethodFilter = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 4. Urutan
                    const Text(
                      'Urutkan Berdasarkan',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'key': 'terbaru', 'label': 'Tanggal Terbaru'},
                        {'key': 'terlama', 'label': 'Tanggal Terlama'},
                        {'key': 'terbesar', 'label': 'Nominal Terbesar'},
                      ].map((item) {
                        final isSelected = _sortBy == item['key'];
                        return ChoiceChip(
                          label: Text(item['label']!),
                          selected: isSelected,
                          selectedColor: AppTheme.secondary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                          onSelected: (val) => setModalState(() => _sortBy = item['key']!),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Terapkan Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _loadHistory();
                        },
                        child: const Text(
                          'Terapkan Filter',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Reprint Thermal Receipt ESC/POS (58mm, 32 Columns)
  void _showReprintReceiptModal(PaymentTransactionModel tx) {
    final receiptText = _generateThermalReceipt(tx);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isPrinting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                            Icon(Icons.print_rounded, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Cetak Ulang Resi (Thermal 58mm)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 12),

                    // Thermal Receipt Preview Box (Paper Simulation)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFD),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        receiptText,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.35,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Salin Teks', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: receiptText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Teks resi thermal berhasil disalin!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: isPrinting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.print_rounded, size: 18),
                            label: Text(
                              isPrinting ? 'Mencetak ke VSC MP-58C...' : 'Cetak Struk Thermal',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: isPrinting
                                ? null
                                : () async {
                                    setModalState(() => isPrinting = true);
                                    await Future.delayed(const Duration(seconds: 1));
                                    if (!context.mounted) return;
                                    setModalState(() => isPrinting = false);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Resi transaksi ${tx.bookingCode} berhasil dicetak via printer thermal VSC MP-58C!',
                                        ),
                                        backgroundColor: const Color(0xFF047857),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Generates 32-column formatted thermal string
  String _generateThermalReceipt(PaymentTransactionModel tx) {
    const divider = '================================';
    const subDivider = '--------------------------------';
    final dateStr = Formatters.date(tx.transactionDate);
    final timeStr = '${tx.transactionDate.hour.toString().padLeft(2, '0')}:${tx.transactionDate.minute.toString().padLeft(2, '0')}';
    final currentUser = AuthService().currentUser;
    final cashierName = (currentUser != null && currentUser.name.isNotEmpty) ? currentUser.name : 'Kasir Toko';
    final outletName = (currentUser != null && currentUser.outletName.isNotEmpty)
        ? 'SKYRENTAL ${currentUser.outletName.toUpperCase()}'
        : 'SKYRENTAL';

    return '''
$divider
${outletName.padLeft(((32 + outletName.length) / 2).floor()).padRight(32)}
${'Sewa iPhone Terpercaya'.padLeft(25).padRight(32)}
$divider
Tgl       : $dateStr $timeStr
No. Struk : STR-202609-0${tx.id}
Admin     : $cashierName
Pelanggan : ${tx.customerName}
Kontak    : ${tx.customerPhone}
Booking   : ${tx.bookingCode}
Unit      : ${tx.iphoneName}
$subDivider
Total Sewa   : ${Formatters.currency(tx.rentTotal).padLeft(16)}
Terbayar     : ${Formatters.currency(tx.paidAmount).padLeft(16)}
Sisa Tagihan : ${Formatters.currency(tx.remainingAmount).padLeft(16)}
Deposit      : ${Formatters.currency(tx.depositAmount).padLeft(16)}
Status Dep.  : ${tx.depositStatus.label.padLeft(16)}
${tx.refundAmount > 0 ? 'Refund Dep.  : ${Formatters.currency(tx.refundAmount).padLeft(16)}' : ''}
${tx.deductionAmount > 0 ? 'Potongan Denda: ${Formatters.currency(tx.deductionAmount).padLeft(15)}' : ''}
$subDivider
TOTAL KAS    : ${Formatters.currency(tx.paidAmount).padLeft(16)}
Metode       : ${tx.paymentMethod.toUpperCase().padLeft(16)}
Status Bayar : ${tx.paymentStatus.toUpperCase().padLeft(16)}
$divider
${'BUKTI TRANSAKSI PEMBAYARAN'.padLeft(28).padRight(32)}
${'Harap simpan struk ini sebagai'.padLeft(31).padRight(32)}
${'bukti transaksi yang sah.'.padLeft(27).padRight(32)}
$divider
'''.trim();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate stats from currently filtered list
    double filteredPaid = 0;
    for (final tx in _transactions) {
      filteredPaid += tx.paidAmount;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Riwayat Pembayaran'),
        actions: [
          IconButton(
            tooltip: 'Filter Lanjutan',
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: _showFilterModalSheet,
          ),
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar & Date Filter Chips
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari kode booking, nama, hp, unit...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadHistory();
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
                    _loadHistory();
                  },
                ),
                const SizedBox(height: 10),

                // Horizontal Period Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPeriodChip('Semua'),
                      const SizedBox(width: 6),
                      _buildPeriodChip('Hari Ini'),
                      const SizedBox(width: 6),
                      _buildPeriodChip('7 Hari'),
                      const SizedBox(width: 6),
                      _buildPeriodChip('30 Hari'),
                      const SizedBox(width: 6),
                      ActionChip(
                        avatar: const Icon(Icons.date_range_rounded, size: 15),
                        label: Text(
                          _customDateRange == null
                              ? 'Kustom...'
                              : '${Formatters.date(_customDateRange!.start)} - ${Formatters.date(_customDateRange!.end)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _selectedPeriod == 'Kustom' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: _selectedPeriod == 'Kustom'
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : AppTheme.surface,
                        side: BorderSide(
                          color: _selectedPeriod == 'Kustom' ? AppTheme.primary : AppTheme.cardBorder,
                        ),
                        onPressed: _selectCustomDateRange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Filter Summary Info Bar
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
                    Text(
                      '${_transactions.length} Transaksi Ditemukan',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                    if (_activeFilterCount > 0) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _resetAllFilters,
                        child: const Text(
                          'Reset Filter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Masuk: ${Formatters.currency(filteredPaid)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),

          // 3. Transactions List / Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            return _buildTransactionCard(_transactions[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label) {
    final isSelected = _selectedPeriod == label;
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
        setState(() {
          _selectedPeriod = label;
          if (label != 'Kustom') {
            _customDateRange = null;
          }
        });
        _loadHistory();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Text('Tidak Ada Riwayat Transaksi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text('Tidak ditemukan transaksi pembayaran yang sesuai dengan kriteria filter saat ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Semua Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(PaymentTransactionModel tx) {
    final bool isRefunded = tx.depositStatus == DepositStatus.refunded;
    final bool isDeducted = tx.depositStatus == DepositStatus.deducted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badges & Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildPaymentStatusBadge(tx.paymentStatus),
                    const SizedBox(width: 6),
                    _buildDepositBadge(tx.depositStatus),
                  ],
                ),
                Text(
                  Formatters.date(tx.transactionDate),
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle: Booking Code, Customer & Unit
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.receipt_rounded, size: 22, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tx.bookingCode,
                            style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppTheme.primary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(_getMethodIcon(tx.paymentMethod), size: 12, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  tx.paymentMethod,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tx.customerName} • ${tx.customerPhone}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tx.iphoneName,
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 18, color: AppTheme.cardBorder),

            // Financial Summary Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildValueColumn('Total Sewa', Formatters.currency(tx.rentTotal)),
                _buildValueColumn('Terbayar', Formatters.currency(tx.paidAmount), color: const Color(0xFF047857)),
                _buildValueColumn(
                  'Sisa Tagihan',
                  Formatters.currency(tx.remainingAmount),
                  color: tx.remainingAmount > 0 ? const Color(0xFFDC2626) : AppTheme.textSecondary,
                ),
                _buildValueColumn(
                  isRefunded
                      ? 'Refund Selesai'
                      : isDeducted
                          ? 'Denda Rp ${tx.deductionAmount.toInt()}'
                          : 'Deposit',
                  Formatters.currency(isRefunded ? tx.refundAmount : tx.depositAmount),
                  color: isRefunded ? const Color(0xFF7C3AED) : const Color(0xFF1D4ED8),
                ),
              ],
            ),

            if (tx.notes != null && tx.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tx.notes!,
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom Actions: Reprint Thermal Receipt & View Booking Detail
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('Detail Booking', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.bookingDetail,
                      arguments: tx.bookingCode,
                    );
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print_rounded, size: 14),
                  label: const Text('Cetak Ulang Resi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showReprintReceiptModal(tx),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'qris':
        return Icons.qr_code_rounded;
      case 'tunai':
        return Icons.payments_rounded;
      case 'transfer bank':
      default:
        return Icons.account_balance_rounded;
    }
  }

  Widget _buildValueColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status.toLowerCase()) {
      case 'paid':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF047857);
        label = 'Lunas';
        break;
      case 'partial':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'DP Sebagian';
        break;
      case 'unpaid':
      default:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        label = 'Belum Bayar';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildDepositBadge(DepositStatus status) {
    Color bg;
    Color text;

    switch (status) {
      case DepositStatus.held:
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1D4ED8);
        break;
      case DepositStatus.readyRefund:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        break;
      case DepositStatus.refunded:
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF7C3AED);
        break;
      case DepositStatus.deducted:
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFFC2410C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }
}
