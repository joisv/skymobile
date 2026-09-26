class AffiliatePaymentItemModel {
  final int id;
  final int bookingId;
  final String bookingCode;
  final String customerName;
  final String iphoneName;
  final double amount;
  final String paymentMethod;
  final String type;
  final DateTime? paidAt;
  final String staffName;

  const AffiliatePaymentItemModel({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.customerName,
    required this.iphoneName,
    required this.amount,
    this.paymentMethod = 'cash',
    this.type = 'payment',
    this.paidAt,
    this.staffName = 'Admin',
  });

  factory AffiliatePaymentItemModel.fromJson(Map<String, dynamic> json) {
    return AffiliatePaymentItemModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      bookingId: json['booking_id'] is int
          ? json['booking_id'] as int
          : int.tryParse(json['booking_id']?.toString() ?? '0') ?? 0,
      bookingCode: json['booking_code'] as String? ?? '-',
      customerName: json['customer_name'] as String? ?? 'Pelanggan',
      iphoneName: json['iphone_name'] as String? ?? 'iPhone',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      type: json['type'] as String? ?? 'payment',
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'].toString()) : null,
      staffName: json['staff_name'] as String? ?? 'Admin',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'booking_code': bookingCode,
      'customer_name': customerName,
      'iphone_name': iphoneName,
      'amount': amount,
      'payment_method': paymentMethod,
      'type': type,
      'paid_at': paidAt?.toIso8601String(),
      'staff_name': staffName,
    };
  }
}

class AffiliateRevenueSummaryModel {
  final int affiliateId;
  final String affiliateName;
  final String affiliateCode;
  final String startDate;
  final String endDate;
  final double affiliateRevenue;
  final int affiliateBookingCount;
  final double revenueToday;
  final int bookingToday;
  final int paymentsCount;
  final List<AffiliatePaymentItemModel> payments;

  const AffiliateRevenueSummaryModel({
    required this.affiliateId,
    required this.affiliateName,
    required this.affiliateCode,
    required this.startDate,
    required this.endDate,
    this.affiliateRevenue = 0.0,
    this.affiliateBookingCount = 0,
    this.revenueToday = 0.0,
    this.bookingToday = 0,
    this.paymentsCount = 0,
    this.payments = const [],
  });

  factory AffiliateRevenueSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['payments'] as List<dynamic>? ?? [];
    return AffiliateRevenueSummaryModel(
      affiliateId: json['affiliate_id'] is int
          ? json['affiliate_id'] as int
          : int.tryParse(json['affiliate_id']?.toString() ?? '0') ?? 0,
      affiliateName: json['affiliate_name'] as String? ?? '',
      affiliateCode: json['affiliate_code'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      affiliateRevenue: (json['affiliate_revenue'] as num?)?.toDouble() ?? 0.0,
      affiliateBookingCount: json['affiliate_booking_count'] is int
          ? json['affiliate_booking_count'] as int
          : int.tryParse(json['affiliate_booking_count']?.toString() ?? '0') ?? 0,
      revenueToday: (json['revenue_today'] as num?)?.toDouble() ?? 0.0,
      bookingToday: json['booking_today'] is int
          ? json['booking_today'] as int
          : int.tryParse(json['booking_today']?.toString() ?? '0') ?? 0,
      paymentsCount: json['payments_count'] is int
          ? json['payments_count'] as int
          : int.tryParse(json['payments_count']?.toString() ?? '0') ?? 0,
      payments: rawPayments
          .map((p) => AffiliatePaymentItemModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  static AffiliateRevenueSummaryModel mockDefault() {
    return AffiliateRevenueSummaryModel(
      affiliateId: 1,
      affiliateName: 'Affiliate Banyuwangi Kota',
      affiliateCode: 'BWI',
      startDate: DateTime.now().subtract(const Duration(days: 6)).toString().split(' ').first,
      endDate: DateTime.now().toString().split(' ').first,
      affiliateRevenue: 3450000.0,
      affiliateBookingCount: 12,
      revenueToday: 750000.0,
      bookingToday: 3,
      paymentsCount: 12,
      payments: [
        AffiliatePaymentItemModel(
          id: 1,
          bookingId: 101,
          bookingCode: 'BKG-BWI-001',
          customerName: 'Ahmad Fauzi',
          iphoneName: 'iPhone 15 Pro 128GB',
          amount: 350000.0,
          paymentMethod: 'qris',
          type: 'pelunasan',
          paidAt: DateTime.now().subtract(const Duration(hours: 2)),
          staffName: 'Kasir BWI',
        ),
        AffiliatePaymentItemModel(
          id: 2,
          bookingId: 102,
          bookingCode: 'BKG-BWI-002',
          customerName: 'Siti Rahmawati',
          iphoneName: 'iPhone 13 128GB',
          amount: 400000.0,
          paymentMethod: 'cash',
          type: 'payment',
          paidAt: DateTime.now().subtract(const Duration(hours: 5)),
          staffName: 'Kasir BWI',
        ),
      ],
    );
  }
}
