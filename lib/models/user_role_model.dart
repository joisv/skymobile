class UserRoleModel {
  final String id;
  final String name;
  final String email;
  final List<String> roles;
  final String role;
  final List<String> permissions;
  final List<String> directPermissions;
  final List<String> rolePermissions;
  final int? affiliateId;
  final String? affiliateName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdAtFormatted;
  final String? updatedAtFormatted;

  const UserRoleModel({
    required this.id,
    required this.name,
    required this.email,
    this.roles = const [],
    this.role = '-',
    this.permissions = const [],
    this.directPermissions = const [],
    this.rolePermissions = const [],
    this.affiliateId,
    this.affiliateName,
    this.createdAt,
    this.updatedAt,
    this.createdAtFormatted,
    this.updatedAtFormatted,
  });

  factory UserRoleModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    List<String> parsedRoles = [];
    if (rawRoles is List) {
      parsedRoles = rawRoles.map((r) => r.toString()).toList();
    } else if (rawRoles is String && rawRoles.isNotEmpty) {
      parsedRoles = [rawRoles];
    }

    String mainRole = json['role']?.toString() ?? '';
    if (mainRole.isEmpty || mainRole == '-') {
      if (parsedRoles.isNotEmpty) {
        mainRole = parsedRoles.first;
      } else {
        mainRole = '-';
      }
    }

    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return const [];
    }

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    return UserRoleModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pengguna',
      email: json['email']?.toString() ?? '-',
      roles: parsedRoles,
      role: mainRole,
      permissions: parseStringList(json['permissions']),
      directPermissions: parseStringList(json['direct_permissions']),
      rolePermissions: parseStringList(json['role_permissions']),
      affiliateId: json['affiliate_id'] is num ? (json['affiliate_id'] as num).toInt() : null,
      affiliateName: json['affiliate_name']?.toString() ?? json['affiliate']?['name']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      createdAtFormatted: json['created_at_formatted']?.toString(),
      updatedAtFormatted: json['updated_at_formatted']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'roles': roles,
      'role': role,
      'permissions': permissions,
      'direct_permissions': directPermissions,
      'role_permissions': rolePermissions,
      'affiliate_id': affiliateId,
      'affiliate_name': affiliateName,
      'created_at': createdAt?.toIso8601String(),
      'created_at_formatted': createdAtFormatted,
      'updated_at': updatedAt?.toIso8601String(),
      'updated_at_formatted': updatedAtFormatted,
    };
  }

  UserRoleModel copyWith({
    String? id,
    String? name,
    String? email,
    List<String>? roles,
    String? role,
    List<String>? permissions,
    List<String>? directPermissions,
    List<String>? rolePermissions,
    int? affiliateId,
    String? affiliateName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdAtFormatted,
    String? updatedAtFormatted,
  }) {
    return UserRoleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      directPermissions: directPermissions ?? this.directPermissions,
      rolePermissions: rolePermissions ?? this.rolePermissions,
      affiliateId: affiliateId ?? this.affiliateId,
      affiliateName: affiliateName ?? this.affiliateName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAtFormatted: createdAtFormatted ?? this.createdAtFormatted,
      updatedAtFormatted: updatedAtFormatted ?? this.updatedAtFormatted,
    );
  }

  /// Label peran yang lebih ramah pengguna
  String get roleDisplay {
    final lower = role.toLowerCase().trim();
    if (lower == 'super-admin' || lower == 'superadmin') return 'Super Admin';
    if (lower == 'admin') return 'Admin';
    if (lower == 'staff' || lower == 'kasir') return 'Staff Kasir';
    if (lower == 'affiliate-admin') return 'Admin Cabang';
    if (lower == 'affiliate') return 'Mitra Affiliate';
    if (lower == '-' || lower.isEmpty) return 'Tanpa Role';
    return role;
  }

  bool get isSuperAdmin =>
      role.toLowerCase().contains('super-admin') ||
      role.toLowerCase().contains('superadmin');
}

class RoleItemModel {
  final dynamic id;
  final String name;
  final String displayName;
  final int permissionsCount;
  final List<String> permissions;

  const RoleItemModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.permissionsCount = 0,
    this.permissions = const [],
  });

  factory RoleItemModel.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString() ?? '';
    String display = json['display_name']?.toString() ?? '';
    if (display.isEmpty) {
      if (rawName == 'super-admin') {
        display = 'Super Admin';
      } else if (rawName == 'admin') {
        display = 'Admin';
      } else if (rawName == 'staff') {
        display = 'Staff Kasir';
      } else {
        display = rawName.isNotEmpty ? '${rawName[0].toUpperCase()}${rawName.substring(1)}' : '-';
      }
    }

    final rawPerms = json['permissions'];
    List<String> perms = [];
    if (rawPerms is List) {
      perms = rawPerms.map((e) => e.toString()).toList();
    }

    final count = json['permissions_count'] is num
        ? (json['permissions_count'] as num).toInt()
        : perms.length;

    return RoleItemModel(
      id: json['id'],
      name: rawName,
      displayName: display,
      permissionsCount: count,
      permissions: perms,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'permissions_count': permissionsCount,
      'permissions': permissions,
    };
  }
}

class PermissionItemModel {
  final dynamic id;
  final String name;
  final String displayName;

  const PermissionItemModel({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory PermissionItemModel.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString() ?? '';
    String display = json['display_name']?.toString() ?? '';
    if (display.isEmpty) {
      display = rawName.replaceAll(RegExp(r'[._-]'), ' ');
      if (display.isNotEmpty) {
        display = display[0].toUpperCase() + display.substring(1);
      }
    }

    return PermissionItemModel(
      id: json['id'],
      name: rawName,
      displayName: display,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
    };
  }
}
