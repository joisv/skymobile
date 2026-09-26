import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/booking_repository.dart';
import '../../models/admin_user_model.dart';
import '../../models/printer_device_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/printer_storage_service.dart';
import '../../services/thermal_print_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../affiliate/affiliate_list_screen.dart';
import '../affiliate/iphone_transfer_list_screen.dart';
import '../dashboard/notification_list_screen.dart';
import '../receipt/printer_settings_screen.dart';
import '../receipt/receipt_format_settings_screen.dart';
import '../receipt/reprint_receipt_list_screen.dart';
import 'theme_settings_screen.dart';

class AccountScreen extends StatefulWidget {
  final BookingRepository repository;

  const AccountScreen({
    super.key,
    required this.repository,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final PrinterStorageService _printerStorageService = PrinterStorageService();
  final ScrollController _tabletSidebarScrollController = ScrollController();
  final ScrollController _tabletDetailScrollController = ScrollController();
  AdminUserModel get _user => AuthService().currentUser ?? AdminUserModel.defaultAdmin();
  PrinterDeviceModel _primaryPrinter = PrinterDeviceModel.defaultVsc();
  bool _isLoading = true;

  // Selected menu on tablet responsive Master-Detail view
  // Default is 'shopSettings' matching user design mockup
  String _selectedMenuKey = 'shopSettings';

  void _selectMenu(String key) {
    if (_selectedMenuKey != key) {
      setState(() => _selectedMenuKey = key);
      if (_tabletDetailScrollController.hasClients && _tabletDetailScrollController.offset > 0) {
        _tabletDetailScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  // Form Controllers for Shop Settings
  late final TextEditingController _shopNameController;
  late final TextEditingController _outletNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _footerController;
  late final TextEditingController _wifiNameController;
  late final TextEditingController _wifiPasswordController;
  bool _obscureWifiPassword = true;
  bool _isSavingShopSettings = false;
  ShopSettingsModel _shopSettings = ShopSettingsModel.defaultSettings();

  // Template message controllers
  late final TextEditingController _waTemplateController;
  late final TextEditingController _tgTemplateController;

  // Change password controllers
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  // Server URL controller
  late final TextEditingController _serverUrlController;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController(text: _shopSettings.shopName);
    _outletNameController = TextEditingController(text: _shopSettings.outletName);
    _addressController = TextEditingController(text: _shopSettings.address);
    _phoneController = TextEditingController(text: _shopSettings.phoneNumber);
    _footerController = TextEditingController(text: _shopSettings.footerNote);
    _wifiNameController = TextEditingController(text: _shopSettings.wifiName);
    _wifiPasswordController = TextEditingController(text: _shopSettings.wifiPassword);

    _waTemplateController = TextEditingController(
      text: 'Halo {nama}, pesanan iPhone {iphone} Anda di SKYRental telah siap diambil.',
    );
    _tgTemplateController = TextEditingController(
      text: 'Halo {nama}, pesanan iPhone {iphone} Anda di SKYRental telah siap diambil.',
    );

    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _serverUrlController = TextEditingController(text: ApiService().baseUrl);

    _initData();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _outletNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    _wifiNameController.dispose();
    _wifiPasswordController.dispose();

    _waTemplateController.dispose();
    _tgTemplateController.dispose();

    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    _serverUrlController.dispose();
    _tabletSidebarScrollController.dispose();
    _tabletDetailScrollController.dispose();

    super.dispose();
  }

  Future<void> _initData() async {
    try {
      await _printerStorageService.init();
      final printer = await ThermalPrintService().ensurePrimaryConnected();
      final shop = await widget.repository.getShopSettings();
      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        setState(() {
          _primaryPrinter = printer;
          _shopSettings = shop;
          _shopNameController.text = shop.shopName;
          _outletNameController.text = shop.outletName;
          _addressController.text = shop.address;
          _phoneController.text = shop.phoneNumber;
          _footerController.text = shop.footerNote;
          _wifiNameController.text = shop.wifiName;
          _wifiPasswordController.text = shop.wifiPassword;

          final savedWa = prefs.getString('custom_wa_msg');
          if (savedWa != null && savedWa.isNotEmpty) {
            _waTemplateController.text = savedWa;
          }
          final savedTg = prefs.getString('custom_tg_msg');
          if (savedTg != null && savedTg.isNotEmpty) {
            _tgTemplateController.text = savedTg;
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSaveShopSettings() async {
    setState(() => _isSavingShopSettings = true);
    try {
      final updated = _shopSettings.copyWith(
        shopName: _shopNameController.text.trim(),
        outletName: _outletNameController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        footerNote: _footerController.text.trim(),
        wifiName: _wifiNameController.text.trim(),
        wifiPassword: _wifiPasswordController.text.trim(),
      );

      final saved = await widget.repository.updateShopSettings(updated);
      if (mounted) {
        setState(() {
          _shopSettings = saved;
          _isSavingShopSettings = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan identitas toko dan outlet berhasil disimpan!'),
            backgroundColor: Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingShopSettings = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengaturan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _showCustomMessageDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final waCtrl = TextEditingController(text: prefs.getString('custom_wa_msg') ?? _waTemplateController.text);
    final tgCtrl = TextEditingController(text: prefs.getString('custom_tg_msg') ?? _tgTemplateController.text);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Template Pesan WA & Telegram', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: waCtrl,
              decoration: const InputDecoration(labelText: 'Template WhatsApp', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tgCtrl,
              decoration: const InputDecoration(labelText: 'Template Telegram', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString('custom_wa_msg', waCtrl.text);
              await prefs.setString('custom_tg_msg', tgCtrl.text);
              if (mounted) {
                setState(() {
                  _waTemplateController.text = waCtrl.text;
                  _tgTemplateController.text = tgCtrl.text;
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template berhasil disimpan')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun SKYRental Admin? Sesi kasir aktif Anda akan ditutup.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Anda telah berhasil keluar dari akun SKYRental Admin.'),
                  backgroundColor: AppTheme.primary,
                ),
              );
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              );
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialogModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_iphone_rounded, color: AppTheme.accent, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              'SKYRental POS Admin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            Text(
              'Versi 1.0.0 (Build 2026.09.09)',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Aplikasi manajemen operasional rental iPhone, pengambilan unit, pengembalian, kasir deposit, dan cetak resi thermal 58mm.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiService().baseUrl);
    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.dns_rounded, color: AppTheme.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alamat Server Backend (API)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Atur IP lokal atau domain server Laravel',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Base URL Server / API',
                  hintText: 'https://skyrental.id atau http://192.168.1.24:8000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 10),
              Text(
                'Pilihan Cepat:',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('192.168.1.24:8000 (IP Baru)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setModalState(() => controller.text = 'http://192.168.1.24:8000'),
                  ),
                  ActionChip(
                    label: const Text('localhost:8000 (Lokal)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setModalState(() => controller.text = 'http://127.0.0.1:8000'),
                  ),
                  ActionChip(
                    label: const Text('skyrental.id (Online)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setModalState(() => controller.text = 'https://skyrental.id'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (testResult != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: testSuccess == true ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: testSuccess == true ? Colors.green.shade200 : Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        testSuccess == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: testSuccess == true ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          testResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: testSuccess == true ? Colors.green.shade800 : Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isTesting
                        ? null
                        : () async {
                            setModalState(() {
                              isTesting = true;
                              testResult = null;
                            });
                            final ok = await ApiService().testConnection(controller.text);
                            setModalState(() {
                              isTesting = false;
                              testSuccess = ok;
                              testResult = ok
                                  ? 'Koneksi berhasil! Server aktif & merespons.'
                                  : 'Gagal terhubung. Pastikan server aktif & 1 jaringan.';
                            });
                          },
                    icon: isTesting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check_rounded, size: 16),
                    label: const Text('Tes Koneksi'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        await ApiService().setCustomBaseUrl(controller.text);
                        if (mounted) setState(() {});
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Server URL berhasil disimpan: ${ApiService().baseUrl}'),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Simpan URL Server', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final mediaSize = MediaQuery.sizeOf(context);
    final isLandscape = mediaSize.width > mediaSize.height;
    final isTablet = mediaSize.width >= 900 && isLandscape;

    return isTablet ? _buildTabletLayout(context) : _buildMobileLayout(context);
  }

  // =========================================================================
  // RESPONSIVE TABLET LAYOUT (MATCHING media_1790255336555.png)
  // =========================================================================

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildTabletAppBar(context),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Master Sidebar (Sticky & Scrollable all the way to bottom)
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  controller: _tabletSidebarScrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildTabletMasterSidebar(),
                ),
              ),
              const SizedBox(width: 20),

              // Right Detail Pane (Independently Scrollable with Profile Card at top)
              Expanded(
                child: SingleChildScrollView(
                  controller: _tabletDetailScrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Admin Profile Card (spans right column only)
                      _buildTabletProfileCard(),
                      const SizedBox(height: 16),

                      // Detail Content
                      _buildDetailContent(),
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

  String _getDayName(DateTime date) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return days[date.weekday - 1];
  }

  String _getRoleBadgeText(String? role) {
    if (role == null) return 'STAFF';
    final r = role.toLowerCase().trim();
    if (r.contains('admin') || r.contains('super')) return 'SUPER-ADMIN';
    if (r.contains('supervisor')) return 'SUPERVISOR';
    if (r.contains('kasir')) return 'KASIR';
    return role.toUpperCase();
  }

  /// Badge status printer reaktif (konsisten dengan DashboardScreen)
  Widget _buildPrinterStatusBadge({bool isTablet = false}) {
    final printService = ThermalPrintService();
    return AnimatedBuilder(
      animation: Listenable.merge([
        printService.activePrinterNotifier,
        printService.isConnectedNotifier,
      ]),
      builder: (context, _) {
        final activePrinter = printService.activePrinterNotifier.value;
        final isConnected = printService.isConnectedNotifier.value;

        String printerName = activePrinter?.name.trim() ?? '';
        if (printerName.isEmpty || printerName == 'Belum Ada Printer Dipilih') {
          printerName = 'Printer Thermal';
        }

        final statusText = isConnected ? 'Terhubung' : 'Belum Terhubung';

        return GestureDetector(
          onTap: () async {
            if (isTablet) {
              _selectMenu('printerSettings');
            } else {
              await Navigator.pushNamed(context, AppRoutes.printerSettings);
              if (mounted) setState(() {});
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConnected
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFFECACA),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isConnected ? AppTheme.success : AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 105),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printerName,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isConnected
                              ? const Color(0xFF065F46)
                              : const Color(0xFF991B1B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? const Color(0xFF047857)
                              : const Color(0xFFB91C1C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildTabletAppBar(BuildContext context) {
    final user = AuthService().currentUser ?? _user;
    final now = DateTime.now();
    final dateFormatted = '${_getDayName(now)}, ${Formatters.date(now)}';
    final topPadding = MediaQuery.paddingOf(context).top;
    final cashierName = user.name.trim().isNotEmpty ? user.name : 'Budi Santoso';
    final cashierRole = (user.role.trim().isNotEmpty ? user.role : 'KASIR').toUpperCase();

    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
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
              const Text(
                'SKYRental',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  _buildPrinterStatusBadge(isTablet: true),
                  const SizedBox(width: 12),
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
                  Row(
                    children: [
                      Stack(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFE2E8F0),
                            child: Icon(Icons.person, size: 20, color: Color(0xFF475569)),
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
                                cashierName,
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
                                  cashierRole,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Text('Shift Pagi • POS-01', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletProfileCard() {
    final outletName = _outletNameController.text.trim().isNotEmpty
        ? _outletNameController.text.trim()
        : _user.outletName;

    return Container(
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
      child: Row(
        children: [
          // Blue Square Avatar with Green Online Dot
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  _user.name.isNotEmpty ? _user.name.trim().substring(0, 1).toUpperCase() : 'A',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // User Info & Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Text(
                        'SUPER-ADMIN',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                    const Text('  •  ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const Icon(Icons.storefront_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        outletName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right Status Pill & Switch Account Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.print_outlined, size: 14, color: Color(0xFF475569)),
                SizedBox(width: 6),
                Text(
                  'Thermal 58mm ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
                Text(
                  '(Siap)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              foregroundColor: const Color(0xFF334155),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text(
              'Ganti Akun',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TABLET MASTER SIDEBAR
  // =========================================================================

  Widget _buildTabletMasterSidebar() {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        final isDark = ThemeService().isDarkMode;
        final themeColor = AppTheme.accent;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category 1: TOKO & OUTLET
            _buildTabletCategorySection(
              title: 'TOKO & OUTLET',
              children: [
                _buildTabletSidebarItem(
                  key: 'shopSettings',
                  icon: Icons.storefront_rounded,
                  title: 'Pengaturan Nama Toko & Outlet',
                  subtitle: 'Konfigurasi identitas, alamat & WiFi',
                ),
                _buildTabletSidebarItem(
                  key: 'shiftOperasional',
                  icon: Icons.access_time_filled_rounded,
                  title: 'Shift Operasional Kasir',
                  subtitle: 'Buka/tutup kas & modal awal',
                  trailingBadge: 'Aktif',
                  trailingBadgeColor: const Color(0xFF15803D),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category 2: MITRA & CABANG AFFILIATE
            _buildTabletCategorySection(
              title: 'MITRA & CABANG AFFILIATE',
              children: [
                _buildTabletSidebarItem(
                  key: 'affiliateList',
                  icon: Icons.store_mall_directory_rounded,
                  title: 'Mitra Cabang & Affiliate',
                  subtitle: 'Kelola outlet cabang & komisi',
                ),
                _buildTabletSidebarItem(
                  key: 'iphoneTransfer',
                  icon: Icons.swap_horiz_rounded,
                  title: 'Mutasi & Transfer Unit iPhone',
                  subtitle: 'Riwayat pengiriman antar cabang',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category 3: HARDWARE & RESI
            _buildTabletCategorySection(
              title: 'HARDWARE & RESI',
              children: [
                _buildTabletSidebarItem(
                  key: 'printerSettings',
                  icon: Icons.print_rounded,
                  title: 'Pengaturan Thermal Printer',
                  subtitle: _primaryPrinter.address.isNotEmpty
                      ? '${_primaryPrinter.name} (${_primaryPrinter.address.substring(0, _primaryPrinter.address.length > 17 ? 17 : _primaryPrinter.address.length)})'
                      : 'RPP02N (86:67:7A:20:9B:AD)',
                  trailingBadge: 'Siap',
                  trailingBadgeColor: const Color(0xFF15803D),
                ),
                _buildTabletSidebarItem(
                  key: 'receiptFormat',
                  icon: Icons.text_snippet_rounded,
                  title: 'Format & Tampilan Resi',
                  subtitle: 'Kustomisasi header, footer & barcode',
                ),
                _buildTabletSidebarItem(
                  key: 'reprintReceipt',
                  icon: Icons.receipt_long_rounded,
                  title: 'Riwayat Cetak & Cetak Ulang',
                  subtitle: 'Daftar resi transaksi serah-terima',
                ),
                _buildTabletSidebarItem(
                  key: 'qrScanner',
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'Scanner Kamera QR',
                  subtitle: 'Pindai barcode resi & unit iPhone',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category 4: NOTIFIKASI OPERASIONAL
            _buildTabletCategorySection(
              title: 'NOTIFIKASI OPERASIONAL',
              children: [
                _buildTabletSidebarItem(
                  key: 'notifications',
                  icon: Icons.notifications_active_rounded,
                  title: 'Pusat Notifikasi Operasional',
                  subtitle: 'Pengingat pengembalian & jatuh tempo',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category 5: KEAMANAN & AKUN
            _buildTabletCategorySection(
              title: 'KEAMANAN & AKUN',
              children: [
                _buildTabletSidebarItem(
                  key: 'messageTemplates',
                  icon: Icons.message_rounded,
                  title: 'Template Pesan WA & Telegram',
                  subtitle: 'Ubah teks default notifikasi pelanggan',
                ),
                _buildTabletSidebarItem(
                  key: 'changePassword',
                  icon: Icons.lock_reset_rounded,
                  title: 'Ubah Kata Sandi',
                  subtitle: 'Perbarui kata sandi akun kasir',
                ),
                _buildTabletSidebarItem(
                  key: 'rolePermissions',
                  icon: Icons.badge_rounded,
                  title: 'Role & Izin Akses',
                  subtitle: _user.role,
                  trailingBadge: 'Admin Penuh',
                  trailingBadgeColor: const Color(0xFF475569),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category 6: TAMPILAN & TEMA
            _buildTabletCategorySection(
              title: 'TAMPILAN & TEMA',
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: const Color(0xFF475569),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mode Gelap (Dark Mode)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch.adaptive(
                          value: isDark,
                          activeThumbColor: themeColor,
                          onChanged: (val) {
                            ThemeService().setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                _buildTabletSidebarItem(
                  key: 'themeSettings',
                  icon: Icons.palette_outlined,
                  title: 'Tema & Warna Aplikasi',
                  subtitle: 'Palet 8 warna aksen aplikasi',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category 7: TENTANG SISTEM
            _buildTabletCategorySection(
              title: 'TENTANG SISTEM',
              children: [
                _buildTabletSidebarItem(
                  key: 'serverConfig',
                  icon: Icons.dns_rounded,
                  title: 'Alamat Server & API Backend',
                  subtitle: ApiService().baseUrl.replaceFirst('http://', '').replaceFirst('https://', ''),
                  trailingBadge: 'LAN / LOCAL',
                  trailingBadgeColor: const Color(0xFF475569),
                ),
                _buildTabletSidebarItem(
                  key: 'aboutApp',
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang SKYRental POS',
                  subtitle: 'Sistem operasional kasir tablet',
                  trailingBadge: 'Versi 1.0.0',
                  trailingBadgeColor: const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Logout Outlined Red Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
              label: const Text(
                'Keluar dari Akun Kasir',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabletCategorySection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.6,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTabletSidebarItem({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    String? trailingBadge,
    Color? trailingBadgeColor,
  }) {
    final isSelected = _selectedMenuKey == key;
    final themeColor = AppTheme.accent;
    final isDarkBackground = ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark;
    final onThemeColor = isDarkBackground ? Colors.white : const Color(0xFF0F172A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectMenu(key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? themeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected
                      ? onThemeColor.withValues(alpha: 0.2)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? onThemeColor : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? onThemeColor : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isSelected ? onThemeColor.withValues(alpha: 0.85) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailingBadge != null && !isSelected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: (trailingBadgeColor ?? const Color(0xFF475569)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    trailingBadge,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: trailingBadgeColor ?? const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isSelected ? onThemeColor : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // DETAIL CONTENT DISPATCHER
  // =========================================================================

  Widget _buildDetailContent() {
    switch (_selectedMenuKey) {
      case 'shopSettings':
        return _buildShopSettingsDetail();
      case 'shiftOperasional':
        return _buildShiftOperasionalDetail();
      case 'affiliateList':
        return _buildAffiliateListDetail();
      case 'iphoneTransfer':
        return _buildIphoneTransferDetail();
      case 'printerSettings':
        return _buildPrinterSettingsDetail();
      case 'receiptFormat':
        return _buildReceiptFormatDetail();
      case 'reprintReceipt':
        return _buildReprintReceiptDetail();
      case 'qrScanner':
        return _buildQrScannerDetail();
      case 'notifications':
        return _buildNotificationsDetail();
      case 'messageTemplates':
        return _buildMessageTemplatesDetail();
      case 'changePassword':
        return _buildChangePasswordDetail();
      case 'rolePermissions':
        return _buildRolePermissionsDetail();
      case 'themeSettings':
        return _buildThemeSettingsDetail();
      case 'serverConfig':
        return _buildServerConfigDetail();
      case 'aboutApp':
      default:
        return _buildAboutAppDetail();
    }
  }

  // =========================================================================
  // 1. DETAIL VIEW: PENGATURAN NAMA TOKO & OUTLET (ACTIVE DESIGN MOCKUP)
  // =========================================================================

  Widget _buildShopSettingsDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header with Title and "Simpan Pengaturan" Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identitas Toko & Konfigurasi Outlet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Kelola identitas outlet resmi, nomor layanan pelanggan, teks kaki struk, dan fasilitas WiFi pelanggan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: _isSavingShopSettings ? null : _handleSaveShopSettings,
              icon: _isSavingShopSettings
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text(
                'Simpan Pengaturan',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // CARD 1: PRATINJAU KERTAS THERMAL 58MM (LIVE RECEIPT PREVIEW)
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'PRATINJAU KERTAS THERMAL 58MM (LIVE RECEIPT PREVIEW)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      '58mm Thermal Print Mode',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Realistic Thermal Receipt Paper Preview
              Center(
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_iphone_rounded, size: 20, color: Color(0xFF475569)),
                      const SizedBox(height: 6),
                      Text(
                        _shopNameController.text.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _outletNameController.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _addressController.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Telp/WA: ${_phoneController.text}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '--------------------------------',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '“${_footerController.text}”',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontStyle: FontStyle.italic,
                          fontSize: 10,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'WiFi: ${_wifiNameController.text} | Pass: ${_wifiPasswordController.text}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      BarcodeWidget(
                        barcode: Barcode.qrCode(),
                        data: 'https://skyrental.id/outlet/${_outletNameController.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
                        width: 56,
                        height: 56,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'VALIDASI OUTLET RESMI',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CARD 2: IDENTITAS RENTAL
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IDENTITAS RENTAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDetailTextField(
                      label: 'Nama Bisnis / Toko',
                      controller: _shopNameController,
                      prefixIcon: Icons.storefront_outlined,
                      hint: 'SKYRental iPhone POS',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDetailTextField(
                      label: 'Nama Cabang / Outlet',
                      controller: _outletNameController,
                      prefixIcon: Icons.store_mall_directory_outlined,
                      hint: 'Outlet Utama Malioboro',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailTextField(
                label: 'Nomor Telepon / WhatsApp CS',
                controller: _phoneController,
                prefixIcon: Icons.phone_outlined,
                hint: '0812-3456-7890',
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _buildDetailTextField(
                label: 'Alamat Lengkap Outlet',
                controller: _addressController,
                prefixIcon: Icons.location_on_outlined,
                hint: 'Jl. Malioboro No. 45, Danurejan, D.I. Yogyakarta',
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CARD 3: TEKS KAKI STRUK (FOOTER STRUK THERMAL)
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TEKS KAKI STRUK (FOOTER STRUK THERMAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              _buildDetailTextField(
                label: 'Pesan / Catatan Struk',
                controller: _footerController,
                prefixIcon: Icons.receipt_outlined,
                hint: 'Terima kasih telah mempercayakan sewa iPhone kepada SKYRental',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    'Dicetak di bagian bawah kertas resi transaksi serah-terima unit iPhone.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CARD 4: WIFI OUTLET (FASILITAS PELANGGAN)
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'WIFI OUTLET (FASILITAS PELANGGAN)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Text(
                      'Tampil di QR & Struk',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDetailTextField(
                      label: 'Nama Jaringan WiFi (SSID)',
                      controller: _wifiNameController,
                      prefixIcon: Icons.wifi,
                      hint: 'SKYRENTAL_GUEST',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildDetailTextField(
                      label: 'Kata Sandi WiFi',
                      controller: _wifiPasswordController,
                      prefixIcon: Icons.lock_outline,
                      hint: 'rentaliphoneoke',
                      obscureText: _obscureWifiPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureWifiPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(() => _obscureWifiPassword = !_obscureWifiPassword),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. DETAIL VIEW: SHIFT OPERASIONAL KASIR
  // =========================================================================

  Widget _buildShiftOperasionalDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailHeader(
          title: 'Shift Operasional Kasir & Laci Kas',
          subtitle: 'Pantau status shift kerja aktif, modal awal laci kasir, dan penutupan shift kasir.',
          actionButton: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Status shift saat ini aktif. Penutupan kasir dapat dilakukan akhir jam shift.')),
              );
            },
            icon: const Icon(Icons.lock_clock_outlined, size: 16),
            label: const Text('Rekonsiliasi Shift', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('STATUS SHIFT KASIR AKTIF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildMetricBox('Kasir Bertugas', _user.name, Icons.person_outline, const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Shift Operasional', _user.shiftName, Icons.schedule, const Color(0xFF059669)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Terminal POS', 'POS-MLBR-04', Icons.devices, const Color(0xFF7C3AED)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MODAL AWAL & SALDO LACI KASIR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildMetricBox('Modal Awal Laci', 'Rp 500.000', Icons.account_balance_wallet_outlined, const Color(0xFFD97706)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Total Transaksi Tunai', 'Rp 1.450.000', Icons.payments_outlined, const Color(0xFF059669)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Estimasi Kas Fisik', 'Rp 1.950.000', Icons.point_of_sale_outlined, const Color(0xFF2563EB)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. DETAIL VIEW: MITRA CABANG & AFFILIATE
  // =========================================================================

  Widget _buildAffiliateListDetail() {
    return AffiliateListScreen(
      repository: widget.repository,
      isEmbedded: true,
    );
  }

  // =========================================================================
  // 4. DETAIL VIEW: MUTASI & TRANSFER UNIT IPHONE
  // =========================================================================

  Widget _buildIphoneTransferDetail() {
    return IphoneTransferListScreen(
      repository: widget.repository,
      isEmbedded: true,
    );
  }

  // =========================================================================
  // 5. DETAIL VIEW: PENGATURAN THERMAL PRINTER
  // =========================================================================

  Widget _buildPrinterSettingsDetail() {
    return PrinterSettingsScreen(
      key: const ValueKey('embedded_printer_settings'),
      isEmbedded: true,
      onDeviceChanged: (device) {
        if (_primaryPrinter.address != device.address ||
            _primaryPrinter.name != device.name ||
            _primaryPrinter.isConnected != device.isConnected) {
          setState(() => _primaryPrinter = device);
        }
      },
    );
  }

  // =========================================================================
  // 6. DETAIL VIEW: FORMAT & TAMPILAN RESI
  // =========================================================================

  Widget _buildReceiptFormatDetail() {
    return const ReceiptFormatSettingsScreen(
      key: ValueKey('embedded_receipt_format'),
      isEmbedded: true,
    );
  }

  // =========================================================================
  // 7. DETAIL VIEW: RIWAYAT CETAK & CETAK ULANG
  // =========================================================================

  Widget _buildReprintReceiptDetail() {
    return ReprintReceiptListScreen(
      key: const ValueKey('embedded_reprint_receipt'),
      repository: widget.repository,
      isEmbedded: true,
    );
  }

  // =========================================================================
  // 8. DETAIL VIEW: SCANNER KAMERA QR
  // =========================================================================

  Widget _buildQrScannerDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailHeader(
          title: 'Scanner Kamera QR & Barcode',
          subtitle: 'Pindai barcode pada resi transaksi atau QR code booking unit iPhone untuk verifikasi kilat.',
          actionButton: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.qrScanner),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: const Text('Buka Kamera Scanner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DUKUNGAN PEMINDAIAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              SizedBox(height: 12),
              Text('Mendukung kamera tablet depan/belakang serta scanner barcode USB/Bluetooth plug-and-play.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 9. DETAIL VIEW: NOTIFIKASI OPERASIONAL
  // =========================================================================

  Widget _buildNotificationsDetail() {
    return NotificationListScreen(
      key: const ValueKey('embedded_notifications'),
      repository: widget.repository,
      isEmbedded: true,
    );
  }

  // =========================================================================
  // 10. DETAIL VIEW: TEMPLATE PESAN WA & TELEGRAM
  // =========================================================================

  Widget _buildMessageTemplatesDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailHeader(
          title: 'Template Pesan WhatsApp & Telegram',
          subtitle: 'Sesuaikan teks pesan otomatis yang dikirimkan ke nomor WhatsApp pelanggan saat booking.',
          actionButton: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('custom_wa_msg', _waTemplateController.text);
              await prefs.setString('custom_tg_msg', _tgTemplateController.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template pesan berhasil disimpan!'), backgroundColor: Color(0xFF047857)),
                );
              }
            },
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Simpan Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TEMPLATE WHATSAPP PELANGGAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              const SizedBox(height: 12),
              _buildDetailTextField(
                label: 'Isi Pesan WhatsApp',
                controller: _waTemplateController,
                prefixIcon: Icons.message_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              const Text('Variabel tersedia: {nama}, {iphone}, {durasi}, {jadwal}', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TEMPLATE TELEGRAM PELANGGAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              const SizedBox(height: 12),
              _buildDetailTextField(
                label: 'Isi Pesan Telegram',
                controller: _tgTemplateController,
                prefixIcon: Icons.send_outlined,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 11. DETAIL VIEW: UBAH KATA SANDI
  // =========================================================================

  Widget _buildChangePasswordDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailHeader(
          title: 'Keamanan Akun & Ubah Kata Sandi',
          subtitle: 'Perbarui kata sandi akun kasir atau supervisor untuk menjaga keamanan terminal POS.',
          actionButton: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kata sandi berhasil diperbarui!'), backgroundColor: Color(0xFF047857)),
              );
            },
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text('Simpan Kata Sandi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FORMULIR GANTI KATA SANDI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              const SizedBox(height: 14),
              _buildDetailTextField(
                label: 'Kata Sandi Saat Ini',
                controller: _currentPasswordController,
                prefixIcon: Icons.lock_outline,
                obscureText: _obscureCurrentPass,
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrentPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscureCurrentPass = !_obscureCurrentPass),
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailTextField(
                label: 'Kata Sandi Baru',
                controller: _newPasswordController,
                prefixIcon: Icons.lock_reset_outlined,
                obscureText: _obscureNewPass,
                suffixIcon: IconButton(
                  icon: Icon(_obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailTextField(
                label: 'Konfirmasi Kata Sandi Baru',
                controller: _confirmPasswordController,
                prefixIcon: Icons.check_circle_outline,
                obscureText: _obscureConfirmPass,
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 12. DETAIL VIEW: ROLE & IZIN AKSES
  // =========================================================================

  Widget _buildRolePermissionsDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailHeader(
          title: 'Role & Izin Hak Akses Akun',
          subtitle: 'Rincian izin modul operasional sistem yang diberikan kepada profil akun ini.',
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('INFORMASI HAK AKSES PENGGUNA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildMetricBox('Role Akun', _user.role, Icons.badge_outlined, const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Otoritas', 'Akses Penuh', Icons.verified_user_outlined, const Color(0xFF059669)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Outlet Ditugaskan', _user.outletName, Icons.storefront_outlined, const Color(0xFF7C3AED)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 13. DETAIL VIEW: TEMA & WARNA APLIKASI
  // =========================================================================

  Widget _buildThemeSettingsDetail() {
    return const ThemeSettingsScreen(
      key: ValueKey('embedded_theme_settings'),
      isEmbedded: true,
    );
  }

  // =========================================================================
  // 14. DETAIL VIEW: ALAMAT SERVER & API BACKEND
  // =========================================================================

  Widget _buildServerConfigDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailHeader(
          title: 'Alamat Server & API Backend',
          subtitle: 'Konfigurasi base URL endpoint server Laravel backend untuk sinkronisasi database lokal/cloud.',
          actionButton: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _showServerConfigDialog,
            icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
            label: const Text('Atur Server URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('STATUS ENDPOINT SERVER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildMetricBox('Base URL', ApiService().baseUrl, Icons.link_rounded, const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Tipe Jaringan', ApiService().baseUrl.startsWith('https://') ? 'PROD / HTTPS' : 'LAN / LOCAL', Icons.lan_outlined, const Color(0xFF059669)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 15. DETAIL VIEW: TENTANG SKYRENTAL POS
  // =========================================================================

  Widget _buildAboutAppDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailHeader(
          title: 'Tentang Aplikasi SKYRental POS',
          subtitle: 'Informasi sistem operasional, build version, dan spesifikasi terminal kasir.',
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('INFORMASI SISTEM & SPESIFIKASI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6, color: Color(0xFF475569))),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildMetricBox('Versi Aplikasi', 'v1.0.0 (Build 2026.09.09)', Icons.info_outline, const Color(0xFF2563EB)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Format Resi', 'Thermal 58mm ESC/POS', Icons.receipt_outlined, const Color(0xFF059669)),
                  const SizedBox(width: 12),
                  _buildMetricBox('Platform', 'Flutter Tablet Edition', Icons.tablet_android_rounded, const Color(0xFF7C3AED)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // COMMON HELPER WIDGETS FOR DETAIL VIEWS
  // =========================================================================

  Widget _buildDetailHeader({
    required String title,
    required String subtitle,
    Widget? actionButton,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        if (actionButton != null) actionButton,
      ],
    );
  }

  Widget _buildDetailCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailTextField({
    required String label,
    required TextEditingController controller,
    required IconData prefixIcon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // MOBILE LAYOUT (PRESERVES EXISTING DESIGN FOR PHONES)
  // =========================================================================

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    final user = AuthService().currentUser ?? _user;
    final userName = user.name.trim().isNotEmpty ? user.name : 'Admin SKYRental';
    final userRole = user.role.trim().isNotEmpty ? user.role : 'Staff Operasional';
    final roleBadge = _getRoleBadgeText(user.role);

    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
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
            // User yang sedang login
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
                    userRole,
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

            // Hardware Printer & Profile Avatar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPrinterStatusBadge(isTablet: false),
                const SizedBox(width: 8),

                // Staff Avatar with online dot
                GestureDetector(
                  onTap: () {},
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
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.surface, width: 1.5),
                          ),
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
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildMobileAppBar(context),
      body: RefreshIndicator(
        onRefresh: _initData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            _buildProfileCard(),
            const SizedBox(height: 16),
            _buildOperationalStatusCard(),
            const SizedBox(height: 20),

            _buildSectionHeader('TOKO & OUTLET'),
            _buildMenuContainer([
              _buildMenuItem(
                icon: Icons.storefront_rounded,
                iconColor: Colors.teal,
                title: 'Pengaturan Nama Toko & Outlet',
                subtitle: 'Konfigurasi identitas toko, alamat & kontak',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.shopSettings),
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuItem(
                icon: Icons.access_time_filled_rounded,
                iconColor: Colors.blueAccent,
                title: 'Shift Operasional Kasir',
                subtitle: _user.shiftName,
                trailingBadge: 'Aktif',
                trailingBadgeColor: Colors.green,
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('MITRA & CABANG AFFILIATE'),
            _buildMenuContainer([
              _buildMenuItem(
                icon: Icons.store_mall_directory_rounded,
                iconColor: Colors.indigo,
                title: 'Mitra Cabang & Affiliate',
                subtitle: 'Kelola outlet cabang, komisi & inventaris unit',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.affiliateList),
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuItem(
                icon: Icons.swap_horiz_rounded,
                iconColor: Colors.orange.shade800,
                title: 'Mutasi & Transfer Unit iPhone',
                subtitle: 'Riwayat & pengiriman unit antar cabang mitra',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.iphoneTransfer),
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('KEAMANAN & AKUN'),
            _buildMenuContainer([
              _buildMenuItem(
                icon: Icons.message_rounded,
                iconColor: Colors.green,
                title: 'Template Pesan WA & Telegram',
                subtitle: 'Ubah teks default notifikasi pelanggan',
                onTap: () => _showCustomMessageDialog(),
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuItem(
                icon: Icons.lock_reset_rounded,
                iconColor: Colors.amber.shade800,
                title: 'Ubah Kata Sandi',
                subtitle: 'Perbarui kata sandi akun admin kasir',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.changePassword),
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuItem(
                icon: Icons.badge_rounded,
                iconColor: Colors.indigo,
                title: 'Role & Izin Akses',
                subtitle: _user.role,
                trailingBadge: 'Admin Penuh',
                trailingBadgeColor: Colors.indigo,
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('TAMPILAN & TEMA'),
            ListenableBuilder(
              listenable: ThemeService(),
              builder: (context, _) {
                final isDark = ThemeService().isDarkMode;
                return _buildMenuContainer([
                  _buildSwitchMenuItem(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    iconColor: isDark ? Colors.amber : Colors.blueGrey,
                    title: 'Mode Gelap (Dark Mode)',
                    subtitle: isDark ? 'Aktif (Tema redup & ramah mata)' : 'Nonaktif (Mode terang aktif)',
                    value: isDark,
                    onChanged: (val) {
                      ThemeService().setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildMenuItem(
                    icon: Icons.palette_outlined,
                    iconColor: Colors.deepPurpleAccent,
                    title: 'Tema & Warna Aplikasi',
                    subtitle: 'Pilihan 8 palet warna, kustomisasi mandiri & mode',
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.themeSettings),
                  ),
                ]);
              },
            ),
            const SizedBox(height: 20),

            _buildSectionHeader('HARDWARE & RESI'),
            _buildMenuContainer([
              _buildMenuItem(
                icon: Icons.print_rounded,
                iconColor: Colors.deepPurple,
                title: 'Pengaturan Thermal Printer',
                subtitle: _primaryPrinter.address.isNotEmpty
                    ? '${_primaryPrinter.name} (${_primaryPrinter.address})'
                    : 'Belum Ada Printer Dipilih',
                trailingBadge: _primaryPrinter.isConnected ? 'Terhubung' : 'Siap',
                trailingBadgeColor: _primaryPrinter.isConnected ? Colors.green : Colors.grey,
                onTap: () async {
                  final res = await Navigator.of(context).pushNamed(AppRoutes.printerSettings);
                  if (res is PrinterDeviceModel && mounted) {
                    setState(() => _primaryPrinter = res);
                  }
                  _initData();
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuItem(
                icon: Icons.text_snippet_rounded,
                iconColor: Colors.teal,
                title: 'Format & Tampilan Resi',
                subtitle: 'Kustomisasi header, footer, separator & visibilitas field',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.receiptFormatSettings),
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuItem(
                icon: Icons.receipt_long_rounded,
                iconColor: Colors.blue,
                title: 'Riwayat Cetak & Cetak Ulang',
                subtitle: 'Daftar struk transaksi dan resi rental',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.reprintReceiptList),
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuItem(
                icon: Icons.qr_code_scanner_rounded,
                iconColor: Colors.cyan.shade700,
                title: 'Scanner Kamera QR',
                subtitle: 'Pindai barcode/QR booking & unit iPhone',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.qrScanner),
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('NOTIFIKASI OPERASIONAL'),
            _buildMenuContainer([
              _buildMenuItem(
                icon: Icons.notifications_active_rounded,
                iconColor: Colors.redAccent,
                title: 'Pusat Notifikasi Operasional',
                subtitle: 'Peringatan pengembalian unit & jatuh tempo',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.notifications),
              ),
            ]),
            const SizedBox(height: 20),

            _buildSectionHeader('TENTANG SISTEM'),
            _buildMenuContainer([
              _buildMenuItem(
                icon: Icons.dns_rounded,
                iconColor: Colors.blueAccent,
                title: 'Alamat Server & API Backend',
                subtitle: ApiService().baseUrl,
                trailingBadge: ApiService().baseUrl.startsWith('https://') ? 'PROD / HTTPS' : 'LAN / LOCAL',
                trailingBadgeColor: ApiService().baseUrl.startsWith('https://') ? Colors.green : Colors.blue,
                onTap: _showServerConfigDialog,
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuItem(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.textSecondary,
                title: 'Tentang SKYRental POS',
                subtitle: 'Versi 1.0.0 (Build 2026.09.09)',
                onTap: _showAboutDialogModal,
              ),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.redAccent,
                ),
                onPressed: _showLogoutDialog,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accent, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              _user.name.isNotEmpty ? _user.name.trim().substring(0, 1).toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _user.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Text(
                        _user.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _user.email,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _user.outletName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
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

  Widget _buildOperationalStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.print, size: 20, color: AppTheme.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thermal 58mm',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      Text(
                        _primaryPrinter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            width: 1,
            color: AppTheme.cardBorder,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cloud_done_rounded, size: 20, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Sync',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const Text(
                        'Tersinkron',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuContainer(List<Widget> children) {
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? trailingBadge,
    Color? trailingBadgeColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingBadge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (trailingBadgeColor ?? AppTheme.accent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trailingBadge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: trailingBadgeColor ?? AppTheme.accent,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: AppTheme.accent,
        activeTrackColor: AppTheme.accent.withValues(alpha: 0.5),
        onChanged: onChanged,
      ),
    );
  }
}
