import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/affiliate_model.dart';
import '../../models/affiliate_revenue_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class AffiliateRevenueScreen extends StatefulWidget {
  final AffiliateModel affiliate;
  final BookingRepository repository;

  const AffiliateRevenueScreen({
    super.key,
    required this.affiliate,
    required this.repository,
  });

  @override
  State<AffiliateRevenueScreen> createState() => _AffiliateRevenueScreenState();
}

class _AffiliateRevenueScreenState extends State<AffiliateRevenueScreen> {
  bool _isLoading = true;
  AffiliateRevenueSummaryModel? _summary;
  String _selectedPeriod = 'all'; // 'today', 'week', 'month', 'all', 'custom'
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _loadRevenueData();
  }

  Future<void> _loadRevenueData() async {
    setState(() => _isLoading = true);
    try {
      String? startDate;
      String? endDate;

      final now = DateTime.now();
      if (_selectedPeriod == 'today') {
        final dStr = now.toIso8601String().substring(0, 10);
        startDate = dStr;
        endDate = dStr;
      } else if (_selectedPeriod == 'week') {
        final start = now.subtract(const Duration(days: 7));
        startDate = start.toIso8601String().substring(0, 10);
        endDate = now.toIso8601String().substring(0, 10);
      } else if (_selectedPeriod == 'month') {
        final start = DateTime(now.year, now.month, 1);
        startDate = start.toIso8601String().substring(0, 10);
        endDate = now.toIso8601String().substring(0, 10);
      } else if (_selectedPeriod == 'custom' && _customDateRange != null) {
        startDate = _customDateRange!.start.toIso8601String().substring(0, 10);
        endDate = _customDateRange!.end.toIso8601String().substring(0, 10);
      }

      final data = await widget.repository.getAffiliateRevenue(
        widget.affiliate.id,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        setState(() {
          _summary = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customDateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customDateRange = picked;
      });
      _loadRevenueData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Omset - ${widget.affiliate.name}',
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: _loadRevenueData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRevenueData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Affiliate Header Info
                  _buildAffiliateHeader(),
                  const SizedBox(height: 16),

                  // Period Filter Buttons
                  _buildPeriodFilter(),
                  const SizedBox(height: 16),

                  // Summary KPI Cards Grid
                  _buildKpiSection(),
                  const SizedBox(height: 24),

                  // Transactions Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Riwayat Transaksi Masuk',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${_summary?.payments.length ?? 0} Transaksi',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Transactions List
                  _buildPaymentsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildAffiliateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.affiliate.code,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.affiliate.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.affiliate.locationSummary,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Text(
              'Aktif',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', 'Semua Periode'),
          const SizedBox(width: 8),
          _buildFilterChip('today', 'Hari Ini'),
          const SizedBox(width: 8),
          _buildFilterChip('week', '7 Hari Terakhir'),
          const SizedBox(width: 8),
          _buildFilterChip('month', 'Bulan Ini'),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range_rounded, size: 16),
            label: Text(
              _selectedPeriod == 'custom' && _customDateRange != null
                  ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                  : 'Pilih Tanggal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: _selectedPeriod == 'custom' ? FontWeight.bold : FontWeight.normal,
                color: _selectedPeriod == 'custom' ? AppTheme.accent : AppTheme.textPrimary,
              ),
            ),
            backgroundColor: _selectedPeriod == 'custom' ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.surface,
            side: BorderSide(
              color: _selectedPeriod == 'custom' ? AppTheme.accent : Colors.grey.shade300,
            ),
            onPressed: _pickDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      side: BorderSide(
        color: isSelected ? AppTheme.primary : Colors.grey.shade300,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPeriod = period);
          _loadRevenueData();
        }
      },
    );
  }

  Widget _buildKpiSection() {
    final s = _summary;
    final totalRev = s?.affiliateRevenue ?? widget.affiliate.totalRevenue;
    final todayRev = s?.revenueToday ?? widget.affiliate.revenueToday;
    final totalBookings = s?.affiliateBookingCount ?? widget.affiliate.bookingsCount;
    final todayBookings = s?.bookingToday ?? 0;

    return Column(
      children: [
        // Main Total Revenue Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'TOTAL OMSET CABANG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppFormatters.formatCurrency(totalRev),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Booking', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(
                        '$totalBookings Sewa',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Hari Ini', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatters.formatCurrency(todayRev),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4ADE80)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2 Secondary KPI Cards
        Row(
          children: [
            Expanded(
              child: _buildSmallKpiCard(
                icon: Icons.calendar_today_rounded,
                iconColor: Colors.blue,
                label: 'Booking Hari Ini',
                value: '$todayBookings Booking',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallKpiCard(
                icon: Icons.receipt_long_rounded,
                iconColor: Colors.orange,
                label: 'Total Transaksi',
                value: '${s?.paymentsCount ?? s?.payments.length ?? 0} Transaksi',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallKpiCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    final payments = _summary?.payments ?? [];

    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Transaksi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada transaksi pembayaran pada cabang ini dalam periode yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final payment = payments[index];
        return _buildPaymentCard(payment);
      },
    );
  }

  Widget _buildPaymentCard(AffiliatePaymentItemModel payment) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF047857), size: 20),
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
                        payment.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '+ ${AppFormatters.formatCurrency(payment.amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${payment.bookingCode} • ${payment.iphoneName}',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        payment.paymentMethod.toUpperCase(),
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                    ),
                    Text(
                      payment.paidAt != null ? AppFormatters.formatDateTime(payment.paidAt!) : '-',
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
