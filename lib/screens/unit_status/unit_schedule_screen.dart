import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../booking/widgets/booking_card_skeleton.dart';

class UnitScheduleScreen extends StatefulWidget {
  final IphoneModel unit;
  final BookingRepository repository;

  const UnitScheduleScreen({
    super.key,
    required this.unit,
    required this.repository,
  });

  @override
  State<UnitScheduleScreen> createState() => _UnitScheduleScreenState();
}

class _UnitScheduleScreenState extends State<UnitScheduleScreen> {
  List<BookingModel> _schedules = [];
  bool _isLoading = true;
  String _selectedTimeframe = 'Semua';

  final List<String> _timeframeOptions = [
    'Semua',
    'Aktif',
    'Mendatang',
    'Selesai',
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.repository.getUnitRentalSchedule(
        widget.unit.assetCode,
        timeframeFilter: _selectedTimeframe == 'Semua' ? null : _selectedTimeframe,
      );
      if (mounted) {
        setState(() {
          _schedules = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat jadwal sewa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, int> _computeCounts() {
    int total = _schedules.length;
    int aktif = 0;
    int mendatang = 0;
    int selesai = 0;

    for (final b in _schedules) {
      if (b.status == BookingStatus.rented) {
        aktif++;
      } else if (b.status == BookingStatus.confirmed || b.status == BookingStatus.pending) {
        mendatang++;
      } else if (b.status == BookingStatus.returned || b.status == BookingStatus.cancelled) {
        selesai++;
      }
    }

    return {
      'total': total,
      'aktif': aktif,
      'mendatang': mendatang,
      'selesai': selesai,
    };
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return const Color(0xFF3B82F6); // Blue
      case BookingStatus.rented:
        return const Color(0xFFF59E0B); // Amber
      case BookingStatus.returned:
        return const Color(0xFF10B981); // Emerald Green
      case BookingStatus.cancelled:
        return const Color(0xFFEF4444); // Red
      case BookingStatus.pending:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  Color _getStatusBgColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return const Color(0xFFDBEAFE);
      case BookingStatus.rented:
        return const Color(0xFFFEF3C7);
      case BookingStatus.returned:
        return const Color(0xFFD1FAE5);
      case BookingStatus.cancelled:
        return const Color(0xFFFEE2E2);
      case BookingStatus.pending:
        return const Color(0xFFEDE9FE);
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Icons.event_available_rounded;
      case BookingStatus.rented:
        return Icons.access_time_filled_rounded;
      case BookingStatus.returned:
        return Icons.check_circle_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_rounded;
      case BookingStatus.pending:
        return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _computeCounts();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jadwal Sewa Unit'),
            Text(
              '${widget.unit.name} • ${widget.unit.assetCode}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadSchedule,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSchedule,
        child: Column(
          children: [
            // Unit Overview Header Card
            _buildUnitHeaderCard(),

            // Stats row
            _buildScheduleStats(counts),

            // Timeframe filter tabs
            _buildTimeframeTabs(),

            // Timeline List
            Expanded(
              child: _isLoading
                  ? const BookingListSkeleton(itemCount: 3)
                  : _schedules.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _schedules.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _buildTimelineItem(_schedules[index], index == _schedules.length - 1);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitHeaderCard() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.phone_iphone_rounded,
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
                    widget.unit.fullDisplayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Aset: ${widget.unit.assetCode}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SN: ${widget.unit.serialNumber}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'BH ${widget.unit.batteryHealth}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleStats(Map<String, int> counts) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStatCard('Total Slot', counts['total'] ?? 0, AppTheme.primary),
          const SizedBox(width: 8),
          _buildStatCard('Aktif Sewa', counts['aktif'] ?? 0, const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _buildStatCard('Mendatang', counts['mendatang'] ?? 0, const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          _buildStatCard('Selesai', counts['selesai'] ?? 0, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
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

  Widget _buildTimeframeTabs() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Row(
        children: _timeframeOptions.map((tf) {
          final isSelected = _selectedTimeframe == tf;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedTimeframe = tf);
                  _loadSchedule();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      tf,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineItem(BookingModel booking, bool isLast) {
    final statusColor = _getStatusColor(booking.status);
    final statusBg = _getStatusBgColor(booking.status);
    final statusIcon = _getStatusIcon(booking.status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Booking Code + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    booking.bookingCode,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  booking.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date & Duration Timeline Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${Formatters.date(booking.startDate)} - ${Formatters.date(booking.endDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${booking.durationDays} Hari',
                    style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Customer Info
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${booking.customerName} • ${booking.customerPhone}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Financial Summary & Detail Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sewa: ${Formatters.currency(booking.price)} (Dep: ${Formatters.currency(booking.deposit)})',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.bookingDetail,
                    arguments: booking,
                  ).then((_) => _loadSchedule());
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Detail', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Tidak ada jadwal sewa ($_selectedTimeframe)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unit siap menerima reservasi booking baru',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
