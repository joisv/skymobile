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
import 'widgets/unit_status_filter_chips.dart';
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
  Map<String, int> _affiliateUnitCounts = {};

  // Cache active bookings for rented units: assetCode -> BookingModel
  final Map<String, BookingModel?> _activeBookings = {};

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
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await widget.repository.getUnitStatusSummary();
      var affiliates = await widget.repository.getAffiliates();
      final allUnits = await widget.repository.getAllInventoryUnits();

      // If affiliates list from repository is empty, infer from actual inventory units so dropdown is populated
      if (affiliates.isEmpty) {
        final seen = <String>{};
        final inferred = <AffiliateModel>[];
        for (final u in allUnits) {
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

      final isAffiliateUser = AuthService().isAffiliate || AuthService().isAffiliateAdmin || (AuthService().affiliateId != null && !AuthService().isSuperAdmin);
      if (isAffiliateUser) {
        final myAffId = AuthService().currentUser?.affiliateId ?? AuthService().affiliateId;
        if (myAffId != null) {
          affiliates = affiliates.where((a) => a.id == myAffId).toList();
        }
        if (affiliates.isNotEmpty && (_selectedAffiliate == 'Semua Cabang' || !affiliates.any((a) => a.name == _selectedAffiliate))) {
          _selectedAffiliate = affiliates.first.name;
        }
      }

      // Compute dynamic branch counts from actual inventory
      final branchCounts = <String, int>{};
      for (final aff in affiliates) {
        final count = allUnits.where((u) {
          if (u.affiliateId != null && u.affiliateId == aff.id) return true;
          final b = (u.branchName ?? u.affiliateName ?? '').toLowerCase();
          return b.contains(aff.name.toLowerCase()) || b.contains(aff.code.toLowerCase());
        }).length;
        branchCounts[aff.name] = count;
      }

      int? filterAffiliateId;
      if (isAffiliateUser) {
        filterAffiliateId = AuthService().currentUser?.affiliateId ?? AuthService().affiliateId;
      } else if (_selectedAffiliate != 'Semua Cabang') {
        final match = affiliates.where((a) => a.name.toLowerCase() == _selectedAffiliate.toLowerCase()).firstOrNull;
        filterAffiliateId = match?.id;
      }

      final units = await widget.repository.getAllInventoryUnits(
        query: _searchController.text,
        statusFilter: _selectedStatus == 'Semua' ? null : _selectedStatus,
        modelFilter: _selectedModel == 'Semua' ? null : _selectedModel,
        branchFilter: _selectedAffiliate == 'Semua Cabang' ? null : _selectedAffiliate,
        affiliateId: filterAffiliateId,
        sortBy: _selectedSort,
      );

      // Pre-fetch active booking for units that are rented/disewa
      for (final unit in units) {
        final s = unit.status.toLowerCase();
        if (s == 'disewa' || s == 'rented' || widget.repository.isUnitCurrentlyRented(unit.assetCode) || (unit.customerName != null && unit.customerName!.isNotEmpty)) {
          final booking = await widget.repository.getActiveBookingForUnit(unit.assetCode);
          _activeBookings[unit.assetCode] = booking;
        }
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _affiliates = affiliates;
          _affiliateUnitCounts = branchCounts;
          _units = units;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
        return const Color(0xFF059669); // Emerald Green
      case 'disewa':
      case 'rented':
        return const Color(0xFFD97706); // Amber / Orange
      case 'terlambat':
      case 'overdue':
      case 'late':
        return const Color(0xFFDC2626); // Crimson Red
      case 'maintenance':
      case 'perawatan':
        return const Color(0xFFE11D48); // Rose / Red
      case 'dibooking':
      case 'booked':
        return const Color(0xFF2563EB); // Blue
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
      case 'ready':
        return const Color(0xFFECFDF5);
      case 'disewa':
      case 'rented':
        return const Color(0xFFFEF3C7);
      case 'terlambat':
      case 'overdue':
      case 'late':
        return const Color(0xFFFEF2F2);
      case 'maintenance':
      case 'perawatan':
        return const Color(0xFFFEE2E2);
      case 'dibooking':
      case 'booked':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFF1F5F9);
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
    var activeBooking = _activeBookings[unit.assetCode] ??
        widget.repository.getActiveBookingForUnitSync(unit.assetCode);
    if (activeBooking == null) {
      activeBooking = await widget.repository.getActiveBookingForUnit(unit.assetCode);
      if (activeBooking != null) {
        _activeBookings[unit.assetCode] = activeBooking;
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
        await widget.repository.updateUnitStatus(unit.assetCode, 'tersedia');
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
    final activeBooking = _activeBookings[unit.assetCode];
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
      await widget.repository.updateUnitStatus(unit.assetCode, 'tersedia');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit ${unit.assetCode} berhasil kembali ke status Tersedia'),
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
      await widget.repository.deleteInventoryUnit(unit.assetCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit ${unit.assetCode} berhasil dihapus'),
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
                          onChanged: (_) => _loadData(),
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
                            _searchController.clear();
                            _loadData();
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
              // + Tambah iPhone Baru button (Hanya super-admin dan admin)
              if (AuthService().canCreateIphone) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    '+ Tambah iPhone Baru',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    elevation: 0,
                  ),
                  onPressed: _showAddUnitDialog,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildKpiCard(
            icon: Icons.desktop_windows_outlined,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFFAF5FF),
            borderColor: const Color(0xFFE9D5FF),
            count: totalUnits,
            countColor: const Color(0xFF6B21A8),
            title: 'TOTAL UNIT',
            subtitle: _selectedAffiliate == 'Semua Cabang'
                ? 'Terdaftar di Gerai Gandaria'
                : 'Terdaftar di $_selectedAffiliate',
            titleColor: const Color(0xFF6B21A8),
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFA7F3D0),
            count: readyUnits,
            countColor: const Color(0xFF059669),
            title: 'TERSEDIA',
            subtitle: 'Siap Sewa / Ready Stock',
            titleColor: const Color(0xFF059669),
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            icon: Icons.access_time_rounded,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            count: rentedUnits,
            countColor: const Color(0xFFD97706),
            title: 'DISEWA',
            subtitle: 'Sedang Digunakan Customer',
            titleColor: const Color(0xFFD97706),
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
            count: lateUnits,
            countColor: const Color(0xFFDC2626),
            title: 'TERLAMBAT',
            subtitle: 'Melewati Batas Sewa',
            titleColor: const Color(0xFFDC2626),
          ),
          if (maintenanceUnits > 0) ...[
            const SizedBox(width: 14),
            _buildKpiCard(
              icon: Icons.block_flipped,
              iconColor: const Color(0xFFE11D48),
              iconBg: const Color(0xFFFFF1F2),
              borderColor: const Color(0xFFFECDD3),
              count: maintenanceUnits,
              countColor: const Color(0xFFE11D48),
              title: 'PERAWATAN',
              subtitle: 'Inspeksi & Maintenance',
              titleColor: const Color(0xFFE11D48),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    required int count,
    required Color countColor,
    required String title,
    required String subtitle,
    required Color titleColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: countColor,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: titleColor.withValues(alpha: 0.75),
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
    final activeBooking = _activeBookings[unit.assetCode] ?? widget.repository.getActiveBookingForUnitSync(unit.assetCode);
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
    final outlineColor = isOverdue ? const Color(0xFFDC2626) : _getModelOutlineColor(unit);
    final isMaintenance = effectiveStatus.toLowerCase() == 'perawatan' || effectiveStatus.toLowerCase() == 'maintenance';
    final isRented = isUnitRented;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? const Color(0xFFFECACA)
              : (isMaintenance ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
          width: (isOverdue || isMaintenance) ? 1.5 : 1.0,
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
          // Header: Icon + Model/Storage + Status Badge & Branch Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Outline Icon Box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: outlineColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: outlineColor.withValues(alpha: 0.25)),
                ),
                child: Icon(
                  Icons.phone_iphone_rounded,
                  color: outlineColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),

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
                      '${unit.storage} • ${unit.color}',
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
            ],
          ),
          const SizedBox(height: 12),

          // Identifiers Box: Asset Code | Serial Number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          unit.assetCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 12, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      const Text('#', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          unit.serialNumber,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: Color(0xFF64748B),
                          ),
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

          // Context Box: Active Rental Info (if Disewa or Terlambat) or Maintenance Note (if Perawatan)
          if (isOverdue || isRented)
            _buildActiveRentalBox(unit, activeBooking, isOverdue: isOverdue)
          else if (isMaintenance)
            _buildMaintenanceBox(unit)
          else
            const SizedBox(height: 8),

          // Battery Health Bar
          Row(
            children: [
              Text(
                'BH: ${unit.batteryHealth}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: bhColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (unit.batteryHealth / 100.0).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(bhColor),
                    minHeight: 5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons Row
          if (isOverdue || isRented)
            _buildRentedActions(unit, isOverdue: isOverdue)
          else if (isMaintenance)
            _buildMaintenanceActions(unit)
          else
            _buildTersediaActions(unit),
        ],
      ),
    );
  }

  Widget _buildBranchBadge(String? branchName) {
    final rawName = (branchName != null && branchName.trim().isNotEmpty)
        ? branchName.trim()
        : '-';

    Color borderColor;
    Color bgColor;
    Color textColor;
    Color iconColor;
    IconData icon;

    final b = rawName.toLowerCase();
    if (b.contains('purwoharjo')) {
      borderColor = const Color(0xFFFDE68A);
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFB45309);
      iconColor = const Color(0xFFD97706);
      icon = Icons.location_on_rounded;
    } else if (b.contains('genteng')) {
      borderColor = const Color(0xFFE9D5FF);
      bgColor = const Color(0xFFFAF5FF);
      textColor = const Color(0xFF6B21A8);
      iconColor = const Color(0xFF7C3AED);
      icon = Icons.location_on_rounded;
    } else if (b.contains('siliragung')) {
      borderColor = const Color(0xFFA7F3D0);
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF047857);
      iconColor = const Color(0xFF059669);
      icon = Icons.location_on_rounded;
    } else if (rawName == '-') {
      borderColor = const Color(0xFFE2E8F0);
      bgColor = const Color(0xFFF8FAFC);
      textColor = const Color(0xFF64748B);
      iconColor = const Color(0xFF94A3B8);
      icon = Icons.storefront_outlined;
    } else {
      borderColor = const Color(0xFFC7D2FE);
      bgColor = const Color(0xFFEEF2FF);
      textColor = const Color(0xFF4338CA);
      iconColor = const Color(0xFF6366F1);
      icon = Icons.location_on_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9.5, color: iconColor),
          const SizedBox(width: 3.5),
          Text(
            rawName,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
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

  Widget _buildTersediaActions(IphoneModel unit) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.receipt_long_rounded, size: 14),
            label: const Text('Booking Kasir', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              elevation: 0,
            ),
            onPressed: () => _handleBookingKasir(unit),
          ),
        ),
        const SizedBox(width: 6),
        _buildQuickIconButton(
          icon: Icons.print_outlined,
          tooltip: 'Cetak Barcode / Label',
          onPressed: () => _printBarcode(unit),
        ),
        const SizedBox(width: 4),
        _buildQuickIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit Unit',
          onPressed: () => _showEditUnitDialog(unit),
        ),
        const SizedBox(width: 4),
        _buildQuickIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Hapus Unit',
          onPressed: () => _confirmDeleteUnit(unit),
        ),
      ],
    );
  }

  Widget _buildRentedActions(IphoneModel unit, {bool isOverdue = false}) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_upward_rounded, size: 14),
            label: Text(
              isOverdue ? 'Kembalikan (Telat)' : 'Pengembalian',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOverdue ? const Color(0xFFDC2626) : const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              elevation: 0,
            ),
            onPressed: () => _handlePengembalian(unit),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onPressed: () => _showUnitDetail(unit),
          child: const Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 4),
        _buildQuickIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit Unit',
          onPressed: () => _showEditUnitDialog(unit),
        ),
        const SizedBox(width: 4),
        _buildQuickIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Hapus Unit',
          onPressed: () => _confirmDeleteUnit(unit),
        ),
      ],
    );
  }

  Widget _buildMaintenanceActions(IphoneModel unit) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 14, color: Color(0xFF059669)),
            label: const Text('Selesai Servis', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF059669), width: 1.2),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onPressed: () => _handleSelesaiServis(unit),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFFFF1F2),
            foregroundColor: const Color(0xFFE11D48),
            side: const BorderSide(color: Color(0xFFFECDD3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onPressed: () => _showServiceLogDialog(unit),
          child: const Text('Log Servis', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 4),
        _buildQuickIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit Unit',
          onPressed: () => _showEditUnitDialog(unit),
        ),
        const SizedBox(width: 4),
        _buildQuickIconButton(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Hapus Unit',
          onPressed: () => _confirmDeleteUnit(unit),
        ),
      ],
    );
  }

  Widget _buildQuickIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 14, color: const Color(0xFF64748B)),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPressed,
      ),
    );
  }

  // =========================================================================
  // MOBILE BODY
  // =========================================================================

  Widget _buildMobileBody() {
    return Column(
      children: [
        // Mobile summary row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              _buildMobileMetricCard('Total Unit', _summary['total'] ?? _units.length, Icons.devices_rounded, const Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              _buildMobileMetricCard('Tersedia', _summary['tersedia'] ?? 0, Icons.check_circle_outline_rounded, const Color(0xFF059669)),
              const SizedBox(width: 6),
              _buildMobileMetricCard('Disewa', _summary['disewa'] ?? 0, Icons.access_time_rounded, const Color(0xFFD97706)),
              const SizedBox(width: 6),
              _buildMobileMetricCard('Terlambat', _summary['terlambat'] ?? 0, Icons.warning_amber_rounded, const Color(0xFFDC2626)),
              if ((_summary['maintenance'] ?? 0) > 0) ...[
                const SizedBox(width: 6),
                _buildMobileMetricCard('Perawatan', _summary['maintenance'] ?? 0, Icons.block_flipped, const Color(0xFFE11D48)),
              ],
            ],
          ),
        ),

        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
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
                          onChanged: (_) => _loadData(),
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
                            _searchController.clear();
                            _loadData();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF475569)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        tooltip: 'Scan Barcode',
                        onPressed: _openBarcodeScannerModal,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
              if (AuthService().canCreateIphone) ...[
                const SizedBox(width: 10),
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                    tooltip: 'Tambah iPhone',
                    onPressed: _showAddUnitDialog,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Filter status
        UnitStatusFilterChips(
          selectedStatus: _selectedStatus,
          counts: _summary,
          onStatusSelected: (status) {
            setState(() => _selectedStatus = status);
            _loadData();
          },
        ),

        // Branch & Sort Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _buildBranchDropdown(isCompact: true),
              ),
              const SizedBox(width: 8),
              _buildMobileSortButton(),
            ],
          ),
        ),

        // Unit list
        Expanded(
          child: _isLoading
              ? const UnitStatusListSkeleton(itemCount: 4)
              : _errorMessage != null
                  ? _buildErrorState()
                  : _units.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _units.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildUnitCard(_units[index]),
                        ),
        ),
      ],
    );
  }

  Widget _buildMobileMetricCard(String label, int count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.85)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

  Widget _buildBranchDropdown({bool isCompact = false}) {
    final totalUnits = _summary['total'] ?? _units.length;
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
        final count = _affiliateUnitCounts[aff.name] ?? _units.length;
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
      height: isCompact ? 36 : 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isAffAdmin ? const Color(0xFFF1F5F9) : Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildMobileSortButton() {
    return PopupMenuButton<String>(
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
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 16, color: Color(0xFF64748B)),
            SizedBox(width: 4),
            Text(
              'Urutkan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
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
