import 'package:flutter/material.dart';
import '../data/booking_repository.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';
import 'account/account_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'dashboard/sales_report_screen.dart';
import 'unit_status/unit_status_list_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final BookingRepository repository;
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    required this.repository,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  late final List<Widget?> _screens;
  final Set<int> _loadedIndices = {};
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = List<Widget?>.filled(4, null);
    _loadedIndices.add(_currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesSilently();
    });
  }

  Future<void> _checkForUpdatesSilently() async {
    try {
      if (AppUpdateDialog.isShowing) return;
      final updateService = AppUpdateService();
      final updateInfo = await updateService.checkForUpdate(forceRefreshVersion: true);
      if (!mounted) return;

      if (updateInfo.updateAvailable) {
        final shouldPrompt = await updateService.shouldPromptUpdate(updateInfo);
        if (shouldPrompt && mounted) {
          await AppUpdateDialog.show(context, updateInfo);
        }
      }
    } catch (e) {
      // Silent check does not interrupt user on failure/offline
      debugPrint('Silent update check exception: $e');
    }
  }

  Widget _buildTabScreen(int index) {
    if (!_loadedIndices.contains(index)) {
      return const SizedBox.shrink();
    }
    if (_screens[index] != null) {
      return _screens[index]!;
    }
    switch (index) {
      case 0:
        _screens[0] = DashboardScreen(key: _dashboardKey, repository: widget.repository);
        break;
      case 1:
        _screens[1] = SalesReportScreen(repository: widget.repository);
        break;
      case 2:
        _screens[2] = UnitStatusListScreen(repository: widget.repository);
        break;
      case 3:
        _screens[3] = AccountScreen(repository: widget.repository);
        break;
    }
    return _screens[index]!;
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        _loadedIndices.add(index);
      });
      // Ketika kembali ke tab Dashboard, cek apakah cache sudah expired (>= 5 menit) dan pastikan keyboard tidak terbuka
      if (index == 0) {
        _dashboardKey.currentState?.unfocusSearch();
        _dashboardKey.currentState?.checkAndRefreshIfExpired();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final isTablet = mediaSize.width >= 900 || mediaSize.shortestSide >= 600;

    final contentStack = IndexedStack(
      index: _currentIndex,
      children: [
        _buildTabScreen(0),
        _buildTabScreen(1),
        _buildTabScreen(2),
        _buildTabScreen(3),
      ],
    );

    return Scaffold(
      body: isTablet
          ? Row(
              children: [
                _buildTabletNavRail(context),
                Expanded(child: contentStack),
              ],
            )
          : contentStack,
      bottomNavigationBar: isTablet ? null : _buildMobileBottomNav(context),
    );
  }

  /// Slim vertical navigation rail / sidebar on the left side for landscape tablets.
  /// Maximizes vertical screen real estate while keeping active route indicators minimal and touch-friendly.
  Widget _buildTabletNavRail(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final isDark = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark;
    final onThemeColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      width: 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            // Vertically center the entire navigation items list
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabletNavRailItem(
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        isActive: _currentIndex == 0,
                        themeColor: themeColor,
                        onThemeColor: onThemeColor,
                        onTap: () => _onTabSelected(0),
                      ),
                      const SizedBox(height: 10),
                      _buildTabletNavRailItem(
                        icon: Icons.assessment_outlined,
                        activeIcon: Icons.assessment_rounded,
                        label: 'Report',
                        isActive: _currentIndex == 1,
                        themeColor: themeColor,
                        onThemeColor: onThemeColor,
                        onTap: () => _onTabSelected(1),
                      ),
                      const SizedBox(height: 10),
                      _buildTabletNavRailItem(
                        icon: Icons.phone_iphone_outlined,
                        activeIcon: Icons.phone_iphone_rounded,
                        label: 'Unit iPhone',
                        isActive: _currentIndex == 2,
                        themeColor: themeColor,
                        onThemeColor: onThemeColor,
                        onTap: () => _onTabSelected(2),
                      ),
                      const SizedBox(height: 10),
                      _buildTabletNavRailItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings_rounded,
                        label: 'Settings',
                        isActive: _currentIndex == 3,
                        themeColor: themeColor,
                        onThemeColor: onThemeColor,
                        onTap: () => _onTabSelected(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Status / Sync Indicator
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletNavRailItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required Color themeColor,
    required Color onThemeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container with Theme Color Background when Active
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive ? themeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.22),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 22,
                    color: isActive ? onThemeColor : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Text label under active icon has NO background, styled with theme color text
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? themeColor : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menu Navigasi Bawah Responsif Tablet (Fallback helper untuk navigasi legacy)
  Widget _buildTabletBottomNav(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTabletNavItem(
            Icons.dashboard_outlined,
            'Dashboard',
            _currentIndex == 0,
            () => _onTabSelected(0),
          ),
          _buildTabletNavItem(
            Icons.assessment_outlined,
            'Report',
            _currentIndex == 1,
            () => _onTabSelected(1),
          ),
          _buildTabletNavItem(
            Icons.phone_iphone_rounded,
            'Unit iPhone',
            _currentIndex == 2,
            () => _onTabSelected(2),
          ),
          _buildTabletNavItem(
            Icons.settings_outlined,
            'Settings',
            _currentIndex == 3,
            () => _onTabSelected(3),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menu Navigasi Bawah Tampilan Mobile (Material 3 Navigation Bar)
  Widget _buildMobileBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: NavigationBar(
        height: 60,
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.surfaceContainerLow,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primary),
            label: '',
          ),
          NavigationDestination(
            icon: const Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment_rounded, color: AppTheme.primary),
            label: '',
          ),
          NavigationDestination(
            icon: const Icon(Icons.phone_iphone_outlined),
            selectedIcon: Icon(Icons.phone_iphone_rounded, color: AppTheme.primary),
            label: '',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
            label: '',
          ),
        ],
      ),
    );
  }
}
