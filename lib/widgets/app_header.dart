import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Reusable top app header shared across Dashboard, Sales Report, and Unit iPhone screens.
/// Features dynamic user authentication information (username, role badge, shift/outlet)
/// with reactive updates via AuthService, and completely omits hardware printer status.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isTablet;
  final String? title;

  const AppHeader({
    super.key,
    this.isTablet = false,
    this.title,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  static String getRoleBadgeText(String? role) {
    if (role == null || role.trim().isEmpty) return 'KASIR';
    final r = role.toLowerCase();
    if (r.contains('superadmin') || r.contains('owner') || r.contains('admin')) {
      return 'ADMIN';
    }
    if (r.contains('manager')) {
      return 'MANAGER';
    }
    if (r.contains('kasir') || r.contains('cashier')) {
      return 'KASIR';
    }
    return 'STAFF';
  }

  static String getDayName(DateTime date) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService(),
      builder: (context, _) {
        final user = AuthService().currentUser;
        final userName = user?.name.trim().isNotEmpty == true
            ? user!.name
            : 'Admin SKYRental';
        final userRole = user?.role.trim().isNotEmpty == true ? user!.role : 'Staff Operasional';
        final roleBadge = getRoleBadgeText(user?.role);

        if (isTablet) {
          return _buildTabletHeader(context, userName, userRole, roleBadge, user?.shiftName, user?.outletName);
        }
        return _buildMobileHeader(context, userName, userRole, roleBadge);
      },
    );
  }

  Widget _buildTabletHeader(
    BuildContext context,
    String userName,
    String userRole,
    String roleBadge,
    String? shiftName,
    String? outletName,
  ) {
    final now = DateTime.now();
    final dateFormatted = '${getDayName(now)}, ${Formatters.date(now)}';
    final topPadding = MediaQuery.paddingOf(context).top;
    final initials = userName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
    final effectiveInitials = initials.isNotEmpty ? initials : 'AS';

    final shiftText = (shiftName != null && shiftName.contains('('))
        ? shiftName.split('(').first.trim()
        : (shiftName?.trim().isNotEmpty == true ? shiftName!.trim() : 'Shift Pagi');
    final subtitleText = '$shiftText • POS-01';

    return PreferredSize(
      preferredSize: preferredSize,
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
              // Left: Logo / Brand Title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                      if (title != null && title!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            title!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Text(
                    'POS Station #01',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              // Right: Date container & User profile (NO printer status)
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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

                      // Staff Profile Info with Online Badge
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.account),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF0F172A),
                                  child: Text(
                                    effectiveInitials,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
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
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      userName,
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
                                        roleBadge,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  subtitleText,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    String userName,
    String userRole,
    String roleBadge,
  ) {
    return PreferredSize(
      preferredSize: preferredSize,
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
            // User login info
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
                  Text(
                    title ?? userRole,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Profile Avatar with green online dot (NO printer status)
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
