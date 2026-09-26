import 'affiliate_user_model.dart';

class AffiliateModel {
  final int id;
  final String code;
  final String name;
  final String slug;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? province;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? logo;
  final String? description;
  final bool isActive;
  final int iphonesCount;
  final int bookingsCount;
  final int usersCount;
  final double revenueToday;
  final double totalRevenue;
  final List<AffiliateUserModel>? users;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AffiliateModel({
    required this.id,
    required this.code,
    required this.name,
    required this.slug,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.province,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.logo,
    this.description,
    this.isActive = true,
    this.iphonesCount = 0,
    this.bookingsCount = 0,
    this.usersCount = 0,
    this.revenueToday = 0.0,
    this.totalRevenue = 0.0,
    this.users,
    this.createdAt,
    this.updatedAt,
  });

  String get initials {
    if (code.isNotEmpty) return code;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
  }

  String get locationSummary {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    return parts.isNotEmpty ? parts.join(', ') : (address ?? 'Lokasi belum diisi');
  }

  bool get isPusat {
    final combined = '$code $name $slug'.toLowerCase();
    return combined.contains('pusat');
  }

  factory AffiliateModel.fromJson(Map<String, dynamic> json) {
    List<AffiliateUserModel>? parsedUsers;
    if (json['users'] is List) {
      parsedUsers = (json['users'] as List)
          .map((u) => AffiliateUserModel.fromJson(u as Map<String, dynamic>))
          .toList();
    }

    return AffiliateModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code'] as String? ?? 'AFF',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      postalCode: json['postal_code'] as String?,
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      logo: json['logo'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      iphonesCount: json['iphones_count'] is int
          ? json['iphones_count'] as int
          : int.tryParse(json['iphones_count']?.toString() ?? '0') ?? 0,
      bookingsCount: json['bookings_count'] is int
          ? json['bookings_count'] as int
          : int.tryParse(json['bookings_count']?.toString() ?? '0') ?? 0,
      usersCount: json['users_count'] is int
          ? json['users_count'] as int
          : (parsedUsers?.length ?? int.tryParse(json['users_count']?.toString() ?? '0') ?? 0),
      revenueToday: (json['revenue_today'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      users: parsedUsers,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'slug': slug,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'logo': logo,
      'description': description,
      'is_active': isActive,
      'iphones_count': iphonesCount,
      'bookings_count': bookingsCount,
      'users_count': usersCount,
      'revenue_today': revenueToday,
      'total_revenue': totalRevenue,
      'users': users?.map((u) => u.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AffiliateModel copyWith({
    int? id,
    String? code,
    String? name,
    String? slug,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? province,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? logo,
    String? description,
    bool? isActive,
    int? iphonesCount,
    int? bookingsCount,
    int? usersCount,
    double? revenueToday,
    double? totalRevenue,
    List<AffiliateUserModel>? users,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AffiliateModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      logo: logo ?? this.logo,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      iphonesCount: iphonesCount ?? this.iphonesCount,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      usersCount: usersCount ?? this.usersCount,
      revenueToday: revenueToday ?? this.revenueToday,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      users: users ?? this.users,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static AffiliateModel mockMalioboro() => mockAffiliates().first;

  static List<AffiliateModel> mockAffiliates() {
    return [
      AffiliateModel(
        id: 1,
        code: 'BWI',
        name: 'Affiliate Banyuwangi Kota',
        slug: 'affiliate-banyuwangi-kota',
        email: 'banyuwangi@skyrent.id',
        phone: '0812-9876-1122',
        address: 'Jl. Ahmad Yani No. 88, Rogojampi',
        city: 'Banyuwangi',
        province: 'Jawa Timur',
        postalCode: '68411',
        description: 'Mitra cabang utama Banyuwangi melayani area kota & wisata Banyuwangi.',
        isActive: true,
        iphonesCount: 6,
        bookingsCount: 24,
        usersCount: 2,
        revenueToday: 750000.0,
        totalRevenue: 12500000.0,
        users: const [
          AffiliateUserModel(
            id: 'user-bwi-1',
            name: 'Budi Santoso',
            email: 'budi.santoso@skyrent.id',
            phone: '0812-3456-7890',
            role: 'Staff Cabang',
            affiliateId: 1,
            isAssigned: true,
          ),
          AffiliateUserModel(
            id: 'user-bwi-2',
            name: 'Siti Rahma',
            email: 'siti.rahma@skyrent.id',
            phone: '0812-9876-5432',
            role: 'Admin Kasir',
            affiliateId: 1,
            isAssigned: true,
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
      AffiliateModel(
        id: 2,
        code: 'SLO',
        name: 'Affiliate Solo Balapan',
        slug: 'affiliate-solo-balapan',
        email: 'solo@skyrent.id',
        phone: '0813-8877-3344',
        address: 'Jl. Slamet Riyadi No. 120, Surakarta',
        city: 'Surakarta',
        province: 'Jawa Tengah',
        postalCode: '57131',
        description: 'Mitra operasional area Solo dan sekitarnya.',
        isActive: true,
        iphonesCount: 4,
        bookingsCount: 18,
        usersCount: 1,
        revenueToday: 450000.0,
        totalRevenue: 8900000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      AffiliateModel(
        id: 3,
        code: 'MLG',
        name: 'Affiliate Malang Ijen',
        slug: 'affiliate-malang-ijen',
        email: 'malang@skyrent.id',
        phone: '0811-2233-4455',
        address: 'Jl. Besar Ijen No. 45, Klojen',
        city: 'Malang',
        province: 'Jawa Timur',
        postalCode: '65115',
        description: 'Cabang kemitraan mahasiswa & wisatawan Malang Raya.',
        isActive: false,
        iphonesCount: 2,
        bookingsCount: 8,
        usersCount: 1,
        revenueToday: 0.0,
        totalRevenue: 3400000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }
}
