import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import 'widgets/booking_card.dart';
import 'widgets/booking_card_skeleton.dart';
import 'widgets/booking_filter_bottom_sheet.dart';
import 'widgets/booking_filter_chips.dart';
import 'widgets/booking_search_bar.dart';

class BookingListScreen extends StatefulWidget {
  final BookingRepository repository;

  const BookingListScreen({
    super.key,
    required this.repository,
  });

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  BookingFilterParams _filterParams = const BookingFilterParams();
  late final TabController _tabController;
  String _selectedReturnFilter = 'Belum Kembali';
  bool _isLoading = false;
  List<BookingModel> _bookings = [];
  Map<BookingStatus, int> _counts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<BookingModel> get _returnBookings {
    return _bookings.where((b) {
      if (_selectedReturnFilter == 'Terlambat') {
        return b.isCurrentlyLate;
      } else if (_selectedReturnFilter == 'Hari Ini') {
        final now = DateTime.now();
        return b.endDate.year == now.year && b.endDate.month == now.month && b.endDate.day == now.day;
      } else if (_selectedReturnFilter == 'Selesai') {
        return b.status == BookingStatus.returned;
      } else if (_selectedReturnFilter == 'Belum Kembali') {
        return b.canReturn;
      }
      return b.canReturn || b.status == BookingStatus.returned;
    }).toList();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await widget.repository.getBookings(
      query: _searchController.text,
      statusFilter: _filterParams.statusFilter,
      paymentFilter: _filterParams.paymentFilter,
      pickupTypeFilter: _filterParams.pickupTypeFilter,
      onlyToday: _filterParams.onlyToday,
      sortBy: _filterParams.sortBy,
    );
    final counts = widget.repository.getStatusCounts();

    if (mounted) {
      setState(() {
        _bookings = results;
        _counts = counts;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _loadData();
  }

  void _onClearSearch() {
    _searchController.clear();
    _loadData();
  }

  void _onStatusSelected(BookingStatus? status) {
    setState(() {
      _filterParams = _filterParams.copyWith(
        statusFilter: () => status,
      );
    });
    _loadData();
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingFilterBottomSheet(
        initialParams: _filterParams,
        onApply: (newParams) {
          setState(() => _filterParams = newParams);
          _loadData();
        },
      ),
    );
  }

  void _openBookingDetail(BookingModel booking) {
    Navigator.pushNamed(
      context,
      AppRoutes.bookingDetail,
      arguments: booking,
    ).then((_) => _loadData());
  }

  void _openQrScanner() {
    Navigator.pushNamed(
      context,
      AppRoutes.qrScanner,
    ).then((_) => _loadData());
  }

  void _openCreateBooking() {
    Navigator.pushNamed(
      context,
      AppRoutes.createBooking,
    ).then((_) => _loadData());
  }

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _filterParams = const BookingFilterParams();
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _filterParams.hasActiveFilter || _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SKYRental Admin'),
            Text(
              'Outlet Utama • Operasional',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Buat Booking Baru',
            onPressed: _openCreateBooking,
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_rounded),
            tooltip: 'Dashboard Operasional',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.dashboard).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.phone_iphone_rounded),
            tooltip: 'Status Unit iPhone',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.unitStatus).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.assignment_return_outlined),
            tooltip: 'Pengembalian iPhone',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.returnScreen).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: 'Pembayaran & Deposit',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.paymentDeposit);
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Pratinjau Resi Thermal',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.receiptPreview);
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Pindai QR',
            onPressed: _openQrScanner,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              text: 'Daftar Booking (${_bookings.length})',
            ),
            Tab(
              icon: const Icon(Icons.assignment_return_rounded, size: 18),
              text: 'Daftar Pengembalian (${_returnBookings.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          BookingSearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onClear: _onClearSearch,
            onScanPressed: _openQrScanner,
            onFilterPressed: _openFilterBottomSheet,
            activeFilterCount: _filterParams.activeFilterCount,
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Daftar Booking
                _buildBookingTabContent(hasActiveFilter),

                // Tab 2: Daftar Pengembalian
                _buildReturnTabContent(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_scan_qr',
            onPressed: _openQrScanner,
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.textPrimary,
            tooltip: 'Pindai QR Booking',
            child: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab_create_booking',
            onPressed: _openCreateBooking,
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(
              '+ Booking Baru',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingTabContent(bool hasActiveFilter) {
    return Column(
      children: [
        // Status Filter Chips
        BookingFilterChips(
          selectedStatus: _filterParams.statusFilter,
          onStatusSelected: _onStatusSelected,
          counts: _counts,
        ),
        const SizedBox(height: 8),

        // Active Filter Indicator Strip (if any active filter)
        if (hasActiveFilter)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list_rounded, size: 14, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Menampilkan ${_bookings.length} hasil terfilter',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _resetAllFilters,
                  child: Text('Hapus Filter',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 6),

        // Booking List or Loading / Empty States
        Expanded(
          child: _isLoading
              ? const BookingListSkeleton()
              : _bookings.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 4),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          return BookingCard(
                            booking: booking,
                            onTap: () => _openBookingDetail(booking),
                            onPickupAction: booking.canPickup
                                ? () => _openBookingDetail(booking)
                                : null,
                            onReturnAction: booking.canReturn
                                ? () => _openBookingDetail(booking)
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildReturnTabContent() {
    final returnList = _returnBookings;
    final filters = ['Belum Kembali', 'Terlambat', 'Hari Ini', 'Selesai', 'Semua'];

    return Column(
      children: [
        // Return filter chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final f = filters[index];
              final isSelected = _selectedReturnFilter == f;
              return FilterChip(
                label: Text(f),
                selected: isSelected,
                selectedColor: AppTheme.accent.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.accent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                ),
                onSelected: (_) {
                  setState(() => _selectedReturnFilter = f);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: _isLoading
              ? const BookingListSkeleton()
              : returnList.isEmpty
                  ? _buildEmptyReturnState()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 4),
                        itemCount: returnList.length,
                        itemBuilder: (context, index) {
                          final booking = returnList[index];
                          return BookingCard(
                            booking: booking,
                            onTap: () => _openBookingDetail(booking),
                            onReturnAction: booking.canReturn
                                ? () => _openBookingDetail(booking)
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyReturnState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_return_outlined,
                size: 48,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada unit dalam daftar pengembalian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Filter "$_selectedReturnFilter" tidak memiliki data pengembalian.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text('Tidak ada booking ditemukan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text('Coba sesuaikan kata kunci pencarian atau filter status yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _resetAllFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Reset Pencarian & Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
