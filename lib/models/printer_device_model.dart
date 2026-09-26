class PrinterDeviceModel {
  final String name;
  final String address;
  final bool isConnected;
  final String connectionType; // 'bluetooth', 'usb'
  final int signalStrength; // 1-4
  final int batteryLevel; // percentage

  const PrinterDeviceModel({
    required this.name,
    required this.address,
    this.isConnected = false,
    this.connectionType = 'bluetooth',
    this.signalStrength = 4,
    this.batteryLevel = 85,
  });

  PrinterDeviceModel copyWith({
    String? name,
    String? address,
    bool? isConnected,
    String? connectionType,
    int? signalStrength,
    int? batteryLevel,
  }) {
    return PrinterDeviceModel(
      name: name ?? this.name,
      address: address ?? this.address,
      isConnected: isConnected ?? this.isConnected,
      connectionType: connectionType ?? this.connectionType,
      signalStrength: signalStrength ?? this.signalStrength,
      batteryLevel: batteryLevel ?? this.batteryLevel,
    );
  }

  factory PrinterDeviceModel.defaultVsc() {
    return const PrinterDeviceModel(
      name: 'VSC MP-58C',
      address: '58:A2:3B:11:89:DC',
      isConnected: false,
      connectionType: 'bluetooth',
      signalStrength: 4,
      batteryLevel: 90,
    );
  }

  factory PrinterDeviceModel.fromBluetoothInfo(
    String name,
    String macAddress, {
    bool isConnected = false,
  }) {
    return PrinterDeviceModel(
      name: name.trim().isNotEmpty ? name.trim() : 'Printer Bluetooth',
      address: macAddress.trim(),
      isConnected: isConnected,
      connectionType: 'bluetooth',
      signalStrength: 4,
      batteryLevel: 90,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'isConnected': isConnected,
    'connectionType': connectionType,
    'signalStrength': signalStrength,
    'batteryLevel': batteryLevel,
  };

  factory PrinterDeviceModel.fromJson(Map<String, dynamic> json) => PrinterDeviceModel(
    name: json['name'] as String? ?? 'VSC MP-58C',
    address: json['address'] as String? ?? '58:A2:3B:11:89:DC',
    isConnected: json['isConnected'] as bool? ?? false,
    connectionType: json['connectionType'] as String? ?? 'bluetooth',
    signalStrength: json['signalStrength'] as int? ?? 4,
    batteryLevel: json['batteryLevel'] as int? ?? 85,
  );
}

class PrinterSettingsModel {
  final int paperWidthMm; // 58mm
  final int columns; // 32 characters
  final String printDensity; // 'Ringan', 'Normal', 'Pekat'
  final int feedLines; // 1, 2, 3
  final bool autoPrintOnTransaction;
  final bool beepOnComplete;
  final bool autoConnect;

  const PrinterSettingsModel({
    this.paperWidthMm = 58,
    this.columns = 32,
    this.printDensity = 'Normal',
    this.feedLines = 2,
    this.autoPrintOnTransaction = true,
    this.beepOnComplete = false,
    this.autoConnect = true,
  });

  PrinterSettingsModel copyWith({
    int? paperWidthMm,
    int? columns,
    String? printDensity,
    int? feedLines,
    bool? autoPrintOnTransaction,
    bool? beepOnComplete,
    bool? autoConnect,
  }) {
    return PrinterSettingsModel(
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      columns: columns ?? this.columns,
      printDensity: printDensity ?? this.printDensity,
      feedLines: feedLines ?? this.feedLines,
      autoPrintOnTransaction: autoPrintOnTransaction ?? this.autoPrintOnTransaction,
      beepOnComplete: beepOnComplete ?? this.beepOnComplete,
      autoConnect: autoConnect ?? this.autoConnect,
    );
  }

  Map<String, dynamic> toJson() => {
    'paperWidthMm': paperWidthMm,
    'columns': columns,
    'printDensity': printDensity,
    'feedLines': feedLines,
    'autoPrintOnTransaction': autoPrintOnTransaction,
    'beepOnComplete': beepOnComplete,
    'autoConnect': autoConnect,
  };

  factory PrinterSettingsModel.fromJson(Map<String, dynamic> json) => PrinterSettingsModel(
    paperWidthMm: json['paperWidthMm'] as int? ?? 58,
    columns: json['columns'] as int? ?? 32,
    printDensity: json['printDensity'] as String? ?? 'Normal',
    feedLines: json['feedLines'] as int? ?? 2,
    autoPrintOnTransaction: json['autoPrintOnTransaction'] as bool? ?? true,
    beepOnComplete: json['beepOnComplete'] as bool? ?? false,
    autoConnect: json['autoConnect'] as bool? ?? true,
  );

  /// Menghasilkan format teks pengujian cetak (Test Print) tepat 32 kolom ESC/POS
  static String generateTestPrintPayload({
    required PrinterDeviceModel device,
    required PrinterSettingsModel settings,
  }) {
    const int width = 32;
    final divider = '=' * width;
    final subDivider = '-' * width;

    String center(String text) {
      if (text.length >= width) return text.substring(0, width);
      final left = (width - text.length) ~/ 2;
      final right = width - text.length - left;
      return ' ' * left + text + ' ' * right;
    }

    String twoCol(String left, String right) {
      if (left.length + right.length + 1 > width) {
        final maxL = width - right.length - 1;
        if (maxL > 0) left = left.substring(0, maxL);
      }
      final spaces = width - left.length - right.length;
      return '$left${' ' * (spaces > 0 ? spaces : 1)}$right';
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final lines = <String>[
      divider,
      center('SKYRENTAL POS PRINTER'),
      center('TEST PRINT VSC MP-58C'),
      divider,
      twoCol('Tanggal   :', dateStr),
      twoCol('Perangkat :', device.name),
      twoCol('Bluetooth :', device.address),
      twoCol('Koneksi   :', device.connectionType.toUpperCase()),
      twoCol('Baterai   :', '${device.batteryLevel}% [OK]'),
      subDivider,
      twoCol('Lebar     :', '${settings.paperWidthMm}mm (32 Kolom)'),
      twoCol('Kerapatan :', settings.printDensity),
      twoCol('Feed Line :', '${settings.feedLines} Baris'),
      subDivider,
      center('UJI FORMAT & PERATAAN'),
      'RATA KIRI       : [OK]          ',
      '     RATA TENGAH : [OK]         ',
      '         RATA KANAN : [OK]      ',
      subDivider,
      '0123456789ABCDEFGHIJKLMNOPQRSTUV',
      'abcdefghijklmnopqrstuvwxyz!@#\$%^',
      subDivider,
      center('UJI FEED & PEMOTONGAN KERTAS'),
      '*' * width,
      center('STATUS: PRINTER BERFUNGSI BAIK'),
      divider,
      center('VSC MP-58C ESC/POS READY'),
    ];

    // Append feed lines
    for (int i = 0; i < settings.feedLines; i++) {
      lines.add('');
    }

    return lines.join('\n');
  }
}
