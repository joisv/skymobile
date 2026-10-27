import 'cash_drawer_shift_model.dart';
import 'receipt_format_settings.dart';
import '../utils/formatters.dart';

enum ReceiptType {
  pickup,
  returnUnit,
  paymentSettlement,
  depositRefund,
  extend;

  String get label {
    switch (this) {
      case ReceiptType.pickup:
        return 'PICKUP IPHONE';
      case ReceiptType.returnUnit:
        return 'PENGEMBALIAN UNIT';
      case ReceiptType.paymentSettlement:
        return 'PELUNASAN SEWA';
      case ReceiptType.depositRefund:
        return 'REFUND DEPOSIT';
      case ReceiptType.extend:
        return 'TAMBAH JAM (EXTEND)';
    }
  }
}

class ReceiptAddonItem {
  final String name;
  final String? assetCode;
  final String? serialNumber;
  final double price;

  const ReceiptAddonItem({
    required this.name,
    this.assetCode,
    this.serialNumber,
    this.price = 0.0,
  });

  factory ReceiptAddonItem.fromJson(Map<String, dynamic> json) {
    return ReceiptAddonItem(
      name: json['name']?.toString() ?? 'Item Add-on',
      assetCode: json['asset_code']?.toString(),
      serialNumber: json['serial_number']?.toString(),
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (assetCode != null) 'asset_code': assetCode,
    if (serialNumber != null) 'serial_number': serialNumber,
    'price': price,
  };
}

class ReceiptModel {
  final String receiptNumber;
  final DateTime date;
  final String adminName;
  final String branchName;
  final ReceiptType type;
  final String? customTypeLabel;
  final String bookingCode;
  final String customerName;
  final String customerPhone;
  final String unitName;
  final String? serialNumber;
  final String? assetCode;
  final List<ReceiptAddonItem> addonItems;
  final String rentalDuration;
  final String? rentalDates;
  final double rentFee;
  final double primaryRentFee;
  final double addonRentFee;
  final double depositFee;
  final double finesFee;
  final double discountFee;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String paymentMethod;
  final String paymentStatus;
  final double cashGiven;
  final double cashChange;
  final String? depositStatus;
  final double refundAmount;
  final String? notes;
  final String? termsAndConditions;

  const ReceiptModel({
    required this.receiptNumber,
    required this.date,
    required this.adminName,
    this.branchName = 'SKYRENTAL YOGYAKARTA',
    required this.type,
    this.customTypeLabel,
    required this.bookingCode,
    required this.customerName,
    required this.customerPhone,
    required this.unitName,
    this.serialNumber,
    this.assetCode,
    this.addonItems = const [],
    required this.rentalDuration,
    this.rentalDates,
    required this.rentFee,
    double? primaryRentFee,
    double? addonRentFee,
    required this.depositFee,
    this.finesFee = 0,
    this.discountFee = 0,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.cashGiven = 0,
    this.cashChange = 0,
    this.depositStatus,
    this.refundAmount = 0,
    this.notes,
    this.termsAndConditions,
  })  : primaryRentFee = primaryRentFee ?? (addonRentFee != null ? (rentFee - addonRentFee) : rentFee),
        addonRentFee = addonRentFee ?? 0.0;

  double get effectiveAddonRentFee {
    if (addonRentFee > 0) return addonRentFee;
    if (addonItems.isNotEmpty) {
      return addonItems.fold<double>(0.0, (acc, item) => acc + item.price);
    }
    return 0.0;
  }

  double get effectivePrimaryRentFee {
    if (primaryRentFee > 0 && primaryRentFee < rentFee) return primaryRentFee;
    final addonFee = effectiveAddonRentFee;
    if (addonFee > 0 && rentFee >= addonFee) {
      return rentFee - addonFee;
    }
    return rentFee;
  }

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    ReceiptType parsedType;
    final typeStr = (json['type']?.toString() ?? '').toLowerCase();
    if (typeStr.contains('extend') || typeStr.contains('tambah')) {
      parsedType = ReceiptType.extend;
    } else if (typeStr.contains('return') || typeStr.contains('kembali')) {
      parsedType = ReceiptType.returnUnit;
    } else if (typeStr.contains('payment') || typeStr.contains('lunas') || typeStr.contains('sewa')) {
      parsedType = ReceiptType.paymentSettlement;
    } else if (typeStr.contains('deposit') || typeStr.contains('refund')) {
      parsedType = ReceiptType.depositRefund;
    } else {
      parsedType = ReceiptType.pickup;
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['date']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final parsedAddons = json['addon_items'] is List
        ? (json['addon_items'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => ReceiptAddonItem.fromJson(m))
            .toList()
        : <ReceiptAddonItem>[];

    final parsedRentFee = (json['rent_fee'] as num?)?.toDouble() ?? 0.0;
    final parsedPrimaryRentFee = (json['primary_rent_fee'] as num?)?.toDouble();
    final parsedAddonRentFee = (json['addon_rent_fee'] as num?)?.toDouble();

    return ReceiptModel(
      receiptNumber: json['receipt_number']?.toString() ?? '',
      date: parsedDate,
      adminName: json['admin_name']?.toString() ?? 'Kasir SKYRental',
      branchName: json['branch_name']?.toString() ?? 'SKYRENTAL YOGYAKARTA',
      type: parsedType,
      customTypeLabel: json['type_label']?.toString() ?? json['custom_type_label']?.toString(),
      bookingCode: json['booking_code']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Pelanggan',
      customerPhone: json['customer_phone']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? 'Unit iPhone',
      serialNumber: json['serial_number']?.toString(),
      assetCode: json['asset_code']?.toString(),
      addonItems: parsedAddons,
      rentalDuration: json['rental_duration']?.toString() ?? '1 Hari',
      rentalDates: json['rental_dates']?.toString(),
      rentFee: parsedRentFee,
      primaryRentFee: parsedPrimaryRentFee,
      addonRentFee: parsedAddonRentFee,
      depositFee: (json['deposit_fee'] as num?)?.toDouble() ?? 0.0,
      finesFee: (json['fines_fee'] as num?)?.toDouble() ?? (json['fines'] as num?)?.toDouble() ?? (json['late_fee'] as num?)?.toDouble() ?? 0.0,
      discountFee: (json['discount_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'Tunai',
      paymentStatus: json['payment_status']?.toString() ?? 'Lunas',
      cashGiven: (json['cash_given'] as num?)?.toDouble() ?? (json['cash_received'] as num?)?.toDouble() ?? (json['pay'] as num?)?.toDouble() ?? 0.0,
      cashChange: (json['cash_change'] as num?)?.toDouble() ?? (json['change'] as num?)?.toDouble() ?? 0.0,
      depositStatus: json['deposit_status']?.toString(),
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      termsAndConditions: json['terms_and_conditions']?.toString(),
    );
  }

  ReceiptModel copyWith({
    String? receiptNumber,
    DateTime? date,
    String? adminName,
    String? branchName,
    ReceiptType? type,
    String? customTypeLabel,
    String? bookingCode,
    String? customerName,
    String? customerPhone,
    String? unitName,
    String? serialNumber,
    String? assetCode,
    List<ReceiptAddonItem>? addonItems,
    String? rentalDuration,
    String? rentalDates,
    double? rentFee,
    double? primaryRentFee,
    double? addonRentFee,
    double? depositFee,
    double? finesFee,
    double? discountFee,
    double? totalAmount,
    double? paidAmount,
    double? remainingAmount,
    String? paymentMethod,
    String? paymentStatus,
    double? cashGiven,
    double? cashChange,
    String? depositStatus,
    double? refundAmount,
    String? notes,
    String? termsAndConditions,
  }) {
    return ReceiptModel(
      receiptNumber: receiptNumber ?? this.receiptNumber,
      date: date ?? this.date,
      adminName: adminName ?? this.adminName,
      branchName: branchName ?? this.branchName,
      type: type ?? this.type,
      customTypeLabel: customTypeLabel ?? this.customTypeLabel,
      bookingCode: bookingCode ?? this.bookingCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      unitName: unitName ?? this.unitName,
      serialNumber: serialNumber ?? this.serialNumber,
      assetCode: assetCode ?? this.assetCode,
      addonItems: addonItems ?? this.addonItems,
      rentalDuration: rentalDuration ?? this.rentalDuration,
      rentalDates: rentalDates ?? this.rentalDates,
      rentFee: rentFee ?? this.rentFee,
      primaryRentFee: primaryRentFee ?? this.primaryRentFee,
      addonRentFee: addonRentFee ?? this.addonRentFee,
      depositFee: depositFee ?? this.depositFee,
      finesFee: finesFee ?? this.finesFee,
      discountFee: discountFee ?? this.discountFee,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      cashGiven: cashGiven ?? this.cashGiven,
      cashChange: cashChange ?? this.cashChange,
      depositStatus: depositStatus ?? this.depositStatus,
      refundAmount: refundAmount ?? this.refundAmount,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receipt_number': receiptNumber,
      'date': date.toIso8601String(),
      'admin_name': adminName,
      'branch_name': branchName,
      'type': type.name,
      'type_label': customTypeLabel ?? type.label,
      'custom_type_label': customTypeLabel,
      'booking_code': bookingCode,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'unit_name': unitName,
      'serial_number': serialNumber,
      'asset_code': assetCode,
      'addon_items': addonItems.map((a) => a.toJson()).toList(),
      'rental_duration': rentalDuration,
      'rental_dates': rentalDates,
      'rent_fee': rentFee,
      'primary_rent_fee': primaryRentFee,
      'addon_rent_fee': addonRentFee,
      'deposit_fee': depositFee,
      'fines_fee': finesFee,
      'discount_fee': discountFee,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'cash_given': cashGiven,
      'cash_change': cashChange,
      'deposit_status': depositStatus,
      'refund_amount': refundAmount,
      'notes': notes,
      'terms_and_conditions': termsAndConditions,
    };
  }

  static String _center(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final leftPadding = (width - text.length) ~/ 2;
    final rightPadding = width - text.length - leftPadding;
    return ' ' * leftPadding + text + ' ' * rightPadding;
  }

  static String _twoColumn(String left, String right, int width) {
    if (right.length >= width) {
      right = right.substring(0, width - 1);
    }
    if (left.length + right.length + 1 > width) {
      final maxLeft = width - right.length - 1;
      left = left.substring(0, maxLeft.clamp(0, left.length));
    }
    final spaceCount = width - left.length - right.length;
    final spaces = spaceCount > 0 ? ' ' * spaceCount : ' ';
    return '$left$spaces$right';
  }

  /// Memformat durasi sewa menggunakan nilai durasi dan unit yang sesuai (Jam, Hari, Minggu, Bulan).
  static String formatRentalDurationText(String rawDuration) {
    final trimmed = rawDuration.trim();
    if (trimmed.isEmpty) return '1 Hari';
    final lower = trimmed.toLowerCase();
    if (lower.contains('jam') ||
        lower.contains('hari') ||
        lower.contains('minggu') ||
        lower.contains('bulan')) {
      return trimmed;
    }
    final numVal = int.tryParse(trimmed);
    if (numVal != null) {
      if (numVal % 24 == 0 && numVal >= 24) {
        final days = numVal ~/ 24;
        if (days % 30 == 0) return '${days ~/ 30} Bulan';
        if (days % 7 == 0) return '${days ~/ 7} Minggu';
        return '$days Hari';
      }
      return '$numVal Hari';
    }
    return trimmed;
  }

  /// Memformat baris key-value dengan pembungkusan (wrapping) jika nilainya panjang
  /// sehingga teks tidak terpotong pada printer thermal 32 karakter (misal nama pelanggan / nomor HP panjang).
  static List<String> _formatKeyValueMultiLine(String label, String value, int width) {
    final result = <String>[];
    final cleanVal = value.trim();
    if (cleanVal.isEmpty) {
      result.add(_twoColumn(label, '-', width));
      return result;
    }

    final maxRightWidth = width - label.length - 1;
    if (cleanVal.length <= maxRightWidth) {
      result.add(_twoColumn(label, cleanVal, width));
      return result;
    }

    final words = cleanVal.split(' ');
    String currentRight = '';
    bool isFirstLine = true;

    for (final word in words) {
      final lineCap = isFirstLine ? maxRightWidth : (width - label.length);
      if (currentRight.isEmpty) {
        if (word.length <= lineCap) {
          currentRight = word;
        } else {
          var rem = word;
          while (rem.isNotEmpty) {
            final cap = isFirstLine ? maxRightWidth : (width - label.length);
            final chunk = rem.length > cap ? rem.substring(0, cap) : rem;
            if (isFirstLine) {
              result.add(_twoColumn(label, chunk, width));
              isFirstLine = false;
            } else {
              result.add((' ' * label.length) + chunk);
            }
            rem = rem.length > cap ? rem.substring(cap) : '';
          }
        }
      } else if (currentRight.length + 1 + word.length <= lineCap) {
        currentRight += ' $word';
      } else {
        if (isFirstLine) {
          result.add(_twoColumn(label, currentRight, width));
          isFirstLine = false;
        } else {
          result.add((' ' * label.length) + currentRight);
        }
        currentRight = word;
      }
    }

    if (currentRight.isNotEmpty) {
      if (isFirstLine) {
        result.add(_twoColumn(label, currentRight, width));
      } else {
        result.add((' ' * label.length) + currentRight);
      }
    }

    return result;
  }

  static String _formatRupiah(double amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return 'Rp $formatted';
  }

  /// Menghasilkan format teks thermal ESC/POS 58mm (tepat 32 karakter per baris)
  /// Sesuai standar dokumen PRD Bagian 9 untuk printer VSC MP-58C.
  /// [formatSettings] memungkinkan kustomisasi header, footer, visibilitas field, gaya font, dan mode kerapatan.
  String toEscPos58mm({ReceiptFormatSettings? formatSettings}) {
    final fmt = formatSettings ?? const ReceiptFormatSettings();
    const int width = 32;
    final divider = (fmt.separatorChar.isNotEmpty ? fmt.separatorChar : '=') * width;
    final subDivider = (fmt.subSeparatorChar.isNotEmpty ? fmt.subSeparatorChar : '-') * width;
    final isCompact = fmt.densityMode == 'compact';

    final lines = <String>[];

    // Helper store name header with typography tag
    final storeNameTag =
        '[STORE_NAME:${fmt.businessNameFontSize}:${fmt.businessNameFontWeight}:${fmt.businessNameAlignment}:${fmt.businessName}]';

    // Format khusus Struk Pengembalian Unit (Return Unit)
    if (type == ReceiptType.returnUnit) {
      if (fmt.showHeader) {
        lines.add(divider);
        lines.add(storeNameTag);
        lines.add(_center('STRUK PENGEMBALIAN UNIT', width));
        if (fmt.showBranch) {
          lines.add(_center(fmt.branchName, width));
        }
        lines.add(divider);
      }

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      if (fmt.showDateTime) lines.add(_twoColumn('Tgl       :', dateStr, width));
      if (fmt.showReceiptNumber) lines.add(_twoColumn('No. Struk :', receiptNumber, width));
      if (fmt.showAdminName) lines.add(_twoColumn('Admin     :', adminName, width));
      if (fmt.showBookingCodeText) lines.add(_twoColumn('Kode Book :', bookingCode, width));
      if (!fmt.compactSpacing) lines.add(subDivider);

      if (fmt.showCustomerName) lines.add(_twoColumn('Pelanggan :', customerName, width));
      if (fmt.showCustomerPhone) lines.add(_twoColumn('Kontak    :', customerPhone, width));
      if (fmt.showUnitName) lines.add(_twoColumn('Unit      :', unitName, width));
      if (fmt.showAssetCode && assetCode != null && assetCode!.isNotEmpty) {
        lines.add(_twoColumn('No. Aset  :', assetCode!, width));
      }
      if (fmt.showSerialNumber && serialNumber != null && serialNumber!.isNotEmpty) {
        lines.add(_twoColumn('Serial No :', serialNumber!, width));
      }
      if (fmt.showRentalDuration && rentalDuration.isNotEmpty) {
        lines.add(_twoColumn('Durasi    :', formatRentalDurationText(rentalDuration), width));
      }
      if (fmt.showRentalDates && rentalDates != null && rentalDates!.isNotEmpty) {
        lines.add(_twoColumn('Periode   :', rentalDates!, width));
      }
      lines.add(_twoColumn('Status    :', 'KEMBALI (TERSEDIA)', width));
      lines.add(_twoColumn('Jaminan   :', 'DISERAHKAN BALIK', width));
      if (addonItems.isNotEmpty) {
        lines.add(subDivider);
        lines.add('ITEM TAMBAHAN / ADD-ON:');
        for (int i = 0; i < addonItems.length; i++) {
          final item = addonItems[i];
          final numPrefix = '${i + 1}. ';
          final maxTitleLen = width - numPrefix.length;
          final itemTitle = item.name.length > maxTitleLen ? item.name.substring(0, maxTitleLen) : item.name;
          lines.add('$numPrefix$itemTitle');
        }
      }
      if (!fmt.compactSpacing) lines.add(subDivider);

      if (fmt.showDeposit && depositFee > 0) {
        lines.add(_twoColumn('Deposit   :', _formatRupiah(depositFee), width));
      }

      final isCash = paymentMethod.toLowerCase().contains('tunai') ||
          paymentMethod.toLowerCase().contains('cash');

      if (finesFee > 0) {
        if (depositStatus != null &&
            depositStatus!.toLowerCase().contains('potong')) {
          lines.add(_twoColumn('Pot. Denda:', '-${_formatRupiah(finesFee)}', width));
        } else {
          lines.add(_twoColumn('Biaya Keterlambatan:', _formatRupiah(finesFee), width));
        }
      }

      if (refundAmount > 0 || (fmt.showDeposit && depositFee > 0 && finesFee == 0)) {
        lines.add(_twoColumn('Refund Dep. :', _formatRupiah(refundAmount), width));
      }

      if (!isCash && paidAmount > 0 && finesFee > 0) {
        lines.add(_twoColumn('Terbayar  :', _formatRupiah(paidAmount), width));
      }

      if (fmt.showPaymentMethod) lines.add(_twoColumn('Metode    :', paymentMethod, width));
      if (fmt.showPaymentStatus) lines.add(_twoColumn('Status    :', 'LUNAS / SELESAI', width));

      if (fmt.showCashDetails && isCash && cashGiven > 0) {
        lines.add(_twoColumn('Uang Diterima:', _formatRupiah(cashGiven), width));
        lines.add(_twoColumn('Kembalian   :', _formatRupiah(cashChange), width));
      }
      lines.add(divider);

      if (fmt.showNotes && notes != null && notes!.isNotEmpty) {
        lines.add('Catatan:');
        var noteText = notes!;
        while (noteText.length > width) {
          lines.add(noteText.substring(0, width));
          noteText = noteText.substring(width);
        }
        if (noteText.isNotEmpty) {
          lines.add(noteText);
        }
        if (!fmt.compactSpacing) lines.add(subDivider);
      }

      if (fmt.showBarcode && bookingCode.isNotEmpty) {
        if (!isCompact) lines.add(_center('KODE BOOKING PENGEMBALIAN', width));
        lines.add('[BARCODE:$bookingCode]');
        if (!fmt.compactSpacing) lines.add(subDivider);
      }

      if (fmt.showFooter) {
        if (fmt.showTerms) {
          lines.add(_center('Unit iPhone & Dokumen Jaminan', width));
          lines.add(_center('telah sah diserahterimakan.', width));
          lines.add(_center(fmt.footerLine1, width));
        }
        if (fmt.showContactInfo) lines.add(_center(fmt.contactInfo, width));
        lines.add(divider);
      }

      return lines.join('\n');
    }

    // Format khusus Struk Tambah Jam / Perpanjangan Sewa (Extend)
    if (type == ReceiptType.extend) {
      if (fmt.showHeader) {
        lines.add(divider);
        lines.add(storeNameTag);
        lines.add(_center('STRUK PERPANJANGAN SEWA', width));
        if (fmt.showBranch) {
          lines.add(_center(fmt.branchName, width));
        }
        lines.add(divider);
      }

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      if (fmt.showDateTime) lines.add(_twoColumn('Tgl       :', dateStr, width));
      if (fmt.showReceiptNumber) lines.add(_twoColumn('No. Struk :', receiptNumber, width));
      if (fmt.showAdminName) lines.add(_twoColumn('Admin     :', adminName, width));
      lines.add(_twoColumn('Tipe Resi :', customTypeLabel ?? 'TAMBAH JAM (EXTEND)', width));
      if (!fmt.compactSpacing) lines.add(subDivider);

      if (fmt.showCustomerName) lines.addAll(_formatKeyValueMultiLine('Pelanggan :', customerName, width));
      if (fmt.showCustomerPhone) lines.addAll(_formatKeyValueMultiLine('Kontak    :', customerPhone, width));
      if (fmt.showBookingCodeText) lines.add(_twoColumn('Kode Book :', bookingCode, width));
      if (fmt.showUnitName) lines.add(_twoColumn('Unit      :', unitName, width));
      if (fmt.showAssetCode && assetCode != null && assetCode!.isNotEmpty) {
        lines.add(_twoColumn('No. Aset  :', assetCode!, width));
      }
      if (fmt.showSerialNumber && serialNumber != null && serialNumber!.isNotEmpty) {
        lines.add(_twoColumn('Serial No :', serialNumber!, width));
      }
      lines.add(_twoColumn('Durasi Ext:', rentalDuration, width));
      if (fmt.showRentalDates && rentalDates != null && rentalDates!.isNotEmpty) {
        lines.add(_twoColumn('Periode   :', rentalDates!, width));
      }
      if (!fmt.compactSpacing) lines.add(subDivider);

      lines.add(_twoColumn('Biaya Ext :', _formatRupiah(totalAmount), width));
      lines.add(_twoColumn('TOTAL     :', _formatRupiah(totalAmount), width));
      lines.add(_twoColumn('Terbayar  :', _formatRupiah(paidAmount), width));
      if (fmt.showPaymentMethod) lines.add(_twoColumn('Metode    :', paymentMethod, width));
      if (fmt.showPaymentStatus) lines.add(_twoColumn('Status    :', 'LUNAS', width));

      if (fmt.showCashDetails &&
          (paymentMethod.toLowerCase().contains('tunai') || paymentMethod.toLowerCase().contains('cash')) &&
          cashGiven > 0) {
        lines.add(_twoColumn('Uang Diterima:', _formatRupiah(cashGiven), width));
        lines.add(_twoColumn('Kembalian   :', _formatRupiah(cashChange), width));
      }
      lines.add(divider);

      if (fmt.showNotes && notes != null && notes!.isNotEmpty) {
        lines.add('Catatan:');
        var noteText = notes!;
        while (noteText.length > width) {
          lines.add(noteText.substring(0, width));
          noteText = noteText.substring(width);
        }
        if (noteText.isNotEmpty) {
          lines.add(noteText);
        }
        if (!fmt.compactSpacing) lines.add(subDivider);
      }

      if (fmt.showBarcode && bookingCode.isNotEmpty) {
        lines.add('[BARCODE:$bookingCode]');
        if (!fmt.compactSpacing) lines.add(subDivider);
      }

      if (fmt.showFooter) {
        lines.add(_center('Terima kasih atas perpanjangan sewa', width));
        lines.add(_center(fmt.footerLine1, width));
        if (fmt.showContactInfo) lines.add(_center(fmt.contactInfo, width));
        lines.add(divider);
      }

      return lines.join('\n');
    }

    // --- Format Struk Transaksi Standar / Compact ---

    // 1. Header Toko
    if (fmt.showHeader) {
      lines.add(divider);
      lines.add(storeNameTag);
      if (fmt.showTagline && !isCompact) {
        lines.add(_center(fmt.businessTagline, width));
      }
      if (fmt.showBranch) {
        lines.add(_center(fmt.branchName, width));
      }
      lines.add(divider);
    }

    // 2. Informasi Transaksi & Pelanggan
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (isCompact) {
      // Mode Ringkas (Echo Mode): Sesuai spesifikasi tata letak
      // 0. Tanggal (mempertahankan format tanggal yang sudah ada)
      if (fmt.showDateTime) lines.add(_twoColumn('Tgl       :', dateStr, width));

      // 1. Nomor Struk / Pengenal Struk
      if (fmt.showReceiptNumber) lines.add(_twoColumn('No. Struk :', receiptNumber, width));

      // 2. Kode Booking (sebelum nama pelanggan)
      if (fmt.showBookingCodeText) lines.add(_twoColumn('Kode Book :', bookingCode, width));

      // 3. Pemisah Visual antara bagian kode booking dan informasi pelanggan
      lines.add(subDivider);

      // 4. Nama Pelanggan
      if (fmt.showCustomerName) {
        lines.addAll(_formatKeyValueMultiLine('Pelanggan :', customerName, width));
      }

      // 5. Nomor Telepon Pelanggan (baris terpisah tepat di bawah nama pelanggan)
      if (fmt.showCustomerPhone) {
        lines.addAll(_formatKeyValueMultiLine('Kontak    :', customerPhone, width));
      }

      // 6. Durasi Sewa (menggunakan durasi aktual dan unit yang sesuai: Jam, Hari, Minggu, Bulan)
      if (fmt.showRentalDuration) {
        lines.add(_twoColumn('Durasi    :', formatRentalDurationText(rentalDuration), width));
      }

      // Detail Unit Tambahan
      if (fmt.showUnitName) {
        lines.add(_twoColumn('Unit      :', unitName, width));
      }
      if (fmt.showSerialNumber && serialNumber != null && serialNumber!.isNotEmpty) {
        lines.add(_twoColumn('Serial No :', serialNumber!, width));
      }
      if (fmt.showAssetCode && assetCode != null && assetCode!.isNotEmpty) {
        lines.add(_twoColumn('No. Aset  :', assetCode!, width));
      }
      if (fmt.showRentalDates && rentalDates != null && rentalDates!.isNotEmpty) {
        lines.add(_twoColumn('Periode   :', rentalDates!, width));
      }
      lines.add(subDivider);
    } else {
      // Mode Standar / Lengkap
      if (fmt.showDateTime) lines.add(_twoColumn('Tgl       :', dateStr, width));
      if (fmt.showReceiptNumber) lines.add(_twoColumn('No. Struk :', receiptNumber, width));
      if (fmt.showAdminName) lines.add(_twoColumn('Admin     :', adminName, width));
      if (fmt.showTransactionType) {
        lines.add(_twoColumn('Tipe Resi :', customTypeLabel ?? type.label, width));
      }
      if (!fmt.compactSpacing) lines.add(subDivider);

      if (fmt.showCustomerName) lines.addAll(_formatKeyValueMultiLine('Pelanggan :', customerName, width));
      if (fmt.showCustomerPhone) lines.addAll(_formatKeyValueMultiLine('Kontak    :', customerPhone, width));
      if (fmt.showBookingCodeText) lines.add(_twoColumn('Kode Book :', bookingCode, width));
      if (fmt.showUnitName) lines.add(_twoColumn('Unit      :', unitName, width));
      if (fmt.showAssetCode && assetCode != null && assetCode!.isNotEmpty) {
        lines.add(_twoColumn('No. Aset  :', assetCode!, width));
      }
      if (fmt.showSerialNumber && serialNumber != null && serialNumber!.isNotEmpty) {
        lines.add(_twoColumn('Serial No :', serialNumber!, width));
      }
      if (fmt.showRentalDuration) lines.add(_twoColumn('Durasi    :', formatRentalDurationText(rentalDuration), width));
      if (fmt.showRentalDates && rentalDates != null && rentalDates!.isNotEmpty) {
        lines.add(_twoColumn('Periode   :', rentalDates!, width));
      }
      if (!fmt.compactSpacing) lines.add(subDivider);
    }

    // 3. Item Tambahan / Add-on (jika ada)
    if (addonItems.isNotEmpty) {
      lines.add('ITEM TAMBAHAN / ADD-ON:');
      for (int i = 0; i < addonItems.length; i++) {
        final item = addonItems[i];
        final numPrefix = '${i + 1}. ';
        final maxTitleLen = width - numPrefix.length;
        final itemTitle = item.name.length > maxTitleLen ? item.name.substring(0, maxTitleLen) : item.name;
        lines.add('$numPrefix$itemTitle');
        final codeStr = (item.assetCode != null && item.assetCode!.isNotEmpty && item.assetCode != '-')
            ? item.assetCode!
            : (item.serialNumber != null && item.serialNumber!.isNotEmpty && item.serialNumber != '-')
                ? item.serialNumber!
                : '';
        final priceStr = _formatRupiah(item.price);
        if (codeStr.isNotEmpty) {
          lines.add(_twoColumn('   [$codeStr]', priceStr, width));
        } else {
          lines.add(_twoColumn('   Biaya:', priceStr, width));
        }
      }
      lines.add(subDivider);
    }

    // 4. Rincian Biaya
    if (addonItems.isNotEmpty) {
      lines.add(_twoColumn('Sewa iPhone :', _formatRupiah(effectivePrimaryRentFee), width));
      lines.add(_twoColumn('Sewa Add-on :', _formatRupiah(effectiveAddonRentFee), width));
    } else if (fmt.showRentFee) {
      lines.add(_twoColumn('Biaya Sewa  :', _formatRupiah(rentFee), width));
    }
    if (fmt.showDeposit && depositFee > 0) {
      lines.add(_twoColumn('Deposit     :', _formatRupiah(depositFee), width));
    }
    if (finesFee > 0) {
      lines.add(_twoColumn('Denda/Kerus.:', _formatRupiah(finesFee), width));
    }
    if (fmt.showDiscount && discountFee > 0) {
      lines.add(_twoColumn('Diskon      :', '-${_formatRupiah(discountFee)}', width));
    }
    if (!fmt.compactSpacing) lines.add(subDivider);

    // 5. Ringkasan Pembayaran
    lines.add(_twoColumn('TOTAL BIAYA :', _formatRupiah(totalAmount), width));
    if (isCompact) {
      lines.add(_twoColumn('Terbayar    :', '${_formatRupiah(paidAmount)} (${paymentStatus.toUpperCase()})', width));
    } else {
      lines.add(_twoColumn('Terbayar    :', _formatRupiah(paidAmount), width));
    }
    if (remainingAmount > 0) {
      lines.add(_twoColumn('Sisa Tagihan:', _formatRupiah(remainingAmount), width));
    }
    if (refundAmount > 0) {
      lines.add(_twoColumn('Refund Dep. :', _formatRupiah(refundAmount), width));
    }
    if (fmt.showPaymentMethod) lines.add(_twoColumn('Metode      :', paymentMethod, width));
    if (fmt.showPaymentStatus && !isCompact) {
      lines.add(_twoColumn('Status Bayar:', paymentStatus.toUpperCase(), width));
    }

    if (fmt.showCashDetails && (paymentMethod.toLowerCase().contains('tunai') || paymentMethod.toLowerCase().contains('cash')) && cashGiven > 0) {
      lines.add(_twoColumn('Uang Diterima:', _formatRupiah(cashGiven), width));
      lines.add(_twoColumn('Kembalian   :', _formatRupiah(cashChange), width));
    }
    lines.add(divider);

    // 6. Catatan Transaksi
    if (fmt.showNotes && notes != null && notes!.isNotEmpty) {
      lines.add('Catatan:');
      var noteText = notes!;
      while (noteText.length > width) {
        lines.add(noteText.substring(0, width));
        noteText = noteText.substring(width);
      }
      if (noteText.isNotEmpty) {
        lines.add(noteText);
      }
      if (!fmt.compactSpacing) lines.add(subDivider);
    }

    // 7. Barcode / QR Code Pengembalian
    if (fmt.showBarcode && bookingCode.isNotEmpty) {
      if (!isCompact) lines.add(_center('PINDAI SAAT PENGEMBALIAN', width));
      lines.add('[BARCODE:$bookingCode]');
      if (!fmt.compactSpacing) lines.add(subDivider);
    }

    // 8. Footer & Kontak
    if (fmt.showFooter) {
      if (fmt.showTerms && !isCompact) {
        lines.add(_center(fmt.footerLine1, width));
        lines.add(_center(fmt.footerLine2, width));
        lines.add(_center(fmt.footerLine3, width));
      }
      if (fmt.showContactInfo) lines.add(_center(fmt.contactInfo, width));
      lines.add(divider);
    }

    return lines.join('\n');
  }

  /// Menghitung estimasi panjang fisik struk kertas thermal (dalam cm) untuk printer 58mm.
  /// Membantu kasir melihat perbandingan penghematan kertas secara langsung.
  static double estimatePaperLengthCm(String receiptText, ReceiptFormatSettings fmt) {
    final lines = receiptText.split('\n').where((l) => !l.contains('[BARCODE:')).length;
    double cm = lines * 0.38;

    if (fmt.showBarcode) {
      if (fmt.barcodeType == 'qrcode') {
        cm += fmt.barcodeSize == 'small' ? 2.0 : 2.8;
      } else if (fmt.barcodeType == 'code128') {
        cm += fmt.barcodeSize == 'small' ? 2.2 : (fmt.barcodeSize == 'large' ? 3.5 : 2.8);
      } else {
        cm += 5.0;
      }
    }

    cm += fmt.feedLines * 0.38;
    return (cm * 10).round() / 10.0;
  }

  /// Menghasilkan format struk thermal 58mm (32 kolom monospace) untuk Tutup Kasir / Closing Shift
  static String generateShiftClosingEscPos58mm({
    required CashDrawerShiftModel shift,
    List<CashBookEntryModel> entries = const [],
    String? businessName,
    String? branchName,
  }) {
    const int width = 32;
    final divider = '=' * width;
    final subDivider = '-' * width;

    final lines = <String>[];
    lines.add(divider);
    lines.add(_center(businessName ?? 'SKYRENTAL INDONESIA', width));
    lines.add(_center('LAPORAN PENUTUPAN KASIR', width));
    lines.add(_center(branchName ?? shift.branchName.toUpperCase(), width));
    lines.add(divider);

    lines.add(_twoColumn('No. Shift   :', shift.shiftNumber, width));
    lines.add(_twoColumn('Kasir Buka  :', shift.openedByName, width));
    if (shift.closedByName != null && shift.closedByName!.isNotEmpty) {
      lines.add(_twoColumn('Kasir Tutup :', shift.closedByName!, width));
    }

    final openWib = Formatters.toWib(shift.openedAt);
    final openStr = '${openWib.year}-${openWib.month.toString().padLeft(2, '0')}-${openWib.day.toString().padLeft(2, '0')} ${openWib.hour.toString().padLeft(2, '0')}:${openWib.minute.toString().padLeft(2, '0')}';
    lines.add(_twoColumn('Waktu Buka  :', openStr, width));

    if (shift.closedAt != null) {
      final closeWib = Formatters.toWib(shift.closedAt!);
      final closeStr = '${closeWib.year}-${closeWib.month.toString().padLeft(2, '0')}-${closeWib.day.toString().padLeft(2, '0')} ${closeWib.hour.toString().padLeft(2, '0')}:${closeWib.minute.toString().padLeft(2, '0')}';
      lines.add(_twoColumn('Waktu Tutup :', closeStr, width));
    }
    lines.add(subDivider);

    lines.add(_center('RINGKASAN KAS FISIK', width));
    lines.add(_twoColumn('Modal Awal (Float) :', _formatRupiah(shift.openingCashFloat), width));
    lines.add(_twoColumn('Total Kas Masuk    :', _formatRupiah(shift.currentCashInflow), width));
    if (shift.currentCashRefund > 0) {
      lines.add(_twoColumn('Total Kas Refund   :', '-${_formatRupiah(shift.currentCashRefund)}', width));
    }
    if (shift.currentCashExpenses > 0) {
      lines.add(_twoColumn('Pengeluaran Kasir  :', '-${_formatRupiah(shift.currentCashExpenses)}', width));
    }
    lines.add(subDivider);

    final expected = shift.effectiveExpectedCash;
    final actual = shift.actualCashCounted ?? expected;
    final diff = shift.cashDifference ?? (actual - expected);

    lines.add(_twoColumn('ESTIMASI KAS LACI  :', _formatRupiah(expected), width));
    lines.add(_twoColumn('FISIK DIHITUNG     :', _formatRupiah(actual), width));

    String diffLabel = 'SEIMBANG';
    if (diff > 0.01) {
      diffLabel = '+${_formatRupiah(diff)} (LEBIH)';
    } else if (diff < -0.01) {
      diffLabel = '-${_formatRupiah(diff.abs())} (KURANG)';
    }
    lines.add(_twoColumn('SELISIH KAS        :', diffLabel, width));

    if (shift.differenceReason != null && shift.differenceReason!.trim().isNotEmpty) {
      lines.add(subDivider);
      lines.add('Alasan Selisih:');
      lines.add(shift.differenceReason!.trim());
    }

    if (shift.closingNotes != null && shift.closingNotes!.trim().isNotEmpty) {
      lines.add(subDivider);
      lines.add('Catatan Shift:');
      lines.add(shift.closingNotes!.trim());
    }

    lines.add(subDivider);
    lines.add(_center('TANDA TANGAN & PERSETUJUAN', width));
    lines.add('');
    lines.add('');
    lines.add(_twoColumn('(    Kasir    )', '(  Supervisor )', width));
    lines.add(divider);
    lines.add(_center('TERCETAK SECARA ELEKTRONIK', width));
    lines.add(_center('DOKUMEN RESMI SKYRENTAL', width));
    lines.add('');
    lines.add('');

    return lines.join('\n');
  }
}
