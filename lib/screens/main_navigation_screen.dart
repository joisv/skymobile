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

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildTabScreen(0),
          _buildTabScreen(1),
          _buildTabScreen(2),
          _buildTabScreen(3),
        ],
      ),
      bottomNavigationBar: isTablet
          ? _buildTabletBottomNav(context)
          : _buildMobileBottomNav(context),
    );
  }

  /// Menu Navigasi Bawah Responsif Tablet (Identik dengan Desain di Halaman Konfirmasi Pembayaran)
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
