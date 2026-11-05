import 'iphone_model.dart';

enum BookingStatus {
  pending,
  confirmed,
  rented,
  returned,
  cancelled;

  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Menunggu';
      case BookingStatus.confirmed:
        return 'Dikonfirmasi';
      case BookingStatus.rented:
        return 'Sedang Sewa';
      case BookingStatus.returned:
        return 'Selesai';
      case BookingStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  static BookingStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'rented':
      case 'disewa':
      case 'active':
      case 'overdue':
      case 'terlambat':
        return BookingStatus.rented;
      case 'returned':
        return BookingStatus.returned;
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      case 'pending':
      default:
        return BookingStatus.pending;
    }
  }
}

enum PaymentStatus {
  unpaid,
  partial,
  paid;

  String get label {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Belum Bayar';
      case PaymentStatus.partial:
        return 'DP / Sebagian';
      case PaymentStatus.paid:
        return 'Lunas';
    }
  }

  static PaymentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partial':
        return PaymentStatus.partial;
      case 'unpaid':
      default:
        return PaymentStatus.unpaid;
    }
  }
}

class BookingModel {
  final int id;
  final String bookingCode;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String? address;
  final String pickupType;
  final String jaminanType;
  final bool kia;
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final double price;
  final double deposit;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final IphoneModel iphone;
  final List<IphoneModel> addonDevices;
  final double primarySubtotal;
  final double addonSubtotal;
  final String? notes;
  final double discount;
  final double downPayment;
  final String? startTime;
  final String? endTime;
  final bool isLate;
  final double diffHours;
  final int hoursLate;
  final int lateMinutes;
  final double? _explicitLateFee;
  final List<dynamic>? returns;
  final String? userName;
  final String? userId;
  final DateTime? createdAt;

  const BookingModel({
    required this.id,
    required this.bookingCode,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    this.address,
    required this.pickupType,
    required this.jaminanType,
    this.kia = false,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.price,
    required this.deposit,
    required this.status,
    required this.paymentStatus,
    required this.iphone,
    this.addonDevices = const [],
    double? primarySubtotal,
    this.addonSubtotal = 0.0,
    this.notes,
    this.discount = 0.0,
    this.downPayment = 0.0,
    this.startTime,
    this.endTime,
    this.isLate = false,
    this.diffHours = 0.0,
    this.hoursLate = 0,
    this.lateMinutes = 0,
    double? estimatedLateFee,
    this.returns,
    this.userName,
    this.userId,
    this.createdAt,
  })  : primarySubtotal = primarySubtotal ?? (price - addonSubtotal),
        _explicitLateFee = estimatedLateFee;

  bool get hasAddons => addonDevices.isNotEmpty;

  bool get canPickup => status == BookingStatus.confirmed;
  bool get canReturn => status == BookingStatus.rented || status == BookingStatus.confirmed;
  bool get canExtend => status == BookingStatus.rented || status == BookingStatus.confirmed;
  double get totalBill => (price + deposit - discount).clamp(0.0, double.infinity);

  bool get isCurrentlyOverdue {
    if (status == BookingStatus.returned || status == BookingStatus.cancelled) return false;
    return DateTime.now().isAfter(endDate);
  }

  int get currentDiffMinutes {
    if (status == BookingStatus.returned || status == BookingStatus.cancelled) {
      return (diffHours * 60).round();
    }
    final now = DateTime.now();
    if (now.isBefore(endDate)) return 0;
    return now.difference(endDate).inMinutes;
  }

  double get currentDiffHours {
    if (status == BookingStatus.returned || status == BookingStatus.cancelled) {
      return diffHours > 0 ? diffHours : (hoursLate + lateMinutes / 60.0);
    }
    final now = DateTime.now();
    if (now.isBefore(endDate)) return 0.0;
    return now.difference(endDate).inMinutes / 60.0;
  }

  bool get isCurrentlyLate {
    if (status == BookingStatus.returned || status == BookingStatus.cancelled) {
      return isLate || hoursLate > 1 || (hoursLate == 1 && lateMinutes > 30);
    }
    return isLate || currentDiffMinutes > 90;
  }

  int get currentLateHours {
    if (status == BookingStatus.returned || status == BookingStatus.cancelled) {
      return hoursLate;
    }
    final diff = currentDiffHours;
    if (diff <= 0) return 0;
    return diff.floor();
  }

  int get currentLateMinutes {
    if (status == BookingStatus.returned || status == BookingStatus.cancelled) {
      return lateMinutes;
    }
    final diff = currentDiffHours;
    if (diff <= 0) return 0;
    final h = diff.floor();
    return ((diff - h) * 60).round();
  }

  String get lateDurationFormatted {
    final h = currentLateHours;
    final m = currentLateMinutes;
    return '$h jam $m menit';
  }

  double get estimatedLateFee {
    if (status == BookingStatus.returned && _explicitLateFee != null && _explicitLateFee! > 0) {
      return _explicitLateFee!;
    }

    final diff = currentDiffHours;
    var lateHours = diff.floor();

    // Toleransi 1 jam sesuai DetailBooking.php
    const toleranceHours = 1;
    if (lateHours <= toleranceHours) {
      return 0.0;
    }

    lateHours -= toleranceHours;
    var remainingHours = lateHours;
    var penalty = 0.0;

    // Paket durasi iPhone diurutkan descending
    final packages = List<IphoneDurationOption>.from(iphone.availableDurations)
      ..sort((a, b) => b.hours.compareTo(a.hours));

    for (final pkg in packages) {
      if (pkg.hours <= 0) continue;
      if (remainingHours < pkg.hours) continue;

      final count = remainingHours ~/ pkg.hours;
      penalty += count * pkg.price;
      remainingHours -= count * pkg.hours;

      if (remainingHours <= 0) break;
    }

    // Sisa jam di bawah paket terkecil: Rp 5.000 / jam sesuai DetailBooking.php
    if (remainingHours > 0) {
      penalty += remainingHours * 5000.0;
    }

    if (penalty > 0) return penalty;
    return _explicitLateFee ?? 0.0;
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final customerData = json['customer'] is Map<String, dynamic>
        ? json['customer'] as Map<String, dynamic>
        : null;

    final customerName = json['customer_name']?.toString() ??
        customerData?['name']?.toString() ??
        'Pelanggan';
    final customerPhone = json['customer_phone']?.toString() ??
        customerData?['phone']?.toString() ??
        '-';
    final customerEmail = json['customer_email']?.toString() ??
        customerData?['email']?.toString() ??
        '';
    final address = json['address']?.toString() ?? customerData?['address']?.toString();

    final sTime = json['start_time']?.toString();
    final eTime = json['end_time']?.toString();

    DateTime startDate;
    try {
      final sDate = json['start_booking_date']?.toString() ?? '';
      if (sDate.isNotEmpty) {
        if (sTime != null && sTime.isNotEmpty && !sDate.contains('T') && !sDate.contains(':')) {
          startDate = DateTime.parse('${sDate.trim()} ${sTime.trim()}');
        } else {
          startDate = DateTime.parse(sDate.trim());
        }
      } else {
        startDate = DateTime.now();
      }
    } catch (_) {
      startDate = DateTime.now();
    }

    DateTime endDate;
    try {
      final eDate = json['end_booking_date']?.toString() ?? '';
      if (eDate.isNotEmpty) {
        if (eTime != null && eTime.isNotEmpty && !eDate.contains('T') && !eDate.contains(':')) {
          endDate = DateTime.parse('${eDate.trim()} ${eTime.trim()}');
        } else {
          endDate = DateTime.parse(eDate.trim());
        }
      } else {
        endDate = startDate.add(const Duration(days: 1));
      }
    } catch (_) {
      endDate = startDate.add(const Duration(days: 1));
    }

    IphoneModel iphoneModel;
    if (json['iphone'] is Map<String, dynamic>) {
      iphoneModel = IphoneModel.fromJson(json['iphone'] as Map<String, dynamic>);
    } else {
      iphoneModel = const IphoneModel(
        id: 0,
        name: 'iPhone Unit',
        storage: '',
        color: 'Default',
        serialNumber: '-',
        assetCode: '-',
        status: 'ready',
      );
    }

    List<IphoneModel> parsedAddons = [];
    if (json['addon_devices'] is List) {
      for (final item in json['addon_devices'] as List) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          if (itemMap['asset'] is Map) {
            final assetMap = Map<String, dynamic>.from(itemMap['asset'] as Map);
            assetMap['price'] ??= itemMap['price'] ?? itemMap['rate'] ?? itemMap['pivot']?['price'] ?? itemMap['subtotal'];
            assetMap['subtotal'] ??= itemMap['subtotal'] ?? itemMap['pivot']?['subtotal'];
            assetMap['pivot'] ??= itemMap['pivot'];
            parsedAddons.add(IphoneModel.fromJson(assetMap));
          } else {
            parsedAddons.add(IphoneModel.fromJson(itemMap));
          }
        }
      }
    } else if (json['addon_items'] is List) {
      for (final item in json['addon_items'] as List) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          if (itemMap['asset'] is Map) {
            final assetMap = Map<String, dynamic>.from(itemMap['asset'] as Map);
            assetMap['price'] ??= itemMap['price'] ?? itemMap['rate'] ?? itemMap['pivot']?['price'] ?? itemMap['subtotal'];
            assetMap['subtotal'] ??= itemMap['subtotal'] ?? itemMap['pivot']?['subtotal'];
            assetMap['pivot'] ??= itemMap['pivot'];
            parsedAddons.add(IphoneModel.fromJson(assetMap));
          } else {
            parsedAddons.add(IphoneModel.fromJson(itemMap));
          }
        }
      }
    } else if (json['addons'] is List) {
      for (final item in json['addons'] as List) {
        if (item is Map) {
          final itemMap = Map<String, dynamic>.from(item);
          if (itemMap['asset'] is Map) {
            final assetMap = Map<String, dynamic>.from(itemMap['asset'] as Map);
            assetMap['price'] ??= itemMap['price'] ?? itemMap['rate'] ?? itemMap['pivot']?['price'] ?? itemMap['subtotal'];
            assetMap['subtotal'] ??= itemMap['subtotal'] ?? itemMap['pivot']?['subtotal'];
            assetMap['pivot'] ??= itemMap['pivot'];
            parsedAddons.add(IphoneModel.fromJson(assetMap));
          } else {
            parsedAddons.add(IphoneModel.fromJson(itemMap));
          }
        }
      }
    }

    final parsedPrice = double.tryParse(json['price']?.toString() ?? '0') ?? 0.0;
    var parsedAddonSubtotal = double.tryParse(json['addon_subtotal']?.toString() ?? '0') ?? 0.0;
    if (parsedAddonSubtotal <= 0 && parsedAddons.isNotEmpty) {
      parsedAddonSubtotal = parsedAddons.fold<double>(
        0.0,
        (sum, a) => sum + (a.price ?? a.subtotal ?? (a.pivot?['price'] as num?)?.toDouble() ?? (a.dailyRate > 0 ? a.dailyRate : 0.0)),
      );
    }
    final parsedPrimarySubtotal = double.tryParse(json['primary_subtotal']?.toString() ?? '') ??
        (parsedPrice >= parsedAddonSubtotal && parsedAddonSubtotal > 0 ? (parsedPrice - parsedAddonSubtotal) : parsedPrice);

    return BookingModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      bookingCode: json['booking_code']?.toString() ?? '-',
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      address: address,
      pickupType: json['pickup_type']?.toString() ?? 'Outlet',
      jaminanType: json['jaminan_type']?.toString() ?? 'KTP',
      kia: json['kia'] == true ||
          json['kia'] == 1 ||
          json['kia']?.toString() == 'true' ||
          json['kia']?.toString() == '1' ||
          (json['customer'] is Map &&
              ((json['customer'] as Map)['kia'] == true ||
                  (json['customer'] as Map)['kia'] == 1 ||
                  (json['customer'] as Map)['kia']?.toString() == 'true' ||
                  (json['customer'] as Map)['kia']?.toString() == '1')),
      startDate: startDate,
      endDate: endDate,
      durationDays: json['duration'] is int
          ? json['duration'] as int
          : int.tryParse(json['duration']?.toString() ?? '1') ?? 1,
      price: parsedPrice,
      deposit: double.tryParse(json['deposit']?.toString() ?? '0') ?? 0.0,
      status: BookingStatus.fromString(json['status']?.toString() ?? 'pending'),
      paymentStatus: PaymentStatus.fromString(json['payment_status']?.toString() ?? 'unpaid'),
      iphone: iphoneModel,
      addonDevices: parsedAddons,
      primarySubtotal: parsedPrimarySubtotal,
      addonSubtotal: parsedAddonSubtotal,
      notes: json['notes']?.toString(),
      discount: double.tryParse(json['discount']?.toString() ?? json['discount_amount']?.toString() ?? '0') ?? 0.0,
      downPayment: double.tryParse(json['total_paid']?.toString() ?? json['down_payment']?.toString() ?? json['dp']?.toString() ?? '0') ?? 0.0,
      startTime: sTime,
      endTime: eTime,
      isLate: json['is_late'] == true,
      diffHours: (json['diff_hours'] as num?)?.toDouble() ?? 0.0,
      hoursLate: (json['hours_late'] as num?)?.toInt() ?? (json['late_hours'] as num?)?.toInt() ?? 0,
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      estimatedLateFee: (json['estimated_late_fee'] as num?)?.toDouble() ?? (json['late_fee'] as num?)?.toDouble() ?? 0.0,
      returns: json['returns'] is List ? json['returns'] as List<dynamic> : null,
      userName: json['user_name']?.toString() ??
          (json['user'] is Map ? (json['user'] as Map)['name']?.toString() : null) ??
          json['created_by']?.toString(),
      userId: json['user_id']?.toString() ??
          (json['user'] is Map ? (json['user'] as Map)['id']?.toString() : null),
      createdAt: () {
        try {
          final cDate = json['created_at']?.toString() ?? json['created']?.toString();
          return (cDate != null && cDate.isNotEmpty) ? DateTime.tryParse(cDate) : null;
        } catch (_) {
          return null;
        }
      }(),
    );
  }

  BookingModel copyWith({
    int? id,
    String? bookingCode,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? address,
    String? pickupType,
    String? jaminanType,
    bool? kia,
    DateTime? startDate,
    DateTime? endDate,
    int? durationDays,
    double? price,
    double? deposit,
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    IphoneModel? iphone,
    List<IphoneModel>? addonDevices,
    double? primarySubtotal,
    double? addonSubtotal,
    String? notes,
    double? discount,
    double? downPayment,
    String? startTime,
    String? endTime,
    bool? isLate,
    double? diffHours,
    int? hoursLate,
    int? lateMinutes,
    double? estimatedLateFee,
    List<dynamic>? returns,
    String? userName,
    String? userId,
    DateTime? createdAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      bookingCode: bookingCode ?? this.bookingCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      address: address ?? this.address,
      pickupType: pickupType ?? this.pickupType,
      jaminanType: jaminanType ?? this.jaminanType,
      kia: kia ?? this.kia,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationDays: durationDays ?? this.durationDays,
      price: price ?? this.price,
      deposit: deposit ?? this.deposit,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      iphone: iphone ?? this.iphone,
      addonDevices: addonDevices ?? this.addonDevices,
      primarySubtotal: primarySubtotal ?? this.primarySubtotal,
      addonSubtotal: addonSubtotal ?? this.addonSubtotal,
      notes: notes ?? this.notes,
      discount: discount ?? this.discount,
      downPayment: downPayment ?? this.downPayment,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isLate: isLate ?? this.isLate,
      diffHours: diffHours ?? this.diffHours,
      hoursLate: hoursLate ?? this.hoursLate,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      estimatedLateFee: estimatedLateFee ?? _explicitLateFee,
      returns: returns ?? this.returns,
      userName: userName ?? this.userName,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_code': bookingCode,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'address': address,
      'pickup_type': pickupType,
      'jaminan_type': jaminanType,
      'kia': kia,
      'start_booking_date': startDate.toIso8601String(),
      'end_booking_date': endDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'duration': durationDays,
      'price': price,
      'deposit': deposit,
      'status': status.name,
      'payment_status': paymentStatus.name,
      'iphone': iphone.toJson(),
      'addon_devices': addonDevices.map((a) => a.toJson()).toList(),
      'primary_subtotal': primarySubtotal,
      'addon_subtotal': addonSubtotal,
      'notes': notes,
      'discount': discount,
      'down_payment': downPayment,
      'is_late': isLate,
      'diff_hours': diffHours,
      'hours_late': hoursLate,
      'late_minutes': lateMinutes,
      'estimated_late_fee': _explicitLateFee,
      'returns': returns,
      'user_name': userName,
      'user_id': userId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
