import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/booking_repository.dart';
import '../../../models/booking_model.dart';
import '../../../models/payment_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/shift_warning_dialog.dart';

/// Enum representing the 4 operational metric categories
enum OperationalMetricType {
  pickup,
  returnToday,
  rentedUnits,
  revenueToday;

  String get title {
    switch (this) {
      case OperationalMetricType.pickup:
        return 'Pickup Hari Ini';
      case OperationalMetricType.returnToday:
        return 'Return Hari Ini';
      case OperationalMetricType.rentedUnits:
        return 'Unit Disewa';
      case OperationalMetricType.revenueToday:
        return 'Omzet Hari Ini';
    }
  }

  IconData get icon {
    switch (this) {
      case OperationalMetricType.pickup:
        return Icons.inbox_rounded;
      case OperationalMetricType.returnToday:
        return Icons.outbox_rounded;
      case OperationalMetricType.rentedUnits:
        return Icons.pie_chart_outline_rounded;
      case OperationalMetricType.revenueToday:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color get color {
    switch (this) {
      case OperationalMetricType.pickup:
        return const Color(0xFF2563EB);
      case OperationalMetricType.returnToday:
        return const Color(0xFFEF4444);
      case OperationalMetricType.rentedUnits:
        return const Color(0xFF2563EB);
      case OperationalMetricType.revenueToday:
        return const Color(0xFF047857);
    }
  }

  Color get bgColor {
    switch (this) {
      case OperationalMetricType.pickup:
        return const Color(0xFFEFF6FF);
      case OperationalMetricType.returnToday:
        return const Color(0xFFFEE2E2);
      case OperationalMetricType.rentedUnits:
        return const Color(0xFFEFF6FF);
      case OperationalMetricType.revenueToday:
        return const Color(0xFFDCFCE7);
    }
  }
}

/// Responsive Side Drawer / Dialog content for the 4 Operational Metrics
class OperationalMetricDetailSheet extends StatefulWidget {
  final OperationalMetricType initialType;
  final Map<String, dynamic> metrics;
  final List<BookingModel> allQueue;
  final List<BookingModel> pickupItems;
  final List<BookingModel> returnItems;
  final BookingRepository repository;
  final VoidCallback onClose;
  final ValueChanged<BookingModel>? onProcessReturn;
  final ValueChanged<BookingModel>? onProcessPickup;
  final ValueChanged<BookingModel>? onViewDetail;

  const OperationalMetricDetailSheet({
    super.key,
    required this.initialType,
    required this.metrics,
    required this.allQueue,
    required this.pickupItems,
    required this.returnItems,
    required this.repository,
    required this.onClose,
    this.onProcessReturn,
    this.onProcessPickup,
    this.onViewDetail,
  });

  @override
  State<OperationalMetricDetailSheet> createState() => _OperationalMetricDetailSheetState();
}

/// Represents all itemized payments grouped under a single parent booking card
class GroupedBookingRevenue {
  final String bookingCode;
  final String customerName;
  final String customerPhone;
  final String iphoneName;
  final double totalPaid;
  final DateTime latestPaymentDate;
  final List<PaymentTransactionModel> payments;

  GroupedBookingRevenue({
    required this.bookingCode,
    required this.customerName,
    required this.customerPhone,
    required this.iphoneName,
    required this.totalPaid,
    required this.latestPaymentDate,
    required this.payments,
  });
}

class _OperationalMetricDetailSheetState extends State<OperationalMetricDetailSheet> {
  late OperationalMetricType _currentType;
  String _returnFilter = 'semua'; // 'semua', 'terlambat', 'on_time'

  bool _loadingTransactions = false;
  List<PaymentTransactionModel> _todayTransactions = [];
  double _cashRevenue = 0.0;
  double _nonCashRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _loadFinancialData();
  }

  void _loadFinancialData() async {
    setState(() => _loadingTransactions = true);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    List<PaymentTransactionModel> txs = [];
    try {
      final fetched = await widget.repository.getPaymentHistory(
        startDate: today,
        endDate: todayEnd,
      );
      txs = fetched.where((t) => t.paymentStatus.toLowerCase() != 'void').toList();
    } catch (_) {}

    // Fallback: If no transactions from backend API yet, extract from paid bookings in allQueue
    if (txs.isEmpty) {
      final paidTodayBookings = widget.allQueue.where((b) {
        final isPaid = b.paymentStatus == PaymentStatus.paid || b.paymentStatus == PaymentStatus.partial;
        if (!isPaid) return false;
        final isToday = (b.createdAt != null &&
                b.createdAt!.year == today.year &&
                b.createdAt!.month == today.month &&
                b.createdAt!.day == today.day) ||
            (b.startDate.year == today.year &&
                b.startDate.month == today.month &&
                b.startDate.day == today.day);
        return isToday;
      }).toList();

      for (final b in paidTodayBookings) {
        final isPaidFull = b.paymentStatus == PaymentStatus.paid;
        final paid = isPaidFull ? b.price : (b.downPayment > 0 ? b.downPayment : b.price * 0.5);
        final rem = isPaidFull ? 0.0 : (b.price - paid);
        txs.add(
          PaymentTransactionModel(
            id: b.id,
            bookingId: b.id,
            bookingCode: b.bookingCode,
            customerName: b.customerName,
            customerPhone: b.customerPhone,
            iphoneName: b.iphone.fullName,
            rentTotal: b.price,
            paidAmount: paid,
            remainingAmount: rem,
            depositAmount: b.deposit,
            depositStatus: DepositStatus.held,
            paymentStatus: b.paymentStatus.name,
            paymentMethod: 'QRIS',
            transactionDate: b.createdAt ?? b.startDate,
          ),
        );
      }
    }

    // Deduplicate transaction records by unique ID or unique signature
    final uniqueTxs = <PaymentTransactionModel>[];
    final seenKeys = <String>{};
    for (final t in txs) {
      final key = t.id > 0
          ? 'id_${t.id}'
          : '${t.bookingCode}_${t.paidAmount}_${t.paymentMethod}_${t.transactionDate.year}${t.transactionDate.month}${t.transactionDate.day}${t.transactionDate.hour}${t.transactionDate.minute}';
      if (seenKeys.add(key)) {
        uniqueTxs.add(t);
      }
    }

    double cashSum = 0.0;
    double nonCashSum = 0.0;
    for (final t in uniqueTxs) {
      final m = t.paymentMethod.toLowerCase();
      final isCash = m.contains('tunai') || m.contains('cash');
      if (isCash) {
        cashSum += t.paidAmount;
      } else {
        nonCashSum += t.paidAmount;
      }
    }

    final totalRev = (widget.metrics['revenueToday'] as num?)?.toDouble() ??
        (widget.metrics['totalRevenue'] as num?)?.toDouble() ??
        (cashSum + nonCashSum);

    // If transactions sum is less than total revenue from metrics, balance with non-cash (QRIS)
    if (cashSum + nonCashSum < totalRev && (cashSum + nonCashSum) > 0) {
      nonCashSum = totalRev - cashSum;
    }

    if (mounted) {
      setState(() {
        _todayTransactions = uniqueTxs;
        _cashRevenue = cashSum;
        _nonCashRevenue = nonCashSum;
        _loadingTransactions = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('$label ($text) berhasil disalin ke clipboard')),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopHeader(),
        _buildCategorySegmentedTabs(),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: _buildSelectedContent(),
        ),
      ],
    );
  }

  Widget _buildTopHeader() {
    final title = _currentType.title;
    final badgeText = _getCategoryBadgeText();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _currentType.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_currentType.icon, size: 20, color: _currentType.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _currentType.bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _currentType.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _currentType.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Close button ("✕") with 44x44px touch target
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(10),
              hoverColor: Colors.grey.shade100,
              splashColor: Colors.grey.shade200,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryBadgeText() {
    switch (_currentType) {
      case OperationalMetricType.pickup:
        final pickupBookings = _getFilteredPickupBookings();
        return '${pickupBookings.length} Jadwal';
      case OperationalMetricType.returnToday:
        final allReturns = _getAllReturnBookings();
        return '${allReturns.length} Unit';
      case OperationalMetricType.rentedUnits:
        final rentedBookings = _getAllRentedBookings();
        return '${rentedBookings.length} Unit Aktif';
      case OperationalMetricType.revenueToday:
        final totalRev = (widget.metrics['revenueToday'] as num?)?.toDouble() ??
            (widget.metrics['totalRevenue'] as num?)?.toDouble() ??
            (_cashRevenue + _nonCashRevenue);
        return Formatters.formatCurrency(totalRev);
    }
  }

  Widget _buildCategorySegmentedTabs() {
    final activeThemeColor = Theme.of(context).colorScheme.primary;

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: OperationalMetricType.values.map((type) {
            final isSelected = _currentType == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentType = type;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? activeThemeColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? activeThemeColor : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: activeThemeColor.withValues(alpha: 0.22),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type.icon,
                          size: 15,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSelectedContent() {
    switch (_currentType) {
      case OperationalMetricType.returnToday:
        return _buildReturnContent();
      case OperationalMetricType.pickup:
        return _buildPickupContent();
      case OperationalMetricType.rentedUnits:
        return _buildRentedUnitsContent();
      case OperationalMetricType.revenueToday:
        return _buildRevenueContent();
    }
  }

  // ==========================================
  // A. "RETURN HARI INI" CONTENT
  // ==========================================
  List<BookingModel> _getAllReturnBookings() {
    if (widget.returnItems.isNotEmpty) {
      return widget.returnItems;
    }
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return widget.allQueue.where((b) {
      if (b.status == BookingStatus.returned || b.status == BookingStatus.cancelled) {
        return false;
      }
      final isRentedOrActive = b.status == BookingStatus.rented || b.status == BookingStatus.confirmed;
      if (!isRentedOrActive) return false;
      // return_deadline <= NOW() or scheduled for return today
      return b.isCurrentlyOverdue || b.endDate.isBefore(todayEnd) || b.endDate.isAtSameMomentAs(todayEnd);
    }).toList();
  }

  List<BookingModel> _getOverdueReturnBookings() {
    final all = _getAllReturnBookings();
    final now = DateTime.now();
    return all.where((b) => b.isCurrentlyOverdue || b.endDate.isBefore(now)).toList();
  }

  List<BookingModel> _getTodayReturnBookings() {
    final all = _getAllReturnBookings();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return all.where((b) {
      final isOverdue = b.isCurrentlyOverdue || b.endDate.isBefore(now);
      final isToday = b.endDate.year == today.year && b.endDate.month == today.month && b.endDate.day == today.day;
      return isToday && !isOverdue;
    }).toList();
  }

  List<BookingModel> _getFilteredReturnBookings() {
    final all = _getAllReturnBookings();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_returnFilter) {
      case 'terlambat':
        return all.where((b) => b.isCurrentlyOverdue || b.endDate.isBefore(now)).toList();
      case 'on_time':
      case 'jadwal_hari_ini':
        return all.where((b) {
          final isOverdue = b.isCurrentlyOverdue || b.endDate.isBefore(now);
          final isToday = b.endDate.year == today.year && b.endDate.month == today.month && b.endDate.day == today.day;
          return isToday && !isOverdue;
        }).toList();
      case 'semua':
      default:
        // Sort: overdue items first, then by endDate
        final list = List<BookingModel>.from(all);
        list.sort((a, b) {
          final aOverdue = a.isCurrentlyOverdue || a.endDate.isBefore(now);
          final bOverdue = b.isCurrentlyOverdue || b.endDate.isBefore(now);
          if (aOverdue && !bOverdue) return -1;
          if (!aOverdue && bOverdue) return 1;
          return a.endDate.compareTo(b.endDate);
        });
        return list;
    }
  }

  Widget _buildReturnContent() {
    final allReturns = _getAllReturnBookings();
    final overdueItems = _getOverdueReturnBookings();
    final todayItems = _getTodayReturnBookings();

    final displayItems = _getFilteredReturnBookings();

    return Column(
      children: [
        // Filter toggle chips: [Semua Return] [Terlambat / Overdue] [Jadwal Hari Ini]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              _buildFilterToggleChip('semua', 'Semua Return', allReturns.length, const Color(0xFF0F172A)),
              const SizedBox(width: 8),
              _buildFilterToggleChip('terlambat', 'Terlambat / Overdue', overdueItems.length, const Color(0xFFDC2626)),
              const SizedBox(width: 8),
              _buildFilterToggleChip('on_time', 'Jadwal Hari Ini', todayItems.length, const Color(0xFF2563EB), sublabel: 'On Time'),
            ],
          ),
        ),

        // List View of Return Items
        Expanded(
          child: displayItems.isEmpty
              ? _buildEmptyState(
                  icon: _returnFilter == 'terlambat' ? Icons.verified_user_rounded : Icons.outbox_rounded,
                  iconColor: _returnFilter == 'terlambat' ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                  iconBg: _returnFilter == 'terlambat' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  title: _returnFilter == 'terlambat'
                      ? 'Tidak ada unit terlambat hari ini'
                      : (_returnFilter == 'on_time'
                          ? 'Tidak ada jadwal return hari ini'
                          : 'Tidak ada data pengembalian unit'),
                  subtitle: _returnFilter == 'terlambat'
                      ? 'Semua unit yang disewa berjalan on time sesuai jadwal perjanjian.'
                      : (_returnFilter == 'on_time'
                          ? 'Belum ada unit yang dijadwalkan kembali pada hari ini.'
                          : 'Belum ada unit terjadwal return pada kategori filter ini.'),
                )
              : _buildCleanReturnList(displayItems, overdueItems, todayItems),
        ),
      ],
    );
  }

  Widget _buildCleanReturnList(List<BookingModel> displayItems, List<BookingModel> overdueItems, List<BookingModel> todayItems) {
    if (_returnFilter == 'semua' && overdueItems.isNotEmpty && todayItems.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildReturnSectionHeader(
            title: 'Terlambat / Overdue',
            count: overdueItems.length,
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 8),
          ...overdueItems.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildReturnCardItem(b),
              )),
          const SizedBox(height: 12),
          _buildReturnSectionHeader(
            title: 'Jadwal Hari Ini',
            count: todayItems.length,
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 8),
          ...todayItems.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildReturnCardItem(b),
              )),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: displayItems.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _buildReturnCardItem(displayItems[i]),
    );
  }

  Widget _buildReturnSectionHeader({
    required String title,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$title ($count Unit)',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggleChip(String key, String label, int count, Color activeColor, {String? sublabel}) {
    final isSelected = _returnFilter == key;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _returnFilter = key;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? activeColor : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sublabel != null)
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeColor : const Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
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

  Widget _buildReturnCardItem(BookingModel b) {
    final now = DateTime.now();
    final isOverdue = b.isCurrentlyOverdue || b.endDate.isBefore(now);
    final lateFee = isOverdue ? b.estimatedLateFee : 0.0;
    final lateDuration = now.difference(b.endDate);
    final isShortDelay = isOverdue && lateDuration.inHours < 2;

    // Severity color tokens
    final Color borderColor = isOverdue
        ? (isShortDelay ? const Color(0xFFFCD34D) : const Color(0xFFFCA5A5))
        : const Color(0xFFE2E8F0);
    final Color bannerBg = isOverdue
        ? (isShortDelay ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2))
        : const Color(0xFFF0FDF4);
    final Color bannerBorder = isOverdue
        ? (isShortDelay ? const Color(0xFFFDE68A) : const Color(0xFFFECACA))
        : const Color(0xFFDCFCE7);
    final Color accentColor = isOverdue
        ? (isShortDelay ? const Color(0xFFD97706) : const Color(0xFFDC2626))
        : const Color(0xFF16A34A);
    final Color bannerTextColor = isOverdue
        ? (isShortDelay ? const Color(0xFFB45309) : const Color(0xFFB91C1C))
        : const Color(0xFF15803D);
    final Color buttonBg = isOverdue
        ? (isShortDelay ? const Color(0xFFD97706) : const Color(0xFFDC2626))
        : AppTheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isOverdue ? 1.5 : 1,
        ),
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
          // Overdue / Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(
                bottom: BorderSide(
                  color: bannerBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isOverdue ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        size: 15,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isOverdue
                              ? (b.lateDurationFormatted.isNotEmpty
                                  ? 'Terlambat: ${b.lateDurationFormatted}'
                                  : 'Terlambat: ${b.currentLateHours} jam ${b.currentLateMinutes} mnt')
                              : 'Jadwal Return Hari Ini (${Formatters.time(b.endDate)} WIB)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: bannerTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOverdue && lateFee > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Denda: ${Formatters.formatCurrency(lateFee)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: Info Customer + Quick WA icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.customerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  b.customerPhone,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Quick WhatsApp copy/action
                              InkWell(
                                onTap: () => _copyToClipboard(b.customerPhone, 'WhatsApp ${b.customerName}'),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF16A34A)),
                                      SizedBox(width: 3),
                                      Text(
                                        'WA',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Collateral Held (Jaminan Ditahan)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Jaminan Ditahan',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                          ),
                          Text(
                            b.jaminanType.isNotEmpty ? b.jaminanType : 'KTP Fisik',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Baris 2: Detail Unit iPhone & S/N Monospace
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${b.iphone.name} • ${b.iphone.color}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                      ),
                      child: Text(
                        'SN: ${b.iphone.serialNumber.isNotEmpty ? b.iphone.serialNumber : '-'}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Baris 3: Jadwal Return (adjacent alignment)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: isOverdue ? accentColor : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Batas Kembali:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          Formatters.dateTime(b.endDate),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? accentColor : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Baris 4: Action Button "Proses Pengembalian" (44-48px touch target)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    key: Key('btn_proses_pengembalian_${b.bookingCode}'),
                    onPressed: () async {
                      final hasShift = await widget.repository.checkHasActiveShift();
                      if (!mounted) return;
                      if (!hasShift) {
                        await showShiftWarningDialog(context);
                        return;
                      }
                      widget.onProcessReturn?.call(b);
                    },
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                    label: const Text(
                      'Proses Pengembalian',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // B. "PICKUP HARI INI" CONTENT
  // ==========================================
  List<BookingModel> _getFilteredPickupBookings() {
    if (widget.pickupItems.isNotEmpty) {
      return widget.pickupItems;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.allQueue.where((b) {
      if (b.status != BookingStatus.confirmed) return false;
      return b.startDate.year == today.year &&
          b.startDate.month == today.month &&
          b.startDate.day == today.day;
    }).toList();
  }

  Widget _buildPickupContent() {
    final pickupItems = _getFilteredPickupBookings();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFEFF6FF),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${pickupItems.length} pelanggan dijadwalkan mengambil iPhone di outlet hari ini.',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: pickupItems.isEmpty
              ? _buildEmptyState(
                  icon: Icons.inbox_outlined,
                  iconColor: const Color(0xFF94A3B8),
                  iconBg: const Color(0xFFF1F5F9),
                  title: 'Tidak ada jadwal pickup hari ini',
                  subtitle: 'Semua booking untuk hari ini telah selesai diserahterimakan.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: pickupItems.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _buildPickupCardItem(pickupItems[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildPickupCardItem(BookingModel b) {
    String paymentTagText;
    Color paymentTagBg;
    Color paymentTagColor;

    switch (b.paymentStatus) {
      case PaymentStatus.paid:
        paymentTagText = 'Lunas';
        paymentTagBg = const Color(0xFFDCFCE7);
        paymentTagColor = const Color(0xFF15803D);
        break;
      case PaymentStatus.partial:
        paymentTagText = 'DP Sebagian';
        paymentTagBg = const Color(0xFFFEF3C7);
        paymentTagColor = const Color(0xFFB45309);
        break;
      case PaymentStatus.unpaid:
        paymentTagText = 'Belum Lunas';
        paymentTagBg = const Color(0xFFFEE2E2);
        paymentTagColor = const Color(0xFFB91C1C);
        break;
    }

    String scheduledTime = b.startTime?.isNotEmpty == true
        ? b.startTime!
        : Formatters.time(b.startDate);
    // Strip trailing seconds if present (e.g. 15:26:00 -> 15:26)
    final timeParts = scheduledTime.split(':');
    if (timeParts.length >= 2) {
      scheduledTime = '${timeParts[0]}:${timeParts[1]}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris 1: Jam Pickup & Tag Pembayaran
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Jadwal: $scheduledTime WIB',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: paymentTagBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    paymentTagText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: paymentTagColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Baris 2: Nama Customer & Quick WA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    b.customerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      b.customerPhone,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _copyToClipboard(b.customerPhone, 'WhatsApp ${b.customerName}'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF16A34A)),
                            SizedBox(width: 3),
                            Text(
                              'WA',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Baris 3: Reserved iPhone & S/N
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${b.iphone.name} • ${b.iphone.color}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                  ),
                  child: Text(
                    'SN: ${b.iphone.serialNumber.isNotEmpty ? b.iphone.serialNumber : '-'}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Baris 4: Package Checklist status & Action Button: "Serah Terima Unit" (side-by-side compact layout, 44px touch target)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF047857)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b.hasAddons
                                ? 'Paket (+${b.addonDevices.length} Add-on: ${b.addonDevices.map((a) => a.name).join(", ")})'
                                : 'Paket Standar (Unit, Kabel & Case)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    key: Key('btn_serah_terima_${b.bookingCode}'),
                    onPressed: () => widget.onProcessPickup?.call(b),
                    icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                    label: const Text(
                      'Serah Terima Unit',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // C. "UNIT DISEWA" CONTENT (ACTIVE FLEET)
  // ==========================================
  List<BookingModel> _getAllRentedBookings() {
    final now = DateTime.now();
    return widget.allQueue.where((b) {
      if (b.status == BookingStatus.returned || b.status == BookingStatus.cancelled) return false;
      if (b.status == BookingStatus.rented) return true;
      if (b.isCurrentlyOverdue || b.endDate.isBefore(now)) {
        return b.status == BookingStatus.confirmed || b.status == BookingStatus.rented;
      }
      return false;
    }).toList();
  }

  Widget _buildRentedUnitsContent() {
    final rentedBookings = _getAllRentedBookings();
    final totalUnits = (widget.metrics['totalUnits'] as num?)?.toInt() ??
        (widget.metrics['total_units'] as num?)?.toInt() ?? 30;
    final rentedCount = rentedBookings.length;
    final utilizationFraction = totalUnits > 0 ? (rentedCount / totalUnits).clamp(0.0, 1.0) : 0.0;
    final utilizationPercent = (utilizationFraction * 100).toInt();

    return Column(
      children: [
        // Top Fleet Summary
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Status Armada & Utilitas Toko',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$rentedCount / $totalUnits Unit Disewa ($utilizationPercent%)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: utilizationFraction,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: const Color(0xFF2563EB),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        // List of Active Rented Units
        Expanded(
          child: rentedBookings.isEmpty
              ? _buildEmptyState(
                  icon: Icons.devices_rounded,
                  iconColor: const Color(0xFF94A3B8),
                  iconBg: const Color(0xFFF1F5F9),
                  title: 'Seluruh unit berada di outlet',
                  subtitle: 'Saat ini tidak ada unit iPhone yang sedang dalam masa sewa aktif.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: rentedBookings.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _buildRentedCardItem(rentedBookings[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildRentedCardItem(BookingModel b) {
    final now = DateTime.now();
    final isOverdue = b.isCurrentlyOverdue || b.endDate.isBefore(now);
    final diff = b.endDate.difference(now);

    String remainingText;
    if (isOverdue) {
      remainingText = 'Lewat Tenggat (${b.lateDurationFormatted})';
    } else {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;
      if (days > 0) {
        remainingText = 'Sisa: $days hari $hours jam';
      } else if (hours > 0) {
        remainingText = 'Sisa: $hours jam $minutes mnt';
      } else {
        remainingText = 'Sisa: $minutes mnt';
      }
    }

    final storeLocation = b.iphone.branchName?.isNotEmpty == true
        ? b.iphone.branchName!
        : 'Outlet Pusat (Main Store)';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris 1: Model & S/N Monospace
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${b.iphone.name} ${b.iphone.storage} • ${b.iphone.color}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                  ),
                  child: Text(
                    'SN: ${b.iphone.serialNumber.isNotEmpty ? b.iphone.serialNumber : '-'}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Baris 2: Active Renter Name & Quick Contact WA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Penyewa: ${b.customerName}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copyToClipboard(b.customerPhone, 'WhatsApp ${b.customerName}'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF16A34A)),
                        SizedBox(width: 3),
                        Text('Hubungi WA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Baris 3: Rental Start & Countdown / Deadline
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mulai Sewa:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          Formatters.dateTime(b.startDate),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Batas Kembali:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            remainingText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Lokasi Toko:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFF047857)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                storeLocation,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Button: "Detail Rental"
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => widget.onViewDetail?.call(b),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Detail Rental', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // D. "OMZET HARI INI" CONTENT (FINANCIAL LOG)
  // ==========================================
  Widget _buildRevenueContent() {
    final totalRev = (widget.metrics['revenueToday'] as num?)?.toDouble() ??
        (widget.metrics['totalRevenue'] as num?)?.toDouble() ??
        1850000.0;

    return Column(
      children: [
        // Quick Financial Summary Bar (3 Cards)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFinancialSummaryCard(
                  title: 'Total Omzet',
                  amount: totalRev,
                  color: const Color(0xFF047857),
                  bgColor: const Color(0xFFECFDF5),
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinancialSummaryCard(
                  title: 'Tunai (Cash)',
                  amount: _cashRevenue,
                  color: const Color(0xFF15803D),
                  bgColor: const Color(0xFFF0FDF4),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinancialSummaryCard(
                  title: 'Non-Tunai (QRIS/Trf)',
                  amount: _nonCashRevenue,
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFFAF5FF),
                  icon: Icons.qr_code_2_rounded,
                ),
              ),
            ],
          ),
        ),

        // Subheader: Transaksi Pembayaran Masuk
        Builder(
          builder: (ctx) {
            final groupedBookings = _getGroupedTodayTransactions();
            final totalPaymentsCount = _todayTransactions.length;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Log Transaksi Hari Ini',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    groupedBookings.length == totalPaymentsCount
                        ? '$totalPaymentsCount Pembayaran'
                        : '${groupedBookings.length} Booking ($totalPaymentsCount Pembayaran)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          },
        ),

        // Transactions List
        Expanded(
          child: _loadingTransactions
              ? const Center(child: CircularProgressIndicator())
              : _todayTransactions.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.receipt_long_outlined,
                      iconColor: const Color(0xFF94A3B8),
                      iconBg: const Color(0xFFF1F5F9),
                      title: 'Belum ada transaksi omzet hari ini',
                      subtitle: 'Transaksi pembayaran lunas atau DP yang dibuat hari ini akan tercatat di sini.',
                    )
                  : Builder(
                      builder: (ctx) {
                        final groupedBookings = _getGroupedTodayTransactions();
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: groupedBookings.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) => _buildGroupedRevenueCardItem(groupedBookings[i]),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  List<GroupedBookingRevenue> _getGroupedTodayTransactions() {
    final Map<String, List<PaymentTransactionModel>> groups = {};
    for (final tx in _todayTransactions) {
      final code = tx.bookingCode.trim().toUpperCase();
      groups.putIfAbsent(code, () => []).add(tx);
    }

    final result = <GroupedBookingRevenue>[];
    for (final entry in groups.entries) {
      final list = entry.value;
      list.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
      final totalPaid = list.fold<double>(0.0, (sum, t) => sum + t.paidAmount);
      final first = list.first;
      final last = list.last;
      result.add(GroupedBookingRevenue(
        bookingCode: entry.key,
        customerName: first.customerName,
        customerPhone: first.customerPhone,
        iphoneName: first.iphoneName,
        totalPaid: totalPaid,
        latestPaymentDate: last.transactionDate,
        payments: list,
      ));
    }

    result.sort((a, b) => b.latestPaymentDate.compareTo(a.latestPaymentDate));
    return result;
  }

  Widget _buildGroupedRevenueCardItem(GroupedBookingRevenue group) {
    if (group.payments.length == 1) {
      return _buildTransactionCardItem(group.payments.first);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Booking code + Multi-part badge + Total Paid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '#${group.bookingCode}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: Text(
                        '${group.payments.length}x Pembayaran',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7E22CE),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.formatCurrency(group.totalPaid),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Customer and Device details
          Row(
            children: [
              Expanded(
                child: Text(
                  '${group.customerName} (${group.customerPhone})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  group.iphoneName,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Itemized Payment Breakdown
          const Text(
            'Rincian Pembayaran Masuk:',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < group.payments.length; i++) ...[
                  if (i > 0) const Divider(height: 8, thickness: 1, color: Color(0xFFE2E8F0)),
                  _buildItemizedPaymentRow(group.payments[i], i, group.payments.length),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedPaymentRow(PaymentTransactionModel tx, int index, int totalCount) {
    final typeLabel = _resolvePaymentTypeLabel(tx, index, totalCount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            Formatters.time(tx.transactionDate),
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D4ED8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildPaymentMethodPill(tx.paymentMethod),
          const Spacer(),
          Text(
            Formatters.formatCurrency(tx.paidAmount),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _resolvePaymentTypeLabel(PaymentTransactionModel tx, int index, int totalCount) {
    if (tx.notes != null) {
      final n = tx.notes!.toLowerCase();
      if (n.contains('dp') || n.contains('uang muka')) return 'Uang Muka (DP)';
      if (n.contains('lunas') || n.contains('pelunasan')) return 'Pelunasan Sewa';
      if (n.contains('denda') || n.contains('penalty')) return 'Denda';
      if (n.contains('extend') || n.contains('tambah jam') || n.contains('durasi')) return 'Perpanjangan';
    }
    if (totalCount > 1) {
      if (index == 0) return 'Uang Muka (DP)';
      return 'Pelunasan Sewa';
    }
    return tx.paymentStatus == 'partial' ? 'Uang Muka (DP)' : 'Pelunasan Sewa';
  }

  Widget _buildPaymentMethodPill(String method) {
    IconData methodIcon = Icons.payments_outlined;
    Color methodColor = const Color(0xFF15803D);
    Color methodBg = const Color(0xFFDCFCE7);
    String methodLabel = method;

    final pmLower = method.toLowerCase();
    if (pmLower.contains('qris')) {
      methodIcon = Icons.qr_code_2_rounded;
      methodColor = const Color(0xFF7C3AED);
      methodBg = const Color(0xFFFAF5FF);
      methodLabel = 'QRIS';
    } else if (pmLower.contains('transfer') || pmLower.contains('bca') || pmLower.contains('mandiri')) {
      methodIcon = Icons.account_balance_outlined;
      methodColor = const Color(0xFF2563EB);
      methodBg = const Color(0xFFEFF6FF);
      methodLabel = 'Transfer';
    } else {
      methodIcon = Icons.payments_outlined;
      methodColor = const Color(0xFF15803D);
      methodBg = const Color(0xFFDCFCE7);
      methodLabel = 'Tunai';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: methodBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(methodIcon, size: 10, color: methodColor),
          const SizedBox(width: 3),
          Text(
            methodLabel,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: methodColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              Formatters.formatCurrency(amount),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveSinglePaymentTypeLabel(PaymentTransactionModel tx) {
    if (tx.notes != null) {
      final n = tx.notes!.toLowerCase();
      if (n.contains('dp') || n.contains('uang muka')) return 'DP';
      if (n.contains('lunas') || n.contains('pelunasan')) return 'Pelunasan';
      if (n.contains('denda') || n.contains('penalty')) return 'Denda';
      if (n.contains('extend') || n.contains('tambah jam') || n.contains('durasi')) return 'Perpanjangan';
    }
    if (tx.paymentStatus.toLowerCase() == 'partial') {
      return 'DP';
    }
    if (tx.remainingAmount > 0) {
      return 'DP';
    }
    return 'Sewa Penuh';
  }

  Widget _buildTransactionCardItem(PaymentTransactionModel tx) {
    IconData methodIcon = Icons.payments_outlined;
    Color methodColor = const Color(0xFF16A34A);
    Color methodBg = const Color(0xFFDCFCE7);
    String methodLabel = tx.paymentMethod;

    final pmLower = tx.paymentMethod.toLowerCase();
    if (pmLower.contains('qris')) {
      methodIcon = Icons.qr_code_2_rounded;
      methodColor = const Color(0xFF7C3AED);
      methodBg = const Color(0xFFFAF5FF);
      methodLabel = 'QRIS';
    } else if (pmLower.contains('transfer') || pmLower.contains('bca') || pmLower.contains('mandiri')) {
      methodIcon = Icons.account_balance_outlined;
      methodColor = const Color(0xFF2563EB);
      methodBg = const Color(0xFFEFF6FF);
      methodLabel = 'Transfer';
    } else {
      methodIcon = Icons.payments_outlined;
      methodColor = const Color(0xFF15803D);
      methodBg = const Color(0xFFDCFCE7);
      methodLabel = 'Tunai';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 500;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Code & Time on left, Payment badges on right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#${tx.bookingCode}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          Formatters.time(tx.transactionDate),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        alignment: WrapAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              _resolveSinglePaymentTypeLabel(tx),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: methodBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(methodIcon, size: 11, color: methodColor),
                                const SizedBox(width: 3),
                                Text(
                                  methodLabel,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: methodColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Bottom Row: Customer & Device on left, Paid Amount on right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.customerName,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx.iphoneName,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.formatCurrency(tx.paidAmount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              // Timestamp & Invoice ID
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${tx.bookingCode}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.time(tx.transactionDate),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Customer & Device
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.customerName,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.iphoneName,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Payment Channel Pill & Amount
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              _resolveSinglePaymentTypeLabel(tx),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: methodBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(methodIcon, size: 11, color: methodColor),
                              const SizedBox(width: 3),
                              Text(
                                methodLabel,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: methodColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatCurrency(tx.paidAmount),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // SHARED EMPTY STATE WIDGET
  // ==========================================
  Widget _buildEmptyState({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
