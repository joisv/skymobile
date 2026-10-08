import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/admin_user_model.dart';
import 'api_service.dart';
import 'fcm_service.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService implements Listenable {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AdminUserModel? _currentUser;
  String? _token;
  bool _rememberMe = true;
  final List<void Function()> _listeners = [];

  AdminUserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _currentUser != null && _token != null;
  bool get rememberMe => _rememberMe;

  // Role & Permission Checks
  bool get isSuperAdmin {
    if (_currentUser == null) return false;
    final role = _currentUser!.role.toLowerCase().trim();
    final name = _currentUser!.name.toLowerCase().trim();
    final email = _currentUser!.email.toLowerCase().trim();
    final roles = _currentUser!.roles.map((r) => r.toLowerCase().trim()).toList();

    if (roles.any((r) =>
        r == 'super-admin' ||
        r == 'superadmin' ||
        r == 'super_admin' ||
        r == 'super admin' ||
        r == 'owner' ||
        r == 'manager')) {
      return true;
    }

    return role == 'super-admin' ||
        role == 'superadmin' ||
        role == 'super_admin' ||
        role == 'super admin' ||
        role.contains('super-admin') ||
        role.contains('superadmin') ||
        role.contains('super_admin') ||
        role.contains('super admin') ||
        role.contains('manager') ||
        role.contains('owner') ||
        email.contains('super-admin') ||
        email.contains('superadmin') ||
        name.contains('super admin') ||
        name.contains('pusat');
  }

  bool get isAffiliateAdmin {
    if (_currentUser == null) return false;
    if (isSuperAdmin) return false;
    final role = _currentUser!.role.toLowerCase().trim();
    final roles = _currentUser!.roles.map((r) => r.toLowerCase().trim()).toList();
    if (roles.any((r) => r.contains('affiliate') || r.contains('cabang'))) {
      return true;
    }
    return role.contains('affiliate-admin') ||
        role.contains('affiliate_admin') ||
        role.contains('affiliate admin') ||
        role.contains('affiliate') ||
        role.contains('cabang');
  }

  bool get isAffiliate {
    if (isSuperAdmin) return false;
    return isAffiliateAdmin ||
        (_currentUser?.role.toLowerCase().contains('affiliate') ?? false) ||
        (_currentUser?.role.toLowerCase().contains('cabang') ?? false) ||
        (_currentUser?.roles.any((r) => r.toLowerCase().contains('affiliate') || r.toLowerCase().contains('cabang')) ?? false);
  }

  bool get isAdmin {
    if (_currentUser == null) return false;
    if (isSuperAdmin) return true;
    final role = _currentUser!.role.toLowerCase().trim();
    final email = _currentUser!.email.toLowerCase().trim();
    final roles = _currentUser!.roles.map((r) => r.toLowerCase().trim()).toList();

    if (roles.any((r) => r == 'admin' || (r.contains('admin') && !r.contains('affiliate')))) {
      return true;
    }

    return role == 'admin' ||
        (role.contains('admin') && !role.contains('affiliate') && !role.contains('cabang')) ||
        email == 'admin@skyrental.id' ||
        isAffiliateAdmin;
  }

  /// Menentukan apakah user terikat pada cakupan affiliate tertentu (scoping).
  /// Mengimplementasikan aturan yang persis sama dengan web Livewire RentIphoneWizard:
  /// !$user->hasRole('super-admin') && ($user->hasRole('affiliate-admin') || $user->hasRole('affiliate') || (!empty($user->affiliate_id) && !$user->hasRole('admin')))
  bool get isAffiliateScoped {
    if (isSuperAdmin) return false;
    if (isAffiliateAdmin || isAffiliate) return true;
    if (affiliateId != null && !isAdmin) return true;
    return false;
  }

  bool get isStaff {
    if (!isAuthenticated) return false;
    return !isSuperAdmin && !isAdmin;
  }

  /// Memeriksa apakah user berhak menambah unit iPhone baru
  /// Hanya diizinkan untuk super-admin dan admin (menolak affiliate-admin, affiliate, dan staff)
  bool get canCreateIphone {
    if (!isAuthenticated) return false;
    if (isSuperAdmin) return true;
    final role = _currentUser?.role.toLowerCase() ?? '';
    if (isAffiliate || isAffiliateAdmin) return false;
    return role == 'admin' || (role.contains('admin') && !role.contains('affiliate') && !role.contains('cabang'));
  }

  bool get canViewAllBookings => isSuperAdmin || (isAdmin && !isAffiliateAdmin && affiliateId == null);
  bool get canViewAllRevenue => isSuperAdmin || (isAdmin && !isAffiliateAdmin && affiliateId == null);

  int? get affiliateId => _currentUser?.affiliateId;

  bool get canAccessFinancials => _currentUser != null;
  bool get canManageInventory => _currentUser != null;
  bool get canModifyShopSettings => isSuperAdmin || (_currentUser != null);

  // Pure Dart Listenable implementation
  @override
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  /// Restore session from API
  Future<void> restoreSession() async {
    final apiService = ApiService();
    // Tunggu SharedPreferences termuat
    await apiService.loadPrefs();
    // Ensure token is loaded
    if (apiService.authToken != null) {
      try {
        final response = await apiService.getMe();
        if (response != null && response['data'] != null) {
          _currentUser = AdminUserModel.fromJson(response['data'] as Map<String, dynamic>);
          _token = apiService.authToken;
          notifyListeners();
          final fcmToken = FcmService().fcmToken;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            unawaited(apiService.registerDeviceTokenApi(fcmToken, platform: 'android'));
          }
        } else {
          apiService.saveAuthToken(null);
        }
      } catch (_) {
        // Assume network error, keep token if exists but user might be null unless cached
      }
    }
  }

  static const Set<String> superAdminOnlyRoutes = {
    '/admin/roles-permissions',
    '/admin/roles-permission',
    'admin/roles-permission',
    'admin/roles-permissions',
    '/roles-permissions',
    '/roles-permission',
    'roles-permissions',
    'roles-permission',
    '/user-roles',
    'user-roles',
    '/users',
    'users',
    '/admin/users',
    'admin/users',
    '/affiliates',
    '/affiliates/detail',
    '/affiliates/form',
    '/affiliates/revenue',
  };

  static const Set<String> transferRoutes = {
    '/affiliates/transfers',
    'affiliates/transfers',
    '/affiliate/transfer-iphone',
    'affiliate/transfer-iphone',
  };

  /// Memeriksa apakah suatu rute diizinkan untuk diakses
  bool canAccessRoute(String routeName) {
    if (routeName == '/login') {
      return true;
    }
    if (!isAuthenticated) {
      return false;
    }
    if (transferRoutes.contains(routeName)) {
      return isSuperAdmin || isAdmin || isAffiliateAdmin || isAffiliate;
    }
    if (superAdminOnlyRoutes.contains(routeName)) {
      return isSuperAdmin;
    }
    return true;
  }

  /// Melakukan autentikasi pengguna langsung ke backend database SKYRental
  Future<AdminUserModel> login({
    required String emailOrUsername,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      final apiResult = await ApiService().loginApi(emailOrUsername, password);
      if (apiResult['user'] != null) {
        final userMap = apiResult['user'] as Map<String, dynamic>;
        final user = AdminUserModel.fromJson(userMap);
        _currentUser = user;
        _token = apiResult['token']?.toString() ?? 'sanctum-token';
        _rememberMe = rememberMe;
        notifyListeners();
        final fcmToken = FcmService().fcmToken;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          unawaited(ApiService().registerDeviceTokenApi(fcmToken, platform: 'android'));
        }
        return user;
      }
      throw const AuthException('Respon data pengguna tidak lengkap dari server database.');
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Gagal masuk: $e');
    }
  }

  Future<void> logout() async {
    try {
      final apiService = ApiService();
      final fcmToken = FcmService().fcmToken;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await apiService.removeDeviceTokenApi(fcmToken);
      }
      if (apiService.authToken != null) {
        // Logout lokal saja sudah cukup untuk membersihkan sesi mobile
        apiService.saveAuthToken(null);
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 150));
    _currentUser = null;
    _token = null;
    notifyListeners();
  }

  /// Mengubah kata sandi pengguna langsung pada database backend
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) {
      throw const AuthException('Sesi telah berakhir. Silakan login kembali.');
    }

    try {
      return await ApiService().changePasswordApi(currentPassword, newPassword);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Gagal mengubah kata sandi: $e');
    }
  }

  void setCurrentUserForTest(AdminUserModel? user, {String? token}) {
    _currentUser = user;
    _token = token ?? (user != null ? 'test-token' : null);
    notifyListeners();
  }
}
