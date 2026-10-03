import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_device_model.dart';
import '../models/receipt_format_settings.dart';

class PrinterStorageService {
  static final PrinterStorageService _instance = PrinterStorageService._internal();
  factory PrinterStorageService() => _instance;
  PrinterStorageService._internal();

  static const String _defaultStoragePath = '.printer_preferences.json';
  static const String _prefKeyPrimary = 'skyrent_primary_printer';
  static const String _prefKeySettings = 'skyrent_printer_settings';
  static const String _prefKeyPaired = 'skyrent_paired_devices';
  static const String _prefKeyReceiptFormat = 'skyrent_receipt_format';

  // In-memory cache
  PrinterDeviceModel? _primaryPrinter;
  PrinterSettingsModel? _settings;
  List<PrinterDeviceModel>? _pairedDevices;
  ReceiptFormatSettings? _receiptFormat;
  bool _isInitialized = false;

  /// Inisialisasi data dari penyimpanan lokal (SharedPreferences & fallback file)
  Future<void> init({String? customPath}) async {
    if (_isInitialized && customPath == null) return;

    // 1. Coba baca dari SharedPreferences terlebih dahulu
    try {
      final prefs = await SharedPreferences.getInstance();
      final primaryRaw = prefs.getString(_prefKeyPrimary);
      if (primaryRaw != null && primaryRaw.isNotEmpty) {
        _primaryPrinter = PrinterDeviceModel.fromJson(
          jsonDecode(primaryRaw) as Map<String, dynamic>,
        );
      }

      final settingsRaw = prefs.getString(_prefKeySettings);
      if (settingsRaw != null && settingsRaw.isNotEmpty) {
        _settings = PrinterSettingsModel.fromJson(
          jsonDecode(settingsRaw) as Map<String, dynamic>,
        );
      }

      final pairedRaw = prefs.getString(_prefKeyPaired);
      if (pairedRaw != null && pairedRaw.isNotEmpty) {
        final list = jsonDecode(pairedRaw) as List<dynamic>;
        _pairedDevices = list
            .map((e) => PrinterDeviceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final receiptFormatRaw = prefs.getString(_prefKeyReceiptFormat);
      if (receiptFormatRaw != null && receiptFormatRaw.isNotEmpty) {
        _receiptFormat = ReceiptFormatSettings.fromJson(
          jsonDecode(receiptFormatRaw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}

    // 2. Fallback baca dari file jika customPath diberikan atau SharedPreferences kosong
    if (_primaryPrinter == null || customPath != null) {
      try {
        final file = File(customPath ?? _defaultStoragePath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;

          if (jsonMap['primaryPrinter'] != null) {
            _primaryPrinter = PrinterDeviceModel.fromJson(
              jsonMap['primaryPrinter'] as Map<String, dynamic>,
            );
          }

          if (jsonMap['settings'] != null) {
            _settings = PrinterSettingsModel.fromJson(
              jsonMap['settings'] as Map<String, dynamic>,
            );
          }

          if (jsonMap['pairedDevices'] != null) {
            final list = jsonMap['pairedDevices'] as List<dynamic>;
            _pairedDevices = list
                .map((e) => PrinterDeviceModel.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (_) {}
    }

    // Default printer handling
    if (Platform.isAndroid) {
      if (_primaryPrinter?.address == '58:A2:3B:11:89:DC' ||
          _primaryPrinter?.address == 'AA:BB:CC:22:33:44' ||
          _primaryPrinter?.address == '11:22:33:44:55:66') {
        _primaryPrinter = null;
      }
      _pairedDevices = _pairedDevices
          ?.where((d) =>
              d.address != '58:A2:3B:11:89:DC' &&
              d.address != 'AA:BB:CC:22:33:44' &&
              d.address != '11:22:33:44:55:66')
          .toList() ??
          [];
    } else {
      _primaryPrinter ??= PrinterDeviceModel.defaultVsc();
      _pairedDevices ??= [
        PrinterDeviceModel.defaultVsc(),
        const PrinterDeviceModel(
          name: 'RPP02N-58 Bluetooth',
          address: 'AA:BB:CC:22:33:44',
          isConnected: false,
          signalStrength: 3,
          batteryLevel: 75,
        ),
        const PrinterDeviceModel(
          name: 'ZJ-5809 Thermal POS',
          address: '11:22:33:44:55:66',
          isConnected: false,
          signalStrength: 2,
          batteryLevel: 60,
        ),
      ];
    }

    _settings ??= const PrinterSettingsModel();
    _isInitialized = true;
  }

  /// Simpan printer utama secara lokal
  Future<void> savePrimaryPrinter(PrinterDeviceModel device, {String? customPath}) async {
    await init();
    _primaryPrinter = device;

    // Perbarui status pada daftar perangkat terpasang
    if (_pairedDevices != null) {
      final index = _pairedDevices!.indexWhere((d) => d.address == device.address);
      if (index != -1) {
        _pairedDevices![index] = device;
      } else {
        _pairedDevices!.add(device);
      }
    }

    await _persist(customPath: customPath);
  }

  /// Ambil printer utama yang tersimpan
  Future<PrinterDeviceModel> getPrimaryPrinter() async {
    await init();
    if (_primaryPrinter != null) return _primaryPrinter!;
    if (Platform.isAndroid) {
      return const PrinterDeviceModel(
        name: 'Belum Ada Printer Dipilih',
        address: '',
        isConnected: false,
      );
    }
    return PrinterDeviceModel.defaultVsc();
  }

  /// Cek apakah alamat MAC tertentu merupakan printer utama
  bool isPrimaryPrinter(String address) {
    return _primaryPrinter?.address.toLowerCase() == address.toLowerCase();
  }

  /// Simpan pengaturan konfigurasi cetak
  Future<void> savePrinterSettings(PrinterSettingsModel settings, {String? customPath}) async {
    await init();
    _settings = settings;
    await _persist(customPath: customPath);
  }

  /// Ambil pengaturan konfigurasi cetak
  Future<PrinterSettingsModel> getPrinterSettings() async {
    await init();
    return _settings ?? const PrinterSettingsModel();
  }

  /// Simpan pengaturan format resi
  Future<void> saveReceiptFormatSettings(ReceiptFormatSettings format, {String? customPath}) async {
    await init();
    _receiptFormat = format;
    await _persist(customPath: customPath);
  }

  /// Ambil pengaturan format resi
  Future<ReceiptFormatSettings> getReceiptFormatSettings() async {
    await init();
    return _receiptFormat ?? const ReceiptFormatSettings();
  }

  /// Ambil daftar seluruh printer bluetooth yang pernah dipasangkan
  Future<List<PrinterDeviceModel>> getPairedDevices() async {
    await init();
    return List.unmodifiable(_pairedDevices ?? []);
  }

  /// Tambah atau perbarui perangkat dalam daftar lokal
  Future<void> savePairedDevices(List<PrinterDeviceModel> devices, {String? customPath}) async {
    await init();
    _pairedDevices = List.from(devices);
    await _persist(customPath: customPath);
  }

  /// Tambah atau perbarui satu perangkat printer (misal input manual)
  Future<void> addOrUpdateDevice(PrinterDeviceModel device, {String? customPath}) async {
    await init();
    _pairedDevices ??= [];
    final idx = _pairedDevices!.indexWhere(
      (d) => d.address.trim().toLowerCase() == device.address.trim().toLowerCase(),
    );
    if (idx != -1) {
      _pairedDevices![idx] = device;
    } else {
      _pairedDevices!.add(device);
    }
    await _persist(customPath: customPath);
  }

  /// Reset preferensi printer ke standar bawaan
  Future<void> resetToDefaults({String? customPath}) async {
    _primaryPrinter = PrinterDeviceModel.defaultVsc();
    _settings = const PrinterSettingsModel();
    _pairedDevices = [
      PrinterDeviceModel.defaultVsc(),
      const PrinterDeviceModel(
        name: 'RPP02N-58 Bluetooth',
        address: 'AA:BB:CC:22:33:44',
        isConnected: false,
        signalStrength: 3,
        batteryLevel: 75,
      ),
      const PrinterDeviceModel(
        name: 'ZJ-5809 Thermal POS',
        address: '11:22:33:44:55:66',
        isConnected: false,
        signalStrength: 2,
        batteryLevel: 60,
      ),
    ];
    await _persist(customPath: customPath);
  }

  Future<void> _persist({String? customPath}) async {
    // 1. Simpan ke SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_primaryPrinter != null) {
        await prefs.setString(_prefKeyPrimary, jsonEncode(_primaryPrinter!.toJson()));
      } else {
        await prefs.remove(_prefKeyPrimary);
      }
      if (_settings != null) {
        await prefs.setString(_prefKeySettings, jsonEncode(_settings!.toJson()));
      }
      if (_pairedDevices != null) {
        await prefs.setString(
          _prefKeyPaired,
          jsonEncode(_pairedDevices!.map((d) => d.toJson()).toList()),
        );
      }
      if (_receiptFormat != null) {
        await prefs.setString(
          _prefKeyReceiptFormat,
          jsonEncode(_receiptFormat!.toJson()),
        );
      }
    } catch (_) {}

    // 2. Simpan ke file untuk testing & desktop
    if (Platform.environment.containsKey('FLUTTER_TEST') && customPath == null) return;
    try {
      final file = File(customPath ?? _defaultStoragePath);
      final data = {
        'primaryPrinter': _primaryPrinter?.toJson(),
        'settings': _settings?.toJson(),
        'pairedDevices': _pairedDevices?.map((d) => d.toJson()).toList(),
        'receiptFormat': _receiptFormat?.toJson(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Jika di lingkungan browser atau tanpa akses IO file, in-memory tetap aktif
    }
  }
}
