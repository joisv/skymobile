enum PrintResultStatus {
  success,
  noPrinterSelected,
  printerNotConnected,
  outOfPaper,
  coverOpen,
  transmissionError,
  busy,
  timeout,
  cancelled,
}

extension PrintResultStatusExtension on PrintResultStatus {
  String get label {
    switch (this) {
      case PrintResultStatus.success:
        return 'Berhasil';
      case PrintResultStatus.noPrinterSelected:
        return 'Printer Belum Dipilih';
      case PrintResultStatus.printerNotConnected:
        return 'Printer Terputus';
      case PrintResultStatus.outOfPaper:
        return 'Kertas Habis';
      case PrintResultStatus.coverOpen:
        return 'Cover Terbuka';
      case PrintResultStatus.transmissionError:
        return 'Gagal Transmisi';
      case PrintResultStatus.busy:
        return 'Printer Sibuk';
      case PrintResultStatus.timeout:
        return 'Batas Waktu Habis';
      case PrintResultStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  bool get isSuccess => this == PrintResultStatus.success;
}

class PrintResult {
  final PrintResultStatus status;
  final String message;
  final String? receiptNumber;
  final String? deviceName;
  final String? deviceAddress;
  final DateTime timestamp;
  final int bytesSent;
  final int executionDurationMs;
  final Map<String, dynamic> metadata;

  const PrintResult({
    required this.status,
    required this.message,
    this.receiptNumber,
    this.deviceName,
    this.deviceAddress,
    required this.timestamp,
    this.bytesSent = 0,
    this.executionDurationMs = 0,
    this.metadata = const {},
  });

  bool get isSuccess => status == PrintResultStatus.success;
  bool get isFailed => !isSuccess;
  String get statusLabel => status.label;

  factory PrintResult.success({
    required String message,
    String? receiptNumber,
    String? deviceName,
    String? deviceAddress,
    DateTime? timestamp,
    int bytesSent = 0,
    int executionDurationMs = 0,
    Map<String, dynamic> metadata = const {},
  }) {
    return PrintResult(
      status: PrintResultStatus.success,
      message: message,
      receiptNumber: receiptNumber,
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      timestamp: timestamp ?? DateTime.now(),
      bytesSent: bytesSent,
      executionDurationMs: executionDurationMs,
      metadata: metadata,
    );
  }

  factory PrintResult.failure({
    required PrintResultStatus status,
    required String message,
    String? receiptNumber,
    String? deviceName,
    String? deviceAddress,
    DateTime? timestamp,
    int bytesSent = 0,
    int executionDurationMs = 0,
    Map<String, dynamic> metadata = const {},
  }) {
    return PrintResult(
      status: status,
      message: message,
      receiptNumber: receiptNumber,
      deviceName: deviceName,
      deviceAddress: deviceAddress,
      timestamp: timestamp ?? DateTime.now(),
      bytesSent: bytesSent,
      executionDurationMs: executionDurationMs,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'message': message,
    'receiptNumber': receiptNumber,
    'deviceName': deviceName,
    'deviceAddress': deviceAddress,
    'timestamp': timestamp.toIso8601String(),
    'bytesSent': bytesSent,
    'executionDurationMs': executionDurationMs,
    'metadata': metadata,
    'isSuccess': isSuccess,
  };

  factory PrintResult.fromJson(Map<String, dynamic> json) {
    return PrintResult(
      status: PrintResultStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PrintResultStatus.transmissionError,
      ),
      message: json['message'] as String? ?? '',
      receiptNumber: json['receiptNumber'] as String?,
      deviceName: json['deviceName'] as String?,
      deviceAddress: json['deviceAddress'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      bytesSent: json['bytesSent'] as int? ?? 0,
      executionDurationMs: json['executionDurationMs'] as int? ?? 0,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}
