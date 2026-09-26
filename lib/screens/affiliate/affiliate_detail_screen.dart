import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/affiliate_model.dart';
import '../../models/affiliate_user_model.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class AffiliateDetailScreen extends StatefulWidget {
  final AffiliateModel affiliate;
  final BookingRepository repository;

  const AffiliateDetailScreen({
    super.key,
    required this.affiliate,
    required this.repository,
  });

  @override
  State<AffiliateDetailScreen> createState() => _AffiliateDetailScreenState();
}

class _AffiliateDetailScreenState extends State<AffiliateDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AffiliateModel _affiliate;
  bool _isLoading = false;
  List<IphoneModel> _assignedIphones = [];
  List<BookingModel> _assignedBookings = [];
  List<AffiliateUserModel> _assignedUsers = [];

  @override
  void initState() {
    super.initState();
    _affiliate = widget.affiliate;
    _tabController = TabController(length: 4, vsync: this);
    _loadAffiliateDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAffiliateDetail() async {
    setState(() => _isLoading = true);
    try {
      final detail = await widget.repository.getAffiliateDetail(_affiliate.id);
      if (detail != null && mounted) {
        setState(() => _affiliate = detail);
      }

      final iphones = await widget.repository.getAffiliateIphones(_affiliate.id, affiliate: _affiliate);
      final bookings = await widget.repository.getAffiliateBookings(_affiliate.id, affiliate: _affiliate);
      final users = await widget.repository.getAffiliateUsers(_affiliate.id);

      if (mounted) {
        setState(() {
          _assignedIphones = iphones;
          _assignedBookings = bookings;
          _assignedUsers = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 22),
            SizedBox(width: 8),
            Text('Hapus Mitra Affiliate?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus cabang "${_affiliate.name}" (${_affiliate.code})?\n\nUnit iPhone yang terhubung akan dilepas status afiliasinya ke pusat.',
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
      try {
        final success = await widget.repository.deleteAffiliate(_affiliate.id);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Mitra ${_affiliate.name} berhasil dihapus.'),
                backgroundColor: const Color(0xFF047857),
              ),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menghapus mitra affiliate.'), backgroundColor: AppTheme.error),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  void _openAssignUserModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignUserModalBottomSheet(
        affiliate: _affiliate,
        repository: widget.repository,
        onAssigned: () {
          _loadAffiliateDetail();
        },
      ),
    );
  }

  Future<void> _confirmRemoveUser(AffiliateUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: AppTheme.error, size: 22),
            SizedBox(width: 8),
            Text('Lepas Penugasan?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin melepas penugasan "${user.name}" dari cabang ${_affiliate.name}?\n\nPengguna ini tidak akan lagi memiliki akses operasional untuk cabang ini.',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textSecondary),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lepas Penugasan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await widget.repository.removeUserFromAffiliate(_affiliate.id, user.id);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Penugasan ${user.name} berhasil dilepas.'),
                backgroundColor: const Color(0xFF047857),
              ),
            );
            _loadAffiliateDetail();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal melepas penugasan user.'), backgroundColor: AppTheme.error),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          '${_affiliate.code} - ${_affiliate.name}',
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
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Mitra',
            onPressed: () async {
              final updated = await Navigator.pushNamed(
                context,
                AppRoutes.affiliateForm,
                arguments: _affiliate,
              );
              if (updated == true) _loadAffiliateDetail();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'revenue') {
                Navigator.pushNamed(context, AppRoutes.affiliateRevenue, arguments: _affiliate);
              } else if (val == 'transfer') {
                Navigator.pushNamed(context, AppRoutes.iphoneTransfer, arguments: _affiliate.id);
              } else if (val == 'assign_user') {
                _openAssignUserModal();
              } else if (val == 'delete') {
                _confirmDelete();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'assign_user',
                child: Row(
                  children: [
                    Icon(Icons.person_add_outlined, size: 18, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('Tugaskan Pengguna'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'revenue',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Laporan Omset & Finansial'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'transfer',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Mutasi / Kirim iPhone'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                    SizedBox(width: 8),
                    Text('Hapus Mitra Cabang', style: TextStyle(color: AppTheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAffiliateDetail,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Overview Header
                          _buildHeaderBanner(),

                          // 6 Metric Summary Cards
                          _buildStatGrid(),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primary,
                          unselectedLabelColor: AppTheme.textSecondary,
                          indicatorColor: AppTheme.primary,
                          indicatorWeight: 3,
                          tabs: const [
                            Tab(icon: Icon(Icons.phone_iphone_rounded, size: 18), text: 'Unit iPhone'),
                            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Booking'),
                            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Pengguna'),
                            Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'Informasi'),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIphonesTab(),
                    _buildBookingsTab(),
                    _buildUsersTab(),
                    _buildInfoTab(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _affiliate.isActive
                    ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                    : [Colors.grey.shade400, Colors.grey.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              _affiliate.code,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _affiliate.name,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _affiliate.locationSummary,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_affiliate.phone != null && _affiliate.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 13, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        _affiliate.phone!,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _affiliate.isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _affiliate.isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
              ),
            ),
            child: Text(
              _affiliate.isActive ? 'Aktif' : 'Nonaktif',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: _affiliate.isActive ? const Color(0xFF047857) : const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: [
          _buildStatCard(
            title: 'Unit iPhone',
            value: '${_assignedIphones.isNotEmpty ? _assignedIphones.length : _affiliate.iphonesCount} Unit',
            subtitle: 'Stok di cabang',
            icon: Icons.phone_iphone_rounded,
            color: Colors.blue,
            onTap: () => _tabController.animateTo(0),
          ),
          _buildStatCard(
            title: 'Total Booking',
            value: '${_assignedBookings.isNotEmpty ? _assignedBookings.length : _affiliate.bookingsCount} Sewa',
            subtitle: 'Riwayat transaksi',
            icon: Icons.calendar_month_rounded,
            color: Colors.indigo,
            onTap: () => _tabController.animateTo(1),
          ),
          _buildStatCard(
            title: 'Pendapatan Hari Ini',
            value: Formatters.currency(_affiliate.revenueToday),
            subtitle: 'Omset kasir cabang',
            icon: Icons.payments_rounded,
            color: Colors.teal,
            onTap: () => Navigator.pushNamed(context, AppRoutes.affiliateRevenue, arguments: _affiliate),
          ),
          _buildStatCard(
            title: 'Mutasi / Transfer',
            value: 'Kirim Unit',
            subtitle: 'Pindah antar-cabang',
            icon: Icons.swap_horiz_rounded,
            color: Colors.orange,
            onTap: () => Navigator.pushNamed(context, AppRoutes.iphoneTransfer, arguments: _affiliate.id),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
                  ),
                  Text(
                    value,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIphonesTab() {
    final iphones = _assignedIphones;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Daftar Unit di ${_affiliate.name} (${iphones.length})',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.iphoneTransfer, arguments: _affiliate.id),
              icon: const Icon(Icons.send_rounded, size: 14),
              label: const Text('Kirim Unit', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (iphones.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.phone_iphone_rounded, size: 40, color: AppTheme.textMuted),
                const SizedBox(height: 10),
                Text(
                  'Belum ada unit iPhone yang ditempatkan di ${_affiliate.name}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.iphoneTransfer, arguments: _affiliate.id),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer iPhone ke Cabang Ini'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        else
          ...iphones.map((iphone) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.cardBorder),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.phone_iphone_rounded, color: AppTheme.primary),
                ),
                title: Text(
                  iphone.name,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  'Kode: ${iphone.assetCode} • BH: ${iphone.batteryHealth}%',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: iphone.status.toLowerCase() == 'ready'
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    iphone.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: iphone.status.toLowerCase() == 'ready'
                          ? const Color(0xFF047857)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBookingStatusBadge(BookingStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case BookingStatus.rented:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        break;
      case BookingStatus.confirmed:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        break;
      case BookingStatus.returned:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        break;
      case BookingStatus.cancelled:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        break;
      case BookingStatus.pending:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildBookingsTab() {
    final bookings = _assignedBookings;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Aktivitas Sewa di Cabang Ini (${bookings.length})',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.bookingList),
              icon: const Icon(Icons.list_alt_rounded, size: 14),
              label: const Text('Semua Booking', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (bookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 40, color: AppTheme.textMuted),
                const SizedBox(height: 10),
                Text(
                  'Belum ada transaksi sewa di cabang ${_affiliate.name}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.bookingList),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Buka Daftar Booking Pusat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          )
        else
          ...bookings.map((b) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: AppTheme.cardBorder),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.bookingDetail, arguments: b);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              b.bookingCode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          _buildBookingStatusBadge(b.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b.customerName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_iphone_rounded, size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              b.iphone.fullName,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            Formatters.currency(b.price),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${Formatters.date(b.startDate)} - ${Formatters.date(b.endDate)}',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildUsersTab() {
    final users = _assignedUsers;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staf & Pengguna (${users.length})',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Akses operasional kasir cabang',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _openAssignUserModal,
              icon: const Icon(Icons.person_add_rounded, size: 15),
              label: const Text('Tugaskan Pengguna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (users.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Belum ada pengguna di ${_affiliate.name}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tugaskan staf atau pengguna ke cabang ini agar mereka dapat mengelola booking dan unit iPhone cabang ${_affiliate.name}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _openAssignUserModal,
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Tugaskan Pengguna Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          )
        else
          ...users.map((u) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        u.initials,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
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
                              Flexible(
                                child: Text(
                                  u.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  u.role ?? 'Staff',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 12, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  u.email,
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (u.phone != null && u.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined, size: 12, color: AppTheme.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  u.phone!,
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined, size: 20, color: AppTheme.error),
                      tooltip: 'Lepas Penugasan',
                      onPressed: () => _confirmRemoveUser(u),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.cardBorder),
          ),
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Informasi Mitra Cabang',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Kode Cabang', _affiliate.code),
                const Divider(height: 20),
                _buildInfoRow('Nama Affiliate', _affiliate.name),
                const Divider(height: 20),
                _buildInfoRow('Email Resmi', _affiliate.email ?? '-'),
                const Divider(height: 20),
                _buildInfoRow('Nomor Telepon', _affiliate.phone ?? '-'),
                const Divider(height: 20),
                _buildInfoRow('Kota / Kabupaten', _affiliate.city ?? '-'),
                const Divider(height: 20),
                _buildInfoRow('Provinsi', _affiliate.province ?? '-'),
                const Divider(height: 20),
                _buildInfoRow('Kode Pos', _affiliate.postalCode ?? '-'),
                const Divider(height: 20),
                _buildInfoRow('Alamat Lengkap', _affiliate.address ?? '-'),
                if (_affiliate.description != null && _affiliate.description!.isNotEmpty) ...[
                  const Divider(height: 20),
                  _buildInfoRow('Catatan / Deskripsi', _affiliate.description!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return true;
  }
}

class _AssignUserModalBottomSheet extends StatefulWidget {
  final AffiliateModel affiliate;
  final BookingRepository repository;
  final VoidCallback onAssigned;

  const _AssignUserModalBottomSheet({
    required this.affiliate,
    required this.repository,
    required this.onAssigned,
  });

  @override
  State<_AssignUserModalBottomSheet> createState() => _AssignUserModalBottomSheetState();
}

class _AssignUserModalBottomSheetState extends State<_AssignUserModalBottomSheet> {
  List<AffiliateUserModel> _users = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.repository.getAvailableUsersForAffiliate(widget.affiliate.id);
      if (mounted) {
        setState(() {
          _users = list;
          for (final u in list) {
            if (u.isAssigned || u.affiliateId == widget.affiliate.id) {
              _selectedUserIds.add(u.id);
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAssignment() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.repository.assignUsersToAffiliate(
        widget.affiliate.id,
        _selectedUserIds.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedUserIds.isEmpty
                  ? 'Semua pengguna telah dilepas dari cabang ${widget.affiliate.name}.'
                  : '${_selectedUserIds.length} user berhasil ditambahkan ke affiliate.',
            ),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menugaskan pengguna: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return u.name.toLowerCase().contains(query) || u.email.toLowerCase().contains(query);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Header matching web modal: "Assign Affiliate to User"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Affiliate to User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pilih salah satu user untuk affiliate ${widget.affiliate.name}.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email pengguna...',
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceContainerLow,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            const SizedBox(height: 8),

            // Selection status & select-all toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedUserIds.length} user dipilih',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedUserIds.isNotEmpty ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                  if (filteredUsers.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          final allFilteredSelected = filteredUsers.every((u) => _selectedUserIds.contains(u.id));
                          if (allFilteredSelected) {
                            for (final u in filteredUsers) {
                              _selectedUserIds.remove(u.id);
                            }
                          } else {
                            for (final u in filteredUsers) {
                              _selectedUserIds.add(u.id);
                            }
                          }
                        });
                      },
                      child: Text(
                        filteredUsers.every((u) => _selectedUserIds.contains(u.id))
                            ? 'Batal Pilih Semua'
                            : 'Pilih Semua (${filteredUsers.length})',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 12),

            // User List matching web styling
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search_rounded, size: 40, color: AppTheme.textMuted),
                                const SizedBox(height: 10),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'Tidak ada data pengguna ditemukan di sistem.'
                                      : 'Tidak ada pengguna dengan kata kunci "$_searchQuery".',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: filteredUsers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isSelected = _selectedUserIds.contains(user.id);
                            final isCurrentBranch = user.isAssigned || user.affiliateId == widget.affiliate.id;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedUserIds.remove(user.id);
                                  } else {
                                    _selectedUserIds.add(user.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primary.withValues(alpha: 0.05)
                                      : AppTheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Checkbox matching web app checkbox
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: isSelected,
                                        activeColor: AppTheme.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedUserIds.add(user.id);
                                            } else {
                                              _selectedUserIds.remove(user.id);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Avatar initials
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isSelected
                                          ? AppTheme.primary.withValues(alpha: 0.15)
                                          : AppTheme.cardBorder,
                                      child: Text(
                                        user.initials,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // User info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  user.name,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isCurrentBranch) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFECFDF5),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                                  ),
                                                  child: const Text(
                                                    'Cabang Ini',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF047857),
                                                    ),
                                                  ),
                                                ),
                                              ] else if (user.currentAffiliateName != null) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFFBEB),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                                  ),
                                                  child: Text(
                                                    'Cabang: ${user.currentAffiliateName}',
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFFB45309),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user.email,
                                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
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
                        ),
            ),

            // Bottom Submit Button matching web button: "Tambahkan User"
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.cardBorder)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submitAssignment,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Text('Menambahkan...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : Text(
                          _selectedUserIds.isEmpty
                              ? 'Terapkan (0 Pengguna)'
                              : 'Tambahkan ${_selectedUserIds.length} User',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
