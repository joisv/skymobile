import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/affiliate_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class AffiliateListScreen extends StatefulWidget {
  final BookingRepository repository;
  final bool isEmbedded;

  const AffiliateListScreen({
    super.key,
    required this.repository,
    this.isEmbedded = false,
  });

  @override
  State<AffiliateListScreen> createState() => _AffiliateListScreenState();
}

class _AffiliateListScreenState extends State<AffiliateListScreen> {
  bool _isLoading = true;
  List<AffiliateModel> _affiliates = [];
  String _searchQuery = '';
  String _selectedFilter = 'semua'; // 'semua', 'aktif', 'nonaktif'

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAffiliates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAffiliates() async {
    setState(() => _isLoading = true);
    try {
      bool? activeFilter;
      if (_selectedFilter == 'aktif') activeFilter = true;
      if (_selectedFilter == 'nonaktif') activeFilter = false;

      final list = await widget.repository.getAffiliates(
        search: _searchQuery,
        isActive: activeFilter,
        forceRefresh: true,
      );

      if (mounted) {
        setState(() {
          _affiliates = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalIphones => _affiliates.fold(0, (sum, a) => sum + a.iphonesCount);
  int get _activeCount => _affiliates.where((a) => a.isActive).length;

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildEmbeddedLayout(context);
    }
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Mitra Cabang & Affiliate',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.cardBorder, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Mutasi & Transfer Unit',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.iphoneTransfer),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadAffiliates,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.pushNamed(
            context,
            AppRoutes.affiliateForm,
          );
          if (created == true) _loadAffiliates();
        },
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Tambah Mitra', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAffiliates,
        child: Column(
          children: [
            // KPI Summary Header Cards
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildKpiMiniCard(
                      label: 'Total Mitra',
                      value: '${_affiliates.length}',
                      subtitle: '$_activeCount Aktif',
                      icon: Icons.store_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiMiniCard(
                      label: 'Unit Tersebar',
                      value: '$_totalIphones Unit',
                      subtitle: 'Di seluruh cabang',
                      icon: Icons.phone_iphone_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.iphoneTransfer),
                      child: _buildKpiMiniCard(
                        label: 'Transfer Unit',
                        value: 'Mutasi',
                        subtitle: 'Kirim / Terima',
                        icon: Icons.sync_alt_rounded,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filter Bar
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari kode, nama affiliate, atau kota...',
                      hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _loadAffiliates();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _loadAffiliates();
                    },
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('semua', 'Semua Mitra (${_affiliates.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('aktif', 'Aktif ($_activeCount)'),
                        const SizedBox(width: 8),
                        _buildFilterChip('nonaktif', 'Nonaktif (${_affiliates.length - _activeCount})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),

            // Affiliate List Items
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _affiliates.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _affiliates.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildAffiliateCard(_affiliates[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiMiniCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9.5, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceContainerLow,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = key);
          _loadAffiliates();
        }
      },
    );
  }

  Widget _buildAffiliateCard(AffiliateModel affiliate) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      color: AppTheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final res = await Navigator.pushNamed(
            context,
            AppRoutes.affiliateDetail,
            arguments: affiliate,
          );
          if (res == true) _loadAffiliates();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header: Code badge, Name & Active indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: affiliate.isActive
                            ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                            : [Colors.grey.shade400, Colors.grey.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      affiliate.code,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                affiliate.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: affiliate.isActive
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: affiliate.isActive
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Text(
                                affiliate.isActive ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: affiliate.isActive
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                affiliate.locationSummary,
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

              // Bottom Stats: iPhone Units, Bookings, Today Revenue
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    icon: Icons.phone_iphone_rounded,
                    label: '${affiliate.iphonesCount} Unit iPhone',
                    color: Colors.blue.shade700,
                  ),
                  _buildStatItem(
                    icon: Icons.calendar_today_rounded,
                    label: '${affiliate.bookingsCount} Booking',
                    color: Colors.indigo.shade700,
                  ),
                  _buildStatItem(
                    icon: Icons.payments_rounded,
                    label: affiliate.revenueToday > 0
                        ? Formatters.currency(affiliate.revenueToday)
                        : 'Belum ada sewa',
                    color: Colors.teal.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_outlined, size: 48, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Mitra Affiliate',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Tambahkan cabang atau mitra rental baru untuk mulai mendistribusikan unit iPhone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final created = await Navigator.pushNamed(context, AppRoutes.affiliateForm);
                if (created == true) _loadAffiliates();
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah Mitra Sekarang'),
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

  Widget _buildEmbeddedLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header matching tablet styling
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mitra Cabang & Affiliate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Kelola jaringan outlet cabang resmi, pembagian komisi, dan inventaris unit antar cabang.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _loadAffiliates,
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
                  tooltip: 'Segarkan Data',
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.iphoneTransfer),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Mutasi Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final created = await Navigator.pushNamed(context, AppRoutes.affiliateForm);
                    if (created == true) _loadAffiliates();
                  },
                  icon: const Icon(Icons.add_business_rounded, size: 16),
                  label: const Text('Tambah Mitra', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // KPI Summary Cards
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RINGKASAN JARINGAN CABANG MITRA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiMiniCard(
                      label: 'Total Mitra',
                      value: '${_affiliates.length}',
                      subtitle: '$_activeCount Aktif',
                      icon: Icons.store_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiMiniCard(
                      label: 'Unit Tersebar',
                      value: '$_totalIphones Unit',
                      subtitle: 'Di seluruh cabang',
                      icon: Icons.phone_iphone_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pushNamed(context, AppRoutes.iphoneTransfer),
                      child: _buildKpiMiniCard(
                        label: 'Transfer Unit',
                        value: 'Mutasi',
                        subtitle: 'Kirim / Terima',
                        icon: Icons.sync_alt_rounded,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search and Filter Bar Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari kode, nama affiliate, atau kota...',
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadAffiliates();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _loadAffiliates();
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildFilterChip('semua', 'Semua Mitra (${_affiliates.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('aktif', 'Aktif ($_activeCount)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('nonaktif', 'Nonaktif (${_affiliates.length - _activeCount})'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Affiliate List Items or Empty State
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_affiliates.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _affiliates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildAffiliateCard(_affiliates[index]);
            },
          ),
      ],
    );
  }
}
