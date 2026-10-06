import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Single unified reusable top app header component used across all screens
/// (Dashboard, Sales Report, Unit iPhone, Printer, Shift, Create Booking, etc.).
///
/// Automatically retrieves authenticated user info (name, role, initials avatar)
/// from AuthService as the single source of truth, strictly omits any hardware printer status,
/// and guarantees consistent initials-based avatar styling with online status dot.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final bool? isTablet;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.isTablet,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(68 + (bottom?.preferredSize.height ?? 0));

  /// Generate profile initials from authenticated user's name:
  /// - One-word name -> first letter (e.g. "Admin" -> "A")
  /// - Multiple words -> first letter of first word + first letter of second word (e.g. "John Doe" -> "JD")
  static String getUserInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Format friendly role title using the application's role mapping.
  /// Strictly distinguishes between Affiliate Admin, Super Admin, Admin, Kasir, and Staff.
  static String formatRole(String? rawRole) {
    if (rawRole == null || rawRole.trim().isEmpty) return 'Staff Operasional';
    final r = rawRole.trim();
    final lower = r.toLowerCase();

    if (lower == 'super-admin' || lower == 'superadmin' || lower == 'super admin') {
      return 'Super Admin';
    }
    if (lower == 'affiliate-admin' || lower == 'affiliate_admin' || lower == 'affiliate admin' ||
        (lower.contains('affiliate') && lower.contains('admin'))) {
      return 'Affiliate Admin';
    }
    if (lower == 'affiliate' || lower == 'mitra' || lower == 'mitra affiliate') {
      return 'Affiliate';
    }
    if (lower == 'admin') {
      return 'Admin';
    }
    if (lower == 'manager') {
      return 'Manager';
    }
    if (lower == 'kasir' || lower == 'cashier') {
      return 'Kasir';
    }
    if (lower == 'staff' || lower == 'staff kasir') {
      return 'Staff';
    }
    if (lower.contains('super')) {
      return 'Super Admin';
    }
    return r;
  }

  /// Uppercase compact badge text for the user's role pill.
  /// Evaluates affiliate-admin and super-admin before generic admin.
  static String getRoleBadgeText(String? rawRole) {
    if (rawRole == null || rawRole.trim().isEmpty) return 'KASIR';
    final r = rawRole.trim();
    final lower = r.toLowerCase();

    if (lower == 'super-admin' || lower == 'superadmin' || lower == 'super admin' || (lower.contains('super') && lower.contains('admin'))) {
      return 'SUPER ADMIN';
    }
    if (lower == 'affiliate-admin' || lower == 'affiliate_admin' || lower == 'affiliate admin' || (lower.contains('affiliate') && lower.contains('admin'))) {
      return 'AFFILIATE ADMIN';
    }
    if (lower == 'affiliate' || lower.contains('affiliate')) {
      return 'AFFILIATE';
    }
    if (lower == 'admin') {
      return 'ADMIN';
    }
    if (lower == 'manager') {
      return 'MANAGER';
    }
    if (lower == 'kasir' || lower == 'cashier') {
      return 'KASIR';
    }
    if (lower == 'staff') {
      return 'STAFF';
    }
    if (lower.contains('kasir')) return 'KASIR';
    if (lower.contains('staff')) return 'STAFF';
    return r.toUpperCase();
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
        final userName = (user?.name.trim().isNotEmpty == true)
            ? user!.name.trim()
            : 'Admin SKYRental';
        final userRole = formatRole(user?.role);
        final roleLabel = userRole;
        final roleBadge = getRoleBadgeText(user?.role);
        final initials = getUserInitials(userName);

        final mediaWidth = MediaQuery.sizeOf(context).width;
        final effectiveIsTablet = isTablet ?? (mediaWidth >= 900);

        if (effectiveIsTablet) {
          return _buildTabletHeader(
            context,
            userName: userName,
            userRole: userRole,
            roleLabel: roleLabel,
            roleBadge: roleBadge,
            initials: initials,
            shiftName: user?.shiftName,
            outletName: user?.outletName,
          );
        }

        return _buildMobileHeader(
          context,
          userName: userName,
          userRole: userRole,
          roleLabel: roleLabel,
          roleBadge: roleBadge,
          initials: initials,
        );
      },
    );
  }

  Widget _buildTabletHeader(
    BuildContext context, {
    required String userName,
    required String userRole,
    required String roleLabel,
    required String roleBadge,
    required String initials,
    String? shiftName,
    String? outletName,
  }) {
    final now = DateTime.now();
    final dateFormatted = '${getDayName(now)}, ${Formatters.date(now)}';
    final topPadding = MediaQuery.paddingOf(context).top;

    final shiftText = (shiftName != null && shiftName.contains('('))
        ? shiftName.split('(').first.trim()
        : (shiftName?.trim().isNotEmpty == true ? shiftName!.trim() : 'Shift Pagi');
    final subtitleText = subtitle ?? (shiftText.contains('•') ? shiftText : '$shiftText • POS-01');

    return PreferredSize(
      preferredSize: preferredSize,
      child: RepaintBoundary(
        child: Container(
          padding: EdgeInsets.only(top: topPadding + 8, bottom: 10, left: 24, right: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Brand / Logo / Title
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showBackButton) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                          onPressed: onBackPressed ?? () => Navigator.maybePop(context),
                          tooltip: 'Kembali',
                        ),
                        const SizedBox(width: 8),
                      ] else if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ],
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
                    ],
                  ),

                  // Right: Actions, Date container & User profile (NO printer status)
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (actions != null) ...[
                            ...actions!,
                            const SizedBox(width: 12),
                          ],
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

                          // Staff Profile Info with Initials Avatar & Online Badge
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
                                        initials,
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
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context, {
    required String userName,
    required String userRole,
    required String roleLabel,
    required String roleBadge,
    required String initials,
  }) {
    final subText = subtitle ?? (title ?? userRole);

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (showBackButton) ...[
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                    onPressed: onBackPressed ?? () => Navigator.maybePop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 8),
                ] else if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],

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
                          Flexible(
                            child: Container(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subText,
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
                if (actions != null) ...[
                  ...actions!,
                  const SizedBox(width: 6),
                ],
                const SizedBox(width: 6),

                // Profile Avatar with initials and green online dot (NO printer status)
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.account),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFF0F172A),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 11,
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
                ),
              ],
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}
