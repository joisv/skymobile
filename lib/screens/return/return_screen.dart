import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class ReturnScreen extends StatefulWidget {
  final BookingRepository repository;

  const ReturnScreen({
    super.key,
    required this.repository,
  });

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<BookingModel> _rentals = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  // Filter state
  String _selectedStatusFilter = 'Semua'; // 'Semua', 'Hari Ini', 'Terlambat', 'Mendatang'
  String _selectedModelFilter = 'Semua'; // 'Semua', 'iPhone 15', 'iPhone 14', 'iPhone 13'
  String _selectedJaminanFilter = 'Semua'; // 'Semua', 'KTP', 'Motor', 'Ijazah', 'Keluarga'
  String _sortBy = 'urgent'; // 'urgent', 'newest', 'customerAsc', 'depositDesc'

  final DateTime _mockCurrentTime = DateTime(2026, 9, 9, 14, 0);

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStatusFilter != 'Semua') count++;
    if (_selectedModelFilter != 'Semua') count++;
    if (_selectedJaminanFilter != 'Semua') count++;
    if (_sortBy != 'urgent') count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0 || _searchController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    bool? isOverdue;
    bool? isDueToday;
    bool? isUpcoming;

    if (_selectedStatusFilter == 'Terlambat') {
      isOverdue = true;
    } else if (_selectedStatusFilter == 'Hari Ini') {
      isDueToday = true;
    } else if (_selectedStatusFilter == 'Mendatang') {
      isUpcoming = true;
    }

    final list = await widget.repository.getActiveRentals(
      query: _searchController.text.trim(),
      isOverdueOnly: isOverdue,
      isDueTodayOnly: isDueToday,
      isUpcomingOnly: isUpcoming,
      modelFilter: _selectedModelFilter,
      jaminanFilter: _selectedJaminanFilter,
      sortBy: _sortBy,
    );

    final summaryData = widget.repository.getReturnSummary();

    if (!mounted) return;
    setState(() {
      _rentals = list;
      _summary = summaryData;
      _isLoading = false;
    });
  }

  void _onStatusFilterChanged(String filter) {
    if (_selectedStatusFilter == filter) return;
    setState(() => _selectedStatusFilter = filter);
    _loadData();
  }

  void _onSearchChanged(String val) {
    _loadData();
  }

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatusFilter = 'Semua';
      _selectedModelFilter = 'Semua';
      _selectedJaminanFilter = 'Semua';
      _sortBy = 'urgent';
    });
    _loadData();
  }

  void _openFilterBottomSheet() {
    String tempStatus = _selectedStatusFilter;
    String tempModel = _selectedModelFilter;
    String tempJaminan = _selectedJaminanFilter;
    String tempSort = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Penyewaan Aktif',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempStatus = 'Semua';
                          tempModel = 'Semua';
                          tempJaminan = 'Semua';
                          tempSort = 'urgent';
                        });
                      },
                      child: const Text('Reset', style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // 1. Status Waktu Jatuh Tempo
                Text('Status Tenggat Waktu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ['Semua', 'Hari Ini', 'Terlambat', 'Mendatang'].map((st) {
                    final sel = tempStatus == st;
                    return ChoiceChip(
                      label: Text(st, style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppTheme.textPrimary)),
                      selected: sel,
                      selectedColor: AppTheme.primary,
                      onSelected: (_) => setModalState(() => tempStatus = st),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 2. Seri iPhone
                Text('Model / Seri iPhone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ['Semua', 'iPhone 15', 'iPhone 14', 'iPhone 13'].map((md) {
                    final sel = tempModel == md;
                    return ChoiceChip(
                      label: Text(md, style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppTheme.textPrimary)),
                      selected: sel,
                      selectedColor: AppTheme.primary,
                      onSelected: (_) => setModalState(() => tempModel = md),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 3. Jenis Jaminan
                Text('Jaminan Fisik Ditahan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: ['Semua', 'KTP', 'Motor', 'Ijazah', 'Keluarga'].map((jm) {
                    final sel = tempJaminan == jm;
                    return ChoiceChip(
                      label: Text(jm, style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppTheme.textPrimary)),
                      selected: sel,
                      selectedColor: AppTheme.primary,
                      onSelected: (_) => setModalState(() => tempJaminan = jm),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 4. Urutkan Berdasarkan
                Text('Urutkan Berdasarkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tempSort,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'urgent', child: Text('Tenggat Terdekat (Urgent Terlebih Dahulu)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'newest', child: Text('Mulai Sewa Terbaru', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'customerAsc', child: Text('Nama Pelanggan (A-Z)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'depositDesc', child: Text('Nilai Deposit Tertinggi', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => tempSort = val);
                  },
                ),
                const SizedBox(height: 20),

                // Tombol Terapkan
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedStatusFilter = tempStatus;
                      _selectedModelFilter = tempModel;
                      _selectedJaminanFilter = tempJaminan;
                      _sortBy = tempSort;
                    });
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToInspection(BookingModel booking) {
    Navigator.pushNamed(
      context,
      AppRoutes.returnSummary,
      arguments: booking,
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Pengembalian iPhone'),
        actions: [
          IconButton(
            tooltip: 'Pindai Barcode / QR Pengembalian',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final scanned = await Navigator.pushNamed(context, AppRoutes.qrScanner);
              if (scanned is String && scanned.isNotEmpty) {
                _searchController.text = scanned;
                _onSearchChanged(scanned);
              } else {
                _loadData();
              }
            },
          ),
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // 1. KPI Summary Ribbon
            _buildSummaryHeader(),

            // 2. Search & Filter Bar
            _buildSearchAndFilters(),

            // 3. Active Filters Chips Row
            if (_hasActiveFilters) _buildActiveFilterTags(),

            // 4. Main Rental List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _rentals.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _rentals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildReturnCard(_rentals[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final totalActive = _summary['totalActiveRentals'] ?? 0;
    final totalDueToday = _summary['totalDueToday'] ?? 0;
    final totalOverdue = _summary['totalOverdue'] ?? 0;
    final totalDeposit = (_summary['totalActiveDeposit'] as num?)?.toDouble() ?? 0.0;

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Sedang Disewa',
                  value: '$totalActive Unit',
                  color: AppTheme.primary,
                  icon: Icons.phone_iphone_rounded,
                  badgeText: 'Aktif',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'Jatuh Tempo Hari Ini',
                  value: '$totalDueToday Unit',
                  color: const Color(0xFFD97706),
                  icon: Icons.access_time_rounded,
                  badgeText: 'Perlu Kembali',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Terlambat (Overdue)',
                  value: '$totalOverdue Unit',
                  color: const Color(0xFFDC2626),
                  icon: Icons.warning_amber_rounded,
                  badgeText: totalOverdue > 0 ? 'Denda Aktif' : 'Aman',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: 'Deposit Ditahan',
                  value: Formatters.currency(totalDeposit),
                  color: const Color(0xFF047857),
                  icon: Icons.account_balance_wallet_rounded,
                  badgeText: 'Jaminan Pelanggan',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: color),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          // Search Field dengan tombol shortcut QR Scanner
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari kode sewa, nama, HP, aset, serial...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.cardBorder,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Modal Filter Lebih Lanjut
              Stack(
                children: [
                  IconButton.filledTonal(
                    onPressed: _openFilterBottomSheet,
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: _activeFilterCount > 0
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.cardBorder,
                    ),
                  ),
                  if (_activeFilterCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Status Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('Semua'),
                const SizedBox(width: 8),
                _buildStatusChip('Hari Ini'),
                const SizedBox(width: 8),
                _buildStatusChip('Terlambat'),
                const SizedBox(width: 8),
                _buildStatusChip('Mendatang'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final isSelected = _selectedStatusFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onStatusFilterChanged(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.cardBorder,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  Widget _buildActiveFilterTags() {
    return Container(
      color: AppTheme.cardBorder,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            'Ditemukan ${_rentals.length} unit aktif',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _resetAllFilters,
            icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
            label: const Text('Reset Filter', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(BookingModel booking) {
    final isOverdue = booking.endDate.isBefore(_mockCurrentTime);
    final isDueToday = booking.endDate.year == _mockCurrentTime.year &&
        booking.endDate.month == _mockCurrentTime.month &&
        booking.endDate.day == _mockCurrentTime.day;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isOverdue) {
      statusColor = const Color(0xFFDC2626);
      final daysLate = _mockCurrentTime.difference(booking.endDate).inDays + 1;
      statusLabel = 'Terlambat $daysLate Hari';
      statusIcon = Icons.error_outline_rounded;
    } else if (isDueToday) {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Jatuh Tempo Hari Ini';
      statusIcon = Icons.access_time_filled_rounded;
    } else {
      statusColor = const Color(0xFF0284C7);
      final daysLeft = booking.endDate.difference(_mockCurrentTime).inDays;
      statusLabel = 'Tersisa $daysLeft Hari';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFCA5A5) : AppTheme.cardBorder,
          width: isOverdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card: Kode Booking & Status Waktu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(
                  color: isOverdue ? const Color(0xFFFECACA) : AppTheme.cardBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      booking.bookingCode,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body Card: Detail Unit, Pelanggan, Jaminan, dan Deposit
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Unit iPhone
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.phone_iphone_rounded, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${booking.iphone.name} (${booking.iphone.storage})',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${booking.iphone.color} • Aset: ${booking.iphone.assetCode}',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          Text(
                            'S/N: ${booking.iphone.serialNumber} • BH: ${booking.iphone.batteryHealth}%',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Info Pelanggan & Jaminan
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Penyewa', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            booking.customerName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            booking.customerPhone,
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jaminan Ditahan', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            booking.jaminanType,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Deposit: ${Formatters.currency(booking.deposit)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Waktu Pengembalian
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Batas Kembali:',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      Text(
                        Formatters.dateTime(booking.endDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOverdue ? const Color(0xFFDC2626) : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Card Actions: Tombol Proses Pengembalian
          Container(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.bookingDetail, arguments: booking);
                  },
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: const Text('Detail', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToInspection(booking),
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                    label: const Text('Proses Pengembalian',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOverdue ? const Color(0xFFDC2626) : AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 56,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tidak Ada Unit Ditemukan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters
                  ? 'Tidak ada penyewaan aktif yang cocok dengan kriteria pencarian dan filter.'
                  : 'Semua unit rental saat ini dalam status aman atau belum ada penyewaan aktif.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Semua Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
