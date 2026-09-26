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
    'total': 0,
    'tersedia': 0,
    'disewa': 0,
    'maintenance': 0,
    'dibooking': 0,
  };

  // Cache active bookings for rented units: assetCode -> BookingModel
  final Map<String, BookingModel?> _activeBookings = {};

  bool _isLoading = true;
  String _selectedStatus = 'Semua';
  String _selectedModel = 'Semua';

  List<String> _modelOptions = ['Semua'];


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
      final units = await widget.repository.getAllInventoryUnits(
        query: _searchController.text,
        statusFilter: _selectedStatus == 'Semua' ? null : _selectedStatus,
        modelFilter: _selectedModel == 'Semua' ? null : _selectedModel,
      );

      // Pre-fetch active booking for units that are rented/disewa
      for (final unit in units) {
        final s = unit.status.toLowerCase();
        if (s == 'disewa' || s == 'rented') {
          final booking = await widget.repository.getActiveBookingForUnit(unit.assetCode);
          _activeBookings[unit.assetCode] = booking;
        }
      }

      // Populate unique model names dynamically from units
      final Set<String> models = {'Semua'};
      for (final u in units) {
        if (u.name.trim().isNotEmpty) {
          models.add(u.name.trim());
        }
      }
      final sortedModels = models.toList();
      if (!sortedModels.contains(_selectedModel)) {
        _selectedModel = 'Semua';
      }

      if (mounted) {
        setState(() {
          _summary = summary;
          _units = units;
          _modelOptions = sortedModels;
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
        return const Color(0xFF10B981); // Emerald Green
      case 'disewa':
      case 'rented':
        return const Color(0xFFF59E0B); // Amber / Orange
      case 'maintenance':
      case 'perawatan':
        return const Color(0xFFEF4444); // Red
      case 'dibooking':
      case 'booked':
        return const Color(0xFF3B82F6); // Blue
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
      case 'ready':
        return const Color(0xFFD1FAE5);
      case 'disewa':
      case 'rented':
        return const Color(0xFFFEF3C7);
      case 'maintenance':
      case 'perawatan':
        return const Color(0xFFFEE2E2);
      case 'dibooking':
      case 'booked':
        return const Color(0xFFDBEAFE);
      default:
        return AppTheme.cardBorder;
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
    if (batteryHealth >= 90) return const Color(0xFF10B981);
    if (batteryHealth >= 80) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  void _showUnitActionSheet(IphoneModel unit) {
    final activeBooking = _activeBookings[unit.assetCode];

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
              // Grab handle
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

              // Title & Status
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
                    child: Icon(Icons.phone_iphone_rounded,
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getStatusColor(unit.status),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Aset: ${unit.assetCode}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
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
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Details Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Nomor Seri (SN)', unit.serialNumber),
                    const SizedBox(height: 8),
                    _buildDetailRow('Kapasitas & Warna', '${unit.storage} • ${unit.color}'),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Battery Health',
                      '${unit.batteryHealth}%',
                      valueColor: _getBatteryColor(unit.batteryHealth),
                    ),
                  ],
                ),
              ),

              // If rented, display borrower info or rented alert banner
              if (activeBooking != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFFB45309)),
                          const SizedBox(width: 6),
                          Text(
                            'Penyewa Aktif: ${activeBooking.customerName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Booking: ${activeBooking.bookingCode} • ${Formatters.date(activeBooking.startDate)} s/d ${Formatters.date(activeBooking.endDate)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(
                              context,
                              AppRoutes.bookingDetail,
                              arguments: activeBooking,
                            ).then((_) => _loadData());
                          },
                          icon: const Icon(Icons.receipt_long_rounded, size: 16),
                          label: const Text('Buka Detail Booking Penyewa'),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (['rented', 'disewa'].contains(unit.status.toLowerCase().trim())) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(children: [
                      Icon(Icons.lock_clock_rounded, size: 20, color: Color(0xFFB45309)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unit sedang dalam masa sewa aktif. Unit tidak dapat disewa oleh pelanggan lain sampai proses pengembalian selesai.',
                          style: TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text('Ubah Status Unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Action Buttons for status change
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _handleStatusChangeRequest(unit, 'tersedia', ctx),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Tersedia'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _handleStatusChangeRequest(unit, 'maintenance', ctx),
                      icon: const Icon(Icons.build_outlined, size: 18),
                      label: const Text('Perawatan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(
                      context,
                      AppRoutes.unitSchedule,
                      arguments: unit,
                    ).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Lihat Jadwal Sewa Unit'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: BorderSide(color: AppTheme.accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showBatteryHealthDialog(unit);
                  },
                  icon: const Icon(Icons.battery_charging_full_rounded, size: 18),
                  label: const Text('Perbarui Battery Health'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _handleStatusChangeRequest(IphoneModel unit, String newStatus, BuildContext ctx) async {
    final isRented = ['rented', 'disewa'].contains(unit.status.toLowerCase().trim());
    final activeBooking = _activeBookings[unit.assetCode];

    if (newStatus == 'tersedia' && (isRented || activeBooking != null)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Konfirmasi Ubah Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Unit ${unit.fullName} (${unit.assetCode}) saat ini tercatat sedang disewa${activeBooking != null ? ' oleh ${activeBooking.customerName}' : ''}. Mengubah status secara manual ke Tersedia tidak membatalkan masa sewa aktif. Yakin ingin melanjutkan?',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Ya, Ubah'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (!ctx.mounted) return;
    await _updateStatus(unit.assetCode, newStatus, ctx);
  }

  Future<void> _updateStatus(String assetCode, String newStatus, BuildContext ctx) async {
    Navigator.pop(ctx);
    try {
      await widget.repository.updateUnitStatus(assetCode, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status unit $assetCode berhasil diubah ke ${_getStatusLabel(newStatus)}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBatteryHealthDialog(IphoneModel unit) {
    final bhController = TextEditingController(text: unit.batteryHealth.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Update BH: ${unit.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kode Aset: ${unit.assetCode}'),
              const SizedBox(height: 12),
              TextField(
                controller: bhController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Battery Health (%)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newBh = int.tryParse(bhController.text);
                if (newBh != null && newBh >= 50 && newBh <= 100) {
                  Navigator.pop(ctx);
                  await widget.repository.updateUnitStatus(
                    unit.assetCode,
                    unit.status,
                    batteryHealth: newBh,
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Masukkan persentase BH valid (50 - 100%)'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: isTablet ? _buildTabletAppBar(context) : _buildMobileAppBar(context),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // Top Summary Cards
            _buildSummaryHeader(),

            // Search Bar
            _buildSearchBar(),

            // Filter Chips (Status & Model)
            _buildFilterSection(),

            // Unit Cards List
            Expanded(
              child: _isLoading
                  ? const UnitStatusListSkeleton(itemCount: 4)
                  : _units.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _units.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildUnitCard(_units[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _buildMetricCard(
            label: 'Total Unit',
            count: _summary['total'] ?? 0,
            icon: Icons.devices_rounded,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          _buildMetricCard(
            label: 'Tersedia',
            count: _summary['tersedia'] ?? 0,
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          _buildMetricCard(
            label: 'Disewa',
            count: _summary['disewa'] ?? 0,
            icon: Icons.access_time_filled_rounded,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          _buildMetricCard(
            label: 'Perawatan',
            count: _summary['maintenance'] ?? 0,
            icon: Icons.build_circle_outlined,
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.85),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _loadData(),
        decoration: InputDecoration(
          hintText: 'Cari iPhone, kode aset, SN, warna...',
          hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
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
          fillColor: AppTheme.cardBorder,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Chips with Live Numerical Count Badges
          UnitStatusFilterChips(
            selectedStatus: _selectedStatus,
            counts: _summary,
            onStatusSelected: (status) {
              setState(() => _selectedStatus = status);
              _loadData();
            },
          ),
          if (_modelOptions.length > 1) ...[
            const SizedBox(height: 6),
            // Model Chips Horizontal Scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _modelOptions.map((model) {
                  final isSelected = _selectedModel == model;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        model,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      backgroundColor: AppTheme.surface,
                      selectedColor: AppTheme.accentLight,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? AppTheme.accent : AppTheme.cardBorder,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() => _selectedModel = selected ? model : 'Semua');
                        _loadData();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnitCard(IphoneModel unit) {
    final activeBooking = _activeBookings[unit.assetCode];
    final bhColor = _getBatteryColor(unit.batteryHealth);
    final statusColor = _getStatusColor(unit.status);
    final statusBg = _getStatusBgColor(unit.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showUnitActionSheet(unit),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Name + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.phone_iphone_rounded,
                      color: AppTheme.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${unit.storage} • ${unit.color}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(unit.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Identifiers Row: Asset Code & SN
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_2_rounded, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            unit.assetCode,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 14, color: Colors.grey.shade300),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.tag_rounded, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              unit.serialNumber,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Battery Health Indicator
              Row(
                children: [
                  Icon(
                    Icons.battery_charging_full_rounded,
                    size: 16,
                    color: bhColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'BH: ${unit.batteryHealth}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: bhColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (unit.batteryHealth / 100.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(bhColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),

              // Active Rental Info Card (if rented)
              if (activeBooking != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Disewa oleh: ${activeBooking.customerName} (${activeBooking.bookingCode})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFB45309)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _selectedStatus = 'Semua';
                _selectedModel = 'Semua';
              });
              _loadData();
            },
            child: const Text('Reset Filter'),
          ),
        ],
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
              color: isConnected
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConnected
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFFECACA),
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
                          color: isConnected
                              ? const Color(0xFF065F46)
                              : const Color(0xFF991B1B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? const Color(0xFF047857)
                              : const Color(0xFFB91C1C),
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
    final cashierName = user?.name.trim().isNotEmpty == true ? user!.name : 'Admin SKYRental';
    final cashierRole = (user?.role.trim().isNotEmpty == true ? user!.role : 'KASIR').toUpperCase();

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
              Row(
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
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFE2E8F0),
                              child: Icon(Icons.person, size: 20, color: Color(0xFF475569)),
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
                            Row(
                              children: [
                                Text(
                                  cashierName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    cashierRole,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Text('Shift Pagi • POS-01', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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
