class IphoneTransferModel {
  final int id;
  final int iphoneId;
  final String iphoneName;
  final String iphoneSerial;
  final String iphoneColor;
  final int? fromAffiliateId;
  final String fromAffiliateName;
  final String fromAffiliateCode;
  final int toAffiliateId;
  final String toAffiliateName;
  final String toAffiliateCode;
  final int? sentBy;
  final String senderName;
  final int? receivedBy;
  final String? receiverName;
  final String status; // 'in_transit', 'received', 'pending'
  final String? notes;
  final DateTime? sentAt;
  final DateTime? receivedAt;
  final DateTime? createdAt;

  const IphoneTransferModel({
    required this.id,
    required this.iphoneId,
    required this.iphoneName,
    required this.iphoneSerial,
    this.iphoneColor = '',
    this.fromAffiliateId,
    this.fromAffiliateName = 'Pusat (SkyRent)',
    this.fromAffiliateCode = 'PST',
    required this.toAffiliateId,
    required this.toAffiliateName,
    this.toAffiliateCode = '-',
    this.sentBy,
    this.senderName = 'Admin',
    this.receivedBy,
    this.receiverName,
    this.status = 'in_transit',
    this.notes,
    this.sentAt,
    this.receivedAt,
    this.createdAt,
  });

  bool get isInTransit => status.toLowerCase() == 'in_transit' || status.toLowerCase() == 'pending';
  bool get isReceived => status.toLowerCase() == 'received';

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'in_transit':
        return 'Dalam Pengiriman';
      case 'received':
        return 'Diterima';
      case 'pending':
        return 'Menunggu';
      default:
        return status.toUpperCase();
    }
  }

  factory IphoneTransferModel.fromJson(Map<String, dynamic> json) {
    return IphoneTransferModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      iphoneId: json['iphone_id'] is int
          ? json['iphone_id'] as int
          : int.tryParse(json['iphone_id']?.toString() ?? '0') ?? 0,
      iphoneName: json['iphone_name'] as String? ?? 'iPhone',
      iphoneSerial: json['iphone_serial'] as String? ?? '-',
      iphoneColor: json['iphone_color'] as String? ?? '',
      fromAffiliateId: json['from_affiliate_id'] != null
          ? int.tryParse(json['from_affiliate_id'].toString())
          : null,
      fromAffiliateName: json['from_affiliate_name'] as String? ?? 'Pusat (SkyRent)',
      fromAffiliateCode: json['from_affiliate_code'] as String? ?? 'PST',
      toAffiliateId: json['to_affiliate_id'] is int
          ? json['to_affiliate_id'] as int
          : int.tryParse(json['to_affiliate_id']?.toString() ?? '0') ?? 0,
      toAffiliateName: json['to_affiliate_name'] as String? ?? 'Tujuan',
      toAffiliateCode: json['to_affiliate_code'] as String? ?? '-',
      sentBy: json['sent_by'] != null ? int.tryParse(json['sent_by'].toString()) : null,
      senderName: json['sender_name'] as String? ?? 'Admin',
      receivedBy: json['received_by'] != null ? int.tryParse(json['received_by'].toString()) : null,
      receiverName: json['receiver_name'] as String?,
      status: json['status'] as String? ?? 'in_transit',
      notes: json['notes'] as String?,
      sentAt: json['sent_at'] != null ? DateTime.tryParse(json['sent_at'].toString()) : null,
      receivedAt: json['received_at'] != null ? DateTime.tryParse(json['received_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'iphone_id': iphoneId,
      'iphone_name': iphoneName,
      'iphone_serial': iphoneSerial,
      'iphone_color': iphoneColor,
      'from_affiliate_id': fromAffiliateId,
      'from_affiliate_name': fromAffiliateName,
      'from_affiliate_code': fromAffiliateCode,
      'to_affiliate_id': toAffiliateId,
      'to_affiliate_name': toAffiliateName,
      'to_affiliate_code': toAffiliateCode,
      'sent_by': sentBy,
      'sender_name': senderName,
      'received_by': receivedBy,
      'receiver_name': receiverName,
      'status': status,
      'notes': notes,
      'sent_at': sentAt?.toIso8601String(),
      'received_at': receivedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  IphoneTransferModel copyWith({
    int? id,
    int? iphoneId,
    String? iphoneName,
    String? iphoneSerial,
    String? iphoneColor,
    int? fromAffiliateId,
    String? fromAffiliateName,
    String? fromAffiliateCode,
    int? toAffiliateId,
    String? toAffiliateName,
    String? toAffiliateCode,
    int? sentBy,
    String? senderName,
    int? receivedBy,
    String? receiverName,
    String? status,
    String? notes,
    DateTime? sentAt,
    DateTime? receivedAt,
    DateTime? createdAt,
  }) {
    return IphoneTransferModel(
      id: id ?? this.id,
      iphoneId: iphoneId ?? this.iphoneId,
      iphoneName: iphoneName ?? this.iphoneName,
      iphoneSerial: iphoneSerial ?? this.iphoneSerial,
      iphoneColor: iphoneColor ?? this.iphoneColor,
      fromAffiliateId: fromAffiliateId ?? this.fromAffiliateId,
      fromAffiliateName: fromAffiliateName ?? this.fromAffiliateName,
      fromAffiliateCode: fromAffiliateCode ?? this.fromAffiliateCode,
      toAffiliateId: toAffiliateId ?? this.toAffiliateId,
      toAffiliateName: toAffiliateName ?? this.toAffiliateName,
      toAffiliateCode: toAffiliateCode ?? this.toAffiliateCode,
      sentBy: sentBy ?? this.sentBy,
      senderName: senderName ?? this.senderName,
      receivedBy: receivedBy ?? this.receivedBy,
      receiverName: receiverName ?? this.receiverName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      sentAt: sentAt ?? this.sentAt,
      receivedAt: receivedAt ?? this.receivedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static List<IphoneTransferModel> mockTransfers() {
    return [
      IphoneTransferModel(
        id: 1,
        iphoneId: 101,
        iphoneName: 'iPhone 15 Pro 128GB',
        iphoneSerial: 'SN-IPH15P-BWI-01',
        iphoneColor: 'Natural Titanium',
        fromAffiliateId: null,
        fromAffiliateName: 'Pusat (SkyRent)',
        fromAffiliateCode: 'PST',
        toAffiliateId: 1,
        toAffiliateName: 'Affiliate Banyuwangi Kota',
        toAffiliateCode: 'BWI',
        senderName: 'Admin Pusat',
        status: 'in_transit',
        notes: 'Alokasi tambahan unit high-demand weekend.',
        sentAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      IphoneTransferModel(
        id: 2,
        iphoneId: 102,
        iphoneName: 'iPhone 13 128GB',
        iphoneSerial: 'SN-IPH13-SLO-02',
        iphoneColor: 'Midnight',
        fromAffiliateId: null,
        fromAffiliateName: 'Pusat (SkyRent)',
        fromAffiliateCode: 'PST',
        toAffiliateId: 2,
        toAffiliateName: 'Affiliate Solo Balapan',
        toAffiliateCode: 'SLO',
        senderName: 'Admin Pusat',
        receiverName: 'Budi Santoso',
        status: 'received',
        notes: 'Transfer reguler unit siap sewa.',
        sentAt: DateTime.now().subtract(const Duration(days: 2)),
        receivedAt: DateTime.now().subtract(const Duration(days: 1, hours: 22)),
      ),
    ];
  }
}
