import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/notification_model.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class NotificationListScreen extends StatefulWidget {
  final BookingRepository repository;
  final bool isEmbedded;

  const NotificationListScreen({
    super.key,
    required this.repository,
    this.isEmbedded = false,
  });

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';

  final List<String> _filters = ['Semua', 'Belum Dibaca', 'Peringatan'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.repository.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat notifikasi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await widget.repository.markAllNotificationsAsRead();
    _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua notifikasi ditandai telah dibaca'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _markAsRead(String id) async {
    await widget.repository.markNotificationAsRead(id);
    _loadNotifications();
  }

  List<NotificationModel> get _filteredNotifications {
    if (_selectedFilter == 'Belum Dibaca') {
      return _notifications.where((n) => !n.isRead).toList();
    } else if (_selectedFilter == 'Peringatan') {
      return _notifications.where((n) => n.type == NotificationType.overdue || n.type == NotificationType.maintenance).toList();
    }
    return _notifications;
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.overdue:
        return const Color(0xFFEF4444); // Red
      case NotificationType.pickupToday:
        return const Color(0xFF3B82F6); // Blue
      case NotificationType.maintenance:
        return const Color(0xFFF59E0B); // Amber
      case NotificationType.closing:
        return const Color(0xFF8B5CF6); // Purple
      case NotificationType.info:
        return AppTheme.accent;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.overdue:
        return Icons.warning_amber_rounded;
      case NotificationType.pickupToday:
        return Icons.event_available_rounded;
      case NotificationType.maintenance:
        return Icons.build_circle_outlined;
      case NotificationType.closing:
        return Icons.receipt_long_rounded;
      case NotificationType.info:
        return Icons.info_outline_rounded;
    }
  }

  void _handleNotificationTap(NotificationModel notif) {
    _markAsRead(notif.id);

    if (notif.bookingCode != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.bookingDetail,
        arguments: notif.bookingCode,
      ).then((_) => _loadNotifications());
    } else if (notif.type == NotificationType.maintenance) {
      Navigator.pushNamed(context, AppRoutes.unitStatus).then((_) => _loadNotifications());
    } else if (notif.type == NotificationType.closing) {
      Navigator.pushNamed(context, AppRoutes.salesReport).then((_) => _loadNotifications());
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredNotifications;
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    if (widget.isEmbedded) {
      return _buildEmbeddedLayout(context, list, unreadCount);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pusat Notifikasi'),
            Text(
              '$unreadCount notifikasi belum dibaca',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Tandai Semua Dibaca',
              onPressed: _markAllAsRead,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.cardBorder,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide.none,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Notification List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _buildNotificationTile(list[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedLayout(
    BuildContext context,
    List<NotificationModel> list,
    int unreadCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header matching tablet design
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pusat Notifikasi Operasional',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unreadCount > 0
                          ? '$unreadCount notifikasi belum dibaca • Pantau pengingat pengembalian, jatuh tempo, dan servis unit.'
                          : 'Semua notifikasi telah dibaca • Pantau pengingat pengembalian, jatuh tempo, dan servis unit.',
                      style: TextStyle(
                        fontSize: 12,
                        color: unreadCount > 0 ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (unreadCount > 0)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _markAllAsRead,
                      icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Tandai Semua Dibaca', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _loadNotifications,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Segarkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter Tabs Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.cardBorder,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedFilter = filter);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Notification List
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (list.isEmpty)
          _buildEmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildNotificationTile(list[index]);
            },
          ),
      ],
    );
  }

  Widget _buildNotificationTile(NotificationModel notif) {
    final color = _getNotificationColor(notif.type);
    final icon = _getNotificationIcon(notif.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationTap(notif),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notif.isRead ? AppTheme.cardBorder : color.withValues(alpha: 0.3),
              width: notif.isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: notif.isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Formatters.dateTime(notif.createdAt),
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                        Row(
                          children: [
                            Text(
                              'Buka Tindakan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
          Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Tidak ada notifikasi ($_selectedFilter)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Semua operasional rental dalam status normal.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
