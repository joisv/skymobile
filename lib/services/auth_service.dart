import 'package:flutter/foundation.dart';
import '../models/admin_user_model.dart';
import 'api_service.dart';

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
    final role = _currentUser?.role.toLowerCase() ?? '';
    return role.contains('superadmin') ||
        role.contains('super-admin') ||
        role.contains('manager') ||
        role.contains('owner');
  }

  bool get isAffiliateAdmin {
    final role = _currentUser?.role.toLowerCase() ?? '';
    return role.contains('affiliate-admin') ||
        role.contains('affiliate_admin') ||
        role.contains('affiliate') ||
        role.contains('cabang');
  }

  bool get isAdmin {
    final role = _currentUser?.role.toLowerCase() ?? '';
    final name = _currentUser?.name.toLowerCase() ?? '';
    final email = _currentUser?.email.toLowerCase() ?? '';
    return isSuperAdmin ||
        role.contains('admin') ||
        name.contains('admin') ||
        email.contains('admin') ||
        isAffiliateAdmin;
  }

  bool get isStaff {
    if (!isAuthenticated) return false;
    return !isSuperAdmin && !isAdmin;
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
        } else {
          apiService.saveAuthToken(null);
        }
      } catch (_) {
        // Assume network error, keep token if exists but user might be null unless cached
      }
    }
  }

  /// Memeriksa apakah suatu rute diizinkan untuk diakses
  bool canAccessRoute(String routeName) {
    if (routeName == '/login') {
      return true;
    }
    return isAuthenticated;
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
