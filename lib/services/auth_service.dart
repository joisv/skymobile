import 'dart:async';
import 'dart:io';
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

  /// Restore session from persistent storage & backend API
  Future<void> restoreSession() async {
    final apiService = ApiService();
    // 1. Muat SharedPreferences (token & base URL)
    await apiService.loadPrefs();

    // 2. Periksa apakah terdapat token autentikasi tersimpan
    if (apiService.authToken != null && apiService.authToken!.isNotEmpty) {
      // 3. Langsung pulihkan sesi pengguna dari penyimpanan lokal jika tersedia
      final cachedUserMap = await apiService.loadCachedUserProfile();
      if (cachedUserMap != null) {
        _currentUser = AdminUserModel.fromJson(cachedUserMap);
        _token = apiService.authToken;
        notifyListeners();
      }

      // 4. Validasi keaktifan token ke backend REST API
      Future<void> validateTokenOnline() async {
        try {
          final response = await apiService.getMe();
          if (response != null && response['data'] != null) {
            final userMap = response['data'] as Map<String, dynamic>;
            _currentUser = AdminUserModel.fromJson(userMap);
            _token = apiService.authToken;
            await apiService.saveUserProfile(userMap);
            notifyListeners();

            final fcmToken = FcmService().fcmToken;
            if (fcmToken != null && fcmToken.isNotEmpty) {
              unawaited(apiService.registerDeviceTokenApi(fcmToken, platform: 'android'));
            }
          } else if (_currentUser == null) {
            // Jika tidak ada cache dan backend mengembalikan respons kosong
            await apiService.clearAuth();
            _token = null;
          }
        } on ApiException catch (e) {
          // Jika server menolak token (401 Unauthorized / 403 Forbidden), bersihkan sesi
          if (e.statusCode == 401 || e.statusCode == 403) {
            await apiService.clearAuth();
            _currentUser = null;
            _token = null;
            notifyListeners();
          }
        } catch (_) {
          // Gangguan jaringan / offline: pertahankan sesi yang sudah dipulihkan dari cache lokal
        }
      }

      if (cachedUserMap != null) {
        // Jalankan validasi secara asinkron agar UI terbuka secara instan tanpa menunggu latensi jaringan
        unawaited(validateTokenOnline());
      } else {
        await validateTokenOnline();
      }
    } else {
      _currentUser = null;
      _token = null;
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
    '/admin/assign-role',
    'admin/assign-role',
    '/assign-role',
    'assign-role',
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

  bool get _isTestEnvironment {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static final List<Map<String, dynamic>> _testCredentials = [
    {
      'email': 'admin@skyrental.id',
      'username': 'admin',
      'password': 'password123',
      'user': const AdminUserModel(
        id: 1,
        name: 'Admin SKYRental',
        email: 'admin@skyrental.id',
        phone: '+62 812-3456-7890',
        role: 'Superadmin / Manager Outlet',
        outletName: 'Outlet Utama Malioboro',
        shiftName: 'Shift Pagi (08:00 - 16:00)',
        isActive: true,
      ),
    },
    {
      'email': 'kasir@skyrental.id',
      'username': 'kasir',
      'password': 'password123',
      'user': const AdminUserModel(
        id: 2,
        name: 'Budi Santoso',
        email: 'kasir@skyrental.id',
        phone: '+62 813-9876-5432',
        role: 'Staff Kasir & Front Office',
        outletName: 'Outlet Utama Malioboro',
        shiftName: 'Shift Pagi (08:00 - 16:00)',
        isActive: true,
      ),
    },
  ];

  /// Melakukan autentikasi pengguna langsung ke backend database SKYRental
  Future<AdminUserModel> login({
    required String emailOrUsername,
    required String password,
    bool rememberMe = true,
  }) async {
    if (_isTestEnvironment) {
      final normalizedInput = emailOrUsername.trim().toLowerCase();
      final normalizedPass = password.trim();

      final match = _testCredentials.firstWhere(
        (c) =>
            ((c['email'] as String).toLowerCase() == normalizedInput ||
                (c['username'] as String).toLowerCase() == normalizedInput) &&
            c['password'] == normalizedPass,
        orElse: () => {},
      );

      if (match.isEmpty) {
        throw const AuthException(
          'Email/username atau kata sandi tidak valid. Periksa kembali data login Anda.',
        );
      }

      final user = match['user'] as AdminUserModel;
      _currentUser = user;
      _token = 'mock-sanctum-token-${user.id}-${DateTime.now().millisecondsSinceEpoch}';
      _rememberMe = rememberMe;

      notifyListeners();
      return user;
    }

    try {
      final apiService = ApiService();
      final apiResult = await apiService.loginApi(emailOrUsername, password);
      if (apiResult['user'] != null) {
        final userMap = apiResult['user'] as Map<String, dynamic>;
        final user = AdminUserModel.fromJson(userMap);
        _currentUser = user;
        _token = apiResult['token']?.toString() ?? 'sanctum-token';
        _rememberMe = rememberMe;

        // Simpan sesi autentikasi secara persisten ke SharedPreferences
        await apiService.saveAuthToken(_token);
        await apiService.saveUserProfile(user.toJson());

        notifyListeners();
        final fcmToken = FcmService().fcmToken;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          unawaited(apiService.registerDeviceTokenApi(fcmToken, platform: 'android'));
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
    final apiService = ApiService();
    try {
      final fcmToken = FcmService().fcmToken;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await apiService.removeDeviceTokenApi(fcmToken);
      }
      if (apiService.authToken != null) {
        // Cabut token pada backend database (Sanctum token revoke)
        await apiService.logoutApi();
      }
    } catch (_) {}

    // Bersihkan token & profil pengguna dari SharedPreferences secara menyeluruh
    await apiService.clearAuth();

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

    if (_isTestEnvironment) {
      final idx = _testCredentials.indexWhere(
        (c) => (c['user'] as AdminUserModel).id == _currentUser!.id,
      );
      if (idx != -1) {
        if (_testCredentials[idx]['password'] != currentPassword) {
          throw const AuthException('Kata sandi saat ini salah.');
        }
        _testCredentials[idx]['password'] = newPassword;
        notifyListeners();
        return true;
      }
      return true;
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
