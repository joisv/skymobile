import '../services/api_service.dart';

class IphoneDurationOption {
  final int id;
  final String name;
  final int hours;
  final double price;

  const IphoneDurationOption({
    required this.id,
    required this.name,
    required this.hours,
    required this.price,
  });

  String get displayName {
    if (name.isNotEmpty && name != 'null') return name;
    if (hours % 24 == 0) {
      final days = hours ~/ 24;
      return '$days Hari ($hours Jam)';
    }
    return '$hours Jam';
  }

  factory IphoneDurationOption.fromJson(Map<String, dynamic> json) {
    final rawHours = json['hours'] is int
        ? json['hours'] as int
        : (int.tryParse(json['hours']?.toString() ?? '') ?? 24);
    final rawPrice = double.tryParse(json['price']?.toString() ?? '100000') ?? 100000.0;
    final rawName = json['name'] as String? ?? '';
    final int id = json['id'] is int
        ? json['id'] as int
        : (int.tryParse(json['id']?.toString() ?? '') ?? 1);

    return IphoneDurationOption(
      id: id,
      name: rawName,
      hours: rawHours,
      price: rawPrice,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hours': hours,
    'price': price,
  };
}

class IphoneModel {
  final int id;
  final String name;
  final String storage;
  final String color;
  final String serialNumber;
  final String assetCode;
  final String status;
  final int batteryHealth;
  final List<IphoneDurationOption> durations;
  final int? affiliateId;
  final String? photoUrl;

  const IphoneModel({
    required this.id,
    required this.name,
    required this.storage,
    required this.color,
    required this.serialNumber,
    required this.assetCode,
    required this.status,
    this.batteryHealth = 100,
    this.durations = const [],
    this.affiliateId,
    this.photoUrl,
  });

  String get fullName => '$name $storage';
  String get fullDisplayName => '$name $storage - $color';
  String get modelName => fullName;
  List<IphoneDurationOption> get availableDurations {
    if (durations.isNotEmpty) return durations;
    return const [
      IphoneDurationOption(
        id: 1,
        name: '24 Jam',
        hours: 24,
        price: 100000.0,
      ),
      IphoneDurationOption(
        id: 2,
        name: '12 Jam',
        hours: 12,
        price: 65000.0,
      ),
    ];
  }
  double get dailyRate {
    if (durations.isNotEmpty) {
      final d24 = durations.where((d) => d.hours == 24).firstOrNull;
      if (d24 != null) return d24.price;
      return durations.first.price;
    }
    return 100000.0;
  }
  double get depositRequired => 200000.0;
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'ready':
      case 'tersedia':
        return 'Tersedia';
      case 'rented':
      case 'disewa':
        return 'Sedang Sewa';
      case 'maintenance':
      case 'perbaikan':
        return 'Perbaikan';
      case 'transferred':
      case 'mutasi':
        return 'Dalam Mutasi';
      default:
        return status;
    }
  }

  String? get resolvedPhotoUrl {
    if (photoUrl == null || photoUrl!.trim().isEmpty) return null;
    final trimmed = photoUrl!.trim();
    final apiBase = ApiService().baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      if (cleanPath.startsWith('storage/')) {
        return '$apiBase/$cleanPath';
      }
      return '$apiBase/storage/$cleanPath';
    }

    try {
      final uri = Uri.parse(trimmed);
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        final baseUri = Uri.parse(apiBase);
        final rewritten = uri.replace(
          scheme: baseUri.scheme,
          host: baseUri.host,
          port: baseUri.hasPort ? baseUri.port : null,
        );
        return rewritten.toString();
      }
    } catch (_) {}

    return trimmed;
  }

  IphoneModel copyWith({
    int? id,
    String? name,
    String? storage,
    String? color,
    String? serialNumber,
    String? assetCode,
    String? status,
    int? batteryHealth,
    List<IphoneDurationOption>? durations,
    int? affiliateId,
    String? photoUrl,
  }) {
    return IphoneModel(
      id: id ?? this.id,
      name: name ?? this.name,
      storage: storage ?? this.storage,
      color: color ?? this.color,
      serialNumber: serialNumber ?? this.serialNumber,
      assetCode: assetCode ?? this.assetCode,
      status: status ?? this.status,
      batteryHealth: batteryHealth ?? this.batteryHealth,
      durations: durations ?? this.durations,
      affiliateId: affiliateId ?? this.affiliateId,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  factory IphoneModel.fromJson(Map<String, dynamic> json) {
    List<IphoneDurationOption> parsedDurations = [];
    if (json['durations'] is List) {
      parsedDurations = (json['durations'] as List)
          .map((d) => IphoneDurationOption.fromJson(d as Map<String, dynamic>))
          .toList();
    }

    final rawAffId = json['affiliate_id'] is int
        ? json['affiliate_id'] as int
        : (json['affiliate'] is Map ? (json['affiliate'] as Map)['id'] as int? : int.tryParse(json['affiliate_id']?.toString() ?? ''));

    final rawPhoto = json['photo_url']?.toString() ??
        (json['gallery'] is Map
            ? ((json['gallery'] as Map)['image'] ?? (json['gallery'] as Map)['photo'])?.toString()
            : null) ??
        json['image']?.toString();

    return IphoneModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'iPhone',
      storage: json['storage']?.toString() ?? '128GB',
      color: json['color']?.toString() ?? 'Default',
      serialNumber: json['serial_number']?.toString() ?? '-',
      assetCode: json['asset_code']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'ready',
      batteryHealth: json['battery_health'] is int
          ? json['battery_health'] as int
          : int.tryParse(json['battery_health']?.toString() ?? '100') ?? 100,
      durations: parsedDurations,
      affiliateId: rawAffId,
      photoUrl: rawPhoto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'storage': storage,
      'color': color,
      'serial_number': serialNumber,
      'asset_code': assetCode,
      'status': status,
      'battery_health': batteryHealth,
      'durations': durations.map((d) => d.toJson()).toList(),
      'affiliate_id': affiliateId,
      'photo_url': photoUrl,
    };
  }
}
