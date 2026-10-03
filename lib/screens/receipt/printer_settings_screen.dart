import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/printer_device_model.dart';
import '../../services/printer_storage_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';

class PrinterSettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  final ValueChanged<PrinterDeviceModel>? onDeviceChanged;

  const PrinterSettingsScreen({
    super.key,
    this.isEmbedded = false,
    this.onDeviceChanged,
  });

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterStorageService _storage = PrinterStorageService();
  final ThermalPrintService _printService = ThermalPrintService();

  PrinterDeviceModel _activeDevice = const PrinterDeviceModel(
    name: 'Belum Ada Printer Dipilih',
    address: '',
    isConnected: false,
  );
  PrinterSettingsModel _settings = const PrinterSettingsModel();
  String _primaryAddress = '';

  bool _isLoading = true;
  bool _isScanning = false;
  bool _isTesting = false;
  String _testStatusMessage = '';

  List<PrinterDeviceModel> _discoveredDevices = [];
  BluetoothDiagnosticInfo? _diagnostic;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      await _storage.init();
      final settings = await _storage.getPrinterSettings();

      // Diagnostik status Bluetooth dan izin sistem
      BluetoothDiagnosticInfo? diag;
      try {
        diag = await _printService.checkBluetoothDiagnostic();
      } catch (_) {}

      // Ambil daftar printer bluetooth yang nyata terpasang dari Android
      List<PrinterDeviceModel> devices = [];
      try {
        devices = await _printService.getPairedPrinters();
      } catch (_) {}

      // Pastikan status primary printer dicek & di-reconnect jika autoConnect aktif
      PrinterDeviceModel active = await _printService.ensurePrimaryConnected();

      // Jika ada printer yang di-pair di Android
      if (devices.isNotEmpty) {
        final matchIndex = devices.indexWhere((d) => d.address == active.address);
        if (matchIndex != -1) {
          active = devices[matchIndex].copyWith(isConnected: active.isConnected);
        } else if (active.address.isEmpty) {
          // Jika printer tersimpan sebelumnya belum ada, pilih printer pertama yang nyata
          active = devices.first;
          await _storage.savePrimaryPrinter(active);
        }
      } else if (active.address.isEmpty ||
          active.address == '58:A2:3B:11:89:DC' ||
          active.address == 'AA:BB:CC:22:33:44') {
        active = const PrinterDeviceModel(
          name: 'Belum Ada Printer Dipilih',
          address: '',
          isConnected: false,
        );
      }

      if (active.address.isNotEmpty) {
        final isConn = await _printService.checkConnection();
        if (active.isConnected != isConn) {
          active = active.copyWith(isConnected: isConn);
          await _storage.savePrimaryPrinter(active);
        }
      }

      if (!mounted) return;
      setState(() {
        _activeDevice = active;
        _primaryAddress = active.address;
        _settings = settings;
        _discoveredDevices = List.from(devices);
        _diagnostic = diag;
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setAsPrimary(PrinterDeviceModel device) async {
    setState(() => _isLoading = true);
    final connResult = await _printService.connectPrinterDetailed(device.address);
    final updated = device.copyWith(isConnected: connResult.isSuccess);

    if (!mounted) return;
    setState(() {
      _activeDevice = updated;
      _primaryAddress = updated.address;
      _isLoading = false;
    });

    await _storage.savePrimaryPrinter(updated);
    widget.onDeviceChanged?.call(updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              connResult.isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${device.name} dijadikan Printer Utama. ${connResult.message}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: connResult.isSuccess ? const Color(0xFF047857) : const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _scanDevices() async {
    setState(() => _isScanning = true);
    try {
      // 1. Cek diagnostik perizinan & status Bluetooth
      final diag = await _printService.checkBluetoothDiagnostic();
      _diagnostic = diag;

      if (!diag.hasPermission) {
        // Coba minta izin
        await _printService.checkAndRequestPermissions();
        final refreshedDiag = await _printService.checkBluetoothDiagnostic();
        _diagnostic = refreshedDiag;

        if (!refreshedDiag.hasPermission) {
          if (!mounted) return;
          setState(() => _isScanning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Izin "Perangkat di sekitar" (Bluetooth) belum diberikan. Silakan izinkan di pengaturan aplikasi.',
              ),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Pengaturan',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          return;
        }
      }

      if (!diag.isBluetoothOn) {
        if (!mounted) return;
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth HP nonaktif. Silakan nyalakan Bluetooth Anda terlebih dahulu.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final devices = await _printService.getPairedPrinters();
      final updatedDiag = await _printService.checkBluetoothDiagnostic();

      if (!mounted) return;
      setState(() {
        _discoveredDevices = List.from(devices);
        _diagnostic = updatedDiag;
        _isScanning = false;
        if (devices.isNotEmpty && _activeDevice.address.isEmpty) {
          _activeDevice = devices.first;
          _primaryAddress = devices.first.address;
        }
      });

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Belum ada printer ter-pair. Jika RPP02N terdeteksi di HP, klik RPP02N di menu Bluetooth HP dan masukkan PIN 0000/1234.',
            ),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Panduan',
              textColor: Colors.white,
              onPressed: _showPairingGuideDialog,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pencarian Bluetooth selesai: ${devices.length} printer siap digunakan.'),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memindai Bluetooth: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showManualInputDialog() {
    final nameController = TextEditingController(text: 'RPP02N Thermal Printer');
    final macController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
            Icon(Icons.add_link_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('Input Printer Manual', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan nama dan Alamat MAC printer thermal Anda (dapat dilihat di kertas self-test printer atau di Bluetooth HP).',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Printer',
                  hintText: 'Misal: RPP02N-58',
                  prefixIcon: Icon(Icons.print_rounded, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Nama printer wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: macController,
                decoration: const InputDecoration(
                  labelText: 'Alamat MAC Bluetooth',
                  hintText: 'Misal: 66:22:33:44:55:66',
                  prefixIcon: Icon(Icons.bluetooth_rounded, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Alamat MAC wajib diisi';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx);
              final newDevice = PrinterDeviceModel(
                name: nameController.text.trim(),
                address: macController.text.trim(),
                isConnected: false,
                connectionType: 'bluetooth',
              );
              await _storage.addOrUpdateDevice(newDevice);
              await _setAsPrimary(newDevice);
              await _scanDevices();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan & Sambungkan'),
          ),
        ],
      ),
    );
  }

  void _showPairingGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
            Icon(Icons.help_outline_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text('Panduan Pairing RPP02N', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded, color: Color(0xFF1D4ED8), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mengapa RPP02N terdeteksi di HP tapi belum terbaca di aplikasi?',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Di Android, saat membuka menu Bluetooth, printer yang baru aktif akan muncul di daftar "Perangkat yang tersedia" (Available devices). '
                'Agar aplikasi thermal dapat mengakses printer, printer WAJIB disandingkan (Paired) terlebih dahulu dengan kode PIN.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              const Text(
                'Langkah Pairing di Android:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _buildStepItem('1', 'Nyalakan printer thermal RPP02N Anda (lampu indikator menyala).'),
              _buildStepItem('2', 'Buka Pengaturan HP Android Anda, lalu masuk ke menu Bluetooth.'),
              _buildStepItem('3', 'Pada bagian "Perangkat yang tersedia", ketuk "RPP02N".'),
              _buildStepItem('4', 'Muncul jendela pairing, masukkan PIN: 0000 atau 1234 lalu tekan OK / Pasangkan.'),
              _buildStepItem('5', 'Pastikan nama RPP02N kini berpindah ke kelompok "Perangkat yang disandingkan" (Paired devices).'),
              _buildStepItem('6', 'Buka kembali aplikasi SKYRental ini dan ketuk tombol "Pindai Perangkat" di atas.'),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Buka Pengaturan HP', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Saya Mengerti', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleConnection() async {
    if (_activeDevice.address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada printer yang dipilih. Silakan pasangkan dan pilih printer terlebih dahulu.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bool currentConnected = _activeDevice.isConnected;
    setState(() => _isLoading = true);

    if (currentConnected) {
      await _printService.disconnectPrinter();
      if (!mounted) return;
      final updated = _activeDevice.copyWith(isConnected: false);
      setState(() {
        _activeDevice = updated;
        _isLoading = false;
      });
      await _storage.savePrimaryPrinter(updated);
      widget.onDeviceChanged?.call(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koneksi ke ${_activeDevice.name} diputuskan.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final connResult = await _printService.connectPrinterDetailed(_activeDevice.address);
      if (!mounted) return;
      final updated = _activeDevice.copyWith(isConnected: connResult.isSuccess);
      setState(() {
        _activeDevice = updated;
        _primaryAddress = updated.address;
        _isLoading = false;
      });

      if (connResult.isSuccess) {
        await _storage.savePrimaryPrinter(updated);
      }
      widget.onDeviceChanged?.call(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(connResult.message),
          backgroundColor: connResult.isSuccess ? const Color(0xFF047857) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _updateSettings(PrinterSettingsModel newSettings) async {
    setState(() => _settings = newSettings);
    await _storage.savePrinterSettings(newSettings);
  }

  Future<void> _runTestPrint({required String testType}) async {
    setState(() {
      _isTesting = true;
      _testStatusMessage = 'Mengirim payload ESC/POS "$testType" ke ${_activeDevice.name}...';
    });

    final printService = ThermalPrintService();
    final result = await printService.printTestPage(
      targetPrinter: _activeDevice,
      settings: _settings,
    );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testStatusMessage = '';
    });

    if (result.isSuccess) {
      final updated = _activeDevice.copyWith(isConnected: true);
      setState(() {
        _activeDevice = updated;
        _primaryAddress = updated.address;
      });
      await _storage.savePrimaryPrinter(updated);
      widget.onDeviceChanged?.call(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Uji cetak "$testType" berhasil dicetak pada ${_activeDevice.name} (${result.bytesSent} byte)!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final isConn = await _printService.checkConnection();
      if (mounted) {
        setState(() {
          _activeDevice = _activeDevice.copyWith(isConnected: isConn);
        });
        if (_primaryAddress == _activeDevice.address) {
          _storage.savePrimaryPrinter(_activeDevice);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      if (widget.isEmbedded) {
        return const Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final testPayload = PrinterSettingsModel.generateTestPrintPayload(
      device: _activeDevice,
      settings: _settings,
    );

    final isPrimary = _activeDevice.address == _primaryAddress;

    if (widget.isEmbedded) {
      return _buildEmbeddedLayout(context, isPrimary, testPayload);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Pengaturan & Uji Printer',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.cardBorder, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _activeDevice),
        ),
        actions: [
          IconButton(
            tooltip: 'Pindai Bluetooth',
            icon: _isScanning
                ? SizedBox(width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                  )
                : const Icon(Icons.bluetooth_searching_rounded),
            onPressed: _isScanning ? null : _scanDevices,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. Bluetooth & Permission Health Diagnostics
            _buildDiagnosticBanner(),

            // 1. Device Status Card with Primary Star Badge
            _buildDeviceStatusCard(isPrimary),
            const SizedBox(height: 16),

            // 2. Discovered Devices Section with Set-as-Primary Action
            _buildDiscoveredDevicesSection(),
            const SizedBox(height: 16),

            // 3. Printer Configuration Section (Density, Feed, Auto-Print)
            _buildConfigurationSection(),
            const SizedBox(height: 16),

            // 4. Test Print Section (32 Columns ESC/POS)
            _buildTestPrintSection(testPayload),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedLayout(
    BuildContext context,
    bool isPrimary,
    String testPayload,
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan & Uji Thermal Printer POS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Hubungkan printer Bluetooth 58mm, kelola densitas cetak, dan lakukan pengujian ESC/POS langsung.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isScanning ? null : _scanDevices,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching_rounded, size: 18),
                label: Text(
                  _isScanning ? 'Memindai...' : 'Pindai Bluetooth',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 0. Bluetooth & Permission Health Diagnostics
        _buildDiagnosticBanner(),

        // 1. Device Status Card with Primary Star Badge
        _buildDeviceStatusCard(isPrimary),
        const SizedBox(height: 16),

        // 2. Discovered Devices Section with Set-as-Primary Action
        _buildDiscoveredDevicesSection(),
        const SizedBox(height: 16),

        // 3. Printer Configuration Section (Density, Feed, Auto-Print)
        _buildConfigurationSection(),
        const SizedBox(height: 16),

        // 4. Test Print Section (32 Columns ESC/POS)
        _buildTestPrintSection(testPayload),
      ],
    );
  }

  Widget _buildDeviceStatusCard(bool isPrimary) {
    final isConn = _activeDevice.isConnected;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isConn ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
          width: 1.5,
        ),
      ),
      color: isConn ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConn ? Icons.print_rounded : Icons.print_disabled_rounded,
                    size: 28,
                    color: isConn ? const Color(0xFF047857) : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _activeDevice.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isPrimary)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                                  SizedBox(width: 2),
                                  Text(
                                    'UTAMA',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                                  ),
                                ],
                              ),
                            )
                          else if (_activeDevice.address.isNotEmpty)
                            InkWell(
                              onTap: () => _setAsPrimary(_activeDevice),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBorder,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_border_rounded, size: 12, color: Color(0xFF64748B)),
                                    SizedBox(width: 2),
                                    Text(
                                      'JADIKAN UTAMA',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isConn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isConn ? 'ONLINE' : 'TERPUTUS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isConn ? const Color(0xFF047857) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'MAC: ${_activeDevice.address} • Bluetooth SPP',
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Baterai: ${_activeDevice.batteryLevel}% • Sinyal: ${_activeDevice.signalStrength}/4 Bar',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isScanning ? null : _scanDevices,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Pindai Ulang', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isPrimary) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _setAsPrimary(_activeDevice),
                      icon: const Icon(Icons.star_outline_rounded, size: 16, color: Color(0xFFD97706)),
                      label: const Text('Jadikan Utama', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFDE68A)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleConnection,
                    icon: Icon(isConn ? Icons.link_off_rounded : Icons.link_rounded, size: 16),
                    label: Text(
                      isConn ? 'Putuskan' : 'Sambungkan',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConn ? const Color(0xFFDC2626) : const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildDiagnosticBanner() {
    final diag = _diagnostic;
    if (diag == null) return const SizedBox.shrink();

    final bool allGood = diag.isBluetoothOn && diag.hasPermission && diag.pairedDevicesCount > 0;
    final bool btOff = !diag.isBluetoothOn;
    final bool permDenied = !diag.hasPermission;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: allGood
            ? const Color(0xFFF0FDF4)
            : (btOff || permDenied ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allGood
              ? const Color(0xFFBBF7D0)
              : (btOff || permDenied ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allGood
                    ? Icons.check_circle_rounded
                    : (btOff || permDenied ? Icons.warning_amber_rounded : Icons.info_outline_rounded),
                size: 20,
                color: allGood
                    ? const Color(0xFF059669)
                    : (btOff || permDenied ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  allGood
                      ? 'Bluetooth HP & Izin Siap Digunakan'
                      : (btOff
                          ? 'Bluetooth HP Anda Nonaktif'
                          : (permDenied
                              ? 'Izin Bluetooth Belum Diberikan'
                              : 'Status Bluetooth & Perangkat HP')),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: allGood
                        ? const Color(0xFF065F46)
                        : (btOff || permDenied ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDiagChip(
                label: 'Bluetooth: ${diag.isBluetoothOn ? "Aktif" : "Mati"}',
                isOk: diag.isBluetoothOn,
              ),
              const SizedBox(width: 6),
              _buildDiagChip(
                label: 'Izin: ${diag.hasPermission ? "Diizinkan" : "Ditolak"}',
                isOk: diag.hasPermission,
              ),
              const SizedBox(width: 6),
              _buildDiagChip(
                label: 'Terpasang: ${diag.pairedDevicesCount}',
                isOk: diag.pairedDevicesCount > 0,
              ),
            ],
          ),
          if (permDenied) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _printService.checkAndRequestPermissions();
                      await _scanDevices();
                    },
                    icon: const Icon(Icons.security_rounded, size: 14),
                    label: const Text('Beri Izin Bluetooth', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => openAppSettings(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  child: const Text('Buka Pengaturan HP', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ] else if (diag.pairedDevicesCount == 0 && diag.isBluetoothOn) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPairingGuideDialog,
                    icon: const Icon(Icons.help_outline_rounded, size: 14),
                    label: const Text('Panduan Pairing RPP02N', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.add_link_rounded, size: 14),
                    label: const Text('Input MAC Manual', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagChip({required String label, required bool isOk}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOk ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isOk ? const Color(0xFF047857) : const Color(0xFFDC2626),
        ),
      ),
    );
  }

  Widget _buildDiscoveredDevicesSection() {
    return Card(
      elevation: 0,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                    Icon(Icons.bluetooth_audio_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Daftar Printer Bluetooth',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Input MAC Manual',
                      icon: Icon(Icons.add_link_rounded, size: 18, color: AppTheme.primary),
                      onPressed: _showManualInputDialog,
                    ),
                    IconButton(
                      tooltip: 'Panduan Pairing RPP02N',
                      icon: Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.textSecondary),
                      onPressed: _showPairingGuideDialog,
                    ),
                    TextButton.icon(
                      onPressed: _isScanning ? null : _scanDevices,
                      icon: const Icon(Icons.sync_rounded, size: 14),
                      label: const Text('Pindai', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 12),
            if (_discoveredDevices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.bluetooth_searching_rounded, size: 40, color: AppTheme.primary),
                    const SizedBox(height: 10),
                    const Text('Printer RPP02N Belum Terbaca di Aplikasi?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Di menu Bluetooth HP Android, printer RPP02N awalnya muncul di kelompok "Perangkat yang tersedia". '
                              'Anda HARUS mengetuk nama RPP02N dan memasukkan PIN (0000 atau 1234) agar disandingkan (Paired) ke HP terlebih dahulu.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showPairingGuideDialog,
                          icon: const Icon(Icons.help_outline_rounded, size: 16),
                          label: const Text('Panduan Pairing RPP02N', style: TextStyle(fontSize: 12)),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showManualInputDialog,
                          icon: const Icon(Icons.add_link_rounded, size: 16),
                          label: const Text('Input Alamat MAC Manual', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isScanning ? null : _scanDevices,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Pindai Ulang', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_discoveredDevices.length, (idx) {
                final d = _discoveredDevices[idx];
                final isCurrent = _activeDevice.address == d.address;
                final isPrimary = d.address == _primaryAddress;

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _setAsPrimary(d),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.cardBorder,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      size: 18,
                      color: isCurrent ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        d.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      if (isPrimary) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${d.address} • Sinyal ${d.signalStrength}/4',
                    style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent && isPrimary)
                        const Chip(
                          label: Text('Aktif & Utama', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                          backgroundColor: Color(0xFFDCFCE7),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )
                      else
                        OutlinedButton(
                          onPressed: () => _setAsPrimary(d),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Pilih', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      elevation: 0,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
                Icon(Icons.tune_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Konfigurasi Cetak (Tersimpan Lokal)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
            const Divider(height: 16),

            // Fixed Paper Width Note
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lebar Kertas Resi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Standar printer VSC MP-58C', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: const Text(
                    '58mm (32 Kolom)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Density Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kerapatan Cetak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 6,
                  children: ['Ringan', 'Normal', 'Pekat'].map((density) {
                    final isSelected = _settings.printDensity == density;
                    return ChoiceChip(
                      label: Text(density),
                      selected: isSelected,
                      selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                      ),
                      onSelected: (val) {
                        if (val) {
                          _updateSettings(_settings.copyWith(printDensity: density));
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Feed Lines Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Baris Pemotong / Feed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Jarak kosong setelah struk selesai', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [1, 2, 3].map((lines) {
                    final isSelected = _settings.feedLines == lines;
                    return ChoiceChip(
                      label: Text('$lines Baris'),
                      selected: isSelected,
                      selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
                      ),
                      onSelected: (val) {
                        if (val) {
                          _updateSettings(_settings.copyWith(feedLines: lines));
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Auto-print toggle
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Cetak Otomatis Setelah Transaksi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: Text('Tampilkan dialog konfirmasi cetak saat transaksi selesai', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              value: _settings.autoPrintOnTransaction,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) {
                _updateSettings(_settings.copyWith(autoPrintOnTransaction: val));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestPrintSection(String testPayload) {
    return Card(
      elevation: 0,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                    Icon(Icons.fact_check_rounded, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Uji Cetak Thermal (ESC/POS 32 Kolom)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Salin Teks Uji',
                  icon: Icon(Icons.copy_rounded, size: 18, color: AppTheme.textSecondary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: testPayload));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payload teks uji cetak thermal disalin ke clipboard!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 12),
            Text('Pratinjau pola cetak untuk memverifikasi perataan karakter, kerapatan, dan pemotongan kertas:',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),

            // Thermal Paper Preview Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: SelectableText(
                testPayload,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.3,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (_isTesting) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _testStatusMessage,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Test Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : () => _runTestPrint(testType: 'Perataan & Karakter'),
                    icon: const Icon(Icons.format_align_center_rounded, size: 14),
                    label: const Text('Uji Perataan', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : () => _runTestPrint(testType: 'Feed Kertas'),
                    icon: const Icon(Icons.vertical_align_bottom_rounded, size: 14),
                    label: const Text('Uji Feed', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : () => _runTestPrint(testType: 'Uji Cetak Penuh'),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Uji Cetak Sekarang',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
}
