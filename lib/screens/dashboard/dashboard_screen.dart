import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../data/mock_booking_data.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../payment/payment_deposit_screen.dart';
import '../../widgets/app_header.dart';
import 'widgets/dashboard_skeleton.dart';

class DashboardScreen extends StatefulWidget {
  final BookingRepository repository;

  const DashboardScreen({
    super.key,
    required this.repository,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  List<IphoneModel> _readyInventory = [];
  int _pendingTransferCount = 0;
  String _selectedQueueFilter = 'semua'; // 'semua', 'pickup', 'return'
  String _selectedSort = 'created_at'; // 'created_at', 'start_booking_date', 'end_booking_date', 'status', 'price'
  final TextEditingController _queueSearchController = TextEditingController();
  String _queueSearchQuery = '';

  @override
  void initState() {
    super.initState();
    AuthService().addListener(_onAuthChanged);
    _initPrinter();
    _loadDashboard();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initPrinter() async {
    try {
      await ThermalPrintService().ensurePrimaryConnected();
    } catch (_) {}
  }

  @override
  void dispose() {
    _queueSearchController.dispose();
    AuthService().removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.repository.getOperationalDashboardData();
      List<IphoneModel> readyUnits = [];
      try {
        readyUnits = await widget.repository.getAllInventoryUnits(statusFilter: 'tersedia');
      } catch (_) {
        readyUnits = MockBookingData.inventory.where((u) => u.status == 'tersedia').toList();
      }
      if (readyUnits.isEmpty) {
        readyUnits = MockBookingData.inventory.where((u) => u.status == 'tersedia').toList();
      }

      int pendingTransferCount = 0;
      try {
        final transfers = await widget.repository.getIphoneTransfers(
          status: 'in_transit',
          affiliateId: AuthService().isAffiliateAdmin ? AuthService().affiliateId : null,
          type: AuthService().isAffiliateAdmin ? 'inbound' : null,
          forceRefresh: true,
        );
        pendingTransferCount = transfers.where((t) => t.isInTransit).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _readyInventory = readyUnits;
          _pendingTransferCount = pendingTransferCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _readyInventory = MockBookingData.inventory.where((u) => u.status == 'tersedia').toList();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteBooking(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 22),
            SizedBox(width: 8),
            Text('Hapus Booking?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus booking #${booking.bookingCode} atas nama ${booking.customerName}?\n\nData booking akan dihapus dari antrean dan database.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.repository.deleteBooking(booking.bookingCode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Booking #${booking.bookingCode} berhasil dihapus.'
                : 'Gagal menghapus booking #${booking.bookingCode}.'),
            backgroundColor: success ? const Color(0xFF047857) : AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadDashboard();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = (_dashboardData['metrics'] as Map<String, dynamic>?) ?? {};
    final actionItems = (_dashboardData['actionItems'] as List<BookingModel>?) ?? [];
    final recentBookings = (_dashboardData['recentBookings'] as List<BookingModel>?) ?? [];

    // Ambil seluruh antrean booking dari database / API repository
    final rawAllQueue = (_dashboardData['allQueue'] as List<BookingModel>?) ??
        [...actionItems, ...recentBookings];

    final allQueue = <BookingModel>[];
    final seen = <String>{};
    for (final b in rawAllQueue) {
      if (seen.add(b.bookingCode)) {
        allQueue.add(b);
      }
    }

    final pickupItems = allQueue
        .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending)
        .toList();
    final returnItems = allQueue
        .where((b) => b.status == BookingStatus.rented || b.status == BookingStatus.returned)
        .toList();

    List<BookingModel> baseItems;
    if (_selectedQueueFilter == 'pickup') {
      baseItems = pickupItems;
    } else if (_selectedQueueFilter == 'return') {
      baseItems = returnItems;
    } else {
      baseItems = allQueue;
    }

    List<BookingModel> displayItems;
    if (_queueSearchQuery.trim().isNotEmpty) {
      final q = _queueSearchQuery.trim().toLowerCase();
      displayItems = baseItems.where((b) {
        return b.customerName.toLowerCase().contains(q) ||
            b.bookingCode.toLowerCase().contains(q) ||
            b.customerPhone.toLowerCase().contains(q) ||
            b.iphone.modelName.toLowerCase().contains(q);
      }).toList();
    } else {
      displayItems = List<BookingModel>.from(baseItems);
    }

    _sortQueueItems(displayItems);

    // Batasi jumlah data yang ditampilkan pada antrean transaksi (maksimal 50 data terbaru)
    if (displayItems.length > 50) {
      displayItems = displayItems.take(50).toList();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 900 && constraints.maxWidth > constraints.maxHeight;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppHeader(isTablet: isTablet),
          body: RefreshIndicator(
            onRefresh: _loadDashboard,
            color: AppTheme.accent,
            child: _isLoading
                ? DashboardSkeleton(isTablet: isTablet)
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: isTablet ? 40 : 100,
                      left: isTablet ? 24 : 0,
                      right: isTablet ? 24 : 0,
                      top: isTablet ? 20 : 0,
                    ),
                    child: isTablet
                        ? _buildTabletLayout(metrics, allQueue, pickupItems, returnItems, displayItems)
                        : _buildMobileLayout(metrics, allQueue, pickupItems, returnItems, displayItems),
                  ),
          ),
          floatingActionButton: isTablet ? null : _buildStitchFloatingActionButton(),
        );
      },
    );
  }

  void _sortQueueItems(List<BookingModel> items) {
    switch (_selectedSort) {
      case 'start_booking_date':
        items.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
      case 'end_booking_date':
        items.sort((a, b) => a.endDate.compareTo(b.endDate));
        break;
      case 'price':
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'status':
        const order = {
          BookingStatus.pending: 1,
          BookingStatus.confirmed: 2,
          BookingStatus.rented: 3,
          BookingStatus.returned: 4,
          BookingStatus.cancelled: 5,
        };
        items.sort((a, b) => (order[a.status] ?? 99).compareTo(order[b.status] ?? 99));
        break;
      case 'created_at':
      default:
        items.sort((a, b) => b.id.compareTo(a.id));
        break;
    }
  }

  Widget _buildOfflineBanner() {
    final host = ApiService()
        .baseUrl
        .replaceFirst('http://', '')
        .replaceFirst('https://', '')
        .replaceFirst('/api/v1', '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFB45309), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode Offline: Belum terhubung ke backend ($host).',
              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(
            onPressed: _loadDashboard,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Muat Ulang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    Map<String, dynamic> metrics,
    List<BookingModel> allQueue,
    List<BookingModel> pickupItems,
    List<BookingModel> returnItems,
    List<BookingModel> displayItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dashboardData['isOnline'] == false)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _buildOfflineBanner(),
          ),

        // 2. Metrik Operasional (2x2 Grid)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _buildOperationalMetricsSection(metrics),
        ),

        // Quick Action khusus Affiliate Admin: Transfer iPhone Masuk & Terima iPhone
        if (AuthService().isAffiliateAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: InkWell(
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.iphoneTransfer).then((_) => _loadDashboard()),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _pendingTransferCount > 0 ? const Color(0xFFF0FDF4) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _pendingTransferCount > 0 ? const Color(0xFF86EFAC) : Colors.grey.shade200,
                    width: _pendingTransferCount > 0 ? 1.5 : 1,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _pendingTransferCount > 0
                            ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                            : Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _pendingTransferCount > 0 ? Icons.local_shipping_rounded : Icons.swap_horiz_rounded,
                        color: _pendingTransferCount > 0 ? const Color(0xFF16A34A) : Colors.indigo,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Transfer iPhone Masuk',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              if (_pendingTransferCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_pendingTransferCount',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _pendingTransferCount > 0
                                ? '$_pendingTransferCount unit dalam perjalanan, klik untuk terima'
                                : 'Riwayat mutasi & penerimaan iPhone cabang',
                            style: TextStyle(
                              fontSize: 11,
                              color: _pendingTransferCount > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                              fontWeight: _pendingTransferCount > 0 ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _pendingTransferCount > 0 ? const Color(0xFF16A34A) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _pendingTransferCount > 0 ? 'Terima Unit' : 'Buka',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _pendingTransferCount > 0 ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: _pendingTransferCount > 0 ? Colors.white : const Color(0xFF334155),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Quick Action: Manajemen User & Role Akses (Hanya untuk Super Admin & Admin)
        if (AuthService().isSuperAdmin || (AuthService().isAdmin && !AuthService().isAffiliateAdmin))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: InkWell(
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.rolesPermissions),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFFEA580C), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manajemen Pengguna & Role',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            'Kelola user, tambah akun & assign hak akses',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Buka', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          SizedBox(width: 3),
                          Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 3. Antrean Transaksi Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _buildTransactionQueueSection(allQueue, pickupItems, returnItems, displayItems),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(
    Map<String, dynamic> metrics,
    List<BookingModel> allQueue,
    List<BookingModel> pickupItems,
    List<BookingModel> returnItems,
    List<BookingModel> displayItems,
  ) {
    final totalUnits = (metrics['totalUnits'] as num?)?.toInt() ?? 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dashboardData['isOnline'] == false)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildOfflineBanner(),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (~70% width)
            Expanded(
              flex: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabletMetricsSection(metrics, allQueue, pickupItems, returnItems),
                  const SizedBox(height: 20),
                  _buildTabletQueueSection(allQueue, pickupItems, returnItems, displayItems),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Right Column (~30% width / Compact Sidebar Menu)
            Expanded(
              flex: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTabletQuickActionsCard(),
                  const SizedBox(height: 12),
                  _buildTabletPrinterCard(),
                  const SizedBox(height: 12),
                  _buildTabletReadyStockCard(totalUnits),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildTabletMetricsSection(
    Map<String, dynamic> metrics,
    List<BookingModel> allQueue,
    List<BookingModel> pickupItems,
    List<BookingModel> returnItems,
  ) {
    final totalUnits = (metrics['totalUnits'] as num?)?.toInt() ?? 30;
    final availableUnits = (metrics['availableUnits'] as num?)?.toInt() ?? 12;
    final rentedUnits = (metrics['rentedUnits'] as num?)?.toInt() ?? (totalUnits - availableUnits);
    final utilizationFraction = totalUnits > 0 ? (rentedUnits / totalUnits).clamp(0.0, 1.0) : 0.0;
    final utilizationPercent = (utilizationFraction * 100).toInt();

    final bookingToday = (metrics['bookingToday'] as num?)?.toInt() ??
        (metrics['todayPickups'] as num?)?.toInt() ?? pickupItems.length;
    final waitingPickups = pickupItems.where((b) => b.status == BookingStatus.pending).length;
    final completedPickups = (bookingToday - waitingPickups).clamp(0, bookingToday);

    final unreturnedUnits = (metrics['unreturnedUnits'] as num?)?.toInt() ??
        (metrics['todayReturns'] as num?)?.toInt() ?? returnItems.length;
    final overdueReturns = (metrics['overdueReturns'] as num?)?.toInt() ??
        returnItems.where((b) => b.status == BookingStatus.rented && b.endDate.isBefore(DateTime.now())).length;
    final onTimeReturns = (unreturnedUnits - overdueReturns).clamp(0, unreturnedUnits);

    final revenueToday = (metrics['revenueToday'] as num?)?.toDouble() ??
        (metrics['totalRevenue'] as num?)?.toDouble() ?? 1850000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Metrik Operasional Hari Ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: _loadDashboard,
              child: Row(
                children: [
                  Icon(Icons.autorenew_rounded, size: 15, color: AppTheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    'Perbarui',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row of 4 cards
        Row(
          children: [
            // Card 1: Pickup Hari Ini
            Expanded(
              child: _buildTabletMetricCard(
                title: 'Pickup Hari Ini',
                icon: Icons.inbox_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          text: '$bookingToday ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Booking',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildTinyPill('$completedPickups Selesai', const Color(0xFFEFF6FF), const Color(0xFF2563EB), isBold: true),
                        _buildTinyPill('$waitingPickups Menunggu', AppTheme.surfaceContainerLow, AppTheme.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Card 2: Return Hari Ini
            Expanded(
              child: _buildTabletMetricCard(
                title: 'Return Hari Ini',
                icon: Icons.outbox_rounded,
                iconColor: const Color(0xFFEF4444),
                iconBg: const Color(0xFFFEE2E2),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          text: '$unreturnedUnits ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Unit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildTinyPill('$onTimeReturns On Time', const Color(0xFFEFF6FF), const Color(0xFF2563EB), isBold: true),
                        if (overdueReturns > 0)
                          _buildTinyPill('$overdueReturns Telat', const Color(0xFFFEE2E2), const Color(0xFFDC2626), isBold: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Card 3: Unit Disewa (with progress bar)
            Expanded(
              child: _buildTabletMetricCard(
                title: 'Unit Disewa',
                icon: Icons.pie_chart_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          text: '$rentedUnits ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: '/ $totalUnits Unit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: utilizationFraction,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: const Color(0xFF2563EB),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$utilizationPercent% Utilitas Toko',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Card 4: Omzet Hari Ini
            Expanded(
              child: _buildTabletMetricCard(
                title: 'Omzet Hari Ini',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF047857),
                iconBg: const Color(0xFFDCFCE7),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Formatters.formatCurrency(revenueToday),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '100% QRIS/Trf',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSuccessContainer,
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
      ],
    );
  }

  Widget _buildTabletMetricCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _buildQueueSearchBar({bool isTablet = false}) {
    return Container(
      height: isTablet ? 38 : 40,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: TextField(
        controller: _queueSearchController,
        onChanged: (val) {
          setState(() {
            _queueSearchQuery = val;
          });
        },
        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari customer, kode booking, nomor WA, unit iPhone...',
          hintStyle: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
          ),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
          suffixIcon: _queueSearchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _queueSearchController.clear();
                    setState(() {
                      _queueSearchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTabletQueueSection(
    List<BookingModel> allQueue,
    List<BookingModel> pickupItems,
    List<BookingModel> returnItems,
    List<BookingModel> displayItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Antrean Transaksi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _queueSearchQuery.isNotEmpty
                        ? '${displayItems.length} Ditemukan'
                        : (allQueue.length > 50 ? '50 Terbaru dari ${allQueue.length}' : '${allQueue.length} Antrean'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQueueTabButton('semua', 'Semua'),
                    const SizedBox(width: 6),
                    _buildQueueTabButton('pickup', 'Pickup (${pickupItems.length})'),
                    const SizedBox(width: 6),
                    _buildQueueTabButton('return', 'Return (${returnItems.length})'),
                    const SizedBox(width: 8),
                    _buildSortDropdown(),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildQueueSearchBar(isTablet: true),
        const SizedBox(height: 12),

        if (displayItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _queueSearchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.inbox_rounded,
                    color: AppTheme.secondary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _queueSearchQuery.isNotEmpty
                      ? 'Tidak Ditemukan'
                      : 'Tidak Ada Antrean Transaksi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _queueSearchQuery.isNotEmpty
                      ? 'Tidak ada transaksi yang cocok dengan "$_queueSearchQuery".'
                      : 'Belum ada transaksi di antrean. Buat booking baru untuk memulai transaksi kasir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                if (_queueSearchQuery.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      _queueSearchController.clear();
                      setState(() {
                        _queueSearchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.clear_rounded, size: 14),
                    label: const Text('Reset Pencarian', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ],
            ),
          )
        else
          ...displayItems.map((b) => _buildTabletQueueCard(b)),
      ],
    );
  }

  Widget _buildDeviceThumbnail(
    IphoneModel iphone, {
    double size = 44,
    double radius = 12,
    bool isOverdue = false,
  }) {
    final photo = iphone.resolvedPhotoUrl;
    final fallbackBg = isOverdue
        ? const Color(0xFFFEE2E2)
        : AppTheme.surfaceContainerLow;
    final fallbackColor = isOverdue
        ? const Color(0xFFDC2626)
        : AppTheme.secondary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFCA5A5) : AppTheme.cardBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: (photo != null && photo.isNotEmpty)
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    isOverdue ? Icons.schedule_rounded : Icons.phone_iphone_rounded,
                    color: fallbackColor,
                    size: size * 0.5,
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: size * 0.35,
                      height: size * 0.35,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              )
            : Center(
                child: Icon(
                  isOverdue ? Icons.schedule_rounded : Icons.phone_iphone_rounded,
                  color: fallbackColor,
                  size: size * 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildTabletQueueCard(BookingModel b) {
    final isPickup = b.status == BookingStatus.confirmed || b.status == BookingStatus.pending;
    final isRented = b.status == BookingStatus.rented;
    final now = DateTime.now();
    final isOverdue = isRented && b.endDate.isBefore(now);
    final overdueHours = isOverdue ? now.difference(b.endDate).inHours.clamp(1, 999) : 0;

    final date = isPickup ? b.startDate : b.endDate;
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final timeStr = isToday
        ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} WIB'
        : '${Formatters.date(date)} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} WIB';

    if (isOverdue) {
      // Overdue Return Card
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, AppRoutes.bookingDetail, arguments: b).then((_) => _loadDashboard()),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RETURN • OVERDUE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                            const SizedBox(width: 4),
                            Text(
                              '+$overdueHours Jam Terlambat',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '+ Denda Rp 50.000',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Device info
                Row(
                  children: [
                    _buildDeviceThumbnail(b.iphone, size: 44, radius: 12, isOverdue: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                b.customerName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '#${b.bookingCode}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${b.iphone.modelName} • ${b.iphone.color} • SN: ${b.iphone.serialNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 12.5, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Dibuat oleh: ${b.userName ?? "Kasir"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFFECACA)),
                const SizedBox(height: 10),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Tarif Sewa: ${Formatters.formatCurrency(b.price)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          const Flexible(
                            child: Text(
                              'Denda terlambat belum lunas',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFDC2626),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _confirmDeleteBooking(b),
                          icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.error),
                          tooltip: 'Hapus Booking',
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.paymentDeposit,
                              arguments: {
                                'booking': b,
                                'initialPaymentType': PaymentTypeOption.penalty,
                                'initialAmount': b.estimatedLateFee > 0 ? b.estimatedLateFee : 50000.0,
                                'isReturnFlow': true,
                              },
                            ).then((_) => _loadDashboard());
                          },
                          icon: const SizedBox.shrink(),
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Proses Telat & Denda',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.receipt_long_rounded, size: 15, color: Colors.white),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isPickup) {
      // Normal Return Card
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, AppRoutes.bookingDetail, arguments: b).then((_) => _loadDashboard()),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RETURN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Menunggu Pengembalian',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Device info
                Row(
                  children: [
                    _buildDeviceThumbnail(b.iphone, size: 44, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                b.customerName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '#${b.bookingCode}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${b.iphone.modelName} • ${b.iphone.color} • SN: ${b.iphone.serialNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 12.5, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Dibuat oleh: ${b.userName ?? "Kasir"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: AppTheme.cardBorder),
                const SizedBox(height: 10),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Tarif Biaya Sewa: ${Formatters.formatCurrency(b.price)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _confirmDeleteBooking(b),
                          icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.error),
                          tooltip: 'Hapus Booking',
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.bookingDetail,
                              arguments: b,
                            ).then((_) => _loadDashboard());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0F2FE),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Inspeksi & Refund',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF0369A1)),
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
        ),
      );
    }

    // Pickup Card
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.bookingDetail, arguments: b).then((_) => _loadDashboard()),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PICKUP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildPaymentStatusBadge(b.paymentStatus),
                ],
              ),
              const SizedBox(height: 12),

              // Device info
              Row(
                children: [
                  _buildDeviceThumbnail(b.iphone, size: 44, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              b.customerName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '#${b.bookingCode}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${b.iphone.modelName} • ${b.iphone.color} • SN: ${b.iphone.serialNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 12.5, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Dibuat oleh: ${b.userName ?? "Kasir"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.cardBorder),
              const SizedBox(height: 10),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Tarif Biaya Sewa: ${Formatters.formatCurrency(b.price)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _confirmDeleteBooking(b),
                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.error),
                        tooltip: 'Hapus Booking',
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aksi Cepat Kasir',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Wide Black Button: + Buat Booking Baru
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.createBooking).then((_) => _loadDashboard());
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Buat Booking Baru',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Row with 2 buttons: Scan QR Booking & Cek Stok Unit
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.qrScanner).then((_) => _loadDashboard());
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 14, color: Color(0xFF0369A1)),
                    label: const Text(
                      'Scan QR Booking',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0F2FE),
                      foregroundColor: const Color(0xFF0369A1),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.unitStatus).then((_) => _loadDashboard());
                    },
                    icon: Icon(Icons.inventory_2_outlined, size: 14, color: AppTheme.textPrimary),
                    label: Text(
                      'Cek Stok Unit',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: AppTheme.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (AuthService().isAffiliateAdmin || AuthService().isSuperAdmin) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.iphoneTransfer).then((_) => _loadDashboard());
                },
                icon: Icon(
                  _pendingTransferCount > 0 ? Icons.local_shipping_rounded : Icons.swap_horiz_rounded,
                  size: 14,
                  color: _pendingTransferCount > 0 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                ),
                label: Text(
                  _pendingTransferCount > 0
                      ? 'Terima Transfer iPhone ($_pendingTransferCount)'
                      : 'Transfer iPhone',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _pendingTransferCount > 0 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pendingTransferCount > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  foregroundColor: _pendingTransferCount > 0 ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabletPrinterCard() {
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
          printerName = 'VSC MP-58C';
        }

        final statusText = isConnected ? 'Terhubung' : 'Belum Terhubung';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.print_outlined, size: 16, color: AppTheme.textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Printer Kasir',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isConnected ? AppTheme.success : AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isConnected ? const Color(0xFF047857) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Device Detail Box
              InkWell(
                onTap: () async {
                  await Navigator.pushNamed(context, AppRoutes.printerSettings);
                  if (mounted) setState(() {});
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.bluetooth_connected_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              printerName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Bluetooth Thermal 58mm',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.battery_charging_full_rounded,
                                size: 13,
                                color: isConnected ? const Color(0xFF047857) : AppTheme.textSecondary,
                              ),
                              Text(
                                isConnected ? ' 100%' : '',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isConnected ? const Color(0xFF047857) : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isConnected ? const Color(0xFF047857) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Button: Tes Cetak Nota Struk
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final result = await ThermalPrintService().printTestPage();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.isSuccess
                                ? 'Tes cetak nota berhasil dikirim ke printer.'
                                : 'Gagal tes cetak: ${result.message}'),
                            backgroundColor: result.isSuccess ? const Color(0xFF047857) : AppTheme.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal tes cetak: $e'),
                            backgroundColor: AppTheme.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.receipt_outlined, size: 15, color: Color(0xFF2563EB)),
                  label: const Text(
                    'Tes Cetak Nota Struk',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    foregroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletReadyStockCard(int totalUnits) {
    // Group inventory units by modelName
    final Map<String, List<IphoneModel>> grouped = {};
    for (final unit in _readyInventory) {
      grouped.putIfAbsent(unit.modelName, () => []).add(unit);
    }

    final entries = grouped.entries.toList();
    entries.sort((a, b) => b.value.length.compareTo(a.value.length));
    const int maxStockDisplay = 3;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Stok Siap Sewa',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_readyInventory.length} Unit Tersedia',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'Tidak ada unit siap sewa saat ini',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            )
          else ...[
            ...entries.take(maxStockDisplay).map((entry) {
              final modelName = entry.key;
              final units = entry.value;
              final colors = units.map((u) => u.color).toSet().join(' & ');
              final storage = units.first.storage;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    _buildDeviceThumbnail(units.first, size: 30, radius: 6),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modelName,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$storage • $colors',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${units.length} Unit',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (entries.length > maxStockDisplay)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Center(
                  child: Text(
                    '+ ${entries.length - maxStockDisplay} model iPhone lainnya',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),

          // Button: Buka Katalog Lengkap
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.unitStatus).then((_) => _loadDashboard());
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.cardBorder),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Buka Katalog Lengkap ($totalUnits Unit)',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }







  /// Operational Metrics Section (2x2 Grid disesuaikan dengan database & booking-page.blade.php)
  Widget _buildOperationalMetricsSection(Map<String, dynamic> metrics) {
    // 1. iPhone Tersedia (Database: unit tanpa booking status 'confirmed')
    final availableUnits = (metrics['availableUnits'] as num?)?.toInt() ?? 12;
    final totalUnits = (metrics['totalUnits'] as num?)?.toInt() ?? 30;

    // 2. iPhone Belum Kembali (Database: booking status 'confirmed' dengan end_booking_date <= today)
    final unreturnedUnits = (metrics['unreturnedUnits'] as num?)?.toInt() ??
        (metrics['todayReturns'] as num?)?.toInt() ?? 3;
    final overdueReturns = (metrics['overdueReturns'] as num?)?.toInt() ?? 0;

    // 3. Booking Hari Ini (Database: booking dibuat hari ini)
    final bookingToday = (metrics['bookingToday'] as num?)?.toInt() ??
        (metrics['todayPickups'] as num?)?.toInt() ?? 5;

    // 4. Pendapatan Hari Ini (Database: total pembayaran BookingPayment paid_at hari ini)
    final revenueToday = (metrics['revenueToday'] as num?)?.toDouble() ??
        (metrics['totalRevenue'] as num?)?.toDouble() ?? 1850000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Metrik Operasional',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: _loadDashboard,
              child: Row(
                children: [
                  Icon(Icons.autorenew_rounded, size: 14, color: AppTheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    'Live Sync',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Grid 2x2
        Row(
          children: [
            // Card 1: iPhone Tersedia (x-mary-stat: iPhone Tersedia)
            Expanded(
              child: _buildMetricCard(
                title: 'iPhone Tersedia',
                icon: Icons.phone_iphone_rounded,
                iconColor: const Color(0xFF047857), // green-600
                iconBg: const Color(0xFFDCFCE7),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: '$availableUnits ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Unit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildTinyPill('Siap Disewa', const Color(0xFFDCFCE7), const Color(0xFF047857), isBold: true),
                        _buildTinyPill('$totalUnits Total', AppTheme.surfaceContainerLow, AppTheme.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Card 2: iPhone Belum Kembali (x-mary-stat: iPhone Belum Kembali)
            Expanded(
              child: _buildMetricCard(
                title: 'iPhone Belum Kembali',
                icon: Icons.assignment_return_rounded,
                iconColor: const Color(0xFF7E22CE), // purple-600
                iconBg: const Color(0xFFF3E8FF),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: '$unreturnedUnits ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Unit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildTinyPill('Jatuh Tempo', const Color(0xFFF3E8FF), const Color(0xFF7E22CE), isBold: true),
                        if (overdueReturns > 0)
                          _buildTinyPill('$overdueReturns Telat', AppTheme.errorContainer, AppTheme.onErrorContainer, isBold: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // Card 3: Booking Hari Ini (x-mary-stat: Booking Hari Ini)
            Expanded(
              child: _buildMetricCard(
                title: 'Booking Hari Ini',
                icon: Icons.assignment_rounded,
                iconColor: const Color(0xFF2563EB), // blue-600
                iconBg: const Color(0xFFEFF6FF),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: '$bookingToday ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Booking',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildTinyPill('Hari Ini', const Color(0xFFEFF6FF), const Color(0xFF2563EB), isBold: true),
                        _buildTinyPill('Operasional', AppTheme.surfaceContainerLow, AppTheme.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Card 4: Pendapatan Hari Ini (x-mary-stat: Pendapatan Hari ini)
            Expanded(
              child: _buildMetricCard(
                title: 'Pendapatan Hari Ini',
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF047857), // text-success
                iconBg: const Color(0xFFDCFCE7),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.formatCurrency(revenueToday),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Penerimaan Sewa',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSuccessContainer,
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
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildTinyPill(String label, Color bg, Color text, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: text,
        ),
      ),
    );
  }

  /// Antrean Transaksi Section matching Stitch exactly with DB sorting & operations
  Widget _buildTransactionQueueSection(
    List<BookingModel> allQueue,
    List<BookingModel> pickupItems,
    List<BookingModel> returnItems,
    List<BookingModel> displayItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Antrean Transaksi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _queueSearchQuery.isNotEmpty
                        ? '${displayItems.length} Hasil'
                        : (allQueue.length > 50 ? '50 Terbaru' : '${allQueue.length}'),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            // Tombol Selector Sort Sesuai Database
            _buildSortDropdown(),
          ],
        ),
        const SizedBox(height: 10),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQueueTabButton('semua', 'Semua (${allQueue.length})'),
              const SizedBox(width: 8),
              _buildQueueTabButton('pickup', 'Pickup (${pickupItems.length})'),
              const SizedBox(width: 8),
              _buildQueueTabButton('return', 'Return (${returnItems.length})'),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Search Bar
        _buildQueueSearchBar(isTablet: false),
        const SizedBox(height: 12),

        // Queue Items dynamically from API
        if (displayItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _queueSearchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.inbox_rounded,
                    color: AppTheme.secondary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _queueSearchQuery.isNotEmpty
                      ? 'Tidak Ditemukan'
                      : 'Tidak Ada Antrean Transaksi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _queueSearchQuery.isNotEmpty
                      ? 'Tidak ada transaksi yang cocok dengan "$_queueSearchQuery".'
                      : 'Belum ada transaksi di antrean. Buat booking baru untuk memulai transaksi kasir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                if (_queueSearchQuery.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      _queueSearchController.clear();
                      setState(() {
                        _queueSearchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.clear_rounded, size: 14),
                    label: const Text('Reset Pencarian', style: TextStyle(fontSize: 11)),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.createBooking).then((_) => _loadDashboard()),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Buat Booking Baru'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          ...displayItems.map((b) {
            final isPickup = b.status == BookingStatus.confirmed || b.status == BookingStatus.pending;
            final isRented = b.status == BookingStatus.rented;
            final now = DateTime.now();
            final isOverdue = isRented && b.endDate.isBefore(now);

            String timeStr = Formatters.date(b.startDate);
            String statusBadge = 'Terkonfirmasi';
            Color badgeBg = AppTheme.successContainer;
            Color badgeColor = AppTheme.onSuccessContainer;

            if (isOverdue) {
              timeStr = 'TELAT PENGEMBALIAN';
              statusBadge = '+ Denda Telat';
              badgeBg = AppTheme.errorContainer;
              badgeColor = AppTheme.error;
            } else if (isRented) {
              timeStr = Formatters.date(b.endDate);
              statusBadge = 'Sedang Disewa';
              badgeBg = AppTheme.surfaceContainerLow;
              badgeColor = AppTheme.textSecondary;
            } else if (b.status == BookingStatus.pending) {
              statusBadge = 'Menunggu Pembayaran';
              badgeBg = AppTheme.surfaceContainerLow;
              badgeColor = AppTheme.textSecondary;
            }

            return _buildStitchQueueItem(
              booking: b,
              type: isPickup ? 'pickup' : 'return',
              isOverdue: isOverdue,
              time: timeStr,
              statusBadge: statusBadge,
              statusBadgeBg: badgeBg,
              statusBadgeColor: badgeColor,
              customerName: b.customerName,
              bookingCode: '#${b.bookingCode}',
              deviceDesc: '${b.iphone.modelName} • ${b.iphone.color} • SN: ${b.iphone.serialNumber}',
              paymentStatus: b.paymentStatus,
              jaminanType: b.jaminanType,
              onDetail: () {
                Navigator.pushNamed(context, AppRoutes.bookingDetail, arguments: b)
                    .then((_) => _loadDashboard());
              },
              onDelete: () => _confirmDeleteBooking(b),
            );
          }),
      ],
    );
  }

  /// Sort dropdown selector matching app's Stitch pill design
  Widget _buildSortDropdown() {
    String label;
    switch (_selectedSort) {
      case 'start_booking_date':
        label = 'Jadwal Mulai';
        break;
      case 'end_booking_date':
        label = 'Jatuh Tempo';
        break;
      case 'status':
        label = 'Status';
        break;
      case 'price':
        label = 'Biaya Tertinggi';
        break;
      case 'created_at':
      default:
        label = 'Terbaru';
        break;
    }

    return PopupMenuButton<String>(
      onSelected: (val) {
        setState(() {
          _selectedSort = val;
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'created_at',
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text('Terbaru (Waktu Dibuat)', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'start_booking_date',
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text('Jadwal Mulai Sewa', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'end_booking_date',
          child: Row(
            children: [
              Icon(Icons.event_busy_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text('Jadwal Selesai Sewa', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'status',
          child: Row(
            children: [
              Icon(Icons.flag_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text('Status Booking (Alur)', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'price',
          child: Row(
            children: [
              Icon(Icons.payments_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text('Biaya Terbesar', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 14, color: AppTheme.secondary),
            const SizedBox(width: 4),
            Text(
              'Urut: $label',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTabButton(String key, String label) {
    final isSelected = _selectedQueueFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedQueueFilter = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentStatusBadge(PaymentStatus status) {
    Color bg;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case PaymentStatus.paid:
        bg = const Color(0xFFDCFCE7); // green-100
        textColor = const Color(0xFF047857); // green-700
        label = 'Lunas';
        icon = Icons.check_circle_rounded;
        break;
      case PaymentStatus.partial:
        bg = const Color(0xFFFEF3C7); // amber-100
        textColor = const Color(0xFFB45309); // amber-700
        label = 'DP / Sebagian';
        icon = Icons.pending_rounded;
        break;
      case PaymentStatus.unpaid:
        bg = const Color(0xFFFEE2E2); // red-100
        textColor = const Color(0xFFB91C1C); // red-700
        label = 'Belum Bayar';
        icon = Icons.error_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchQueueItem({
    required BookingModel booking,
    required String type,
    bool isOverdue = false,
    required String time,
    required String statusBadge,
    required Color statusBadgeBg,
    required Color statusBadgeColor,
    required String customerName,
    required String bookingCode,
    required String deviceDesc,
    required PaymentStatus paymentStatus,
    required String jaminanType,
    required VoidCallback onDetail,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? AppTheme.errorBorder : AppTheme.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Type pill + Time + Status right pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? AppTheme.errorContainer
                              : (type == 'pickup' ? AppTheme.secondary : AppTheme.surfaceContainerHigh),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOverdue ? 'RETURN • OVERDUE' : type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isOverdue
                                ? AppTheme.onErrorContainer
                                : (type == 'pickup' ? Colors.white : AppTheme.secondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isOverdue ? AppTheme.error : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBadgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusBadge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusBadgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Middle row: Phone thumbnail + Customer Name + Model
              Row(
                children: [
                  _buildDeviceThumbnail(
                    booking.iphone,
                    size: 40,
                    radius: 10,
                    isOverdue: isOverdue,
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
                              customerName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              bookingCode,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deviceDesc,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Dibuat oleh: ${booking.userName ?? "Kasir"}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Footer Row: Status Pembayaran + Tarif (Kiri) & Action Buttons (Delete & Detail) (Kanan)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _buildPaymentStatusBadge(paymentStatus),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Tarif: ${Formatters.formatCurrency(booking.price)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol Hapus Booking (tempat sampah merah)
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.error),
                        tooltip: 'Hapus Booking',
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 4),

                      // Tombol Detail Booking
                      OutlinedButton.icon(
                        onPressed: onDetail,
                        icon: Icon(Icons.visibility_outlined, size: 14, color: AppTheme.textPrimary),
                        label: Text(
                          'Detail',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: AppTheme.cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Floating Action Button matching Stitch design
  Widget _buildStitchFloatingActionButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.createBooking).then((_) => _loadDashboard());
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
        ),
        icon: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, size: 18, color: Colors.white),
        ),
        label: const Text(
          'Buat Booking',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
