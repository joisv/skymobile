import 'receipt_format_settings.dart';

enum ReceiptType {
  pickup,
  returnUnit,
  paymentSettlement,
  depositRefund;

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
    }
  }
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
  final String rentalDuration;
  final String? rentalDates;
  final double rentFee;
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
    required this.rentalDuration,
    this.rentalDates,
    required this.rentFee,
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
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    ReceiptType parsedType;
    final typeStr = (json['type']?.toString() ?? '').toLowerCase();
    if (typeStr.contains('return') || typeStr.contains('kembali')) {
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

    return ReceiptModel(
      receiptNumber: json['receipt_number']?.toString() ?? '',
      date: parsedDate,
      adminName: json['admin_name']?.toString() ?? 'Kasir SKYRental',
      branchName: json['branch_name']?.toString() ?? 'SKYRENTAL YOGYAKARTA',
      type: parsedType,
      customTypeLabel: json['type_label']?.toString(),
      bookingCode: json['booking_code']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Pelanggan',
      customerPhone: json['customer_phone']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? 'Unit iPhone',
      serialNumber: json['serial_number']?.toString(),
      assetCode: json['asset_code']?.toString(),
      rentalDuration: json['rental_duration']?.toString() ?? '1 Hari',
      rentalDates: json['rental_dates']?.toString(),
      rentFee: (json['rent_fee'] as num?)?.toDouble() ?? 0.0,
      depositFee: (json['deposit_fee'] as num?)?.toDouble() ?? 0.0,
      finesFee: (json['fines_fee'] as num?)?.toDouble() ?? 0.0,
      discountFee: (json['discount_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'Tunai',
      paymentStatus: json['payment_status']?.toString() ?? 'Lunas',
      cashGiven: (json['cash_given'] as num?)?.toDouble() ?? 0.0,
      cashChange: (json['cash_change'] as num?)?.toDouble() ?? 0.0,
      depositStatus: json['deposit_status']?.toString(),
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      termsAndConditions: json['terms_and_conditions']?.toString(),
    );
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
      lines.add(_twoColumn('Status    :', 'KEMBALI (TERSEDIA)', width));
      lines.add(_twoColumn('Jaminan   :', 'DISERAHKAN BALIK', width));
      if (!fmt.compactSpacing) lines.add(subDivider);

      if (fmt.showDeposit) {
        lines.add(_twoColumn('Deposit   :', _formatRupiah(depositFee), width));
      }
      if (finesFee > 0) {
        lines.add(_twoColumn('Pot. Denda:', '-${_formatRupiah(finesFee)}', width));
      }
      lines.add(_twoColumn('Refund Dep. :', _formatRupiah(refundAmount), width));
      if (fmt.showPaymentMethod) lines.add(_twoColumn('Metode    :', paymentMethod, width));
      if (fmt.showPaymentStatus) lines.add(_twoColumn('Status    :', 'LUNAS / SELESAI', width));
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

    // 4. Rincian Biaya
    if (fmt.showRentFee) {
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
}
