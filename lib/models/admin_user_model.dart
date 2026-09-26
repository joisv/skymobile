class AdminUserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String outletName;
  final String shiftName;
  final bool isActive;

  const AdminUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.outletName,
    required this.shiftName,
    this.isActive = true,
  });

  factory AdminUserModel.defaultAdmin() {
    return const AdminUserModel(
      id: 1,
      name: 'Admin SKYRental',
      email: 'admin@skyrental.id',
      phone: '+62 812-3456-7890',
      role: 'Staff Operasional / Kasir',
      outletName: 'Outlet Utama Malioboro',
      shiftName: 'Shift Pagi (08:00 - 16:00)',
      isActive: true,
    );
  }

  AdminUserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? outletName,
    String? shiftName,
    bool? isActive,
  }) {
    return AdminUserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      outletName: outletName ?? this.outletName,
      shiftName: shiftName ?? this.shiftName,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'outlet_name': outletName,
      'shift_name': shiftName,
      'is_active': isActive,
    };
  }

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    int parsedId = 1;
    if (json['id'] is int) {
      parsedId = json['id'] as int;
    } else if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 1;
    }

    String roleStr = 'Staff Operasional / Kasir';
    if (json['role'] != null) {
      roleStr = json['role'].toString();
    } else if (json['roles'] is List && (json['roles'] as List).isNotEmpty) {
      roleStr = (json['roles'] as List).first.toString();
    }

    return AdminUserModel(
      id: parsedId,
      name: json['name'] as String? ?? 'Admin SKYRental',
      email: json['email'] as String? ?? 'admin@skyrental.id',
      phone: json['phone'] as String? ?? '+62 812-3456-7890',
      role: roleStr,
      outletName: json['outlet_name'] as String? ?? 'Outlet Utama Malioboro',
      shiftName: json['shift_name'] as String? ?? 'Shift Pagi (08:00 - 16:00)',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class ShopSettingsModel {
  final String shopName;
  final String outletName;
  final String address;
  final String phoneNumber;
  final String footerNote;
  final String wifiName;
  final String wifiPassword;

  const ShopSettingsModel({
    required this.shopName,
    required this.outletName,
    required this.address,
    required this.phoneNumber,
    required this.footerNote,
    required this.wifiName,
    required this.wifiPassword,
  });

  factory ShopSettingsModel.defaultSettings() {
    return const ShopSettingsModel(
      shopName: 'SKYRental iPhone POS',
      outletName: 'Outlet Utama Malioboro',
      address: 'Jl. Malioboro No. 45, Danurejan, D.I. Yogyakarta',
      phoneNumber: '0812-3456-7890',
      footerNote: 'Terima kasih telah mempercayakan sewa iPhone kepada SKYRental',
      wifiName: 'SKYRENTAL_GUEST',
      wifiPassword: 'rentaliphoneoke',
    );
  }

  ShopSettingsModel copyWith({
    String? shopName,
    String? outletName,
    String? address,
    String? phoneNumber,
    String? footerNote,
    String? wifiName,
    String? wifiPassword,
  }) {
    return ShopSettingsModel(
      shopName: shopName ?? this.shopName,
      outletName: outletName ?? this.outletName,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      footerNote: footerNote ?? this.footerNote,
      wifiName: wifiName ?? this.wifiName,
      wifiPassword: wifiPassword ?? this.wifiPassword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_name': shopName,
      'outlet_name': outletName,
      'address': address,
      'phone_number': phoneNumber,
      'footer_note': footerNote,
      'wifi_name': wifiName,
      'wifi_password': wifiPassword,
    };
  }

  factory ShopSettingsModel.fromJson(Map<String, dynamic> json) {
    return ShopSettingsModel(
      shopName: json['shop_name'] as String? ?? 'SKYRental iPhone POS',
      outletName: json['outlet_name'] as String? ?? 'Outlet Utama Malioboro',
      address: json['address'] as String? ?? 'Jl. Malioboro No. 45, Yogyakarta',
      phoneNumber: json['phone_number'] as String? ?? '0812-3456-7890',
      footerNote: json['footer_note'] as String? ?? 'Terima kasih telah menyewa di SKYRental',
      wifiName: json['wifi_name'] as String? ?? 'SKYRENTAL_GUEST',
      wifiPassword: json['wifi_password'] as String? ?? 'rentaliphoneoke',
    );
  }
}
