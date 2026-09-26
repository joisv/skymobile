import 'package:flutter/material.dart';
import '../data/booking_repository.dart';
import '../theme/app_theme.dart';
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
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      DashboardScreen(repository: widget.repository),
      SalesReportScreen(repository: widget.repository),
      UnitStatusListScreen(repository: widget.repository),
      AccountScreen(repository: widget.repository),
    ];
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final isTabletLandscape = mediaSize.width >= 900 && mediaSize.width > mediaSize.height;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: isTabletLandscape
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
            Icons.print_outlined,
            'Printer & Shift',
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
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.surfaceContainerLow,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primary),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: const Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment_rounded, color: AppTheme.primary),
            label: 'Report',
          ),
          NavigationDestination(
            icon: const Icon(Icons.phone_iphone_outlined),
            selectedIcon: Icon(Icons.phone_iphone_rounded, color: AppTheme.primary),
            label: 'Unit iPhone',
          ),
          NavigationDestination(
            icon: const Icon(Icons.print_outlined),
            selectedIcon: Icon(Icons.print_rounded, color: AppTheme.primary),
            label: 'Printer & Akun',
          ),
        ],
      ),
    );
  }
}
