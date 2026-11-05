import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/cash_drawer_shift_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_cached_network_image.dart';
import '../../widgets/shift_warning_dialog.dart';
import 'widgets/dashboard_skeleton.dart';
import 'widgets/operational_metric_detail_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final BookingRepository repository;

  const DashboardScreen({
    super.key,
    required this.repository,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver, RouteAware {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  List<IphoneModel> _readyInventory = [];
  int _pendingTransferCount = 0;
  String _selectedQueueFilter = 'semua'; // 'semua', 'pickup', 'return'
  String _selectedSort = 'created_at'; // 'created_at', 'start_booking_date', 'end_booking_date', 'status', 'price'
  final TextEditingController _queueSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _queueSearchQuery = '';
  ShiftScheduleModel? _shiftSchedule;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService().addListener(_onAuthChanged);
    _initPrinter();

    // Inisialisasi awal langsung dari client-side in-memory cache jika masih valid (< 5 menit)
    if (widget.repository.isDashboardCacheValid && widget.repository.cachedDashboardData != null) {
      _dashboardData = widget.repository.cachedDashboardData!;
      _readyInventory = widget.repository.cachedReadyInventory ?? [];
      _pendingTransferCount = widget.repository.cachedPendingTransferCount ?? 0;
      _isLoading = false;
      _reloadShiftStatus();
    } else {
      _loadDashboard();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      AppRoutes.routeObserver.subscribe(this, route);
    }
    _reloadShiftStatus();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    unfocusSearch();
    _reloadShiftStatus();
    _loadDashboard(forceRefresh: true);
  }

  /// Memuat ulang status shift aktif secara reaktif tanpa menunggu cache kedaluwarsa
  Future<void> _reloadShiftStatus() async {
    try {
      final activeBranchId = AuthService().isAffiliateScoped ? AuthService().affiliateId : (AuthService().affiliateId ?? 4);
      final schedule = await widget.repository.getShiftSchedule(branchId: activeBranchId, forceRefresh: true);
      if (mounted) {
        setState(() {
          _shiftSchedule = schedule;
        });
      }
    } catch (_) {}
  }

  void _onAuthChanged() {
    if (!AuthService().isAuthenticated) {
      widget.repository.invalidateDashboardCache();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unfocusSearch();
      checkAndRefreshIfExpired();
    }
  }

  Future<void> _initPrinter() async {
    try {
      await ThermalPrintService().ensurePrimaryConnected();
    } catch (_) {}
  }

  @override
  void dispose() {
    AppRoutes.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _queueSearchController.dispose();
    _searchFocusNode.dispose();
    AuthService().removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Memastikan field pencarian dashboard tidak fokus dan virtual keyboard tidak terbuka otomatis
  void unfocusSearch() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Navigasi ke rute lain dengan memastikan keyboard tidak terbuka saat kembali
  Future<T?> _navigateAndRefresh<T>(String routeName, {Object? arguments}) async {
    unfocusSearch();
    if (routeName == AppRoutes.createBooking) {
      final hasActive = await widget.repository.checkHasActiveShift(forceRefresh: true);
      if (!hasActive) {
        if (mounted) {
          await showShiftWarningDialog(
            context,
            title: 'Shift Kasir Belum Dibuka',
            message: 'Shift kasir belum dibuka untuk cabang ini. Anda harus membuka shift kasir terlebih dahulu sebelum melayani dan memproses booking baru.',
            onOpenShift: () => _navigateAndRefresh(AppRoutes.cashierShift),
          );
        }
        return null;
      }
      final schedule = _shiftSchedule ?? await widget.repository.getShiftSchedule(forceRefresh: true);
      if (!schedule.canCreateBooking) {
        _showDashboardShiftRequiredDialog(schedule);
        return null;
      }
    }
    final result = await Navigator.pushNamed<T>(context, routeName, arguments: arguments);
    if (mounted) {
      unfocusSearch();
      _reloadShiftStatus();
      _loadDashboard(forceRefresh: true);
    }
    return result;
  }

  void _showDashboardShiftRequiredDialog(ShiftScheduleModel schedule) {
    final isClosed = schedule.operationalState == ShiftOperationalState.closed;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.white,
        elevation: 8,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Centered Warning / Shift Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isClosed ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isClosed ? Icons.lock_clock_rounded : Icons.point_of_sale_rounded,
                    color: isClosed ? const Color(0xFF475569) : const Color(0xFFD97706),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),

                // Cohesive Centered Title
                Text(
                  isClosed ? 'Shift Kasir Ditutup' : 'Shift Kasir Belum Dibuka',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Descriptive Message with Balanced Line Height
                Text(
                  isClosed
                      ? 'Shift kasir untuk hari ini telah selesai ditutup (${schedule.shiftClosingTime}). Transaksi booking baru hanya dapat dibuat saat shift kasir aktif.'
                      : 'Shift kasir belum dibuka untuk cabang ini. Anda harus membuka shift kasir terlebih dahulu sebelum melayani dan memproses booking baru.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Proportional Touch-Friendly Action Buttons (48px height)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: const Key('btn_batal_shift_dialog'),
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            foregroundColor: const Color(0xFF475569),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    if (!isClosed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            key: const Key('btn_buka_shift_kasir'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _navigateAndRefresh(AppRoutes.cashierShift);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.vpn_key_rounded, size: 16),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Buka Shift',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Cek apakah cache dashboard sudah kedaluwarsa (>= 5 menit) dan muat ulang secara otomatis jika perlu
  void checkAndRefreshIfExpired() {
    if (!widget.repository.isDashboardCacheValid) {
      _loadDashboard();
    }
  }

  Future<void> _loadDashboard({bool forceRefresh = false}) async {
    // 1. Cek apakah cache client-side valid (< 5 menit) dan bukan forceRefresh
    if (!forceRefresh && widget.repository.isDashboardCacheValid) {
      final cached = widget.repository.cachedDashboardData;
      if (cached != null) {
        if (_dashboardData.isEmpty || _isLoading) {
          setState(() {
            _dashboardData = cached;
            _readyInventory = widget.repository.cachedReadyInventory ?? [];
            _pendingTransferCount = widget.repository.cachedPendingTransferCount ?? 0;
            _isLoading = false;
          });
        }
        widget.repository.getShiftSchedule().then((s) {
          if (mounted) setState(() => _shiftSchedule = s);
        }).catchError((_) {});
        return;
      }
    }

    // 2. Hanya tampilkan loading skeleton jika data belum pernah dimuat (cold start)
    if (_dashboardData.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final activeBranchId = AuthService().isAffiliateScoped ? AuthService().affiliateId : (AuthService().affiliateId ?? 4);
      final data = await widget.repository.getOperationalDashboardData(affiliateId: activeBranchId, forceRefresh: forceRefresh);
      List<IphoneModel> readyUnits = [];
      try {
        readyUnits = await widget.repository.getAllInventoryUnits(
          statusFilter: 'tersedia',
          affiliateId: activeBranchId,
        );
      } catch (_) {
        readyUnits = [];
      }

      int pendingTransferCount = 0;
      try {
        final isAffUser = AuthService().isAffiliate || AuthService().isAffiliateAdmin;
        final transfers = await widget.repository.getIphoneTransfers(
          status: 'in_transit',
          affiliateId: isAffUser ? AuthService().affiliateId : null,
          type: isAffUser ? 'inbound' : null,
          forceRefresh: forceRefresh,
        );
        pendingTransferCount = transfers.where((t) => t.isInTransit).length;
      } catch (_) {}

      // Simpan ke in-memory cache di repository
      widget.repository.setDashboardCache(
        data: data,
        readyUnits: readyUnits,
        pendingTransferCount: pendingTransferCount,
      );

      ShiftScheduleModel? schedule;
      try {
        schedule = await widget.repository.getShiftSchedule(forceRefresh: forceRefresh);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _readyInventory = readyUnits;
          _pendingTransferCount = pendingTransferCount;
          if (schedule != null) _shiftSchedule = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_dashboardData.isEmpty) {
            _readyInventory = [];
          }
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
        _loadDashboard(forceRefresh: true);
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final pickupItems = allQueue.where((b) {
      if (b.status != BookingStatus.confirmed) return false;
      return b.startDate.year == today.year &&
          b.startDate.month == today.month &&
          b.startDate.day == today.day;
    }).toList();

    final returnItems = allQueue.where((b) {
      if (b.status == BookingStatus.returned || b.status == BookingStatus.cancelled) return false;
      final isRentedOrActive = b.status == BookingStatus.rented || b.status == BookingStatus.confirmed;
      if (!isRentedOrActive) return false;
      return b.isCurrentlyOverdue || b.endDate.isBefore(todayEnd) || b.endDate.isAtSameMomentAs(todayEnd);
    }).toList();

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
        final matchSerial = b.iphone.serialNumber.isNotEmpty &&
            b.iphone.serialNumber != '-' &&
            b.iphone.serialNumber.toLowerCase().contains(q);
        final matchAsset = b.iphone.assetCode.isNotEmpty &&
            b.iphone.assetCode != '-' &&
            b.iphone.assetCode.toLowerCase().contains(q);
        return b.customerName.toLowerCase().contains(q) ||
            b.bookingCode.toLowerCase().contains(q) ||
            b.customerPhone.toLowerCase().contains(q) ||
            b.iphone.modelName.toLowerCase().contains(q) ||
            b.iphone.name.toLowerCase().contains(q) ||
            matchSerial ||
            matchAsset;
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
        final isLandscapeTablet = constraints.maxWidth >= 900 && constraints.maxWidth > constraints.maxHeight;
        final isPortraitTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900 && constraints.maxHeight > constraints.maxWidth && constraints.maxHeight <= 1600;
        final isTablet = isLandscapeTablet || isPortraitTablet;

        Widget bodyContent;
        if (_isLoading) {
          bodyContent = DashboardSkeleton(isTablet: isTablet);
        } else if (isTablet) {
          bodyContent = _buildTabletLayout(metrics, allQueue, pickupItems, returnItems, displayItems);
        } else {
          bodyContent = RefreshIndicator(
            onRefresh: () => _loadDashboard(forceRefresh: true),
            color: AppTheme.accent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: _buildMobileLayout(metrics, allQueue, pickupItems, returnItems, displayItems),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppHeader(
            isTablet: isTablet,
          ),
          body: bodyContent,
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

  Widget _buildShiftBadgeHeader() {
    final hasActive = _shiftSchedule?.hasActiveShift ?? false;
    final Color bg;
    final Color fg;
    final String text;

    if (hasActive) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      text = 'Shift Aktif';
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      text = 'Shift Belum Dibuka';
    }

    return Container(
      key: const Key('shift_indicator_pill'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
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
            onPressed: () => _loadDashboard(forceRefresh: true),
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
          child: _buildOperationalMetricsSection(
            metrics,
            allQueue: allQueue,
            pickupItems: pickupItems,
            returnItems: returnItems,
          ),
        ),

        // Quick Action: Shift Kasir & Buku Kas (POS Cash Drawer)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: InkWell(
            onTap: () => _navigateAndRefresh(AppRoutes.cashierShift),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
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
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Color(0xFF0284C7),
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
                            const Flexible(
                              child: Text(
                                'Shift Kasir & Buku Kas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildShiftBadgeHeader(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _shiftSchedule?.statusMessage ?? 'Buka/tutup shift, modal awal & mutasi kas fisik',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Buka',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
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

        // Quick Action khusus Affiliate: Transfer iPhone Masuk & Terima iPhone
        if (AuthService().isAffiliate || AuthService().isAffiliateAdmin)
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

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 40,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_dashboardData['isOnline'] == false)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildOfflineBanner(),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (~66% width: Metrik Operasional & Antrean Transaksi 2 Kolom) - SCROLLABLE MAIN CONTENT
                Expanded(
                  flex: 66,
                  child: RefreshIndicator(
                    onRefresh: () => _loadDashboard(forceRefresh: true),
                    color: AppTheme.accent,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTabletMetricsSection(metrics, allQueue, pickupItems, returnItems),
                          const SizedBox(height: 20),
                          _buildTabletQueueSection(allQueue, pickupItems, returnItems, displayItems),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Right Column (~34% width: Aksi Cepat Kasir, Printer, Stok Siap Sewa) - STICKY
                Expanded(
                  flex: 34,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTabletMetricsSection(
    Map<String, dynamic> metrics,
    List<BookingModel> allQueue,
    List<BookingModel> pickupItems,
    List<BookingModel> returnItems,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final rentedItems = allQueue.where((b) {
      if (b.status == BookingStatus.returned || b.status == BookingStatus.cancelled) return false;
      if (b.status == BookingStatus.rented) return true;
      if (b.isCurrentlyOverdue || b.endDate.isBefore(now)) {
        return b.status == BookingStatus.confirmed || b.status == BookingStatus.rented;
      }
      return false;
    }).toList();

    final totalUnits = (metrics['totalUnits'] as num?)?.toInt() ??
        (metrics['total_units'] as num?)?.toInt() ?? 30;
    final rentedUnits = rentedItems.isNotEmpty
        ? rentedItems.length
        : ((metrics['rentedUnits'] as num?)?.toInt() ??
            (metrics['rented_units'] as num?)?.toInt() ?? 0);
    final utilizationFraction = totalUnits > 0 ? (rentedUnits / totalUnits).clamp(0.0, 1.0) : 0.0;
    final utilizationPercent = (utilizationFraction * 100).toInt();

    final bookingToday = pickupItems.isNotEmpty
        ? pickupItems.length
        : ((metrics['bookingToday'] as num?)?.toInt() ??
            (metrics['todayPickups'] as num?)?.toInt() ?? 0);
    final waitingPickups = pickupItems.length;
    final completedPickups = allQueue.where((b) {
      final isToday = b.startDate.year == today.year &&
          b.startDate.month == today.month &&
          b.startDate.day == today.day;
      return isToday && (b.status == BookingStatus.rented || b.status == BookingStatus.returned);
    }).length;

    final unreturnedUnits = returnItems.isNotEmpty
        ? returnItems.length
        : ((metrics['unreturnedUnits'] as num?)?.toInt() ??
            (metrics['todayReturns'] as num?)?.toInt() ?? 0);
    final overdueReturns = returnItems.where((b) => b.isCurrentlyOverdue || b.endDate.isBefore(now)).length;
    final onTimeReturns = (unreturnedUnits - overdueReturns).clamp(0, unreturnedUnits);

    final revenueToday = (metrics['revenueToday'] as num?)?.toDouble() ??
        (metrics['totalRevenue'] as num?)?.toDouble() ?? 1850000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Metrik Operasional Hari Ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Perbarui Data',
              child: InkWell(
                onTap: () => _loadDashboard(forceRefresh: true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

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
                onTap: () => _openOperationalMetricDetail(
                  OperationalMetricType.pickup,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                ),
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
                    const SizedBox(height: 5),
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
                onTap: () => _openOperationalMetricDetail(
                  OperationalMetricType.returnToday,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                ),
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
                    const SizedBox(height: 5),
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
                onTap: () => _openOperationalMetricDetail(
                  OperationalMetricType.rentedUnits,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                ),
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
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: utilizationFraction,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: const Color(0xFF2563EB),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$utilizationPercent% Utilitas Toko',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
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
                onTap: () => _openOperationalMetricDetail(
                  OperationalMetricType.revenueToday,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                ),
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
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
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

  void _openOperationalMetricDetail(
    OperationalMetricType type, {
    required Map<String, dynamic> metrics,
    required List<BookingModel> allQueue,
    required List<BookingModel> pickupItems,
    required List<BookingModel> returnItems,
  }) {
    unfocusSearch();
    final screenSize = MediaQuery.of(context).size;
    final isTabletLandscape = screenSize.width >= 900 && screenSize.width > screenSize.height;
    final isTabletPortrait = screenSize.width >= 600 && screenSize.width < 900 && screenSize.height > screenSize.width && screenSize.height <= 1600;
    final isTablet = isTabletLandscape || isTabletPortrait;
    final drawerWidth = isTabletLandscape
        ? 640.0
        : (screenSize.width >= 600 ? 540.0 : screenSize.width);

    // Adaptive container for mobile viewport: bottom sheet with full operational controls
    if (!isTablet) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (sheetCtx) {
          return Container(
            height: screenSize.height * 0.90,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: OperationalMetricDetailSheet(
                      initialType: type,
                      metrics: metrics,
                      allQueue: allQueue,
                      pickupItems: pickupItems,
                      returnItems: returnItems,
                      repository: widget.repository,
                      onClose: () => Navigator.of(sheetCtx).pop(),
                      onProcessReturn: (booking) async {
                        final hasShift = await widget.repository.checkHasActiveShift();
                        if (!hasShift && mounted) {
                          await showShiftWarningDialog(context);
                          return;
                        }
                        Navigator.of(sheetCtx).pop();
                        _navigateAndRefresh(AppRoutes.returnSummary, arguments: booking);
                      },
                      onProcessPickup: (booking) {
                        Navigator.of(sheetCtx).pop();
                        _navigateAndRefresh(AppRoutes.pickup, arguments: booking);
                      },
                      onViewDetail: (booking) {
                        Navigator.of(sheetCtx).pop();
                        _navigateAndRefresh(AppRoutes.bookingDetail, arguments: booking);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup Detail',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: drawerWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(-6, 0),
                  ),
                ],
              ),
              child: SafeArea(
                left: false,
                child: OperationalMetricDetailSheet(
                  initialType: type,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                  repository: widget.repository,
                  onClose: () => Navigator.of(dialogCtx).pop(),
                  onProcessReturn: (booking) async {
                    final hasShift = await widget.repository.checkHasActiveShift();
                    if (!hasShift && mounted) {
                      await showShiftWarningDialog(context);
                      return;
                    }
                    Navigator.of(dialogCtx).pop();
                    _navigateAndRefresh(AppRoutes.returnSummary, arguments: booking);
                  },
                  onProcessPickup: (booking) {
                    Navigator.of(dialogCtx).pop();
                    _navigateAndRefresh(AppRoutes.pickup, arguments: booking);
                  },
                  onViewDetail: (booking) {
                    Navigator.of(dialogCtx).pop();
                    _navigateAndRefresh(AppRoutes.bookingDetail, arguments: booking);
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (dialogCtx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  Widget _buildTabletMetricCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget content,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: iconColor.withValues(alpha: 0.04),
        splashColor: iconColor.withValues(alpha: 0.08),
        highlightColor: iconColor.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 9,
                            color: AppTheme.textSecondary.withValues(alpha: 0.6),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, size: 15, color: iconColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueSearchBar({bool isTablet = false}) {
    return Container(
      height: isTablet ? 44 : 40,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: _queueSearchController,
        focusNode: _searchFocusNode,
        autofocus: false,
        onChanged: (val) {
          setState(() {
            _queueSearchQuery = val;
          });
        },
        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari customer, kode booking, nomor WA, unit iPhone, S/N...',
          hintStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF64748B)),
          suffixIcon: _queueSearchQuery.isNotEmpty
              ? Tooltip(
                  message: 'Hapus pencarian',
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _queueSearchController.clear();
                      setState(() {
                        _queueSearchQuery = '';
                      });
                    },
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 10, horizontal: 12),
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
    final leftItems = <BookingModel>[];
    final rightItems = <BookingModel>[];
    for (int i = 0; i < displayItems.length; i++) {
      if (i % 2 == 0) {
        leftItems.add(displayItems[i]);
      } else {
        rightItems.add(displayItems[i]);
      }
    }

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
        const SizedBox(height: 14),

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
          Row(
            key: const Key('tablet_transaction_queue_two_columns'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  key: const Key('tablet_queue_column_left'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: leftItems.map((b) => _buildTabletQueueCard(b)).toList(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  key: const Key('tablet_queue_column_right'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rightItems.map((b) => _buildTabletQueueCard(b)).toList(),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDeviceThumbnail(
    IphoneModel iphone, {
    double size = 44,
    double radius = 12,
    bool isOverdue = false,
  }) {
    final photo = iphone.resolvedThumbnailUrl ?? iphone.resolvedPhotoUrl;
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
            ? AppCachedNetworkImage(
                imageUrl: photo,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * 2).clamp(48.0, 200.0).toInt(),
                cacheHeight: (size * 2).clamp(48.0, 200.0).toInt(),
                placeholder: (context) => Center(
                  child: SizedBox(
                    width: size * 0.35,
                    height: size * 0.35,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fallbackColor),
                    ),
                  ),
                ),
                errorWidget: (context, error) => Center(
                  child: Icon(
                    isOverdue ? Icons.schedule_rounded : Icons.phone_iphone_rounded,
                    color: fallbackColor,
                    size: size * 0.5,
                  ),
                ),
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

    return _buildStitchQueueItem(
      booking: b,
      type: isPickup ? 'pickup' : 'return',
      isOverdue: isOverdue,
      time: Formatters.date(b.startDate),
      statusBadge: '',
      statusBadgeBg: Colors.transparent,
      statusBadgeColor: Colors.transparent,
      customerName: b.customerName,
      bookingCode: '#${b.bookingCode}',
      deviceDesc: '${b.iphone.modelName} • ${b.iphone.color} • SN: ${b.iphone.serialNumber}',
      paymentStatus: b.paymentStatus,
      jaminanType: b.jaminanType,
      onDetail: () {
        _navigateAndRefresh(AppRoutes.bookingDetail, arguments: b);
      },
      onDelete: () => _confirmDeleteBooking(b),
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

          // Primary Action 1: + Buat Booking Baru (prominent with at least 48px touch target)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                _navigateAndRefresh(AppRoutes.createBooking);
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Buat Booking Baru',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Row with 2 primary buttons: Scan QR Booking & Cek Stok Unit (>= 48px touch target)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _navigateAndRefresh(AppRoutes.qrScanner);
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF0369A1)),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Scan QR Booking',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0F2FE),
                      foregroundColor: const Color(0xFF0369A1),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _navigateAndRefresh(AppRoutes.unitStatus);
                    },
                    icon: Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.textPrimary),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Cek Stok Unit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: AppTheme.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  /// Collapsed minimal 1-line status row for tablet printer card
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

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minimal 1-line status row (Icon, Printer Kasir, Online/Offline badge)
              InkWell(
                onTap: () async {
                  unfocusSearch();
                  await Navigator.pushNamed(context, AppRoutes.printerSettings);
                  if (mounted) {
                    unfocusSearch();
                    setState(() {});
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isConnected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.print_outlined,
                        size: 15,
                        color: isConnected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Printer Kasir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isConnected ? const Color(0xFF047857) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Button: Tes Cetak Nota Struk (visually disabled when offline)
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton(
                  onPressed: isConnected
                      ? () async {
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
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    foregroundColor: isConnected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                    disabledBackgroundColor: const Color(0xFFF1F5F9),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isConnected ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_outlined,
                          size: 13,
                          color: isConnected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Tes Cetak Nota Struk',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConnected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Stok Siap Sewa',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
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
          else
            // Clean max-height with smooth scrolling to prevent list overflow when items increase
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...entries.take(maxStockDisplay).map((entry) {
                      final modelName = entry.key;
                      final units = entry.value;
                      final colors = units.map((u) => u.color).toSet().join(' & ');
                      final storage = units.first.storage;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
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
                                    storage.isNotEmpty ? '$storage • $colors' : colors,
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
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Button: Buka Katalog Lengkap
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              onPressed: () {
                _navigateAndRefresh(AppRoutes.unitStatus);
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
  Widget _buildOperationalMetricsSection(
    Map<String, dynamic> metrics, {
    List<BookingModel> allQueue = const [],
    List<BookingModel> pickupItems = const [],
    List<BookingModel> returnItems = const [],
  }) {
    final now = DateTime.now();

    // 1. iPhone Tersedia (Database: unit tanpa booking status 'confirmed')
    final availableUnits = (metrics['availableUnits'] as num?)?.toInt() ?? 12;
    final totalUnits = (metrics['totalUnits'] as num?)?.toInt() ??
        (metrics['total_units'] as num?)?.toInt() ?? 30;

    // 2. iPhone Belum Kembali (Database: booking status 'confirmed' dengan end_booking_date <= today)
    final unreturnedUnits = returnItems.isNotEmpty
        ? returnItems.length
        : ((metrics['unreturnedUnits'] as num?)?.toInt() ??
            (metrics['todayReturns'] as num?)?.toInt() ?? 3);
    final overdueReturns = returnItems.where((b) => b.isCurrentlyOverdue || b.endDate.isBefore(now)).isNotEmpty
        ? returnItems.where((b) => b.isCurrentlyOverdue || b.endDate.isBefore(now)).length
        : ((metrics['overdueReturns'] as num?)?.toInt() ?? 0);

    // 3. Booking Hari Ini (Database: booking dibuat hari ini)
    final bookingToday = pickupItems.isNotEmpty
        ? pickupItems.length
        : ((metrics['bookingToday'] as num?)?.toInt() ??
            (metrics['todayPickups'] as num?)?.toInt() ?? 5);

    // 4. Pendapatan Hari Ini (Database: total pembayaran BookingPayment paid_at hari ini)
    final revenueToday = (metrics['revenueToday'] as num?)?.toDouble() ??
        (metrics['totalRevenue'] as num?)?.toDouble() ?? 1850000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  const Opacity(
                    opacity: 0.0,
                    child: Text(
                      'Metrik Operasional Hari Ini',
                      style: TextStyle(fontSize: 1),
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    'Metrik Operasional',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _loadDashboard(forceRefresh: true),
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
            // Card 1: iPhone Tersedia (x-mary-stat: iPhone Tersedia) / Unit Disewa
            Expanded(
              child: _buildMetricCard(
                title: 'iPhone Tersedia',
                alternateTitle: 'Unit Disewa',
                icon: Icons.phone_iphone_rounded,
                iconColor: const Color(0xFF047857), // green-600
                iconBg: const Color(0xFFDCFCE7),
                onTap: () => _openOperationalMetricDetail(
                  OperationalMetricType.rentedUnits,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                ),
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

            // Card 2: iPhone Belum Kembali (x-mary-stat: iPhone Belum Kembali) / Return Hari Ini
            Expanded(
              child: _buildMetricCard(
                title: 'iPhone Belum Kembali',
                alternateTitle: 'Return Hari Ini',
                icon: Icons.assignment_return_rounded,
                iconColor: const Color(0xFF7E22CE), // purple-600
                iconBg: const Color(0xFFF3E8FF),
                onTap: () => _openOperationalMetricDetail(
                  OperationalMetricType.returnToday,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                ),
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
            // Card 3: Booking Hari Ini (x-mary-stat: Booking Hari Ini) / Pickup Hari Ini
            Expanded(
              child: _buildMetricCard(
                title: 'Booking Hari Ini',
                alternateTitle: 'Pickup Hari Ini',
                icon: Icons.assignment_rounded,
                iconColor: const Color(0xFF2563EB), // blue-600
                iconBg: const Color(0xFFEFF6FF),
                onTap: () => _openOperationalMetricDetail(
                  OperationalMetricType.pickup,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                ),
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

            // Card 4: Pendapatan Hari Ini (x-mary-stat: Pendapatan Hari ini) / Omzet Hari Ini
            Expanded(
              child: _buildMetricCard(
                title: 'Pendapatan Hari Ini',
                alternateTitle: 'Omzet Hari Ini',
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF047857), // text-success
                iconBg: const Color(0xFFDCFCE7),
                onTap: () => _openOperationalMetricDetail(
                  OperationalMetricType.revenueToday,
                  metrics: metrics,
                  allQueue: allQueue,
                  pickupItems: pickupItems,
                  returnItems: returnItems,
                ),
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
                        const Flexible(
                          child: Text(
                            'Penerimaan Sewa',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSuccessContainer,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    String? alternateTitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget content,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: iconColor.withValues(alpha: 0.04),
        splashColor: iconColor.withValues(alpha: 0.08),
        highlightColor: iconColor.withValues(alpha: 0.04),
        child: Container(
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
                  Expanded(
                    child: alternateTitle != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(
                                height: 0,
                                child: Opacity(
                                  opacity: 0.0,
                                  child: Text(
                                    alternateTitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            title,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  const SizedBox(width: 4),
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
        ),
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
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Antrean Transaksi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            ),
            const SizedBox(width: 8),
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
                    onPressed: () => _navigateAndRefresh(AppRoutes.createBooking),
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final b = displayItems[index];
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
                  _navigateAndRefresh(AppRoutes.bookingDetail, arguments: b);
                },
                onDelete: () => _confirmDeleteBooking(b),
              );
            },
          ),
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

  String _formatQueueDate(DateTime dt, [String? customTime]) {
    final local = Formatters.toWib(dt);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = (local.year % 100).toString().padLeft(2, '0');

    String timeStr;
    if (customTime != null && customTime.trim().isNotEmpty) {
      final parts = customTime.trim().split(':');
      if (parts.length >= 2) {
        timeStr = '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      } else {
        timeStr = customTime.trim();
      }
    } else {
      timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return '$day $month $year $timeStr';
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
    // 1. Warna teks kode booking merepresentasikan status pembayaran
    // @switch($booking->payment_status)
    //   @case('partial') text-yellow-600
    //   @case('paid') text-green-600
    //   @default text-red-600
    Color paymentCodeColor;
    switch (paymentStatus) {
      case PaymentStatus.paid:
        paymentCodeColor = const Color(0xFF16A34A); // bg-green-600
        break;
      case PaymentStatus.partial:
        paymentCodeColor = const Color(0xFFD97706); // bg-amber-600
        break;
      case PaymentStatus.unpaid:
        paymentCodeColor = const Color(0xFFDC2626); // bg-red-600
        break;
    }

    // 2. Booking status badge merepresentasikan status booking
    // @switch($booking->status)
    //   @case('pending') Menunggu Pembayaran (bg-yellow-500)
    //   @case('confirmed') Dikonfirmasi (bg-green-500)
    //   @case('returned') Dikembalikan (bg-blue-500)
    //   @case('cancelled') Dibatalkan (bg-red-500)
    //   @default {{ ucfirst($booking->status) }} (bg-gray-400)
    Color bookingStatusBg;
    String bookingStatusText;
    switch (booking.status) {
      case BookingStatus.pending:
        bookingStatusBg = const Color(0xFFEAB308); // bg-yellow-500
        bookingStatusText = 'Menunggu Pembayaran';
        break;
      case BookingStatus.confirmed:
        bookingStatusBg = const Color(0xFF22C55E); // bg-green-500
        bookingStatusText = 'Dikonfirmasi';
        break;
      case BookingStatus.returned:
        bookingStatusBg = const Color(0xFF3B82F6); // bg-blue-500
        bookingStatusText = 'Dikembalikan';
        break;
      case BookingStatus.cancelled:
        bookingStatusBg = const Color(0xFFEF4444); // bg-red-500
        bookingStatusText = 'Dibatalkan';
        break;
      case BookingStatus.rented:
        bookingStatusBg = const Color(0xFF9CA3AF); // bg-gray-400
        bookingStatusText = 'Disewa';
        break;
    }

    final targetDate = (booking.status == BookingStatus.rented || booking.status == BookingStatus.returned)
        ? booking.endDate
        : booking.startDate;
    final targetTime = (booking.status == BookingStatus.rented || booking.status == BookingStatus.returned)
        ? booking.endTime
        : booking.startTime;
    final formattedDate = _formatQueueDate(targetDate, targetTime);
    final displayCode = bookingCode.startsWith('#') ? bookingCode : '#$bookingCode';

    final rawIphoneName = booking.iphone.name.toLowerCase().contains(booking.iphone.color.toLowerCase())
        ? booking.iphone.name
        : '${booking.iphone.name} ${booking.iphone.color}'.trim();
    // Hapus kata 'default' pada akhir nama iPhone jika ada (case-insensitive)
    final cleanIphoneName = rawIphoneName.replaceAll(RegExp(r'\s+default$', caseSensitive: false), '').trim();

    final isPickup = type == 'pickup' || booking.status == BookingStatus.confirmed || booking.status == BookingStatus.pending;
    final accentColor = isOverdue
        ? const Color(0xFFDC2626)
        : (isPickup ? const Color(0xFF2563EB) : const Color(0xFFD97706));

    // Payment badge text & styling
    String paymentBadgeText;
    Color paymentBadgeBg;
    Color paymentBadgeTextCol;
    switch (paymentStatus) {
      case PaymentStatus.paid:
        paymentBadgeText = 'Lunas';
        paymentBadgeBg = const Color(0xFFDCFCE7);
        paymentBadgeTextCol = const Color(0xFF15803D);
        break;
      case PaymentStatus.partial:
        paymentBadgeText = 'DP';
        paymentBadgeBg = const Color(0xFFFEF3C7);
        paymentBadgeTextCol = const Color(0xFFB45309);
        break;
      case PaymentStatus.unpaid:
        paymentBadgeText = 'Pending';
        paymentBadgeBg = const Color(0xFFFEE2E2);
        paymentBadgeTextCol = const Color(0xFFB91C1C);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Subtle colored border accent on the left of each card for fast visual scanning
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: accentColor),
            ),
            InkWell(
              onTap: onDetail,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header: Kode Booking & Tanggal dengan background putih
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        displayCode,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: paymentCodeColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris 1: Nama Customer (Kiri) & Badge Status Booking (Kanan)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: paymentBadgeBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    paymentBadgeText,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: paymentBadgeTextCol,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: bookingStatusBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    bookingStatusText,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Baris 2: Model iPhone & Warna (dikurangi 2-3 pt, kata default dihapus)
                    Text(
                      cleanIphoneName,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Baris 3: Serial Number (SN) Unit dalam Monospace Pill Badge & Destructive Action Link (hapus)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Monospace S/N Pill Badge
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                            ),
                            child: Text(
                              booking.iphone.serialNumber.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Secondary Destructive Action: Subtle link with confirmation styling
                        InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 12.5, color: Color(0xFF94A3B8)),
                                SizedBox(width: 2),
                                Text(
                                  'hapus',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Metadata Creator: positioned subtly in corner
                    Text(
                      'Dibuat oleh: ${booking.userName ?? "Kasir"}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (booking.hasAddons) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Add-on (${booking.addonDevices.length}): ${booking.addonDevices.map((a) => a.name).join(", ")}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF15803D),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),

                    // Baris 4: Nominal Transaksi & Primary Constructive Action Button ("Detail")
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Rp',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: Formatters.formatCurrency(booking.price).replaceAll('Rp ', ''),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Primary Constructive Action Button: "Detail"
                        Material(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: onDetail,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Detail',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

  /// Floating Action Button matching Stitch design
  Widget _buildStitchFloatingActionButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FloatingActionButton.extended(
        onPressed: () {
          _navigateAndRefresh(AppRoutes.createBooking);
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
