class AffiliateUserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? role;
  final int? affiliateId;
  final bool isAssigned;
  final String? currentAffiliateName;
  final DateTime? createdAt;

  const AffiliateUserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role,
    this.affiliateId,
    this.isAssigned = false,
    this.currentAffiliateName,
    this.createdAt,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
  }

  factory AffiliateUserModel.fromJson(Map<String, dynamic> json) {
    return AffiliateUserModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Pengguna',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'Staff',
      affiliateId: json['affiliate_id'] != null
          ? int.tryParse(json['affiliate_id'].toString())
          : null,
      isAssigned: json['is_assigned'] as bool? ?? (json['affiliate_id'] != null),
      currentAffiliateName: json['current_affiliate_name'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'affiliate_id': affiliateId,
      'is_assigned': isAssigned,
      'current_affiliate_name': currentAffiliateName,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  AffiliateUserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    int? affiliateId,
    bool? isAssigned,
    String? currentAffiliateName,
    DateTime? createdAt,
  }) {
    return AffiliateUserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      affiliateId: affiliateId ?? this.affiliateId,
      isAssigned: isAssigned ?? this.isAssigned,
      currentAffiliateName: currentAffiliateName ?? this.currentAffiliateName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
