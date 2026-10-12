import 'package:flutter/material.dart';
import 'booking_model.dart';

enum DepositStatus {
  held,
  readyRefund,
  refunded,
  deducted;

  String get label {
    switch (this) {
      case DepositStatus.held:
        return 'Ditahan (Aktif)';
      case DepositStatus.readyRefund:
        return 'Siap Refund';
      case DepositStatus.refunded:
        return 'Telah Direfund';
      case DepositStatus.deducted:
        return 'Dipotong Denda';
    }
  }

  static DepositStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'ready_refund':
      case 'siap_refund':
        return DepositStatus.readyRefund;
      case 'refunded':
      case 'selesai':
        return DepositStatus.refunded;
      case 'deducted':
      case 'dipotong':
        return DepositStatus.deducted;
      case 'held':
      case 'ditahan':
      default:
        return DepositStatus.held;
    }
  }
}

class PaymentTransactionModel {
  final int id;
  final int bookingId;
  final String bookingCode;
  final String customerName;
  final String customerPhone;
  final String iphoneName;
  final double rentTotal;
  final double paidAmount;
  final double remainingAmount;
  final double depositAmount;
  final DepositStatus depositStatus;
  final double refundAmount;
  final double deductionAmount;
  final String paymentStatus; // 'unpaid', 'partial', 'paid'
  final String paymentMethod; // 'QRIS', 'Tunai', 'Transfer Bank'
  final DateTime transactionDate;
  final String? notes;

  const PaymentTransactionModel({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.customerName,
    required this.customerPhone,
    required this.iphoneName,
    required this.rentTotal,
    required this.paidAmount,
    required this.remainingAmount,
    required this.depositAmount,
    required this.depositStatus,
    this.refundAmount = 0,
    this.deductionAmount = 0,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.transactionDate,
    this.notes,
  });

  bool get isPaid => paymentStatus == 'paid';
  bool get hasRemaining => remainingAmount > 0;
  bool get canRefundDeposit => depositStatus == DepositStatus.readyRefund;

  PaymentTransactionModel copyWith({
    int? id,
    int? bookingId,
    String? bookingCode,
    String? customerName,
    String? customerPhone,
    String? iphoneName,
    double? rentTotal,
    double? paidAmount,
    double? remainingAmount,
    double? depositAmount,
    DepositStatus? depositStatus,
    double? refundAmount,
    double? deductionAmount,
    String? paymentStatus,
    String? paymentMethod,
    DateTime? transactionDate,
    String? notes,
  }) {
    return PaymentTransactionModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      bookingCode: bookingCode ?? this.bookingCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      iphoneName: iphoneName ?? this.iphoneName,
      rentTotal: rentTotal ?? this.rentTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      depositAmount: depositAmount ?? this.depositAmount,
      depositStatus: depositStatus ?? this.depositStatus,
      refundAmount: refundAmount ?? this.refundAmount,
      deductionAmount: deductionAmount ?? this.deductionAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionDate: transactionDate ?? this.transactionDate,
      notes: notes ?? this.notes,
    );
  }

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionModel(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int,
      bookingCode: json['booking_code'] as String,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      iphoneName: json['iphone_name'] as String? ?? 'iPhone',
      rentTotal: (json['rent_total'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      remainingAmount: (json['remaining_amount'] as num).toDouble(),
      depositAmount: (json['deposit_amount'] as num).toDouble(),
      depositStatus: DepositStatus.fromString(json['deposit_status'] as String? ?? 'held'),
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0,
      deductionAmount: (json['deduction_amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paymentMethod: json['payment_method'] as String? ?? 'QRIS',
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'booking_code': bookingCode,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'iphone_name': iphoneName,
      'rent_total': rentTotal,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'deposit_amount': depositAmount,
      'deposit_status': depositStatus.name,
      'refund_amount': refundAmount,
      'deduction_amount': deductionAmount,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'transaction_date': transactionDate.toIso8601String(),
      'notes': notes,
    };
  }
}

class PaymentMethodOption {
  final int? id;
  final String name;
  final String slug;
  final String? icon;
  final String? description;
  final bool isActive;
  final String? badge;

  const PaymentMethodOption({
    this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.description,
    this.isActive = true,
    this.badge,
  });

  String get idStr => slug.isNotEmpty ? slug : (id?.toString() ?? name.toLowerCase());

  String get displayName {
    final lower = name.toLowerCase();
    if (lower == 'cash' || lower == 'tunai') return 'Tunai';
    if (lower == 'bank_transfer' || lower == 'transfer_bank' || lower == 'transfer / va bank') return 'VA Bank';
    if (lower == 'qris') return 'QRIS';
    if (lower == 'edc' || lower == 'edc_mesin') return 'EDC Mesin';
    return name;
  }

  String get defaultSubtitle {
    if (isCash) return 'Input Uang Pas';
    if (slug.contains('qris') || name.toLowerCase().contains('qris')) return 'Auto Settlement';
    if (slug.contains('va') || slug.contains('bank') || name.toLowerCase().contains('bank')) return 'Virtual Account';
    if (slug.contains('edc') || name.toLowerCase().contains('edc')) return 'Swipe / Dip';
    return description ?? 'Metode Pembayaran';
  }

  String? get defaultBadge {
    if (badge != null && badge!.isNotEmpty) return badge;
    if (isCash) return 'FISIK';
    if (slug.contains('va') || slug.contains('bank') || name.toLowerCase().contains('bank')) return 'BCA/MDR';
    if (slug.contains('edc') || name.toLowerCase().contains('edc')) return 'KARTU';
    return null;
  }

  bool get isCash {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    return s == 'tunai' || s == 'cash' || n == 'tunai' || n == 'cash' || s.contains('tunai') || s.contains('cash') || n.contains('tunai') || n.contains('cash');
  }

  IconData get iconData {
    final s = slug.toLowerCase();
    final n = name.toLowerCase();
    if (s.contains('qris') || n.contains('qris')) {
      return Icons.qr_code_2_rounded;
    }
    if (isCash) {
      return Icons.payments_outlined;
    }
    if (s.contains('va') || s.contains('bank') || s.contains('transfer') || n.contains('bank')) {
      return Icons.account_balance_outlined;
    }
    if (s.contains('edc') || s.contains('kartu') || s.contains('card') || n.contains('edc')) {
      return Icons.point_of_sale_rounded;
    }
    return Icons.credit_card_rounded;
  }

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOption(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name'] as String? ?? 'Metode Pembayaran',
      slug: (json['slug'] as String? ?? '').toLowerCase(),
      icon: json['icon'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      badge: json['badge'] as String?,
    );
  }

  static List<PaymentMethodOption> defaultMethods() {
    return const [
      PaymentMethodOption(id: 1, name: 'Tunai', slug: 'tunai', badge: 'FISIK', description: 'Input Uang Pas'),
      PaymentMethodOption(id: 2, name: 'QRIS', slug: 'qris', badge: 'INSTAN', description: 'Auto Settlement'),
      PaymentMethodOption(id: 3, name: 'VA Bank', slug: 'va', badge: 'BCA/MDR', description: 'Virtual Account'),
      PaymentMethodOption(id: 4, name: 'EDC Mesin', slug: 'edc', badge: 'KARTU', description: 'Swipe / Dip'),
    ];
  }
}

/// Model hasil pembayaran nyata yang dikembalikan dari backend REST API Laravel
class BookingPaymentResult {
  final String bookingCode;
  final String receiptNumber;
  final String? paymentCode;
  final String customerName;
  final String? customerPhone;
  final String unitName;
  final double amount;
  final double cashReceived;
  final double change;
  final String paymentMethod;
  final String paymentType;
  final String paymentTypeLabel;
  final double totalAmount;
  final double totalPaid;
  final double remainingPayment;
  final String paymentStatus;
  final bool isSettled;
  final DateTime paidAt;
  final String? paidAtFormatted;
  final String? note;
  final BookingModel? updatedBooking;

  const BookingPaymentResult({
    required this.bookingCode,
    required this.receiptNumber,
    this.paymentCode,
    required this.customerName,
    this.customerPhone,
    required this.unitName,
    required this.amount,
    this.cashReceived = 0.0,
    this.change = 0.0,
    required this.paymentMethod,
    required this.paymentType,
    required this.paymentTypeLabel,
    required this.totalAmount,
    required this.totalPaid,
    required this.remainingPayment,
    required this.paymentStatus,
    this.isSettled = false,
    required this.paidAt,
    this.paidAtFormatted,
    this.note,
    this.updatedBooking,
  });

  factory BookingPaymentResult.fromJson(Map<String, dynamic> json) {
    final summary = (json['payment_summary'] as Map<String, dynamic>?) ?? {};
    final payment = (json['payment'] as Map<String, dynamic>?) ?? {};
    final bookingJson = (json['data'] as Map<String, dynamic>?);

    final String bCode = summary['booking_code']?.toString() ??
        payment['booking_code']?.toString() ??
        bookingJson?['booking_code']?.toString() ??
        json['booking_code']?.toString() ??
        '-';

    final String rNum = summary['receipt_number']?.toString() ??
        payment['receipt_number']?.toString() ??
        summary['payment_code']?.toString() ??
        payment['payment_code']?.toString() ??
        bCode;

    final String? pCode = summary['payment_code']?.toString() ?? payment['payment_code']?.toString();

    final String cName = summary['customer_name']?.toString() ??
        payment['customer_name']?.toString() ??
        bookingJson?['customer_name']?.toString() ??
        '-';

    final String? cPhone = summary['customer_phone']?.toString() ??
        payment['customer_phone']?.toString() ??
        bookingJson?['customer_phone']?.toString();

    String uName = summary['unit_name']?.toString() ??
        payment['unit_name']?.toString() ??
        '-';
    if (uName == '-' && bookingJson != null && bookingJson['iphone'] is Map) {
      final iph = bookingJson['iphone'] as Map;
      uName = "${iph['name'] ?? 'iPhone'} (${iph['serial_number'] ?? '-'})";
    }

    final double amt = (summary['amount_paid'] as num?)?.toDouble() ??
        (summary['amount'] as num?)?.toDouble() ??
        (payment['amount'] as num?)?.toDouble() ??
        (json['amount'] as num?)?.toDouble() ??
        0.0;

    final double cRecv = (summary['cash_received'] as num?)?.toDouble() ??
        (payment['pay'] as num?)?.toDouble() ??
        (json['pay'] as num?)?.toDouble() ??
        amt;

    final double chg = (summary['change'] as num?)?.toDouble() ??
        (payment['change'] as num?)?.toDouble() ??
        (json['change'] as num?)?.toDouble() ??
        0.0;

    final String pMethod = summary['payment_method']?.toString() ??
        payment['payment_method']?.toString() ??
        json['payment_method']?.toString() ??
        'Tunai (Cash)';

    final String pType = summary['payment_type']?.toString() ??
        payment['type']?.toString() ??
        json['type']?.toString() ??
        'payment';

    final String pTypeLabel = summary['payment_type_label']?.toString() ??
        payment['type_label']?.toString() ??
        (pType == 'dp' ? 'Uang Muka (DP)' : 'Pelunasan Sewa');

    final double tAmount = (summary['total_amount'] as num?)?.toDouble() ??
        (summary['price'] as num?)?.toDouble() ??
        (bookingJson?['price'] as num?)?.toDouble() ??
        amt;

    final double tPaid = (summary['total_paid'] as num?)?.toDouble() ??
        (payment['amount'] as num?)?.toDouble() ??
        amt;

    final double rPayment = (summary['remaining_payment'] as num?)?.toDouble() ?? 0.0;

    final String pStatus = summary['payment_status']?.toString() ??
        bookingJson?['payment_status']?.toString() ??
        (rPayment <= 0 ? 'paid' : 'partial');

    final bool settled = summary['is_settled'] == true || pStatus == 'paid';

    DateTime pAt = DateTime.now();
    final pAtRaw = summary['paid_at'] ?? payment['paid_at'] ?? json['paid_at'];
    if (pAtRaw != null) {
      try {
        pAt = DateTime.parse(pAtRaw.toString());
      } catch (_) {}
    }

    final String? pAtFormatted = summary['paid_at_formatted']?.toString() ??
        payment['paid_at_formatted']?.toString();

    final String? nt = summary['note']?.toString() ?? payment['note']?.toString() ?? json['note']?.toString();

    BookingModel? upBooking;
    if (bookingJson != null) {
      try {
        upBooking = BookingModel.fromJson(bookingJson);
      } catch (_) {}
    }

    return BookingPaymentResult(
      bookingCode: bCode,
      receiptNumber: rNum,
      paymentCode: pCode,
      customerName: cName,
      customerPhone: cPhone,
      unitName: uName,
      amount: amt,
      cashReceived: cRecv,
      change: chg,
      paymentMethod: pMethod,
      paymentType: pType,
      paymentTypeLabel: pTypeLabel,
      totalAmount: tAmount,
      totalPaid: tPaid,
      remainingPayment: rPayment,
      paymentStatus: pStatus,
      isSettled: settled,
      paidAt: pAt,
      paidAtFormatted: pAtFormatted,
      note: nt,
      updatedBooking: upBooking,
    );
  }
}