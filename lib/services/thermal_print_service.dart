import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../models/printer_device_model.dart';
import '../models/print_result_model.dart';
import '../models/receipt_model.dart';
import '../models/receipt_format_settings.dart';
import 'printer_storage_service.dart';

enum PrintServiceState {
  idle,
  connecting,
  transmitting,
  completed,
  error,
}

extension PrintServiceStateExtension on PrintServiceState {
  String get label {
    switch (this) {
      case PrintServiceState.idle:
        return 'Siap';
      case PrintServiceState.connecting:
        return 'Menghubungkan Printer...';
      case PrintServiceState.transmitting:
        return 'Mengirim Data Resi...';
      case PrintServiceState.completed:
        return 'Selesai Dicetak';
      case PrintServiceState.error:
        return 'Gagal Mencetak';
    }
  }

  bool get isPrinting =>
      this == PrintServiceState.connecting || this == PrintServiceState.transmitting;
}

class PrinterConnectionResult {
  final bool isSuccess;
  final String message;

  const PrinterConnectionResult({
    required this.isSuccess,
    required this.message,
  });
}

class BluetoothDiagnosticInfo {
  final bool isBluetoothOn;
  final bool hasPermission;
  final bool isPermissionPermanentlyDenied;
  final int pairedDevicesCount;
  final String statusMessage;

  const BluetoothDiagnosticInfo({
    required this.isBluetoothOn,
    required this.hasPermission,
    required this.isPermissionPermanentlyDenied,
    required this.pairedDevicesCount,
    required this.statusMessage,
  });
}

class ThermalPrintService {
  static final ThermalPrintService _instance = ThermalPrintService._internal();
  factory ThermalPrintService() => _instance;
  ThermalPrintService._internal();

  final PrinterStorageService _storage = PrinterStorageService();

  // Value Notifiers untuk sinkronisasi instan antar halaman
  final ValueNotifier<PrinterDeviceModel?> activePrinterNotifier =
      ValueNotifier<PrinterDeviceModel?>(null);
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);

  PrintServiceState _state = PrintServiceState.idle;
  PrintServiceState get state => _state;

  PrintResult? _lastResult;
  PrintResult? get lastResult => _lastResult;

  final List<PrintResult> _history = [];
  List<PrintResult> get history => List.unmodifiable(_history);

  // Stream Controllers untuk notifikasi perubahan status secara reaktif
  final StreamController<PrintServiceState> _stateStreamController =
      StreamController<PrintServiceState>.broadcast();
  Stream<PrintServiceState> get stateStream => _stateStreamController.stream;

  final StreamController<PrintResult> _resultStreamController =
      StreamController<PrintResult>.broadcast();
  Stream<PrintResult> get resultStream => _resultStreamController.stream;

  // Observers / listeners biasa (untuk fleksibilitas tanpa StreamBuilder jika dibutuhkan)
  final List<void Function(PrintServiceState state)> _stateListeners = [];
  final List<void Function(PrintResult result)> _resultListeners = [];

  void addStateListener(void Function(PrintServiceState state) listener) {
    _stateListeners.add(listener);
  }

  void removeStateListener(void Function(PrintServiceState state) listener) {
    _stateListeners.remove(listener);
  }

  void addResultListener(void Function(PrintResult result) listener) {
    _resultListeners.add(listener);
  }

  void removeResultListener(void Function(PrintResult result) listener) {
    _resultListeners.remove(listener);
  }

  /// Memeriksa diagnostik status Bluetooth, izin, dan jumlah printer tersandingkan
  Future<BluetoothDiagnosticInfo> checkBluetoothDiagnostic() async {
    if (!Platform.isAndroid) {
      return const BluetoothDiagnosticInfo(
        isBluetoothOn: true,
        hasPermission: true,
        isPermissionPermanentlyDenied: false,
        pairedDevicesCount: 3,
        statusMessage: 'Mode simulasi desktop aktif.',
      );
    }

    bool hasPerm = false;
    bool permPermanentlyDenied = false;
    try {
      final connStatus = await Permission.bluetoothConnect.status;
      final scanStatus = await Permission.bluetoothScan.status;

      if (connStatus.isPermanentlyDenied || scanStatus.isPermanentlyDenied) {
        permPermanentlyDenied = true;
      }

      final pluginGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      hasPerm = pluginGranted || (connStatus.isGranted && scanStatus.isGranted);
    } catch (_) {
      hasPerm = true;
    }

    bool isBtOn = false;
    try {
      if (hasPerm) {
        isBtOn = await PrintBluetoothThermal.bluetoothEnabled;
      }
    } catch (_) {}

    int pairedCount = 0;
    if (hasPerm && isBtOn) {
      try {
        final paired = await PrintBluetoothThermal.pairedBluetooths;
        pairedCount = paired.length;
      } catch (_) {}
    }

    String msg = '';
    if (permPermanentlyDenied) {
      msg = 'Izin Bluetooth ditolak permanen. Buka Pengaturan HP untuk mengizinkan "Perangkat di sekitar".';
    } else if (!hasPerm) {
      msg = 'Izin Bluetooth belum diberikan. Mohon izinkan akses perangkat di sekitar.';
    } else if (!isBtOn) {
      msg = 'Bluetooth HP dalam keadaan nonaktif. Silakan nyalakan Bluetooth Anda.';
    } else if (pairedCount == 0) {
      msg = 'Bluetooth aktif & izin disetujui, tetapi belum ada printer yang di-pair di Android.';
    } else {
      msg = '$pairedCount printer Bluetooth terpasang di Android.';
    }

    return BluetoothDiagnosticInfo(
      isBluetoothOn: isBtOn,
      hasPermission: hasPerm,
      isPermissionPermanentlyDenied: permPermanentlyDenied,
      pairedDevicesCount: pairedCount,
      statusMessage: msg,
    );
  }

  /// Memeriksa dan meminta izin Bluetooth & Lokasi pada Android
  Future<bool> checkAndRequestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final bool isAlreadyGranted =
            await PrintBluetoothThermal.isPermissionBluetoothGranted;
        if (isAlreadyGranted) return true;

        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

        final bool connGranted =
            statuses[Permission.bluetoothConnect]?.isGranted ?? false;
        final bool scanGranted =
            statuses[Permission.bluetoothScan]?.isGranted ?? false;

        if (connGranted && scanGranted) {
          return true;
        }

        final bool pluginPermission =
            await PrintBluetoothThermal.isPermissionBluetoothGranted;
        return pluginPermission;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Mengambil daftar printer Bluetooth yang telah dipasangkan (paired) di HP Android
  Future<List<PrinterDeviceModel>> getPairedPrinters() async {
    await _storage.init();
    try {
      if (Platform.isAndroid) {
        await checkAndRequestPermissions();
        final isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
        if (!isEnabled) {
          return await _storage.getPairedDevices();
        }
        final List<BluetoothInfo> paired =
            await PrintBluetoothThermal.pairedBluetooths;
        final devices = paired.map((info) {
          return PrinterDeviceModel.fromBluetoothInfo(
            info.name,
            info.macAdress,
          );
        }).toList();

        // Gabungkan juga perangkat dari storage lokal yang telah diinput sebelumnya
        final savedDevices = await _storage.getPairedDevices();
        for (final s in savedDevices) {
          if (s.address.isNotEmpty &&
              !devices.any((d) => d.address.toLowerCase() == s.address.toLowerCase())) {
            devices.add(s);
          }
        }

        if (devices.isNotEmpty) {
          await _storage.savePairedDevices(devices);
        }
        return devices;
      }
    } catch (_) {}
    return _storage.getPairedDevices();
  }

  /// Menghubungkan ke printer thermal fisik melalui Bluetooth dengan hasil detail
  Future<PrinterConnectionResult> connectPrinterDetailed(String macAddress) async {
    final cleanMac = macAddress.trim();
    if (cleanMac.isEmpty) {
      return const PrinterConnectionResult(
        isSuccess: false,
        message: 'Alamat MAC printer belum dipilih. Silakan pilih printer dari daftar perangkat terpasang.',
      );
    }

    if (cleanMac == '58:A2:3B:11:89:DC' ||
        cleanMac == 'AA:BB:CC:22:33:44' ||
        cleanMac == '11:22:33:44:55:66') {
      return PrinterConnectionResult(
        isSuccess: false,
        message: 'Alamat $cleanMac adalah data simulasi. Pasangkan printer thermal Anda di Pengaturan Bluetooth HP, lalu tekan "Pindai Perangkat" dan pilih printer Anda.',
      );
    }

    try {
      if (Platform.isAndroid) {
        await checkAndRequestPermissions();

        final isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
        if (!isEnabled) {
          return const PrinterConnectionResult(
            isSuccess: false,
            message: 'Bluetooth di HP Android Anda belum aktif. Mohon nyalakan Bluetooth.',
          );
        }

        // Putuskan koneksi lama terlebih dahulu untuk menyegarkan RFCOMM socket
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 300));

        final bool connected =
            await PrintBluetoothThermal.connect(macPrinterAddress: cleanMac);

        isConnectedNotifier.value = connected;
        if (connected) {
          if (activePrinterNotifier.value != null &&
              activePrinterNotifier.value!.address == cleanMac) {
            activePrinterNotifier.value =
                activePrinterNotifier.value!.copyWith(isConnected: true);
          }
          return PrinterConnectionResult(
            isSuccess: true,
            message: 'Berhasil terhubung ke printer ($cleanMac)!',
          );
        } else {
          return PrinterConnectionResult(
            isSuccess: false,
            message: 'Tidak dapat menyambung ke $cleanMac. Pastikan printer ON, lampu indikator menyala, dan sudah di-pair di Bluetooth HP.',
          );
        }
      }
    } catch (e) {
      isConnectedNotifier.value = false;
      return PrinterConnectionResult(
        isSuccess: false,
        message: 'Gagal menghubungkan Bluetooth: $e',
      );
    }

    isConnectedNotifier.value = true;
    return const PrinterConnectionResult(
      isSuccess: true,
      message: 'Mode simulasi terhubung.',
    );
  }

  /// Menghubungkan ke printer thermal fisik melalui Bluetooth
  Future<bool> connectPrinter(String macAddress) async {
    final res = await connectPrinterDetailed(macAddress);
    return res.isSuccess;
  }

  /// Memutuskan koneksi printer
  Future<bool> disconnectPrinter() async {
    isConnectedNotifier.value = false;
    if (activePrinterNotifier.value != null) {
      activePrinterNotifier.value =
          activePrinterNotifier.value!.copyWith(isConnected: false);
    }
    try {
      if (Platform.isAndroid) {
        return await PrintBluetoothThermal.disconnect;
      }
    } catch (_) {}
    return true;
  }

  /// Memeriksa status koneksi printer fisik
  Future<bool> checkConnection() async {
    try {
      if (Platform.isAndroid) {
        final bool isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
        if (!isEnabled) {
          isConnectedNotifier.value = false;
          return false;
        }
        final bool isConn = await PrintBluetoothThermal.connectionStatus;
        isConnectedNotifier.value = isConn;
        return isConn;
      }
    } catch (_) {}
    return false;
  }

  /// Memastikan printer utama terhubung ke Bluetooth (dengan auto-reconnect jika terputus)
  Future<PrinterDeviceModel> ensurePrimaryConnected({bool forceReconnect = false}) async {
    await _storage.init();
    final primary = await _storage.getPrimaryPrinter();
    final settings = await _storage.getPrinterSettings();

    if (primary.address.isEmpty ||
        primary.address == '58:A2:3B:11:89:DC' ||
        primary.address == 'AA:BB:CC:22:33:44' ||
        primary.address == '11:22:33:44:55:66') {
      final updated = primary.copyWith(isConnected: false);
      activePrinterNotifier.value = updated;
      isConnectedNotifier.value = false;
      return updated;
    }

    if (Platform.isAndroid && !_simulateHardwareFailure) {
      bool isConn = await checkConnection();
      if (!isConn && (settings.autoConnect || forceReconnect)) {
        final res = await connectPrinterDetailed(primary.address);
        isConn = res.isSuccess;
      }
      final updated = primary.copyWith(isConnected: isConn);
      activePrinterNotifier.value = updated;
      isConnectedNotifier.value = isConn;
      await _storage.savePrimaryPrinter(updated);
      return updated;
    }

    final updated = primary.copyWith(isConnected: primary.isConnected);
    activePrinterNotifier.value = updated;
    isConnectedNotifier.value = primary.isConnected;
    return updated;
  }

  // --- Parameter Simulasi Hardware untuk Pengujian & Demo Mode ---
  bool _simulateHardwareFailure = false;
  PrintResultStatus _simulatedFailureStatus = PrintResultStatus.outOfPaper;
  String _simulatedFailureMessage = 'Kertas pada printer VSC MP-58C habis.';
  int _simulatedDelayMs = 600;

  void configureSimulation({
    bool simulateFailure = false,
    PrintResultStatus failureStatus = PrintResultStatus.outOfPaper,
    String failureMessage = 'Kertas pada printer habis.',
    int delayMs = 600,
  }) {
    _simulateHardwareFailure = simulateFailure;
    _simulatedFailureStatus = failureStatus;
    _simulatedFailureMessage = failureMessage;
    _simulatedDelayMs = delayMs;
  }

  void resetSimulation() {
    _simulateHardwareFailure = false;
    _simulatedFailureStatus = PrintResultStatus.outOfPaper;
    _simulatedFailureMessage = 'Kertas pada printer habis.';
    _simulatedDelayMs = 600;
  }

  // --- Perintah Standar ESC/POS VSC MP-58C ---
  static const List<int> escInit = [0x1B, 0x40]; // ESC @
  static const List<int> escAlignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> escAlignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> escAlignRight = [0x1B, 0x61, 0x02]; // ESC a 2
  static const List<int> escDensityNormal = [0x1B, 0x47, 0x00]; // ESC G 0
  static const List<int> escDensityBold = [0x1B, 0x47, 0x01]; // ESC G 1 (Double strike)
  static const List<int> escCutPaper = [0x1D, 0x56, 0x42, 0x00]; // GS V 66 0 (Feed & Partial Cut)

  /// Menghasilkan byte ESC/POS untuk Barcode 1D (Code 128)
  static List<int> generateBarcode128Bytes(
    String code, {
    int height = 64, // ~8mm
    int width = 2, // 2 dots per module (ideal untuk 58mm)
    bool showHri = true, // Cetak teks di bawah barcode
  }) {
    final List<int> bytes = [];
    bytes.addAll(escAlignCenter);

    // GS h n - Tinggi barcode
    bytes.addAll([0x1D, 0x68, height.clamp(1, 255)]);

    // GS w n - Lebar modul barcode
    bytes.addAll([0x1D, 0x77, width.clamp(2, 6)]);

    // GS H n - Posisi HRI (0 = None, 2 = Below)
    bytes.addAll([0x1D, 0x48, showHri ? 0x02 : 0x00]);

    // GS f n - Font HRI (0 = Font A)
    bytes.addAll([0x1D, 0x66, 0x00]);

    // GS k 73 len data - Format B Code 128
    // Code 128 Subset B diawali dengan prefix {B (0x7B, 0x42)
    final codeBytes = ascii.encode(code);
    final data = [0x7B, 0x42, ...codeBytes];
    bytes.addAll([0x1D, 0x6B, 73, data.length, ...data]);

    bytes.add(0x0A); // Line feed setelah barcode
    bytes.addAll(escAlignLeft); // Kembalikan ke rata kiri

    return bytes;
  }

  /// Menghasilkan byte ESC/POS untuk 2D QR Code
  static List<int> generateQrCodeBytes(
    String data, {
    int moduleSize = 4, // 1 to 16 dots
  }) {
    final List<int> bytes = [];
    bytes.addAll(escAlignCenter);

    final dataBytes = utf8.encode(data);
    final storeLen = dataBytes.length + 3;
    final pL = storeLen % 256;
    final pH = storeLen ~/ 256;

    // 1. Function 165: Select model (Model 2)
    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    // 2. Function 167: Set module size (1 to 16)
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize.clamp(1, 16)]);

    // 3. Function 169: Error correction level (49 = Level M, 15%)
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

    // 4. Function 180: Store data
    bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30, ...dataBytes]);

    // 5. Function 181: Print QR code
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    bytes.add(0x0A); // Line feed setelah QR code
    bytes.addAll(escAlignLeft); // Kembalikan ke rata kiri

    return bytes;
  }

  /// Mengonversi teks ke paket byte ESC/POS siap kirim dengan header, kerapatan, barcode/QR, dan pemotong kertas
  List<int> formatEscPosBytes(
    String text, {
    PrinterSettingsModel? settings,
    ReceiptFormatSettings? formatSettings,
  }) {
    final s = settings ?? const PrinterSettingsModel();
    final fmt = formatSettings ?? const ReceiptFormatSettings();
    final List<int> bytes = [];

    // 1. Initialize printer
    bytes.addAll(escInit);

    // 2. Set density
    if (s.printDensity.toLowerCase() == 'pekat') {
      bytes.addAll(escDensityBold);
    } else {
      bytes.addAll(escDensityNormal);
    }

    // Helper untuk memproses tag STORE_NAME
    void appendTextChunkWithStoreName(String chunk) {
      if (!chunk.contains('[STORE_NAME:')) {
        bytes.addAll(utf8.encode(chunk));
        return;
      }

      final storePattern = RegExp(r'\[STORE_NAME:(.*?):(.*?):(.*?):(.*?)\]');
      int pos = 0;
      for (final sm in storePattern.allMatches(chunk)) {
        final pre = chunk.substring(pos, sm.start);
        if (pre.isNotEmpty) {
          bytes.addAll(utf8.encode(pre));
        }

        final size = sm.group(1)?.toLowerCase() ?? 'large';
        final weight = sm.group(2)?.toLowerCase() ?? 'bold';
        final align = sm.group(3)?.toLowerCase() ?? 'center';
        final name = sm.group(4) ?? '';

        // Set Alignment
        bytes.addAll([0x1B, 0x61, align == 'left' ? 0x00 : 0x01]);

        // Set Weight
        if (weight == 'extrabold' || weight == 'extra_bold') {
          bytes.addAll([0x1B, 0x45, 0x01, 0x1B, 0x47, 0x01]);
        } else if (weight == 'bold') {
          bytes.addAll([0x1B, 0x45, 0x01, 0x1B, 0x47, 0x00]);
        } else {
          bytes.addAll([0x1B, 0x45, 0x00, 0x1B, 0x47, 0x00]);
        }

        // Set Size
        if (size == 'extralarge' || size == 'extra_large') {
          bytes.addAll([0x1D, 0x21, 0x11]); // double height & width
        } else if (size == 'large') {
          bytes.addAll([0x1D, 0x21, 0x01]); // double height
        } else {
          bytes.addAll([0x1D, 0x21, 0x00]); // normal
        }

        bytes.addAll(utf8.encode(name));
        bytes.add(0x0A);

        // Reset text formatting
        bytes.addAll([
          0x1D, 0x21, 0x00, // normal size
          0x1B, 0x45, 0x00, // bold off
          0x1B, 0x47, 0x00, // double strike off
          0x1B, 0x61, 0x00, // align left
        ]);

        pos = sm.end;
      }

      final post = chunk.substring(pos);
      if (post.isNotEmpty) {
        bytes.addAll(utf8.encode(post));
      }
    }

    // 3. Tentukan ukuran barcode
    final int barcodeHeight = fmt.barcodeSize == 'small'
        ? 40
        : (fmt.barcodeSize == 'large' ? 80 : 64);
    final int qrModuleSize = fmt.barcodeSize == 'small'
        ? 3
        : (fmt.barcodeSize == 'large' ? 5 : 4);

    // 4. Add text content and process [BARCODE:...] tags
    if (fmt.showBarcode && text.contains('[BARCODE:')) {
      final pattern = RegExp(r'\[BARCODE:(.*?)\]');
      int lastIndex = 0;
      for (final match in pattern.allMatches(text)) {
        final before = text.substring(lastIndex, match.start);
        if (before.isNotEmpty) {
          appendTextChunkWithStoreName(before);
          bytes.add(0x0A);
        }

        final barcodeCode = match.group(1)?.trim() ?? '';
        if (barcodeCode.isNotEmpty) {
          if (fmt.barcodeType == 'code128' || fmt.barcodeType == 'both') {
            bytes.addAll(generateBarcode128Bytes(
              barcodeCode,
              height: barcodeHeight,
              showHri: fmt.showBarcodeHri,
            ));
          }
          if (fmt.barcodeType == 'qrcode' || fmt.barcodeType == 'both') {
            bytes.addAll(generateQrCodeBytes(
              barcodeCode,
              moduleSize: qrModuleSize,
            ));
          }
        }

        lastIndex = match.end;
      }

      final remaining = text.substring(lastIndex);
      if (remaining.isNotEmpty) {
        appendTextChunkWithStoreName(remaining);
        bytes.add(0x0A);
      }
    } else {
      // Hapus tag [BARCODE:...] jika barcode dinonaktifkan
      final cleanText = text.replaceAll(RegExp(r'\[BARCODE:.*?\]\n?'), '');
      appendTextChunkWithStoreName(cleanText);
      bytes.add(0x0A);
    }

    // 5. Feed lines (gunakan fmt.feedLines untuk kontrol penghematan kertas)
    final linesToFeed = fmt.feedLines.clamp(1, 5);
    for (int i = 0; i < linesToFeed; i++) {
      bytes.add(0x0A);
    }

    // 6. Paper cut / marker
    bytes.addAll(escCutPaper);

    return bytes;
  }

  void _setState(PrintServiceState newState) {
    _state = newState;
    _stateStreamController.add(newState);
    for (final listener in List.of(_stateListeners)) {
      listener(newState);
    }
  }

  void _recordResult(PrintResult result) {
    _lastResult = result;
    _history.insert(0, result);
    if (_history.length > 50) {
      _history.removeLast();
    }
    _resultStreamController.add(result);
    for (final listener in List.of(_resultListeners)) {
      listener(result);
    }
  }

  Future<bool> _ensureConnected(PrinterDeviceModel printer) async {
    if (Platform.isAndroid && !_simulateHardwareFailure) {
      try {
        final cleanMac = printer.address.trim();
        if (cleanMac.isEmpty ||
            cleanMac == '58:A2:3B:11:89:DC' ||
            cleanMac == 'AA:BB:CC:22:33:44' ||
            cleanMac == '11:22:33:44:55:66') {
          return false;
        }

        final bool isEnabled = await PrintBluetoothThermal.bluetoothEnabled;
        if (!isEnabled) return false;

        final isConn = await PrintBluetoothThermal.connectionStatus;
        if (isConn) return true;

        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 250));
        return await PrintBluetoothThermal.connect(macPrinterAddress: cleanMac);
      } catch (_) {
        return false;
      }
    }
    return printer.isConnected;
  }

  Future<bool> _sendBytes(List<int> bytes) async {
    if (Platform.isAndroid && !_simulateHardwareFailure) {
      try {
        return await PrintBluetoothThermal.writeBytes(bytes);
      } catch (_) {
        return false;
      }
    }
    await Future.delayed(Duration(milliseconds: _simulatedDelayMs));
    return true;
  }

  /// Mencetak resi transaksi SKYRental
  Future<PrintResult> printReceipt(
    ReceiptModel receipt, {
    PrinterDeviceModel? targetPrinter,
    PrinterSettingsModel? settings,
  }) async {
    final startTime = DateTime.now();

    // Pastikan service penyimpanan sudah siap
    await _storage.init();
    final printer = targetPrinter ?? await _storage.getPrimaryPrinter();
    final printerSettings = settings ?? await _storage.getPrinterSettings();

    // 1. Validasi keberadaan printer
    if (printer.address.isEmpty) {
      final res = PrintResult.failure(
        status: PrintResultStatus.noPrinterSelected,
        message: 'Belum ada printer thermal yang dipilih. Buka Pengaturan Printer untuk memilih printer utama.',
        receiptNumber: receipt.receiptNumber,
        timestamp: startTime,
      );
      _setState(PrintServiceState.error);
      _recordResult(res);
      _setState(PrintServiceState.idle);
      return res;
    }

    // 2. Transisi state ke connecting
    _setState(PrintServiceState.connecting);

    // 3. Validasi & hubungkan koneksi printer
    if (!_simulateHardwareFailure) {
      final connected = await _ensureConnected(printer);
      if (!connected) {
        final res = PrintResult.failure(
          status: PrintResultStatus.printerNotConnected,
          message: 'Printer ${printer.name} (${printer.address}) tidak terhubung. Nyalakan Bluetooth dan pastikan printer aktif.',
          receiptNumber: receipt.receiptNumber,
          deviceName: printer.name,
          deviceAddress: printer.address,
          timestamp: startTime,
          executionDurationMs: DateTime.now().difference(startTime).inMilliseconds,
        );
        _setState(PrintServiceState.error);
        _recordResult(res);
        _setState(PrintServiceState.idle);
        return res;
      }
    }

    // 4. Transisi state ke transmitting
    _setState(PrintServiceState.transmitting);

    // 5. Cek kondisi simulasi kegagalan hardware
    if (_simulateHardwareFailure) {
      final res = PrintResult.failure(
        status: _simulatedFailureStatus,
        message: _simulatedFailureMessage,
        receiptNumber: receipt.receiptNumber,
        deviceName: printer.name,
        deviceAddress: printer.address,
        timestamp: startTime,
        executionDurationMs: DateTime.now().difference(startTime).inMilliseconds,
      );
      _setState(PrintServiceState.error);
      _recordResult(res);
      _setState(PrintServiceState.idle);
      return res;
    }

    // 6. Pembentukan byte ESC/POS dari 32 kolom resi (dengan format settings kustom)
    final receiptFormat = await _storage.getReceiptFormatSettings();
    final rawText = receipt.toEscPos58mm(formatSettings: receiptFormat);
    final bytes = formatEscPosBytes(rawText, settings: printerSettings, formatSettings: receiptFormat);

    final bool sent = await _sendBytes(bytes);
    if (!sent) {
      final res = PrintResult.failure(
        status: PrintResultStatus.transmissionError,
        message: 'Gagal mentransmisikan data ke printer ${printer.name}. Silakan periksa status printer.',
        receiptNumber: receipt.receiptNumber,
        deviceName: printer.name,
        deviceAddress: printer.address,
        timestamp: startTime,
        executionDurationMs: DateTime.now().difference(startTime).inMilliseconds,
      );
      _setState(PrintServiceState.error);
      _recordResult(res);
      _setState(PrintServiceState.idle);
      return res;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    final successResult = PrintResult.success(
      message: 'Struk resi ${receipt.receiptNumber} berhasil dicetak pada printer ${printer.name}.',
      receiptNumber: receipt.receiptNumber,
      deviceName: printer.name,
      deviceAddress: printer.address,
      timestamp: startTime,
      bytesSent: bytes.length,
      executionDurationMs: duration,
      metadata: {
        'type': receipt.type.name,
        'bookingCode': receipt.bookingCode,
        'customerName': receipt.customerName,
        'totalAmount': receipt.totalAmount,
        'paperWidthMm': printerSettings.paperWidthMm,
        'columns': printerSettings.columns,
        'printDensity': printerSettings.printDensity,
        'feedLines': printerSettings.feedLines,
      },
    );

    _setState(PrintServiceState.completed);
    _recordResult(successResult);
    _setState(PrintServiceState.idle);

    return successResult;
  }

  /// Mencetak halaman uji cetak (Test Print Page)
  Future<PrintResult> printTestPage({
    PrinterDeviceModel? targetPrinter,
    PrinterSettingsModel? settings,
  }) async {
    final startTime = DateTime.now();

    await _storage.init();
    final printer = targetPrinter ?? await _storage.getPrimaryPrinter();
    final printerSettings = settings ?? await _storage.getPrinterSettings();

    _setState(PrintServiceState.connecting);

    if (!_simulateHardwareFailure) {
      final connected = await _ensureConnected(printer);
      if (!connected) {
        final res = PrintResult.failure(
          status: PrintResultStatus.printerNotConnected,
          message: 'Printer ${printer.name} tidak terhubung. Sambungkan Bluetooth terlebih dahulu.',
          deviceName: printer.name,
          deviceAddress: printer.address,
          timestamp: startTime,
        );
        _setState(PrintServiceState.error);
        _recordResult(res);
        _setState(PrintServiceState.idle);
        return res;
      }
    }

    _setState(PrintServiceState.transmitting);

    if (_simulateHardwareFailure) {
      final res = PrintResult.failure(
        status: _simulatedFailureStatus,
        message: _simulatedFailureMessage,
        deviceName: printer.name,
        deviceAddress: printer.address,
        timestamp: startTime,
      );
      _setState(PrintServiceState.error);
      _recordResult(res);
      _setState(PrintServiceState.idle);
      return res;
    }

    final testText = PrinterSettingsModel.generateTestPrintPayload(
      device: printer,
      settings: printerSettings,
    );
    final bytes = formatEscPosBytes(testText, settings: printerSettings);

    final bool sent = await _sendBytes(bytes);
    if (!sent) {
      final res = PrintResult.failure(
        status: PrintResultStatus.transmissionError,
        message: 'Gagal mengirim data uji cetak ke printer ${printer.name}.',
        deviceName: printer.name,
        deviceAddress: printer.address,
        timestamp: startTime,
      );
      _setState(PrintServiceState.error);
      _recordResult(res);
      _setState(PrintServiceState.idle);
      return res;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    final successResult = PrintResult.success(
      message: 'Halaman uji coba berhasil dicetak pada printer ${printer.name}.',
      receiptNumber: 'TEST-PRINT-${DateTime.now().millisecondsSinceEpoch}',
      deviceName: printer.name,
      deviceAddress: printer.address,
      timestamp: startTime,
      bytesSent: bytes.length,
      executionDurationMs: duration,
      metadata: {
        'isTestPrint': true,
        'paperWidthMm': printerSettings.paperWidthMm,
        'columns': printerSettings.columns,
        'density': printerSettings.printDensity,
      },
    );

    _setState(PrintServiceState.completed);
    _recordResult(successResult);
    _setState(PrintServiceState.idle);

    return successResult;
  }

  /// Mencetak teks bebas / struk kustom (32 kolom)
  Future<PrintResult> printCustomText(
    String text, {
    String? title,
    PrinterDeviceModel? targetPrinter,
    PrinterSettingsModel? settings,
  }) async {
    final startTime = DateTime.now();

    await _storage.init();
    final printer = targetPrinter ?? await _storage.getPrimaryPrinter();
    final printerSettings = settings ?? await _storage.getPrinterSettings();

    _setState(PrintServiceState.connecting);

    if (!_simulateHardwareFailure) {
      final connected = await _ensureConnected(printer);
      if (!connected) {
        final res = PrintResult.failure(
          status: PrintResultStatus.printerNotConnected,
          message: 'Printer ${printer.name} tidak terhubung.',
          deviceName: printer.name,
          deviceAddress: printer.address,
          timestamp: startTime,
        );
        _setState(PrintServiceState.error);
        _recordResult(res);
        _setState(PrintServiceState.idle);
        return res;
      }
    }

    _setState(PrintServiceState.transmitting);

    if (_simulateHardwareFailure) {
      final res = PrintResult.failure(
        status: _simulatedFailureStatus,
        message: _simulatedFailureMessage,
        deviceName: printer.name,
        deviceAddress: printer.address,
        timestamp: startTime,
      );
      _setState(PrintServiceState.error);
      _recordResult(res);
      _setState(PrintServiceState.idle);
      return res;
    }

    final bytes = formatEscPosBytes(text, settings: printerSettings);
    final bool sent = await _sendBytes(bytes);
    if (!sent) {
      final res = PrintResult.failure(
        status: PrintResultStatus.transmissionError,
        message: 'Gagal mengirim teks ke printer ${printer.name}.',
        deviceName: printer.name,
        deviceAddress: printer.address,
        timestamp: startTime,
      );
      _setState(PrintServiceState.error);
      _recordResult(res);
      _setState(PrintServiceState.idle);
      return res;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    final successResult = PrintResult.success(
      message: 'Teks $title berhasil dicetak pada printer ${printer.name}.',
      deviceName: printer.name,
      deviceAddress: printer.address,
      timestamp: startTime,
      bytesSent: bytes.length,
      executionDurationMs: duration,
    );

    _setState(PrintServiceState.completed);
    _recordResult(successResult);
    _setState(PrintServiceState.idle);

    return successResult;
  }

  /// Coba ulang pencetakan terakhir jika ada
  Future<PrintResult?> retryLastPrint() async {
    if (_lastResult == null) return null;
    final last = _lastResult!;

    if (last.receiptNumber != null) {
      // Jika memiliki nomor resi, lakukan pencetakan ulang
      return printTestPage();
    }
    return null;
  }

  /// Mengambil status diagnostik printer saat ini
  Future<Map<String, dynamic>> checkDiagnostics({PrinterDeviceModel? targetPrinter}) async {
    await _storage.init();
    final printer = targetPrinter ?? await _storage.getPrimaryPrinter();
    final settings = await _storage.getPrinterSettings();

    final isOnline = printer.isConnected && !_simulateHardwareFailure;
    return {
      'printerName': printer.name,
      'printerAddress': printer.address,
      'connectionType': printer.connectionType,
      'isConnected': isOnline,
      'batteryLevel': printer.batteryLevel,
      'signalStrength': printer.signalStrength,
      'paperWidthMm': settings.paperWidthMm,
      'columns': settings.columns,
      'printDensity': settings.printDensity,
      'statusDescription': isOnline ? 'Siap Cetak' : 'Offline / Terputus',
    };
  }

  /// Menghapus seluruh riwayat cetak lokal
  void clearHistory() {
    _history.clear();
  }
}
