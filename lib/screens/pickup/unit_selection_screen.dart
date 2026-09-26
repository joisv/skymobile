import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class UnitSelectionScreen extends StatefulWidget {
  final BookingModel? booking;
  final IphoneModel? currentSelectedUnit;
  final BookingRepository repository;

  const UnitSelectionScreen({
    super.key,
    this.booking,
    this.currentSelectedUnit,
    required this.repository,
  });

  @override
  State<UnitSelectionScreen> createState() => _UnitSelectionScreenState();
}

class _UnitSelectionScreenState extends State<UnitSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<IphoneModel> _units = [];
  bool _isLoading = true;
  IphoneModel? _selectedUnit;

  // Filter state
  bool _filterOnlyExactModel = true;
  bool _filterOnlyAvailable = true;

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.currentSelectedUnit ?? widget.booking?.iphone;
    _loadUnits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    setState(() => _isLoading = true);

    final modelFilter = (_filterOnlyExactModel && widget.booking != null)
        ? widget.booking!.iphone.name
        : null;

    final result = await widget.repository.getInventoryUnits(
      modelName: modelFilter,
      query: _searchController.text.trim(),
      onlyAvailable: _filterOnlyAvailable,
    );

    if (!mounted) return;
    setState(() {
      _units = result;
      _isLoading = false;
    });
  }

  void _onUnitTapped(IphoneModel unit) {
    final status = unit.status.toLowerCase().trim();
    if (['rented', 'disewa'].contains(status)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock_rounded, color: AppTheme.warning, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Unit Sedang Disewa',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit ${unit.fullName} (${unit.assetCode}) saat ini sedang dalam status aktif disewa oleh pelanggan lain.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Unit baru dapat diserahkan setelah proses pengembalian dan inspeksi unit selesai.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ),
          ],
        ),
      );
      return;
    }

    if (!['tersedia', 'ready'].contains(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit ${unit.assetCode} berstatus "${unit.status}" dan tidak dapat dipilih.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selectedUnit = unit);
  }

  void _confirmSelection() {
    if (_selectedUnit == null) return;
    Navigator.pop(context, _selectedUnit);
  }

  @override
  Widget build(BuildContext context) {
    final requestedIphone = widget.booking?.iphone;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pilih Unit iPhone Tersedia'),
        actions: [
          IconButton(
            tooltip: 'Pindai Barcode / SN Unit',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, AppRoutes.qrScanner);
              if (result is String && result.isNotEmpty) {
                _searchController.text = result;
                _loadUnits();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Target Booking & Requested Model Header
          if (widget.booking != null) _buildRequestedModelHeader(widget.booking!),

          // 2. Search & Filter Bar
          _buildSearchAndFilters(requestedIphone),

          // 3. Unit List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _units.isEmpty
                    ? _buildEmptyState()
                    : RadioGroup<int>(
                        groupValue: _selectedUnit?.id,
                        onChanged: (id) {
                          if (id == null) return;
                          final index = _units.indexWhere((unit) => unit.id == id);
                          if (index != -1) {
                            _onUnitTapped(_units[index]);
                          }
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _units.length,
                          itemBuilder: (context, index) {
                            final unit = _units[index];
                            final isSelected = _selectedUnit?.id == unit.id;
                            final isMatch = requestedIphone != null &&
                                unit.name.toLowerCase() == requestedIphone.name.toLowerCase() &&
                                unit.storage.toLowerCase() == requestedIphone.storage.toLowerCase();

                            return _buildUnitCard(unit, isSelected, isMatch);
                          },
                        ),
                      ),
          ),

          // 4. Sticky Bottom Confirmation Bar
          _buildBottomConfirmationBar(),
        ],
      ),
    );
  }

  Widget _buildRequestedModelHeader(BookingModel booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        border: Border(bottom: BorderSide(color: Color(0xFFBFDBFE))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pesanan: ${booking.bookingCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                    Text(
                      booking.customerName,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Model Dibooking: ${booking.iphone.fullName} (${booking.iphone.color})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(IphoneModel? requestedIphone) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.white,
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari Kode Aset, Serial Number, atau Warna...',
              hintStyle: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.cardBorder),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _loadUnits();
                      },
                    )
                  : null,
            ),
            onChanged: (_) => _loadUnits(),
          ),
          const SizedBox(height: 8),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (requestedIphone != null) ...[
                  FilterChip(
                    label: Text('Hanya ${requestedIphone.name}'),
                    selected: _filterOnlyExactModel,
                    selectedColor: AppTheme.accent.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.accent,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: _filterOnlyExactModel ? FontWeight.bold : FontWeight.normal,
                      color: _filterOnlyExactModel ? AppTheme.accent : AppTheme.textPrimary,
                    ),
                    onSelected: (val) {
                      setState(() => _filterOnlyExactModel = val);
                      _loadUnits();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                FilterChip(
                  label: const Text('Hanya Unit Tersedia'),
                  selected: _filterOnlyAvailable,
                  selectedColor: const Color(0xFFDCFCE7),
                  checkmarkColor: const Color(0xFF047857),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: _filterOnlyAvailable ? FontWeight.bold : FontWeight.normal,
                    color: _filterOnlyAvailable ? const Color(0xFF047857) : AppTheme.textPrimary,
                  ),
                  onSelected: (val) {
                    setState(() => _filterOnlyAvailable = val);
                    _loadUnits();
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '(${_units.length} Unit Ditemukan)',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Tidak ada unit iPhone yang cocok dengan filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _filterOnlyExactModel = false;
                  _filterOnlyAvailable = false;
                });
                _loadUnits();
              },
              child: const Text('Reset Semua Filter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(IphoneModel unit, bool isSelected, bool isMatch) {
    final status = unit.status.toLowerCase().trim();
    final isRented = ['rented', 'disewa'].contains(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFF0FDF4)
            : (isRented ? const Color(0xFFFFFBEB) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF047857)
              : isRented
                  ? const Color(0xFFFDE68A)
                  : isMatch
                      ? AppTheme.accent.withValues(alpha: 0.5)
                      : AppTheme.cardBorder,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: InkWell(
        onTap: () => _onUnitTapped(unit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Unit Name & Radio / Match Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<int>(
                    value: unit.id,
                    activeColor: const Color(0xFF047857),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              unit.fullName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isRented ? const Color(0xFF92400E) : AppTheme.primary,
                              ),
                            ),
                            if (isMatch) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppTheme.accent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text('Cocok',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${unit.color} • ${unit.storage}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Detail Row: Asset Code, Battery, Daily Rate
              Row(
                children: [
                  _buildBadgeInfo('Kode Unit', unit.assetCode),
                  const SizedBox(width: 8),
                  _buildBadgeInfo('Baterai', '${unit.batteryHealth}%'),
                  const SizedBox(width: 8),
                  _buildBadgeInfo(
                    'Harga/Hari',
                    Formatters.formatCurrency(unit.dailyRate),
                  ),
                  const Spacer(),
                  // Status Badge
                  _buildStatusChip(unit.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color text;
    String label;

    switch (status.toLowerCase().trim()) {
      case 'tersedia':
      case 'ready':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF047857);
        label = 'Tersedia';
        break;
      case 'disewa':
      case 'rented':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = '🔒 Sedang Disewa';
        break;
      case 'maintenance':
      case 'perbaikan':
      case 'perawatan':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        label = 'Perawatan';
        break;
      default:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildBadgeInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomConfirmationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Terpilih:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  Text(
                    _selectedUnit != null
                        ? '${_selectedUnit!.assetCode} • ${_selectedUnit!.fullName}'
                        : 'Belum ada unit dipilih',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _selectedUnit != null ? AppTheme.primary : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _selectedUnit != null ? _confirmSelection : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Gunakan Unit Ini', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
