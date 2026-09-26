import '../models/admin_user_model.dart';
import 'api_service.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
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
  bool get isSuperAdmin =>
      _currentUser?.role.toLowerCase().contains('superadmin') ??
      _currentUser?.role.toLowerCase().contains('manager') ??
      false;

  bool get canAccessFinancials => _currentUser != null;
  bool get canManageInventory => _currentUser != null;
  bool get canModifyShopSettings => isSuperAdmin || (_currentUser != null);

  // Pure Dart Listenable implementation
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  // Mock users database
  final List<Map<String, dynamic>> _credentials = [
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

  Future<AdminUserModel> login({
    required String emailOrUsername,
    required String password,
    bool rememberMe = true,
  }) async {
    // 1. Coba login via REST API backend Skyrent (Sanctum)
    try {
      final apiResult = await ApiService().loginApi(emailOrUsername, password);
      if (apiResult != null && apiResult['user'] != null) {
        final userMap = apiResult['user'] as Map<String, dynamic>;
        final user = AdminUserModel.fromJson(userMap);
        _currentUser = user;
        _token = apiResult['token']?.toString() ?? 'sanctum-token';
        _rememberMe = rememberMe;
        notifyListeners();
        return user;
      }
    } catch (_) {
      // Fallback ke kredensial lokal jika offline
    }

    // 2. Fallback kredensial lokal (untuk mode offline & unit test)
    await Future.delayed(const Duration(milliseconds: 150));

    final normalizedInput = emailOrUsername.trim().toLowerCase();
    final normalizedPass = password.trim();

    final match = _credentials.firstWhere(
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

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (_currentUser == null) {
      throw const AuthException('Sesi telah berakhir. Silakan login kembali.');
    }

    final idx = _credentials.indexWhere(
      (c) => (c['user'] as AdminUserModel).id == _currentUser!.id,
    );

    if (idx != -1) {
      if (_credentials[idx]['password'] != currentPassword) {
        throw const AuthException('Kata sandi saat ini salah.');
      }
      _credentials[idx]['password'] = newPassword;
      notifyListeners();
      return true;
    }

    return true;
  }

  void setCurrentUserForTest(AdminUserModel? user, {String? token}) {
    _currentUser = user;
    _token = token ?? (user != null ? 'test-token' : null);
    notifyListeners();
  }
}
