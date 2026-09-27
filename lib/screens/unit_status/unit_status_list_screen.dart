import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
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
  Map<String, int> _summary = {
    'total': 24,
    'tersedia': 18,
    'disewa': 5,
    'maintenance': 1,
    'dibooking': 0,
  };
  Map<String, int> _branchCounts = {
    'genteng': 2,
    'siliragung': 2,
    'purwoharjo': 2,
  };

  // Cache active bookings for rented units: assetCode -> BookingModel
  final Map<String, BookingModel?> _activeBookings = {};

  bool _isLoading = true;
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
    setState(() => _isLoading = true);

    try {
      final summary = await widget.repository.getUnitStatusSummary();
      final allUnits = await widget.repository.getAllInventoryUnits();

      // Compute dynamic branch counts
      final branchCounts = <String, int>{'genteng': 0, 'siliragung': 0, 'purwoharjo': 0};
      for (final u in allUnits) {
        final b = (u.branchName ?? '').toLowerCase();
        if (b.contains('genteng')) branchCounts['genteng'] = (branchCounts['genteng'] ?? 0) + 1;
        if (b.contains('siliragung')) branchCounts['siliragung'] = (branchCounts['siliragung'] ?? 0) + 1;
        if (b.contains('purwoharjo')) branchCounts['purwoharjo'] = (branchCounts['purwoharjo'] ?? 0) + 1;
      }

      final units = await widget.repository.getAllInventoryUnits(
        query: _searchController.text,
        statusFilter: _selectedStatus == 'Semua' ? null : _selectedStatus,
        modelFilter: _selectedModel == 'Semua' ? null : _selectedModel,
        branchFilter: _selectedAffiliate == 'Semua Cabang' ? null : _selectedAffiliate,
        sortBy: _selectedSort,
      );

      // Pre-fetch active booking for units that are rented/disewa
      for (final unit in units) {
        final s = unit.status.toLowerCase();
        if (s == 'disewa' || s == 'rented') {
          final booking = await widget.repository.getActiveBookingForUnit(unit.assetCode);
          _activeBookings[unit.assetCode] = booking;
        }
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _branchCounts = branchCounts;
          _units = units;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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

  void _handlePengembalian(IphoneModel unit) {
    final activeBooking = _activeBookings[unit.assetCode];
    Navigator.pushNamed(
      context,
      AppRoutes.returnInspection,
      arguments: activeBooking != null ? {'booking': activeBooking} : null,
    );
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
    final nameCtrl = TextEditingController(text: 'iPhone 15 Pro');
    final storageCtrl = TextEditingController(text: '256GB');
    final colorCtrl = TextEditingController(text: 'Black Titanium');
    final assetCtrl = TextEditingController(text: 'IPHSKY${DateTime.now().millisecond + 1000}');
    final snCtrl = TextEditingController(text: 'SN${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}');
    final bhCtrl = TextEditingController(text: '100');
    String selectedBranch = 'Purwoharjo';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0F172A)),
              SizedBox(width: 8),
              Text('Tambah iPhone Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Model iPhone', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: storageCtrl,
                        decoration: const InputDecoration(labelText: 'Kapasitas', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: colorCtrl,
                        decoration: const InputDecoration(labelText: 'Warna', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: assetCtrl,
                        decoration: const InputDecoration(labelText: 'Kode Aset', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: bhCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Battery Health (%)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: snCtrl,
                  decoration: const InputDecoration(labelText: 'Nomor Seri (Serial Number)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedBranch,
                  decoration: const InputDecoration(labelText: 'Cabang Affiliate', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Purwoharjo', child: Text('Purwoharjo')),
                    DropdownMenuItem(value: 'Genteng', child: Text('Genteng')),
                    DropdownMenuItem(value: 'Siliragung', child: Text('Siliragung')),
                    DropdownMenuItem(value: 'Gandaria', child: Text('Gandaria (Pusat)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedBranch = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newUnit = IphoneModel(
                  id: DateTime.now().millisecondsSinceEpoch % 10000,
                  name: nameCtrl.text.trim(),
                  storage: storageCtrl.text.trim(),
                  color: colorCtrl.text.trim(),
                  serialNumber: snCtrl.text.trim(),
                  assetCode: assetCtrl.text.trim(),
                  status: 'tersedia',
                  batteryHealth: int.tryParse(bhCtrl.text) ?? 100,
                  branchName: selectedBranch,
                );
                Navigator.pop(ctx);
                await widget.repository.addInventoryUnit(newUnit);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unit ${newUnit.fullName} (${newUnit.assetCode}) berhasil ditambahkan'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
                _loadData();
              },
              child: const Text('Simpan Unit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUnitDialog(IphoneModel unit) {
    final bhCtrl = TextEditingController(text: unit.batteryHealth.toString());
    String selectedStatus = unit.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Unit: ${unit.fullName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kode Aset: ${unit.assetCode} • SN: ${unit.serialNumber}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              TextField(
                controller: bhCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Battery Health (%)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus.toLowerCase(),
                decoration: const InputDecoration(labelText: 'Status Unit', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'tersedia', child: Text('Tersedia')),
                  DropdownMenuItem(value: 'disewa', child: Text('Disewa')),
                  DropdownMenuItem(value: 'perawatan', child: Text('Perawatan')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedStatus = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () async {
                final newBh = int.tryParse(bhCtrl.text);
                Navigator.pop(ctx);
                await widget.repository.updateUnitStatus(
                  unit.assetCode,
                  selectedStatus,
                  batteryHealth: newBh,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unit ${unit.assetCode} berhasil diperbarui'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
                _loadData();
              },
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
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
      appBar: isTablet ? _buildTabletAppBar(context) : _buildMobileAppBar(context),
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

          // Status Filter Pills with Counts + Sort Dropdown + Grid/List View Switcher
          _buildStatusFilterAndControlsRow(),

          // Affiliate Branch Filter Chips (AFFILIATE: [Semua Cabang] [• Genteng] ...)
          _buildAffiliateFilterRow(),

          const SizedBox(height: 8),

          // Inventory Cards Grid (3 Columns)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: UnitStatusListSkeleton(itemCount: 6),
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
              SizedBox(
                width: 260,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _loadData(),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                            hintText: 'Ketik model iPhone, kode ba...',
                            hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF94A3B8)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () {
                            _searchController.clear();
                            _loadData();
                          },
                        ),
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: InkWell(
                          onTap: _openBarcodeScannerModal,
                          child: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // + Tambah iPhone Baru button
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  '+ Tambah iPhone Baru',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  elevation: 0,
                ),
                onPressed: _showAddUnitDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardsTablet() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildKpiCard(
            icon: Icons.desktop_windows_outlined,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFFAF5FF),
            borderColor: const Color(0xFFE9D5FF),
            count: _summary['total'] ?? 24,
            countColor: const Color(0xFF6B21A8),
            title: 'TOTAL UNIT',
            subtitle: 'Terdaftar di Gerai Gandaria',
            titleColor: const Color(0xFF6B21A8),
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFA7F3D0),
            count: _summary['tersedia'] ?? 18,
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
            count: _summary['disewa'] ?? 5,
            countColor: const Color(0xFFD97706),
            title: 'DISEWA',
            subtitle: 'Sedang Digunakan Customer',
            titleColor: const Color(0xFFD97706),
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            icon: Icons.block_flipped,
            iconColor: const Color(0xFFE11D48),
            iconBg: const Color(0xFFFFF1F2),
            borderColor: const Color(0xFFFECDD3),
            count: _summary['maintenance'] ?? 1,
            countColor: const Color(0xFFE11D48),
            title: 'PERAWATAN',
            subtitle: 'Inspeksi & Maintenance',
            titleColor: const Color(0xFFE11D48),
          ),
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

          // Right side: Sort + View Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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

  Widget _buildAffiliateFilterRow() {
    final branches = [
      {'name': 'Semua Cabang', 'count': _summary['total'] ?? 24, 'dot': null},
      {'name': 'Genteng', 'count': _branchCounts['genteng'] ?? 2, 'dot': const Color(0xFF7C3AED)},
      {'name': 'Siliragung', 'count': _branchCounts['siliragung'] ?? 2, 'dot': const Color(0xFF10B981)},
      {'name': 'Purwoharjo', 'count': _branchCounts['purwoharjo'] ?? 2, 'dot': const Color(0xFFF59E0B)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF6366F1)),
                SizedBox(width: 4),
                Text(
                  'AFFILIATE:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            ...branches.map((b) {
              final name = b['name'] as String;
              final isSelected = _selectedAffiliate == name;
              final dotColor = b['dot'] as Color?;
              final count = b['count'] as int;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedAffiliate = name);
                    _loadData();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dotColor != null) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        if (dotColor != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
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
    final activeBooking = _activeBookings[unit.assetCode];
    final bhColor = _getBatteryColor(unit.batteryHealth);
    final statusColor = _getStatusColor(unit.status);
    final statusBg = _getStatusBgColor(unit.status);
    final outlineColor = _getModelOutlineColor(unit);
    final isMaintenance = unit.status.toLowerCase() == 'perawatan' || unit.status.toLowerCase() == 'maintenance';
    final isRented = unit.status.toLowerCase() == 'disewa' || unit.status.toLowerCase() == 'rented';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMaintenance ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
          width: isMaintenance ? 1.5 : 1.0,
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
                          _getStatusLabel(unit.status),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBranchBadge(unit.branchName),
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

          // Context Box: Active Rental Info (if Disewa) or Maintenance Note (if Perawatan)
          if (isRented)
            _buildActiveRentalBox(unit, activeBooking)
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
          if (isRented)
            _buildRentedActions(unit)
          else if (isMaintenance)
            _buildMaintenanceActions(unit)
          else
            _buildTersediaActions(unit),
        ],
      ),
    );
  }

  Widget _buildBranchBadge(String? branchName) {
    if (branchName == null || branchName.isEmpty) return const SizedBox.shrink();
    Color borderColor;
    Color bgColor;
    Color textColor;
    Color iconColor;

    final b = branchName.toLowerCase();
    if (b.contains('purwoharjo')) {
      borderColor = const Color(0xFFFDE68A);
      bgColor = const Color(0xFFFFFBEB);
      textColor = const Color(0xFFB45309);
      iconColor = const Color(0xFFD97706);
    } else if (b.contains('genteng')) {
      borderColor = const Color(0xFFE9D5FF);
      bgColor = const Color(0xFFFAF5FF);
      textColor = const Color(0xFF6B21A8);
      iconColor = const Color(0xFF7C3AED);
    } else {
      borderColor = const Color(0xFFA7F3D0);
      bgColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF047857);
      iconColor = const Color(0xFF059669);
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, size: 9, color: iconColor),
          const SizedBox(width: 3),
          Text(
            branchName,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRentalBox(IphoneModel unit, BookingModel? activeBooking) {
    final customer = unit.customerName ?? activeBooking?.customerName ?? 'Customer';
    final code = unit.bookingCode ?? (activeBooking != null ? '#${activeBooking.bookingCode}' : '#SKY-8421');
    final schedule = unit.returnScheduleText ??
        (activeBooking != null
            ? 'Kembali: ${Formatters.formatDateTime(activeBooking.endDate)}'
            : 'Kembali: Hari Ini');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF78350F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF78350F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFFD97706)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  schedule,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
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

  Widget _buildRentedActions(IphoneModel unit) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.arrow_upward_rounded, size: 14),
            label: const Text('Pengembalian', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
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
              _buildMobileMetricCard('Total Unit', _summary['total'] ?? 24, Icons.devices_rounded, const Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              _buildMobileMetricCard('Tersedia', _summary['tersedia'] ?? 18, Icons.check_circle_outline_rounded, const Color(0xFF059669)),
              const SizedBox(width: 6),
              _buildMobileMetricCard('Disewa', _summary['disewa'] ?? 5, Icons.access_time_rounded, const Color(0xFFD97706)),
              const SizedBox(width: 6),
              _buildMobileMetricCard('Perawatan', _summary['maintenance'] ?? 1, Icons.block_flipped, const Color(0xFFE11D48)),
            ],
          ),
        ),

        // Search bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _loadData(),
                  decoration: InputDecoration(
                    hintText: 'Cari iPhone, kode aset, SN...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                tooltip: 'Tambah iPhone',
                onPressed: _showAddUnitDialog,
              ),
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

        // Unit list
        Expanded(
          child: _isLoading
              ? const UnitStatusListSkeleton(itemCount: 4)
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
                  _selectedAffiliate = 'Semua Cabang';
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
          printerName = isConnected ? 'Thermal 58mm' : 'Printer';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isConnected ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.print_outlined,
                size: 14,
                color: isConnected ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 4),
              Text(
                printerName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isConnected ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
            ],
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
    final cashierName = user?.name.trim().isNotEmpty == true ? user!.name : 'Budi Santoso';

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SKYRental',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Status Unit iPhone',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155), size: 20),
                        tooltip: 'Segarkan Data',
                        onPressed: _loadData,
                      ),
                      const SizedBox(width: 6),
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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.account),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF0F172A),
                                  child: Text(
                                    cashierName.isNotEmpty
                                        ? cashierName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
                                        : 'BS',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
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
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.account),
                            child: Column(
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
                                const Text('Kasir • Shift Pagi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
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
                    'Status Unit iPhone',
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
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Segarkan Data',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _loadData,
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
