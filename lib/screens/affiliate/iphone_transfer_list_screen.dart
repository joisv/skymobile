import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/affiliate_model.dart';
import '../../models/iphone_model.dart';
import '../../models/iphone_transfer_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../services/auth_service.dart';

class IphoneTransferListScreen extends StatefulWidget {
  final BookingRepository repository;
  final int? initialAffiliateId;
  final bool isEmbedded;

  const IphoneTransferListScreen({
    super.key,
    required this.repository,
    this.initialAffiliateId,
    this.isEmbedded = false,
  });

  @override
  State<IphoneTransferListScreen> createState() => _IphoneTransferListScreenState();
}

class _IphoneTransferListScreenState extends State<IphoneTransferListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<IphoneTransferModel> _allTransfers = [];
  int? _selectedAffiliateId;
  List<AffiliateModel> _affiliateList = [];

  @override
  void initState() {
    super.initState();
    final isAffiliateUser = AuthService().isAffiliate || AuthService().isAffiliateAdmin;
    _selectedAffiliateId = widget.initialAffiliateId ??
        (isAffiliateUser ? AuthService().affiliateId : null);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final isAffiliateUser = AuthService().isAffiliate || AuthService().isAffiliateAdmin;
      final transfers = await widget.repository.getIphoneTransfers(
        affiliateId: _selectedAffiliateId,
        type: isAffiliateUser ? 'inbound' : null,
        forceRefresh: true,
      );
      if (mounted) {
        setState(() => _allTransfers = transfers);
      }
    } catch (_) {}

    try {
      final affiliates = await widget.repository.getAffiliates();
      if (mounted) {
        setState(() => _affiliateList = affiliates);
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  List<IphoneTransferModel> _getFilteredTransfers(int tabIndex) {
    if (tabIndex == 1) {
      return _allTransfers.where((t) => t.isInTransit).toList();
    } else if (tabIndex == 2) {
      return _allTransfers.where((t) => t.isReceived).toList();
    }
    return _allTransfers;
  }

  Future<void> _handleAcceptTransfer(IphoneTransferModel transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF047857), size: 24),
            SizedBox(width: 8),
            Text('Konfirmasi Penerimaan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda ingin mengonfirmasi penerimaan unit "${transfer.iphoneName}" di cabang "${transfer.toAffiliateName}"?',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unit akan dialihkan ke inventaris ${transfer.toAffiliateName} dan berstatus Siap Sewa.',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terima Unit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.repository.acceptIphoneTransfer(transfer.id);
        // Refresh unit inventory di repository agar layar Unit iPhone langsung ter-update
        try {
          widget.repository.getAllInventoryUnits();
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unit ${transfer.iphoneName} berhasil diterima di cabang tujuan!'),
              backgroundColor: const Color(0xFF047857),
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  void _showCreateTransferModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateTransferBottomSheet(
        repository: widget.repository,
        affiliates: _affiliateList,
        defaultAffiliateId: _selectedAffiliateId,
        onTransferCreated: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildEmbeddedLayout(context);
    }
    final inTransitCount = _allTransfers.where((t) => t.isInTransit).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          (AuthService().isAffiliate || AuthService().isAffiliateAdmin) ? 'Transfer iPhone Masuk' : 'Mutasi & Transfer Unit',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Semua (${_allTransfers.length})'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text((AuthService().isAffiliate || AuthService().isAffiliateAdmin) ? 'Dalam Pengiriman' : 'Terkirim'),
                  if (inTransitCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$inTransitCount',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              text: (AuthService().isAffiliate || AuthService().isAffiliateAdmin)
                  ? 'Diterima (${_allTransfers.where((t) => t.isReceived).length})'
                  : 'Selesai (${_allTransfers.where((t) => t.isReceived).length})',
            ),
          ],
        ),
      ),
      floatingActionButton: (AuthService().isSuperAdmin || (AuthService().isAdmin && !(AuthService().isAffiliate || AuthService().isAffiliateAdmin)))
          ? FloatingActionButton.extended(
              onPressed: _showCreateTransferModal,
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Kirim Unit iPhone', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTransferList(_getFilteredTransfers(0)),
                _buildTransferList(_getFilteredTransfers(1)),
                _buildTransferList(_getFilteredTransfers(2)),
              ],
            ),
    );
  }

  Widget _buildTransferList(List<IphoneTransferModel> list) {
    if (list.isEmpty) {
      final isAffiliate = AuthService().isAffiliate || AuthService().isAffiliateAdmin;
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(40),
          children: [
            const SizedBox(height: 60),
            Icon(Icons.swap_horiz_rounded, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              isAffiliate ? 'Belum ada transfer iPhone masuk.' : 'Tidak Ada Riwayat Transfer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              isAffiliate
                  ? 'Unit iPhone yang dikirim ke cabang Anda akan muncul di sini.'
                  : 'Gunakan tombol "Kirim Unit iPhone" di bawah untuk memutasi unit antar cabang.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final transfer = list[index];
          return _buildTransferCard(transfer);
        },
      ),
    );
  }

  Widget _buildTransferCard(IphoneTransferModel transfer) {
    final isInTransit = transfer.isInTransit;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInTransit ? Colors.amber.shade300 : AppTheme.cardBorder,
          width: isInTransit ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: iPhone unit & Status badge
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isInTransit ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isInTransit ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Icon(
                    isInTransit ? Icons.local_shipping_outlined : Icons.check_circle_outline_rounded,
                    color: isInTransit ? const Color(0xFFD97706) : const Color(0xFF047857),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.iphoneName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'SN: ${transfer.iphoneSerial}',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isInTransit ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isInTransit ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Text(
                    transfer.statusLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isInTransit ? const Color(0xFFD97706) : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Route: Dari -> Ke
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DARI',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transfer.fromAffiliateName,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.textMuted),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TUJUAN',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transfer.toAffiliateName,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Meta: Pengirim, Penerima, Waktu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dikirim oleh: ${transfer.senderName}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  transfer.sentAt != null ? AppFormatters.formatDateTime(transfer.sentAt!) : '-',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),

            if (transfer.isReceived && transfer.receiverName != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Diterima oleh: ${transfer.receiverName}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    transfer.receivedAt != null ? AppFormatters.formatDateTime(transfer.receivedAt!) : '-',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],

            if (transfer.notes != null && transfer.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Catatan: ${transfer.notes}',
                style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
              ),
            ],

            // Action Button: Terima Unit (if In Transit)
            if (isInTransit) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _handleAcceptTransfer(transfer),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Terima iPhone di Cabang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedLayout(BuildContext context) {
    final inTransitCount = _allTransfers.where((t) => t.isInTransit).length;
    final receivedCount = _allTransfers.where((t) => t.isReceived).length;
    final currentList = _getFilteredTransfers(_tabController.index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header matching tablet styling
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (AuthService().isAffiliate || AuthService().isAffiliateAdmin)
                        ? 'Transfer iPhone Masuk'
                        : 'Mutasi & Transfer Unit iPhone',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (AuthService().isAffiliate || AuthService().isAffiliateAdmin)
                        ? 'Daftar unit iPhone yang dikirim ke cabang Anda.'
                        : 'Pencatatan pengiriman, pelacakan transit, dan serah-terima unit iPhone antar outlet.',
                    style: const TextStyle(
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
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
                  tooltip: 'Segarkan Data',
                ),
                if (AuthService().isSuperAdmin || (AuthService().isAdmin && !(AuthService().isAffiliate || AuthService().isAffiliateAdmin))) ...[
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showCreateTransferModal,
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Kirim Unit iPhone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
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
                'STATISTIK TRANSFER TERBARU',
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
                    child: _buildKpiBox(
                      label: 'Total Transfer',
                      value: '${_allTransfers.length} Unit',
                      icon: Icons.outbox_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiBox(
                      label: 'Dalam Transit',
                      value: '$inTransitCount Unit',
                      icon: Icons.local_shipping_outlined,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiBox(
                      label: 'Selesai Diterima',
                      value: '$receivedCount Unit',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter Chips Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildFilterChoiceChip(0, 'Semua (${_allTransfers.length})'),
              const SizedBox(width: 8),
              _buildFilterChoiceChip(1, 'Dalam Transit ($inTransitCount)'),
              const SizedBox(width: 8),
              _buildFilterChoiceChip(2, 'Selesai Diterima ($receivedCount)'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Transfer List Items or Loading or Empty
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (currentList.isEmpty)
          Builder(
            builder: (context) {
              final isAffiliate = AuthService().isAffiliate || AuthService().isAffiliateAdmin;
              return Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 54, color: AppTheme.textMuted),
                    const SizedBox(height: 14),
                    Text(
                      isAffiliate ? 'Belum ada transfer iPhone masuk.' : 'Tidak Ada Riwayat Transfer',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAffiliate
                          ? 'Unit iPhone yang dikirim ke cabang Anda akan muncul di sini.'
                          : 'Gunakan tombol "Kirim Unit iPhone" di atas untuk memutasi unit antar cabang.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              );
            },
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: currentList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildTransferCard(currentList[index]);
            },
          ),
      ],
    );
  }

  Widget _buildKpiBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChoiceChip(int tabIndex, String label) {
    final isSelected = _tabController.index == tabIndex;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _tabController.index = tabIndex;
          });
        }
      },
    );
  }
}

class _CreateTransferBottomSheet extends StatefulWidget {
  final BookingRepository repository;
  final List<AffiliateModel> affiliates;
  final int? defaultAffiliateId;
  final VoidCallback onTransferCreated;

  const _CreateTransferBottomSheet({
    required this.repository,
    required this.affiliates,
    this.defaultAffiliateId,
    required this.onTransferCreated,
  });

  @override
  State<_CreateTransferBottomSheet> createState() => _CreateTransferBottomSheetState();
}

class _CreateTransferBottomSheetState extends State<_CreateTransferBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoadingUnits = true;
  bool _isSubmitting = false;

  List<IphoneModel> _availableUnits = [];
  IphoneModel? _selectedUnit;
  int? _selectedToAffiliateId;
  List<AffiliateModel> _affiliates = [];
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedToAffiliateId = widget.defaultAffiliateId;
    _affiliates = List.of(widget.affiliates);
    if (_affiliates.isEmpty) {
      widget.repository.getAffiliates().then((list) {
        if (mounted) setState(() => _affiliates = list);
      });
    }
    _loadUnits();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await widget.repository.getAllInventoryUnits();
      if (mounted) {
        setState(() {
          // Hanya unit yang tidak sedang tersewa/disewa atau dalam perjalanan mutasi yang dapat dimutasi
          _availableUnits = units.where((u) {
            final s = u.status.toLowerCase();
            return s != 'rented' &&
                s != 'disewa' &&
                s != 'booked' &&
                s != 'transferred' &&
                s != 'in_transit';
          }).toList();
          _isLoadingUnits = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUnits = false);
    }
  }

  Future<void> _openIphonePicker() async {
    if (_availableUnits.isEmpty) return;

    final chosen = await showModalBottomSheet<IphoneModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IphonePickerModal(
        availableUnits: _availableUnits,
        selectedUnit: _selectedUnit,
      ),
    );

    if (chosen != null && mounted) {
      setState(() {
        _selectedUnit = chosen;
        // Jika affiliate tujuan sama dengan asal unit, reset pilihan tujuan
        if (_selectedToAffiliateId != null && chosen.affiliateId == _selectedToAffiliateId) {
          _selectedToAffiliateId = null;
        }
      });
    }
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih unit iPhone yang akan dikirim.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (_selectedToAffiliateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih cabang tujuan pengiriman.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_selectedUnit!.affiliateId != null &&
        _selectedUnit!.affiliateId == _selectedToAffiliateId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cabang tujuan tidak boleh sama dengan cabang asal unit.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.createIphoneTransfer(
        iphoneId: _selectedUnit!.id,
        toAffiliateId: _selectedToAffiliateId!,
        fromAffiliateId: _selectedUnit!.affiliateId,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unit ${_selectedUnit!.name} berhasil dikirim ke cabang tujuan.'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
        widget.onTransferCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Saring pilihan cabang: jangan tampilkan cabang yang saat ini memegang unit
    final eligibleAffiliates = _affiliates.where((a) {
      if (_selectedUnit?.affiliateId != null) {
        return a.id != _selectedUnit!.affiliateId;
      }
      return true;
    }).toList();

    AffiliateModel? targetAffiliate;
    if (_selectedToAffiliateId != null) {
      targetAffiliate = _affiliates
          .where((a) => a.id == _selectedToAffiliateId)
          .firstOrNull;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.swap_horiz_rounded, color: AppTheme.accent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kirim & Mutasi iPhone',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kirim unit iPhone ke cabang mitra affiliate lain.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bagian Pemilihan Unit iPhone yang Scalable
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Unit iPhone *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  if (!_isLoadingUnits && _availableUnits.isNotEmpty)
                    Text(
                      '${_availableUnits.length} unit tersedia',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (_isLoadingUnits)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_availableUnits.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tidak ada unit iPhone yang siap dikirim saat ini (semua unit sedang tersewa atau dalam mutasi).',
                          style: TextStyle(fontSize: 12, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_selectedUnit == null)
                InkWell(
                  onTap: _openIphonePicker,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.phone_iphone_rounded, color: AppTheme.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pilih Unit iPhone...',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Cari berdasarkan tipe, nomor seri, atau warna',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_rounded, size: 14, color: AppTheme.accent),
                              const SizedBox(width: 4),
                              Text('Cari', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Card Unit Terpilih
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.phone_iphone_rounded, color: AppTheme.accent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedUnit!.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _selectedUnit!.assetCode,
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_selectedUnit!.storage} • ${_selectedUnit!.color}',
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openIphonePicker,
                            icon: const Icon(Icons.sync_rounded, size: 14),
                            label: const Text('Ganti', style: TextStyle(fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accent,
                              side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_outlined, size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text('Asal Unit: ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            Text(
                              _selectedUnit!.branchName ?? 'Pusat (SkyRent)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // Pilih Cabang Tujuan
              const Text('Cabang Mitra Tujuan *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _selectedToAffiliateId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Pilih cabang tujuan',
                  prefixIcon: Icon(Icons.storefront_rounded),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: eligibleAffiliates.map((a) {
                  return DropdownMenuItem<int>(
                    value: a.id,
                    child: Text(
                      '${a.code} - ${a.name} (${a.locationSummary})',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedToAffiliateId = val),
                validator: (val) => val == null ? 'Pilih cabang tujuan' : null,
              ),

              // Ringkasan Alur Mutasi (Preview Card)
              if (_selectedUnit != null && targetAffiliate != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: Colors.blue.shade800),
                          const SizedBox(width: 6),
                          Text(
                            'Alur Mutasi Pengiriman',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ASAL', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedUnit!.branchName ?? 'Pusat (SkyRent)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1E40AF)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('TUJUAN', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                const SizedBox(height: 2),
                                Text(
                                  targetAffiliate.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Catatan / Keterangan Mutasi
              const Text('Catatan / Alasan Mutasi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Misal: Penambahan stok rental, permintaan cabang...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Submit dengan pencegahan double-submit
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (_isSubmitting || _isLoadingUnits || _availableUnits.isEmpty)
                      ? null
                      : _submitTransfer,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Mengirim iPhone...' : 'Kirim Sekarang',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal Search & Selector Unit iPhone untuk kemudahan memilih dari puluhan/ratusan unit
class _IphonePickerModal extends StatefulWidget {
  final List<IphoneModel> availableUnits;
  final IphoneModel? selectedUnit;

  const _IphonePickerModal({
    required this.availableUnits,
    this.selectedUnit,
  });

  @override
  State<_IphonePickerModal> createState() => _IphonePickerModalState();
}

class _IphonePickerModalState extends State<_IphonePickerModal> {
  final TextEditingController _searchController = TextEditingController();
  List<IphoneModel> _filteredUnits = [];
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _filteredUnits = widget.availableUnits;
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final cats = <String>{'Semua'};
    for (final u in widget.availableUnits) {
      final nameLower = u.name.toLowerCase();
      if (nameLower.contains('iphone 16')) {
        cats.add('iPhone 16');
      } else if (nameLower.contains('iphone 15')) {
        cats.add('iPhone 15');
      } else if (nameLower.contains('iphone 14')) {
        cats.add('iPhone 14');
      } else if (nameLower.contains('iphone 13')) {
        cats.add('iPhone 13');
      } else if (nameLower.contains('iphone 12')) {
        cats.add('iPhone 12');
      } else if (nameLower.contains('iphone 11')) {
        cats.add('iPhone 11');
      } else if (nameLower.contains('xr')) {
        cats.add('iPhone XR');
      }
    }
    return cats.toList();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUnits = widget.availableUnits.where((u) {
        final matchesQuery = query.isEmpty ||
            u.name.toLowerCase().contains(query) ||
            u.assetCode.toLowerCase().contains(query) ||
            u.serialNumber.toLowerCase().contains(query) ||
            u.color.toLowerCase().contains(query) ||
            u.storage.toLowerCase().contains(query) ||
            (u.branchName ?? '').toLowerCase().contains(query);

        if (!matchesQuery) return false;

        if (_selectedCategory == 'Semua') return true;
        return u.name.toLowerCase().contains(_selectedCategory.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.phone_iphone_rounded, color: AppTheme.accent, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Pilih Unit iPhone',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.availableUnits.length} Unit',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accent),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),

          // Kolom Pencarian
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari tipe, nomor seri/aset, warna...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: AppTheme.surface,
              ),
            ),
          ),

          // Kategori Filter Cepat (Jika ada lebih dari 1 kategori selain Semua)
          if (categories.length > 2)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.accent,
                    backgroundColor: Colors.grey.shade100,
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                          _applyFilter();
                        });
                      }
                    },
                  );
                },
              ),
            ),

          // Info Bar Hasil
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text(
                  'Menampilkan ${_filteredUnits.length} unit siap dimutasi',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Daftar Unit
          Expanded(
            child: _filteredUnits.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Unit iPhone tidak ditemukan',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tidak ada unit yang cocok dengan kata kunci "${_searchController.text}".',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _selectedCategory = 'Semua';
                                _filteredUnits = widget.availableUnits;
                              });
                            },
                            child: const Text('Reset Pencarian'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _filteredUnits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final unit = _filteredUnits[index];
                      final isSelected = unit.id == widget.selectedUnit?.id;

                      return InkWell(
                        onTap: () => Navigator.pop(context, unit),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent.withValues(alpha: 0.08)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accent
                                  : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.phone_iphone_rounded,
                                  color: AppTheme.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      unit.name,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppTheme.accent
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            unit.assetCode,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${unit.storage} • ${unit.color}',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.place_outlined, size: 12, color: AppTheme.textSecondary),
                                            const SizedBox(width: 2),
                                            Text(
                                              unit.branchName ?? 'Pusat (SkyRent)',
                                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 22)
                              else
                                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

