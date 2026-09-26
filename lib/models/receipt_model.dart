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
      lines.add(_twoColumn('Refund Dep:', _formatRupiah(refundAmount), width));
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

    // 2. Informasi Transaksi
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (fmt.showDateTime) lines.add(_twoColumn('Tgl       :', dateStr, width));
    if (fmt.showReceiptNumber) lines.add(_twoColumn('No. Struk :', receiptNumber, width));
    if (fmt.showAdminName && !isCompact) lines.add(_twoColumn('Admin     :', adminName, width));
    if (fmt.showTransactionType && !isCompact) {
      lines.add(_twoColumn('Tipe Resi :', customTypeLabel ?? type.label, width));
    }
    if (!fmt.compactSpacing) lines.add(subDivider);

    // 3. Data Pelanggan & Unit
    if (isCompact) {
      // Mode Ringkas (Eco): Menggabungkan baris untuk efisiensi tinggi
      if (fmt.showCustomerName) {
        final cust = fmt.showCustomerPhone ? '$customerName ($customerPhone)' : customerName;
        lines.add(_twoColumn('Pelanggan :', cust, width));
      }
      if (fmt.showBookingCodeText) lines.add(_twoColumn('Kode Book :', bookingCode, width));
      if (fmt.showUnitName) {
        final u = fmt.showRentalDuration ? '$unitName ($rentalDuration)' : unitName;
        lines.add(_twoColumn('Unit      :', u, width));
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
    } else {
      // Mode Standar / Lengkap
      if (fmt.showCustomerName) lines.add(_twoColumn('Pelanggan :', customerName, width));
      if (fmt.showCustomerPhone) lines.add(_twoColumn('Kontak    :', customerPhone, width));
      if (fmt.showBookingCodeText) lines.add(_twoColumn('Kode Book :', bookingCode, width));
      if (fmt.showUnitName) lines.add(_twoColumn('Unit      :', unitName, width));
      if (fmt.showAssetCode && assetCode != null && assetCode!.isNotEmpty) {
        lines.add(_twoColumn('No. Aset  :', assetCode!, width));
      }
      if (fmt.showSerialNumber && serialNumber != null && serialNumber!.isNotEmpty) {
        lines.add(_twoColumn('Serial No :', serialNumber!, width));
      }
      if (fmt.showRentalDuration) lines.add(_twoColumn('Durasi    :', rentalDuration, width));
      if (fmt.showRentalDates && rentalDates != null && rentalDates!.isNotEmpty) {
        lines.add(_twoColumn('Periode   :', rentalDates!, width));
      }
    }
    if (!fmt.compactSpacing) lines.add(subDivider);

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
