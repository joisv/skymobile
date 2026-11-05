import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/affiliate_model.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_header.dart';
import '../payment/payment_deposit_screen.dart';
import 'widgets/create_iphone_dialog.dart';
import 'widgets/unit_status_skeleton.dart';

class UnitStatusListScreen extends StatefulWidget {
  final BookingRepository repository;

  const UnitStatusListScreen({
    super.key,
    required this.repository,
  });

  @override
  State<UnitStatusListScreen> createState() => _UnitStatusListScreenState();
}

class _UnitStatusListScreenState extends State<UnitStatusListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounceTimer;

  static const int _pageSize = 20;
  int _currentPage = 1;
  int _totalUnitCount = 0;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  List<IphoneModel> _units = [];
  List<AffiliateModel> _affiliates = [];
  Map<String, int> _summary = {
    'total': 0,
    'tersedia': 0,
    'disewa': 0,
    'terlambat': 0,
    'maintenance': 0,
    'dibooking': 0,
  };

  // Cache active bookings for rented units: unitId -> BookingModel
  final Map<int, BookingModel?> _activeBookings = {};

  bool _isLoading = true;
  String? _errorMessage;
  String _selectedStatus = 'Semua';
  String _selectedModel = 'Semua';
  String _selectedAffiliate = 'Semua Cabang';
  String _selectedSort = 'bh_desc';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreUnits();
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _loadData(resetPagination: true);
      }
    });
  }

  Future<void> _loadMoreUnits() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    await _loadData(resetPagination: false, isLoadMore: true);
  }

  Future<void> _loadData({bool resetPagination = true, bool isLoadMore = false, bool forceRefresh = false}) async {
    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        if (resetPagination) {
          _currentPage = 1;
          _hasMore = false;
        }
      });
    }

    try {
      final isAffiliateUser = AuthService().isAffiliate || AuthService().isAffiliateAdmin || (AuthService().affiliateId != null && !AuthService().isSuperAdmin);

      int? filterAffiliateId;
      if (isAffiliateUser) {
        filterAffiliateId = AuthService().currentUser?.affiliateId ?? AuthService().affiliateId;
      } else if (_selectedAffiliate != 'Semua Cabang') {
        final match = _affiliates.where((a) => a.name.toLowerCase() == _selectedAffiliate.toLowerCase()).firstOrNull;
        filterAffiliateId = match?.id;
      }

      final targetPage = isLoadMore ? (_currentPage + 1) : 1;

      if (isLoadMore) {
        final pagedResult = await widget.repository.getInventoryUnitsPaginated(
          query: _searchController.text.isNotEmpty ? _searchController.text : null,
          statusFilter: _selectedStatus == 'Semua' ? null : _selectedStatus,
          modelFilter: _selectedModel == 'Semua' ? null : _selectedModel,
          branchFilter: _selectedAffiliate == 'Semua Cabang' ? null : _selectedAffiliate,
          affiliateId: filterAffiliateId,
          sortBy: _selectedSort,
          page: targetPage,
          perPage: _pageSize,
        );

        for (final unit in pagedResult.units) {
          final s = unit.status.toLowerCase();
          if (s == 'disewa' || s == 'rented' || widget.repository.isUnitCurrentlyRented(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber) || (unit.customerName != null && unit.customerName!.isNotEmpty)) {
            final booking = widget.repository.getActiveBookingForUnitSync(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber);
            if (booking != null) {
              _activeBookings[unit.id] = booking;
            }
          }
        }

        if (mounted) {
          setState(() {
            _units.addAll(pagedResult.units);
            _currentPage = targetPage;
            _totalUnitCount = pagedResult.total;
            _hasMore = _units.length < pagedResult.total && targetPage < pagedResult.lastPage;
            _isLoadingMore = false;
          });
        }
        return;
      }

      // Ambil data halaman pertama dan cabang secara paralel (concurrent)
      final results = await Future.wait([
        widget.repository.getInventoryUnitsPaginated(
          query: _searchController.text.isNotEmpty ? _searchController.text : null,
          statusFilter: _selectedStatus == 'Semua' ? null : _selectedStatus,
          modelFilter: _selectedModel == 'Semua' ? null : _selectedModel,
          branchFilter: _selectedAffiliate == 'Semua Cabang' ? null : _selectedAffiliate,
          affiliateId: filterAffiliateId,
          sortBy: _selectedSort,
          page: 1,
          perPage: _pageSize,
          forceRefresh: forceRefresh,
        ),
        widget.repository.getAffiliates(forceRefresh: forceRefresh),
      ]);

      final pagedResult = results[0] as PaginatedIphonesResult;
      var affiliates = results[1] as List<AffiliateModel>;
      final summary = pagedResult.summary ?? _summary;

      // If affiliates list from repository is empty, infer from inventory units so dropdown is populated
      if (affiliates.isEmpty) {
        final seen = <String>{};
        final inferred = <AffiliateModel>[];
        for (final u in pagedResult.units) {
          final name = u.affiliateName ?? u.branchName;
          if (name != null && name.trim().isNotEmpty && !seen.contains(name.toLowerCase())) {
            seen.add(name.toLowerCase());
            inferred.add(AffiliateModel(
              id: u.affiliateId ?? (inferred.length + 1),
              name: name,
              code: (name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase()),
              slug: name.toLowerCase().replaceAll(' ', '-'),
              isActive: true,
            ));
          }
        }
        if (inferred.isNotEmpty) {
          affiliates = inferred;
        }
      }

      if (isAffiliateUser) {
        final myAffId = AuthService().currentUser?.affiliateId ?? AuthService().affiliateId;
        if (myAffId != null) {
          affiliates = affiliates.where((a) => a.id == myAffId).toList();
        }
        if (affiliates.isNotEmpty && (_selectedAffiliate == 'Semua Cabang' || !affiliates.any((a) => a.name == _selectedAffiliate))) {
          _selectedAffiliate = affiliates.first.name;
        }
      }

      _activeBookings.clear();
      // Pre-fetch active booking for units that are rented/disewa secara instan dari sinkronisasi memori
      for (final unit in pagedResult.units) {
        final s = unit.status.toLowerCase();
        if (s == 'disewa' || s == 'rented' || widget.repository.isUnitCurrentlyRented(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber) || (unit.customerName != null && unit.customerName!.isNotEmpty)) {
          final booking = widget.repository.getActiveBookingForUnitSync(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber);
          if (booking != null) {
            _activeBookings[unit.id] = booking;
          }
        }
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _affiliates = affiliates;
          _units = List<IphoneModel>.from(pagedResult.units);
          _currentPage = 1;
          _totalUnitCount = pagedResult.total;
          _hasMore = _units.length < pagedResult.total && 1 < pagedResult.lastPage;
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Gagal memuat data unit: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat unit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
      case 'ready':
        return const Color(0xFF15803D); // Green
      case 'disewa':
      case 'rented':
      case 'dibooking':
      case 'booked':
        return const Color(0xFF1D4ED8); // Blue
      case 'terlambat':
      case 'overdue':
      case 'late':
        return const Color(0xFFB91C1C); // Red
      case 'maintenance':
      case 'perawatan':
      case 'transferred':
      case 'in_transit':
      default:
        return const Color(0xFF475569); // Gray
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
      case 'ready':
        return const Color(0xFFDCFCE7); // Green bg
      case 'disewa':
      case 'rented':
      case 'dibooking':
      case 'booked':
        return const Color(0xFFEFF6FF); // Blue bg
      case 'terlambat':
      case 'overdue':
      case 'late':
        return const Color(0xFFFEE2E2); // Red bg
      case 'maintenance':
      case 'perawatan':
      case 'transferred':
      case 'in_transit':
      default:
        return const Color(0xFFF1F5F9); // Gray bg
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
      case 'ready':
        return 'Tersedia';
      case 'disewa':
      case 'rented':
        return 'Disewa';
      case 'terlambat':
      case 'overdue':
      case 'late':
        return 'Terlambat';
      case 'maintenance':
      case 'perawatan':
        return 'Perawatan';
      case 'dibooking':
      case 'booked':
        return 'Dibooking';
      default:
        return status;
    }
  }

  Color _getBatteryColor(int batteryHealth) {
    if (batteryHealth >= 90) return const Color(0xFF059669);
    if (batteryHealth >= 80) return const Color(0xFFD97706);
    return const Color(0xFFE11D48);
  }

  Color _getModelOutlineColor(IphoneModel unit) {
    final color = unit.color.toLowerCase();
    final name = unit.name.toLowerCase();
    final status = unit.status.toLowerCase();

    if (status == 'maintenance' || status == 'perawatan') {
      return const Color(0xFFE11D48);
    }
    if (color.contains('pink')) {
      return const Color(0xFFDB2777);
    }
    if (color.contains('blue') || name.contains('pro max')) {
      return const Color(0xFF2563EB);
    }
    if (color.contains('purple') || name.contains('13')) {
      return const Color(0xFF7C3AED);
    }
    if (color.contains('natural')) {
      return const Color(0xFF475569);
    }
    return const Color(0xFF334155);
  }

  String _getSortLabel() {
    switch (_selectedSort) {
      case 'bh_desc':
        return 'Battery Health (Tertinggi)';
      case 'bh_asc':
        return 'Battery Health (Terendah)';
      case 'name_asc':
        return 'Model (A - Z)';
      case 'asset_asc':
        return 'Kode Aset (A - Z)';
      default:
        return 'Battery Health (Tertinggi)';
    }
  }

  // =========================================================================
  // ACTIONS & DIALOGS
  // =========================================================================

  void _handleBookingKasir(IphoneModel unit) {
    Navigator.pushNamed(
      context,
      AppRoutes.createBooking,
      arguments: {'selectedIphone': unit},
    );
  }

  Future<void> _handlePengembalian(IphoneModel unit) async {
    var activeBooking = _activeBookings[unit.id] ??
        widget.repository.getActiveBookingForUnitSync(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber);
    if (activeBooking == null) {
      activeBooking = await widget.repository.getActiveBookingForUnit(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber);
      if (activeBooking != null) {
        _activeBookings[unit.id] = activeBooking;
      }
    }

    if (!mounted) return;

    // 1. Jika unit memiliki booking aktif
    if (activeBooking != null) {
      // Jika telat dan ada estimasi denda: arahkan langsung ke konfirmasi kasir & settlement pembayaran denda
      if (activeBooking.isCurrentlyLate && activeBooking.estimatedLateFee > 0) {
        Navigator.pushNamed(
          context,
          AppRoutes.paymentDeposit,
          arguments: {
            'booking': activeBooking,
            'initialPaymentType': PaymentTypeOption.penalty,
            'initialAmount': activeBooking.estimatedLateFee,
            'isReturnFlow': true,
          },
        ).then((_) {
          if (mounted) _loadData();
        });
        return;
      }

      // Jika tepat waktu / bebas denda: dialog konfirmasi cepat dan selesaikan pengembalian
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Konfirmasi Pengembalian',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Unit ${unit.fullName.isNotEmpty ? unit.fullName : unit.name} dikembalikan tepat waktu tanpa denda. Selesaikan pengembalian unit dan ubah status unit menjadi Tersedia (Ready)?',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, Selesaikan'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        try {
          await widget.repository.completeReturn(
            bookingCode: activeBooking.bookingCode,
            physicalCondition: 'Baik / Sempurna',
            batteryHealthFinal: unit.batteryHealth,
            lateFee: 0,
            damageFee: 0,
            depositRefunded: 0,
            refundMethod: 'Tanpa Denda',
            accessoriesReturned: ['Lengkap'],
            staffNotes: 'Pengembalian unit tepat waktu diselesaikan langsung.',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pengembalian unit berhasil diselesaikan! Status unit kembali Tersedia.'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
            _loadData();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gagal menyelesaikan pengembalian: $e'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        }
      }
      return;
    }

    // 2. Fallback jika data booking aktif tidak ditemukan tapi unit berstatus disewa
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Konfirmasi Pengembalian',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Selesaikan pengembalian unit ${unit.name} dan ubah status unit menjadi Tersedia (Ready)?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.repository.updateUnitStatus(
          unit.id > 0 ? unit.id.toString() : unit.assetCode,
          'tersedia',
          unitId: unit.id,
          serialNumber: unit.serialNumber,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengembalian unit berhasil diselesaikan! Status unit kembali Tersedia.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyelesaikan pengembalian: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  void _showUnitDetail(IphoneModel unit) {
    final activeBooking = _activeBookings[unit.id] ??
        widget.repository.getActiveBookingForUnitSync(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber);
    if (activeBooking != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.bookingDetail,
        arguments: activeBooking,
      );
    } else {
      _showUnitActionSheet(unit);
    }
  }

  Future<void> _handleSelesaiServis(IphoneModel unit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Selesai Servis & Siap Sewa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Tandai unit ${unit.fullName} (${unit.assetCode}) telah selesai perbaikan/inspeksi dan siap kembali ke status Tersedia?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Siap Sewa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.updateUnitStatus(
        unit.id > 0 ? unit.id.toString() : unit.assetCode,
        'tersedia',
        unitId: unit.id,
        serialNumber: unit.serialNumber,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit ${unit.fullName} berhasil kembali ke status Tersedia'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      _loadData();
    }
  }

  void _showServiceLogDialog(IphoneModel unit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.build_rounded, color: Color(0xFFE11D48), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Servis: ${unit.fullName}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Kode: ${unit.assetCode} • SN: ${unit.serialNumber}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_rounded, size: 14, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text(
                        'Inspeksi Servis Terakhir (09 Sep 2026)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    unit.maintenanceNote ?? 'Ganti tempered glass & deep cleaning port audio/charging.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUnitDialog() {
    if (!AuthService().canCreateIphone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses ditolak: Hanya Super Admin dan Admin yang dapat menambah iPhone baru.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateIphoneDialog(
        repository: widget.repository,
        onCreated: (newUnit) {
          _loadData();
        },
      ),
    );
  }

  void _showEditUnitDialog(IphoneModel unit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CreateIphoneDialog.edit(
        repository: widget.repository,
        unit: unit,
        onSaved: (updated) {
          _loadData();
        },
      ),
    );
  }

  Future<void> _confirmDeleteUnit(IphoneModel unit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Unit iPhone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus ${unit.fullName} (${unit.assetCode}) dari inventaris?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.deleteInventoryUnit(
        unit.id > 0 ? unit.id.toString() : unit.assetCode,
        unitId: unit.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit ${unit.fullName} berhasil dihapus'),
          backgroundColor: Colors.red,
        ),
      );
      _loadData();
    }
  }

  void _printBarcode(IphoneModel unit) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mencetak label barcode untuk ${unit.assetCode}...'),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  void _openBarcodeScannerModal() {
    final scannerCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Text('Scan Barcode Unit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan dengan barcode reader atau ketik kode barcode/SN di bawah:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: scannerCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Contoh: IPHSKY1048',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_2_rounded),
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx);
                _searchController.text = val;
                _loadData();
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              if (scannerCtrl.text.isNotEmpty) {
                _searchController.text = scannerCtrl.text;
                _loadData();
              }
            },
            child: const Text('Cari'),
          ),
        ],
      ),
    );
  }

  void _showUnitActionSheet(IphoneModel unit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.phone_iphone_rounded,
                      color: AppTheme.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.fullDisplayName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusBgColor(unit.status),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getStatusLabel(unit.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(unit.status),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'BH: ${unit.batteryHealth}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getBatteryColor(unit.batteryHealth),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              'Affiliate: ${unit.branchName ?? unit.affiliateName ?? "-"}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showEditUnitDialog(unit);
                  },
                  child: const Text('Edit Unit'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // BUILD SCREEN LAYOUT
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppHeader(
        isTablet: isTablet,
        title: 'Status Unit iPhone',
      ),
      floatingActionButton: (!isTablet && AuthService().canCreateIphone)
          ? FloatingActionButton.extended(
              onPressed: _showAddUnitDialog,
              backgroundColor: const Color(0xFF0F172A),
              elevation: 4,
              heroTag: 'fab_add_iphone_unit',
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              label: const Text(
                'Tambah Unit',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: isTablet ? _buildTabletBody() : _buildMobileBody(),
      ),
    );
  }

  // =========================================================================
  // TABLET LAYOUT (MATCHING SCREENSHOT)
  // =========================================================================

  Widget _buildTabletBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Title + Search with Barcode Button + "+ Tambah iPhone Baru" button
          _buildTitleAndActionBar(),

          // 4 Summary Metric Cards (Total, Tersedia, Disewa, Perawatan)
          _buildSummaryCardsTablet(),

          // Status Filter Pills with Counts + Branch Dropdown + Sort + Grid/List View Switcher
          _buildStatusFilterAndControlsRow(),

          const SizedBox(height: 8),

          // Inventory Cards Grid (3 Columns)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: UnitStatusListSkeleton(itemCount: 6),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _buildErrorState(),
            )
          else if (_units.isEmpty)
            _buildEmptyState()
          else
            _buildUnitCardsGridTablet(),

          if (_hasMore || _isLoadingMore)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.expand_more_rounded, size: 18),
                        label: Text('Muat Lebih Banyak (${_units.length} dari $_totalUnitCount)'),
                        onPressed: _loadMoreUnits,
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleAndActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title
          const Expanded(
            child: Text(
              'Status Unit & Inventaris iPhone',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),

          // Right side: Search Box + "+ Tambah iPhone Baru" button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search field with barcode scan button
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 320,
                  maxWidth: 440,
                ),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(
                            hintText: 'Cari model, kode aset, SN, penyewa...',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            _searchDebounceTimer?.cancel();
                            _searchController.clear();
                            _loadData(resetPagination: true);
                          },
                        ),
                      InkWell(
                        onTap: _openBarcodeScannerModal,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, size: 15, color: Color(0xFF475569)),
                              SizedBox(width: 4),
                              Text(
                                'Scan',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // + Tambah Unit button (Hanya super-admin dan admin)
              if (AuthService().canCreateIphone) ...[
                const SizedBox(width: 12),
                ElevatedButton(
                  key: const Key('btn_add_unit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: _showAddUnitDialog,
                  child: const Text(
                    '+ Tambah Unit',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardsTablet() {
    final totalUnits = _summary['total'] ?? _units.length;
    final readyUnits = _summary['tersedia'] ?? 0;
    final rentedUnits = _summary['disewa'] ?? 0;
    final lateUnits = _summary['terlambat'] ?? 0;
    final maintenanceUnits = _summary['maintenance'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          _buildKpiCard(
            count: totalUnits,
            countColor: const Color(0xFF0F172A),
            title: 'TOTAL UNIT',
            subtitle: _selectedAffiliate == 'Semua Cabang'
                ? 'Terdaftar di Gerai Gandaria'
                : 'Terdaftar di $_selectedAffiliate',
            statusDotColor: const Color(0xFF64748B),
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            count: readyUnits,
            countColor: const Color(0xFF15803D),
            title: 'TERSEDIA',
            subtitle: 'Siap Sewa / Ready Stock',
            statusDotColor: const Color(0xFF16A34A),
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            count: rentedUnits,
            countColor: const Color(0xFF1D4ED8),
            title: 'DISEWA',
            subtitle: 'Sedang Digunakan Customer',
            statusDotColor: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 12),
          _buildKpiCard(
            count: lateUnits,
            countColor: const Color(0xFFB91C1C),
            title: 'TERLAMBAT',
            subtitle: 'Melewati Batas Sewa',
            statusDotColor: const Color(0xFFDC2626),
          ),
          if (maintenanceUnits > 0) ...[
            const SizedBox(width: 12),
            _buildKpiCard(
              count: maintenanceUnits,
              countColor: const Color(0xFF475569),
              title: 'PERAWATAN',
              subtitle: 'Inspeksi & Maintenance',
              statusDotColor: const Color(0xFF64748B),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required int count,
    required Color countColor,
    required String title,
    required String subtitle,
    Color? statusDotColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (statusDotColor != null) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusDotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: countColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterAndControlsRow() {
    final statusItems = [
      {'label': 'Semua', 'count': _summary['total'] ?? 24},
      {'label': 'Tersedia', 'count': _summary['tersedia'] ?? 18},
      {'label': 'Disewa', 'count': _summary['disewa'] ?? 5},
      {'label': 'Perawatan', 'count': _summary['maintenance'] ?? 1},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status Pills
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statusItems.map((item) {
                  final label = item['label'] as String;
                  final count = item['count'] as int;
                  final isSelected = _selectedStatus == label;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedStatus = label);
                        _loadData();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF4A154B) : Colors.white,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4A154B) : const Color(0xFFE2E8F0),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF6B21A8) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right side: Branch Dropdown + Sort + View Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Branch Dropdown
              _buildBranchDropdown(),
              const SizedBox(width: 8),

              // Sort Dropdown
              PopupMenuButton<String>(
                onSelected: (val) {
                  setState(() => _selectedSort = val);
                  _loadData();
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'bh_desc',
                    child: Text('Battery Health (Tertinggi)', style: TextStyle(fontSize: 12.5)),
                  ),
                  const PopupMenuItem(
                    value: 'bh_asc',
                    child: Text('Battery Health (Terendah)', style: TextStyle(fontSize: 12.5)),
                  ),
                  const PopupMenuItem(
                    value: 'name_asc',
                    child: Text('Model iPhone (A - Z)', style: TextStyle(fontSize: 12.5)),
                  ),
                  const PopupMenuItem(
                    value: 'asset_asc',
                    child: Text('Kode Aset (A - Z)', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Urutkan: ${_getSortLabel()}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // View Switcher Pill
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isGridView = true),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isGridView ? const Color(0xFFEFF6FF) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: _isGridView ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                    InkWell(
                      onTap: () => setState(() => _isGridView = false),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: !_isGridView ? const Color(0xFFEFF6FF) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                        ),
                        child: Icon(
                          Icons.view_list_rounded,
                          size: 16,
                          color: !_isGridView ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitCardsGridTablet() {
    if (!_isGridView) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        itemCount: _units.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildUnitCard(_units[index]),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
        final rows = <List<IphoneModel>>[];
        for (var i = 0; i < _units.length; i += crossAxisCount) {
          rows.add(_units.sublist(i, (i + crossAxisCount).clamp(0, _units.length)));
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, rowIndex) {
            final rowUnits = rows[rowIndex];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < crossAxisCount; c++)
                  if (c < rowUnits.length)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: c == 0 ? 0 : 8,
                          right: c == crossAxisCount - 1 ? 0 : 8,
                        ),
                        child: _buildUnitCard(rowUnits[c]),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // CARD COMPONENT (TABLET & MOBILE)
  // =========================================================================

  Widget _buildUnitCard(IphoneModel unit) {
    final activeBooking = _activeBookings[unit.id] ??
        widget.repository.getActiveBookingForUnitSync(unit.assetCode, unitId: unit.id, serialNumber: unit.serialNumber);
    final statusLower = unit.status.toLowerCase();
    final isOverdue = statusLower == 'terlambat' ||
        statusLower == 'overdue' ||
        statusLower == 'late';
    final isUnitRented = !isOverdue && (statusLower == 'disewa' ||
        statusLower == 'rented' ||
        activeBooking != null ||
        (unit.customerName != null && unit.customerName!.isNotEmpty));
    final effectiveStatus = isOverdue
        ? 'terlambat'
        : (isUnitRented ? 'disewa' : unit.status);
    final bhColor = _getBatteryColor(unit.batteryHealth);
    final statusColor = _getStatusColor(effectiveStatus);
    final statusBg = _getStatusBgColor(effectiveStatus);
    final isMaintenance = effectiveStatus.toLowerCase() == 'perawatan' || effectiveStatus.toLowerCase() == 'maintenance';
    final isRented = isUnitRented;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Model & Specs (Left) + Status & Branch & Overflow Menu (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Model & Specs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit.storage.isNotEmpty ? '${unit.storage} • ${unit.color}' : unit.color,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status Badge & Branch Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusLabel(effectiveStatus),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBranchBadge(unit.branchName ?? unit.affiliateName),
                ],
              ),
              const SizedBox(width: 4),

              // Overflow Menu (•••)
              PopupMenuButton<String>(
                tooltip: 'Opsi Unit',
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (value) {
                  if (value == 'print') {
                    _printBarcode(unit);
                  } else if (value == 'edit') {
                    _showEditUnitDialog(unit);
                  } else if (value == 'return') {
                    _handlePengembalian(unit);
                  } else if (value == 'delete') {
                    _confirmDeleteUnit(unit);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'print',
                    height: 38,
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Cetak Barcode / Label', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    height: 38,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Edit Unit', style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (isOverdue || isRented)
                    const PopupMenuItem(
                      value: 'return',
                      height: 38,
                      child: Row(
                        children: [
                          Icon(Icons.assignment_return_outlined, size: 16, color: Color(0xFF475569)),
                          SizedBox(width: 8),
                          Text('Pengembalian Unit', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 38,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('Hapus Unit', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Identifiers Box: Asset Code | Serial Number | Battery Health (inline, no progress bar, no grid icon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if (unit.isAddon) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD8B4FE)),
                    ),
                    child: const Text(
                      'ADD-ON',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7E22CE),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  unit.assetCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 12, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SN: ${unit.serialNumber}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 12, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 8),
                Text(
                  'BH: ${unit.batteryHealth}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: bhColor,
                  ),
                ),
              ],
            ),
          ),

          // Context Box: Active Rental Info (if Disewa or Terlambat) or Maintenance Note (if Perawatan)
          if (isOverdue || isRented)
            _buildActiveRentalBox(unit, activeBooking, isOverdue: isOverdue)
          else if (isMaintenance)
            _buildMaintenanceBox(unit)
          else
            const SizedBox(height: 10),

          // Single Contextual Primary Action Button
          _buildContextualActionButton(unit, isOverdue: isOverdue, isRented: isRented, isMaintenance: isMaintenance),
        ],
      ),
    );
  }

  Widget _buildContextualActionButton(IphoneModel unit, {required bool isOverdue, required bool isRented, required bool isMaintenance}) {
    if (isOverdue || isRented) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.info_outline_rounded, size: 16),
          label: const Text(
            'Detail Rental',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _showUnitDetail(unit),
        ),
      );
    }

    if (isMaintenance) {
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF059669)),
          label: const Text(
            'Selesai Servis',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF059669), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _handleSelesaiServis(unit),
        ),
      );
    }

    // Default: Tersedia
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.receipt_long_rounded, size: 16),
        label: const Text(
          'Booking Unit',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        onPressed: () => _handleBookingKasir(unit),
      ),
    );
  }

  Widget _buildBranchBadge(String? branchName) {
    final rawName = (branchName != null && branchName.trim().isNotEmpty)
        ? branchName.trim()
        : '-';

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        rawName,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildActiveRentalBox(IphoneModel unit, BookingModel? activeBooking, {bool isOverdue = false}) {
    final customer = (unit.customerName != null && unit.customerName!.isNotEmpty)
        ? unit.customerName!
        : (activeBooking?.customerName ?? 'Pelanggan');

    String code = '';
    if (unit.bookingCode != null && unit.bookingCode!.isNotEmpty) {
      code = unit.bookingCode!;
    } else if (activeBooking != null && activeBooking.bookingCode.isNotEmpty) {
      final raw = activeBooking.bookingCode.replaceFirst('#', '').trim();
      code = '#$raw';
    } else {
      code = '#SKY-${unit.assetCode}';
    }

    String schedule = '';
    if (unit.returnScheduleText != null && unit.returnScheduleText!.isNotEmpty) {
      schedule = unit.returnScheduleText!;
    } else if (activeBooking != null) {
      final dateStr = Formatters.date(activeBooking.endDate);
      final timeStr = activeBooking.endTime ?? '14:00 WIB';
      final jaminan = activeBooking.jaminanType.isNotEmpty ? ' (${activeBooking.jaminanType})' : '';
      schedule = isOverdue
          ? 'Terlambat: Harusnya $dateStr • $timeStr$jaminan'
          : 'Kembali: $dateStr • $timeStr$jaminan';
    } else {
      schedule = isOverdue
          ? 'Terlambat: Harusnya batas sewa hari ini'
          : 'Kembali: Batas sewa hari ini';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isOverdue ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Customer: $customer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOverdue ? const Color(0xFF991B1B) : const Color(0xFF78350F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                code,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isOverdue ? const Color(0xFF991B1B) : const Color(0xFF78350F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                isOverdue ? Icons.warning_amber_rounded : Icons.access_time_rounded,
                size: 12,
                color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFFD97706),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  schedule,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.w600,
                    color: isOverdue ? const Color(0xFFB91C1C) : const Color(0xFF92400E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceBox(IphoneModel unit) {
    final note = unit.maintenanceNote ?? 'Ganti tempered glass & deep cleaning port audio/charging.';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFE11D48)),
              SizedBox(width: 4),
              Text(
                'Inspeksi Servis:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFBE123C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF475569),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        // Top Section: 4 Metric Cards as Status Filter Selectors
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              _buildMobileMetricCard(
                label: 'Total Unit',
                count: _summary['total'] ?? _units.length,
                icon: Icons.devices_rounded,
                color: const Color(0xFF7C3AED),
                isSelected: _selectedStatus.toLowerCase() == 'semua',
                onTap: () {
                  setState(() => _selectedStatus = 'Semua');
                  _loadData(resetPagination: true);
                },
              ),
              const SizedBox(width: 6),
              _buildMobileMetricCard(
                label: 'Tersedia',
                count: _summary['tersedia'] ?? 0,
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF059669),
                isSelected: _selectedStatus.toLowerCase() == 'tersedia',
                onTap: () {
                  setState(() => _selectedStatus = 'Tersedia');
                  _loadData(resetPagination: true);
                },
              ),
              const SizedBox(width: 6),
              _buildMobileMetricCard(
                label: 'Disewa',
                count: _summary['disewa'] ?? 0,
                icon: Icons.access_time_rounded,
                color: const Color(0xFFD97706),
                isSelected: _selectedStatus.toLowerCase() == 'disewa',
                onTap: () {
                  setState(() => _selectedStatus = 'Disewa');
                  _loadData(resetPagination: true);
                },
              ),
              const SizedBox(width: 6),
              _buildMobileMetricCard(
                label: 'Terlambat',
                count: _summary['terlambat'] ?? 0,
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFDC2626),
                isSelected: _selectedStatus.toLowerCase() == 'terlambat' || _selectedStatus.toLowerCase() == 'overdue',
                onTap: () {
                  setState(() => _selectedStatus = 'Terlambat');
                  _loadData(resetPagination: true);
                },
              ),
              if ((_summary['maintenance'] ?? 0) > 0) ...[
                const SizedBox(width: 6),
                _buildMobileMetricCard(
                  label: 'Perawatan',
                  count: _summary['maintenance'] ?? 0,
                  icon: Icons.block_flipped,
                  color: const Color(0xFFE11D48),
                  isSelected: _selectedStatus.toLowerCase() == 'perawatan' || _selectedStatus.toLowerCase() == 'maintenance',
                  onTap: () {
                    setState(() => _selectedStatus = 'Perawatan');
                    _loadData(resetPagination: true);
                  },
                ),
              ],
            ],
          ),
        ),

        // Search bar (Full width with integrated QR and Sort button)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      hintText: 'Cari iPhone, kode aset, SN, penyewa...',
                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      _searchDebounceTimer?.cancel();
                      _searchController.clear();
                      _loadData(resetPagination: true);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF475569)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: 'Scan Barcode',
                  onPressed: _openBarcodeScannerModal,
                ),
                _buildMobileSortIconButton(),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),

        // Sleek "Semua Cabang (X)" Dropdown beneath search row (compact, height: 40px)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _buildBranchDropdown(isCompact: true, height: 40),
        ),

        // Unit list (with 80px bottom padding so FAB never obscures last card)
        Expanded(
          child: _isLoading
              ? const UnitStatusListSkeleton(itemCount: 4)
              : _errorMessage != null
                  ? _buildErrorState()
                  : _units.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                          itemCount: _units.length + ((_hasMore || _isLoadingMore) ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index >= _units.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: _isLoadingMore
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : OutlinedButton(
                                          onPressed: _loadMoreUnits,
                                          child: Text('Muat Lebih Banyak (${_units.length} dari $_totalUnitCount)'),
                                        ),
                                ),
                              );
                            }
                            return _buildUnitCard(_units[index]);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildMobileMetricCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.18),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.20),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: color),
                      const SizedBox(width: 3),
                      Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : color.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileSortIconButton() {
    return PopupMenuButton<String>(
      tooltip: 'Urutkan',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: const Icon(Icons.sort_rounded, size: 20, color: Color(0xFF475569)),
      onSelected: (val) {
        setState(() => _selectedSort = val);
        _loadData(resetPagination: true);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'bh_desc',
          child: Text('Battery Health (Tertinggi)', style: TextStyle(fontSize: 12.5)),
        ),
        const PopupMenuItem(
          value: 'bh_asc',
          child: Text('Battery Health (Terendah)', style: TextStyle(fontSize: 12.5)),
        ),
        const PopupMenuItem(
          value: 'name_asc',
          child: Text('Model iPhone (A - Z)', style: TextStyle(fontSize: 12.5)),
        ),
        const PopupMenuItem(
          value: 'asset_asc',
          child: Text('Kode Aset (A - Z)', style: TextStyle(fontSize: 12.5)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_iphone_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Tidak ada unit iPhone ditemukan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba sesuaikan kata kunci atau filter status',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _selectedStatus = 'Semua';
                  _selectedModel = 'Semua';
                  final isAffUser = AuthService().isAffiliate || AuthService().isAffiliateAdmin || (AuthService().affiliateId != null && !AuthService().isSuperAdmin);
                  _selectedAffiliate = (isAffUser && _affiliates.isNotEmpty)
                      ? _affiliates.first.name
                      : 'Semua Cabang';
                });
                _loadData();
              },
              child: const Text('Reset Filter'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // BRANCH DROPDOWN & SORT CONTROLS
  // =========================================================================

  Widget _buildBranchDropdown({bool isCompact = false, double? height}) {
    final totalUnits = _affiliates.isNotEmpty
        ? _affiliates.fold<int>(0, (sum, a) => sum + a.iphonesCount)
        : (_summary['total'] ?? _units.length);
    final isAffAdmin = AuthService().isAffiliate || AuthService().isAffiliateAdmin || (AuthService().affiliateId != null && !AuthService().isSuperAdmin);

    final items = <DropdownMenuItem<String>>[
      if (!isAffAdmin)
        DropdownMenuItem<String>(
          value: 'Semua Cabang',
          child: Text(
            'Semua Cabang ($totalUnits)',
            style: TextStyle(
              fontSize: isCompact ? 12 : 12.5,
              fontWeight: _selectedAffiliate == 'Semua Cabang' ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ..._affiliates.map((aff) {
        final count = aff.iphonesCount;
        return DropdownMenuItem<String>(
          value: aff.name,
          child: Text(
            '${aff.name} ($count)',
            style: TextStyle(
              fontSize: isCompact ? 12 : 12.5,
              fontWeight: _selectedAffiliate == aff.name ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    ];

    // Ensure _selectedAffiliate matches one of the items
    final validValues = isAffAdmin
        ? _affiliates.map((a) => a.name).toList()
        : ['Semua Cabang', ..._affiliates.map((a) => a.name)];
    final currentValue = validValues.contains(_selectedAffiliate)
        ? _selectedAffiliate
        : (validValues.isNotEmpty ? validValues.first : 'Semua Cabang');

    return Container(
      height: height ?? (isCompact ? 36 : 38),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isAffAdmin ? const Color(0xFFF1F5F9) : Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          icon: isAffAdmin
              ? const SizedBox.shrink()
              : const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          isDense: true,
          isExpanded: isCompact,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          elevation: 3,
          style: TextStyle(
            fontSize: isCompact ? 12 : 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
          items: items,
          onChanged: (isAffAdmin || validValues.length <= 1)
              ? null
              : (val) {
                  if (val != null) {
                    setState(() => _selectedAffiliate = val);
                    _loadData();
                  }
                },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Data Unit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat mengambil inventaris unit iPhone.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              onPressed: _loadData,
            ),
          ],
        ),
      ),
    );
  }
}
