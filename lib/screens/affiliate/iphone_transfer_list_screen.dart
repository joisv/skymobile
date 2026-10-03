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
    _selectedAffiliateId = widget.initialAffiliateId ??
        (AuthService().isAffiliateAdmin ? AuthService().affiliateId : null);
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
      final transfers = await widget.repository.getIphoneTransfers(
        affiliateId: _selectedAffiliateId,
        forceRefresh: true,
      );
      final affiliates = await widget.repository.getAffiliates();

      if (mounted) {
        setState(() {
          _allTransfers = transfers;
          _affiliateList = affiliates;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
          AuthService().isAffiliateAdmin ? 'Transfer iPhone Masuk' : 'Mutasi & Transfer Unit',
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
                  Text(AuthService().isAffiliateAdmin ? 'Dalam Pengiriman' : 'Terkirim'),
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
              text: AuthService().isAffiliateAdmin
                  ? 'Diterima (${_allTransfers.where((t) => t.isReceived).length})'
                  : 'Selesai (${_allTransfers.where((t) => t.isReceived).length})',
            ),
          ],
        ),
      ),
      floatingActionButton: (AuthService().isSuperAdmin || (AuthService().isAdmin && !AuthService().isAffiliateAdmin))
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
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(40),
          children: [
            const SizedBox(height: 60),
            Icon(Icons.swap_horiz_rounded, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'Tidak Ada Riwayat Transfer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Gunakan tombol "Kirim Unit iPhone" di bawah untuk memutasi unit antar cabang.',
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mutasi & Transfer Unit iPhone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Pencatatan pengiriman, pelacakan transit, dan serah-terima unit iPhone antar outlet.',
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
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF475569)),
                  tooltip: 'Segarkan Data',
                ),
                if (AuthService().isSuperAdmin || (AuthService().isAdmin && !AuthService().isAffiliateAdmin)) ...[
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
          Container(
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
                const Text(
                  'Tidak Ada Riwayat Transfer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gunakan tombol "Kirim Unit iPhone" di atas untuk memutasi unit antar cabang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
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
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedToAffiliateId = widget.defaultAffiliateId;
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
          // Hanya unit yang tidak sedang tersewa/disewa yang dapat dimutasi
          _availableUnits = units.where((u) {
            final s = u.status.toLowerCase();
            return s != 'rented' && s != 'disewa' && s != 'booked';
          }).toList();
          _isLoadingUnits = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUnits = false);
    }
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih unit iPhone yang akan dikirim.'), backgroundColor: AppTheme.error),
      );
      return;
    }
    if (_selectedToAffiliateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih cabang tujuan pengiriman.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.repository.createIphoneTransfer(
        iphoneId: _selectedUnit!.id,
        toAffiliateId: _selectedToAffiliateId!,
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
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Row(children: [
                  Icon(Icons.swap_horiz_rounded, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Kirim & Mutasi iPhone',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Kirim unit iPhone ke cabang mitra affiliate lain.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),

              // Pilih Unit iPhone
              const Text('Unit iPhone *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (_isLoadingUnits)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_availableUnits.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tidak ada unit iPhone yang siap dikirim (semua unit sedang tersewa atau dalam mutasi).',
                          style: TextStyle(fontSize: 12, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<IphoneModel>(
                  initialValue: _selectedUnit,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Pilih unit iPhone',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _availableUnits.map((u) {
                    return DropdownMenuItem<IphoneModel>(
                      value: u,
                      child: Text(
                        '${u.name} (${u.assetCode}) - ${u.statusLabel}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedUnit = val),
                  validator: (val) => val == null ? 'Pilih unit iPhone' : null,
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
                items: widget.affiliates.map((a) {
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

              // Tombol Submit
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (_isSubmitting || _availableUnits.isEmpty) ? null : _submitTransfer,
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Mengirim...' : 'Kirim Sekarang',
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
