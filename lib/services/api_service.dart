import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/iphone_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    loadPrefs();
  }

  static const String _prefKeyBaseUrl = 'api_base_url';
  static const String _prefKeyAuthToken = 'api_auth_token';

  static String get _initialBaseUrl {
    if (!kIsWeb) {
      try {
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          return 'http://127.0.0.1:8000/api/v1';
        }
      } catch (_) {}
    }
    return 'http://192.168.1.24:8000/api/v1';
  }

  /// Default API base URL pointing to local Laravel backend or production domain
  String baseUrl = _initialBaseUrl;

  /// Bearer Sanctum auth token
  String? authToken;

  Future<void> loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyBaseUrl);
      if (saved != null && saved.trim().isNotEmpty) {
        baseUrl = saved.trim();
      }
      final savedToken = prefs.getString(_prefKeyAuthToken);
      if (savedToken != null && savedToken.trim().isNotEmpty) {
        authToken = savedToken.trim();
      }
    } catch (_) {}
  }

  /// Memperbarui dan menyimpan Base URL baru (bisa IP lokal maupun domain seperti https://skyrental.id)
  Future<void> setCustomBaseUrl(String inputUrl) async {
    String clean = inputUrl.trim();
    if (clean.isEmpty) return;

    // Normalisasi protokol jika belum ada
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }

    // Bersihkan trailing slash
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }

    // Pastikan berakhiran /api/v1
    if (!clean.endsWith('/api/v1')) {
      if (clean.endsWith('/api')) {
        clean = '$clean/v1';
      } else {
        clean = '$clean/api/v1';
      }
    }

    baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBaseUrl, clean);
  }

  /// Reset base URL ke default sistem
  Future<void> resetBaseUrl() async {
    baseUrl = _initialBaseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyBaseUrl);
    } catch (_) {}
  }

  /// Menguji konektivitas ke server target
  Future<bool> testConnection(String inputUrl) async {
    try {
      String clean = inputUrl.trim();
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
        clean = 'http://$clean';
      }
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
      if (!clean.endsWith('/api/v1')) {
        if (clean.endsWith('/api')) {
          clean = '$clean/v1';
        } else {
          clean = '$clean/api/v1';
        }
      }

      // 1. Coba endpoint /health langsung
      try {
        final healthUri = Uri.parse('$clean/health');
        final healthResp = await http.get(healthUri).timeout(const Duration(seconds: 3));
        if (healthResp.statusCode >= 200 && healthResp.statusCode < 300) {
          return true;
        }
      } catch (_) {}

      // 2. Fallback cek endpoint /ping
      try {
        final pingUri = Uri.parse('$clean/ping');
        final pingResp = await http.get(pingUri).timeout(const Duration(seconds: 2));
        if (pingResp.statusCode >= 200 && pingResp.statusCode < 300) {
          return true;
        }
      } catch (_) {}

      // 3. Fallback cek endpoint /login dengan POST
      // Route POST /login di Laravel akan merespons 422 jika body kosong, atau 200/401.
      // Jika server merespons 404 (Not Found), berarti route tidak tersedia di server tersebut!
      try {
        final uri = Uri.parse('$clean/login');
        final resp = await http.post(
          uri,
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
          body: jsonEncode({'test': true}),
        ).timeout(const Duration(seconds: 3));

        if (resp.statusCode == 200 || resp.statusCode == 422 || resp.statusCode == 401) {
          return true;
        }
      } catch (_) {}

      return false;
    } catch (_) {
      return false;
    }
  }

  void _saveWorkingUrl(String url) {
    baseUrl = url;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefKeyBaseUrl, url);
    }).catchError((_) {});
  }

  void saveAuthToken(String? token) {
    authToken = token;
    SharedPreferences.getInstance().then((prefs) {
      if (token == null) {
        prefs.remove(_prefKeyAuthToken);
      } else {
        prefs.setString(_prefKeyAuthToken, token);
      }
    }).catchError((_) {});
  }

  List<String> get candidateUrls {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return const [];
    }
    final list = <String>[];
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      list.addAll([
        'http://127.0.0.1:8000/api/v1',
        'http://localhost:8000/api/v1',
        'http://skyrent.test/api/v1',
        'http://localhost/api/v1',
        if (!baseUrl.contains('skyrental.id')) baseUrl,
        'http://192.168.1.24:8000/api/v1',
      ]);
    } else {
      // Mobile / Emulator
      // Jika baseUrl bukan skyrental.id, prioritaskan baseUrl yang tersimpan
      if (!baseUrl.contains('skyrental.id')) {
        list.add(baseUrl);
      }
      list.addAll([
        'http://10.0.2.2:8000/api/v1',       // Android Emulator loopback
        'http://192.168.1.24:8000/api/v1',   // Laptop LAN IP
        'http://127.0.0.1:8000/api/v1',
        'http://localhost:8000/api/v1',
        'http://skyrent.test/api/v1',
        'http://localhost/api/v1',
      ]);
      // Jika baseUrl adalah skyrental.id, coba setelah endpoint lokal
      if (baseUrl.contains('skyrental.id')) {
        list.add(baseUrl);
      }
    }
    // Tambahkan domain production sebagai cadangan terakhir
    list.add('https://skyrental.id/api/v1');

    // Return distinct non-empty list
    final seen = <String>{};
    return list.where((u) => u.isNotEmpty && seen.add(u)).toList();
  }

  Map<String, String> _buildHeaders({bool isJson = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  /// Login ke Skyrent backend
  /// POST /api/v1/login
  Future<Map<String, dynamic>> loginApi(String emailOrUsername, String password) async {
    String? lastErrorMessage;
    int? lastStatusCode;

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/login');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode({
            'email': emailOrUsername.trim(),
            'password': password.trim(),
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final Map<String, dynamic> json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            baseUrl = base;
            _saveWorkingUrl(base);
            final data = json['data'] as Map<String, dynamic>;
            if (data['token'] != null) {
              saveAuthToken(data['token'].toString());
            }
            return data;
          }
        } else if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 422) {
          // Server valid merespons (kredensial salah atau validasi input gagal)
          baseUrl = base;
          _saveWorkingUrl(base);
          lastStatusCode = response.statusCode;
          try {
            final Map<String, dynamic> json = jsonDecode(response.body);
            if (json['message'] != null) {
              lastErrorMessage = json['message'].toString();
            } else if (json['errors'] is Map) {
              final errors = json['errors'] as Map;
              if (errors.isNotEmpty && errors.values.first is List && (errors.values.first as List).isNotEmpty) {
                lastErrorMessage = (errors.values.first as List).first.toString();
              }
            }
          } catch (_) {
            lastErrorMessage = 'Login gagal dengan kode HTTP ${response.statusCode}.';
          }

          // Hentikan loop dan lemparkan pesan langsung dari server autentikasi
          throw ApiException(
            lastErrorMessage ?? 'Email/nama pengguna atau kata sandi tidak valid. Silakan periksa kembali.',
            statusCode: response.statusCode,
          );
        } else if (response.statusCode == 404) {
          // Route tidak ditemukan di server candidate ini (misal production belum deploy API atau prefix salah).
          // JANGAN simpan URL ini sebagai working URL dan JANGAN lempar pesan 404 mentah ke user!
          debugPrint('API candidate $base mengembalikan 404 pada /login. Melanjutkan pencarian server...');
          if (baseUrl == base) {
            baseUrl = _initialBaseUrl;
          }
          continue;
        } else {
          // Status code lain (misal 500, 502, 503)
          lastStatusCode = response.statusCode;
          try {
            final Map<String, dynamic> json = jsonDecode(response.body);
            if (json['message'] != null) {
              lastErrorMessage = json['message'].toString();
            }
          } catch (_) {}
        }
      } catch (e) {
        if (e is ApiException) rethrow;
        // Coba url berikutnya jika connection timeout / refused
      }
    }

    if (lastErrorMessage != null) {
      throw ApiException(lastErrorMessage, statusCode: lastStatusCode);
    }

    throw ApiException(
      'Tidak dapat terhubung ke server backend database SkyRental. Pastikan backend aktif (misal php artisan serve) dan URL server dapat dijangkau.',
    );
  }

  /// Mengubah password akun melalui REST API backend
  /// POST /api/v1/change-password
  Future<bool> changePasswordApi(String currentPassword, String newPassword) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/change-password');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode({
            'current_password': currentPassword,
            'new_password': newPassword,
            'password': newPassword,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }

        try {
          final Map<String, dynamic> json = jsonDecode(response.body);
          String errorMsg = json['message']?.toString() ?? 'Gagal mengubah kata sandi.';
          if (json['errors'] is Map) {
            final errors = json['errors'] as Map;
            if (errors.values.isNotEmpty) {
              final first = errors.values.first;
              if (first is List && first.isNotEmpty) {
                errorMsg = first.first.toString();
              }
            }
          }
          throw ApiException(errorMsg, statusCode: response.statusCode);
        } catch (e) {
          if (e is ApiException) rethrow;
          throw ApiException('Gagal mengubah kata sandi (Kode: ${response.statusCode})');
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
    }
    throw ApiException('Tidak dapat terhubung ke server untuk mengubah kata sandi.');
  }

  /// Ambil data user yang sedang login
  /// GET /api/v1/me
  Future<Map<String, dynamic>?> getMe() async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/me');
        final response = await http.get(
          uri,
          headers: _buildHeaders(),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return json;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mendapatkan data dashboard operasional langsung dari API
  /// GET /api/v1/dashboard
  Future<Map<String, dynamic>?> getDashboardData() async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/dashboard');
        final response = await http.get(
          uri,
          headers: _buildHeaders(),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final Map<String, dynamic> json = jsonDecode(response.body);
          if (json['status'] == 'success' || json['data'] != null) {
            _saveWorkingUrl(base);
            return json;
          }
        }
      } catch (_) {
        // Coba url berikutnya
      }
    }
    return null;
  }

  /// Mendapatkan daftar unit iPhone yang tersedia langsung dari API backend
  /// GET /api/v1/iphones/available?q={query}
  ///
  /// Mengembalikan list kosong jika request berhasil tetapi memang tidak ada
  /// unit yang tersedia, dan null jika seluruh kandidat host gagal dihubungi.
  Future<List<IphoneModel>?> getAvailableIphones({String? query}) async {
    for (final base in candidateUrls) {
      try {
        final qParams = <String, String>{};
        if (query != null && query.trim().isNotEmpty) {
          qParams['q'] = query.trim();
        }

        final uri = Uri.parse('$base/iphones/available').replace(
          queryParameters: qParams.isNotEmpty ? qParams : null,
        );

        final response = await http.get(
          uri,
          headers: _buildHeaders(),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final Map<String, dynamic> json = jsonDecode(response.body);
          if (json['data'] is List) {
            final list = (json['data'] as List)
                .map((item) => IphoneModel.fromJson(item as Map<String, dynamic>))
                .toList();
            // Cache successful working base URL
            baseUrl = base;
            return list;
          }
        }
      } catch (_) {
        // Continue to next candidate URL
      }
    }

    return null;
  }

  /// Mengambil laporan penjualan dari API backend
  /// GET /api/v1/reports/sales
  Future<Map<String, dynamic>?> getSalesReportApi({
    String? period,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    int? perPage,
  }) async {
    for (final base in candidateUrls) {
      try {
        final queryParams = <String, String>{};
        if (period != null) queryParams['period'] = period;
        if (paymentMethod != null) queryParams['payment_method'] = paymentMethod;
        if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
        if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
        if (page != null) queryParams['page'] = page.toString();
        if (perPage != null) queryParams['per_page'] = perPage.toString();

        final uri = Uri.parse('$base/reports/sales').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
        final response = await http.get(
          uri,
          headers: _buildHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded['status'] == 'success' || decoded['summary'] != null) {
            return decoded;
          }
        }
      } catch (_) {
        // Abaikan dan coba URL berikutnya
      }
    }
    return null;
  }

  /// Mengambil daftar booking dari API backend
  /// GET /api/v1/bookings
  Future<List<Map<String, dynamic>>?> getBookingsApi({
    String? query,
    String? status,
    String? paymentStatus,
  }) async {
    for (final base in candidateUrls) {
      try {
        final queryParams = <String, String>{};
        if (query != null && query.trim().isNotEmpty) queryParams['search'] = query.trim();
        if (status != null && status.isNotEmpty && status != 'all' && status != 'semua') {
          queryParams['status'] = status;
        }
        if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'all' && paymentStatus != 'semua') {
          queryParams['payment_status'] = paymentStatus;
        }

        final uri = Uri.parse('$base/bookings').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['data'] is List) {
            return (decoded['data'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil detail booking dari API backend
  /// GET /api/v1/bookings/{idOrCode}
  Future<Map<String, dynamic>?> getBookingDetailApi(String idOrCode) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/bookings/$idOrCode');
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['data'] is Map<String, dynamic>) {
            return decoded['data'] as Map<String, dynamic>;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Membuat booking baru via API backend
  /// POST /api/v1/bookings
  Future<Map<String, dynamic>?> createBookingApi({
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? address,
    required int iphoneId,
    required DateTime startDate,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required int duration,
    required double price,
    required double depositAmount,
    required String jaminanType,
    String pickupType = 'Outlet',
    String paymentStatus = 'paid',
    required double amountPaid,
    String paymentMethod = 'QRIS Kasir',
    String? notes,
  }) async {
    final startStr =
        "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
    final endStr =
        "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

    final payload = {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'address': address ?? 'Datang Langsung (Walk-in Outlet)',
      'iphone_id': iphoneId,
      'start_booking_date': startStr,
      'end_booking_date': endStr,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'price': price,
      'deposit_amount': depositAmount,
      'deposit': depositAmount,
      'jaminan_type': jaminanType,
      'pickup_type': pickupType,
      'payment_status': paymentStatus,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'notes': notes,
      'send_whatsapp': false, // Notifikasi WA dikirim 1x saat konfirmasi pembayaran di kasir
    };

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/bookings');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          return jsonDecode(response.body) as Map<String, dynamic>;
        }

        // Jika backend merespon (misal validasi 422/400), jangan retry ke host lain
        if (response.statusCode >= 400 && response.statusCode < 500) {
          try {
            final decoded = jsonDecode(response.body);
            final msg = decoded['message'] ?? decoded['error'];
            if (msg != null && msg.toString().trim().isNotEmpty) {
              throw Exception(msg.toString().trim());
            }
          } catch (e) {
            if (e is Exception && !e.toString().contains('FormatException')) {
              rethrow;
            }
          }
          return null;
        }
      } catch (_) {
        // Coba kandidat URL berikutnya hanya jika koneksi fisik gagal
      }
    }

    return null;
  }

  /// Menghapus booking dari backend
  /// DELETE /api/v1/bookings/{idOrCode}
  Future<bool> deleteBooking(String idOrCode) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/bookings/$idOrCode');
        final response = await http.delete(
          uri,
          headers: _buildHeaders(),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 || response.statusCode == 204) {
          _saveWorkingUrl(base);
          return true;
        }
      } catch (_) {
        // Coba url berikutnya
      }
    }
    return false;
  }

  /// Memvalidasi apakah nomor WhatsApp terdaftar via Fonnte API di backend
  /// POST /api/v1/validate-whatsapp
  Future<Map<String, dynamic>> validateWhatsApp(String phone) async {
    final payload = {'phone': phone};

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/validate-whatsapp');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 || response.statusCode == 422 || response.statusCode == 400) {
          _saveWorkingUrl(base);
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data;
        }
      } catch (_) {
        // Coba url berikutnya
      }
    }

    // Fallback jika backend offline: jangan blokir kasir
    return {
      'status': 'offline',
      'registered': true,
      'message': 'Mode offline: validasi WhatsApp dilewati.',
    };
  }

  /// Mencatat pembayaran sewa (Pelunasan / DP) via REST API backend
  /// POST /api/v1/bookings/{bookingCode}/payments
  Future<Map<String, dynamic>?> recordPaymentApi({
    required String bookingCode,
    required double amount,
    required double pay,
    required String paymentMethod,
    required String type,
    DateTime? paidAt,
    String? note,
    bool sendWhatsapp = true,
  }) async {
    final payload = {
      'amount': amount,
      'pay': pay,
      'payment_method': paymentMethod,
      'type': type,
      'paid_at': (paidAt ?? DateTime.now()).toIso8601String(),
      'note': note ?? 'Pembayaran kasir via ${paymentMethod.toUpperCase()}',
      'send_whatsapp': sendWhatsapp,
    };

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/bookings/$bookingCode/payments');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          return jsonDecode(response.body) as Map<String, dynamic>;
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          return null;
        }
      } catch (_) {
        // Coba kandidat URL berikutnya hanya jika koneksi fisik gagal
      }
    }

    return null;
  }

  /// Mengambil daftar metode pembayaran aktif dari database
  /// GET /api/v1/payment-methods
  Future<List<Map<String, dynamic>>?> getPaymentMethods() async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/payment-methods');
        final response = await http.get(
          uri,
          headers: _buildHeaders(),
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic> && data['data'] is List) {
            return List<Map<String, dynamic>>.from(data['data']);
          } else if (data is List) {
            return List<Map<String, dynamic>>.from(data);
          }
        }
      } catch (_) {
        // Coba kandidat URL berikutnya
      }
    }

    return null;
  }

  /// Inspeksi pengembalian (Mendapatkan denda telat & status dari backend)
  /// GET /api/v1/returns/inspect/{bookingIdOrCode}
  Future<Map<String, dynamic>?> inspectReturn(String bookingCode) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/returns/inspect/$bookingCode');
        final response = await http.get(
          uri,
          headers: _buildHeaders(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          return jsonDecode(response.body) as Map<String, dynamic>;
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          return null;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Menyelesaikan pengembalian via API backend
  /// POST /api/v1/returns/complete/{bookingIdOrCode}
  Future<Map<String, dynamic>?> completeReturnApi({
    required String bookingCode,
    required Map<String, dynamic> payload,
  }) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/returns/complete/$bookingCode');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          return jsonDecode(response.body) as Map<String, dynamic>;
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          return null;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil daftar semua unit iPhone beserta ringkasan status dari backend
  /// GET /api/v1/iphones
  Future<Map<String, dynamic>?> getAllIphonesApi({
    String? query,
    String? status,
    String? model,
    String? branch,
    int? affiliateId,
  }) async {
    for (final base in candidateUrls) {
      try {
        final qParams = <String, String>{};
        if (query != null && query.trim().isNotEmpty) qParams['q'] = query.trim();
        if (status != null && status.isNotEmpty && status.toLowerCase() != 'semua' && status.toLowerCase() != 'all') {
          qParams['status'] = status;
        }
        if (model != null && model.isNotEmpty && model.toLowerCase() != 'semua' && model.toLowerCase() != 'all') {
          qParams['model'] = model;
        }
        if (branch != null && branch.isNotEmpty && !branch.toLowerCase().contains('semua')) {
          qParams['branch'] = branch.replaceAll('•', '').trim();
        }
        if (affiliateId != null) {
          qParams['affiliate_id'] = affiliateId.toString();
        }

        final uri = Uri.parse('$base/iphones').replace(
          queryParameters: qParams.isNotEmpty ? qParams : null,
        );
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
            return decoded;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Menambahkan unit iPhone baru ke backend
  /// POST /api/v1/iphones
  Future<Map<String, dynamic>?> createIphoneApi(Map<String, dynamic> data) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/iphones');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
            return decoded;
          }
        } else if (response.statusCode >= 400) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          String msg = decoded['message']?.toString() ?? 'Gagal menambahkan unit iPhone.';
          Map<String, dynamic>? errorsMap;
          if (decoded is Map<String, dynamic> && decoded['errors'] is Map) {
            errorsMap = (decoded['errors'] as Map).cast<String, dynamic>();
            final errorList = <String>[];
            for (final entry in errorsMap.entries) {
              if (entry.value is List && (entry.value as List).isNotEmpty) {
                errorList.add((entry.value as List).map((e) => e.toString()).join(', '));
              } else if (entry.value is String && (entry.value as String).isNotEmpty) {
                errorList.add(entry.value.toString());
              }
            }
            if (errorList.isNotEmpty) {
              msg = errorList.join('\n');
            }
          }
          throw ApiException(msg, statusCode: response.statusCode, errors: errorsMap);
        }
      } catch (e) {
        if (e is ApiException) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Memperbarui unit iPhone di backend
  /// PUT /api/v1/iphones/{idOrAssetCode}
  Future<Map<String, dynamic>?> updateIphoneApi(String idOrAssetCode, Map<String, dynamic> data) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/iphones/$idOrAssetCode');
        final response = await http.put(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
            return decoded;
          }
        } else if (response.statusCode >= 400) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          String msg = decoded['message']?.toString() ?? 'Gagal memperbarui unit iPhone.';
          Map<String, dynamic>? errorsMap;
          if (decoded is Map<String, dynamic> && decoded['errors'] is Map) {
            errorsMap = (decoded['errors'] as Map).cast<String, dynamic>();
            final errorList = <String>[];
            for (final entry in errorsMap.entries) {
              if (entry.value is List && (entry.value as List).isNotEmpty) {
                errorList.add((entry.value as List).map((e) => e.toString()).join(', '));
              } else if (entry.value is String && (entry.value as String).isNotEmpty) {
                errorList.add(entry.value.toString());
              }
            }
            if (errorList.isNotEmpty) {
              msg = errorList.join('\n');
            }
          }
          throw ApiException(msg, statusCode: response.statusCode, errors: errorsMap);
        }
      } catch (e) {
        if (e is ApiException) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Mengambil daftar poster gallery dari backend
  /// GET /api/v1/galleries
  Future<List<Map<String, dynamic>>?> getGalleriesApi() async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/galleries');
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['status'] == 'success' && decoded['data'] is List) {
            return (decoded['data'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengunggah gambar ke backend galeri dari memori internal / file lokal
  /// POST /api/v1/galleries/upload
  Future<Map<String, dynamic>?> uploadGalleryImageApi({
    required List<int> bytes,
    required String filename,
  }) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/galleries/upload');
        final request = http.MultipartRequest('POST', uri);
        final headers = _buildHeaders();
        request.headers.addAll(headers);

        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: filename,
          ),
        );

        final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['data'] is Map<String, dynamic>) {
            return decoded['data'] as Map<String, dynamic>;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Memperbarui status unit iPhone di backend
  /// POST /api/v1/iphones/{idOrAssetCode}/status
  Future<bool> updateUnitStatusApi(
    String idOrAssetCode,
    String status, {
    int? batteryHealth,
    String? notes,
  }) async {
    final payload = {
      'status': status,
      if (batteryHealth != null) 'battery_health': batteryHealth,
      if (notes != null) 'notes': notes,
    };

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/iphones/$idOrAssetCode/status');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Mengambil jadwal sewa unit dari backend
  /// GET /api/v1/iphones/{idOrAssetCode}/schedule
  Future<Map<String, dynamic>?> getUnitScheduleApi(
    String idOrAssetCode, {
    String? timeframe,
  }) async {
    for (final base in candidateUrls) {
      try {
        final qParams = <String, String>{};
        if (timeframe != null && timeframe.isNotEmpty && timeframe.toLowerCase() != 'semua') {
          qParams['timeframe'] = timeframe;
        }
        final uri = Uri.parse('$base/iphones/$idOrAssetCode/schedule').replace(
          queryParameters: qParams.isNotEmpty ? qParams : null,
        );
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
            return decoded;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Memeriksa ketersediaan unit untuk penambahan durasi jam sewa
  /// GET /api/v1/bookings/{idOrCode}/can-extend?hours={hours}
  Future<Map<String, dynamic>?> checkExtendAvailability(String idOrCode, int hours) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/bookings/$idOrCode/can-extend').replace(
          queryParameters: {'hours': hours.toString()},
        );
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 || response.statusCode == 422) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Memperpanjang durasi jam sewa (Tambah Jam) pada booking
  /// POST /api/v1/bookings/{idOrCode}/extend
  Future<Map<String, dynamic>?> extendBookingApi(
    String idOrCode, {
    required int hours,
    int? durationId,
    int? multiplier,
    double? price,
    String? paymentMethod,
    double? pay,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'hours': hours,
      if (durationId != null) 'duration_id': durationId,
      if (multiplier != null) 'multiplier': multiplier,
      if (price != null) 'price': price,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (pay != null) 'pay': pay,
      if (note != null) 'note': note,
    };

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/bookings/$idOrCode/extend');
        final response = await http.post(
          uri,
          headers: _buildHeaders(),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['status'] == 'success') {
            return decoded;
          }
        } else if (response.statusCode == 422) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Unit tidak dapat diperpanjang karena jadwal bertabrakan.';
          throw Exception(msg.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Mengambil daftar mitra affiliate
  /// GET /api/v1/affiliates
  Future<Map<String, dynamic>?> getAffiliatesApi({String? search, bool? isActive}) async {
    for (final base in candidateUrls) {
      try {
        final queryParams = <String, String>{};
        if (search != null && search.trim().isNotEmpty) {
          queryParams['search'] = search.trim();
        }
        if (isActive != null) {
          queryParams['is_active'] = isActive.toString();
        }

        final uri = Uri.parse('$base/affiliates').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil detail mitra affiliate
  /// GET /api/v1/affiliates/{id}
  Future<Map<String, dynamic>?> getAffiliateDetailApi(int id) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/$id');
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as Map<String, dynamic>?;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Membuat mitra affiliate baru
  /// POST /api/v1/affiliates
  Future<Map<String, dynamic>?> createAffiliateApi(Map<String, dynamic> data) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as Map<String, dynamic>?;
          }
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          String msg = decoded['message'] ?? 'Gagal membuat mitra affiliate.';
          if (decoded['errors'] is Map) {
            final errMap = decoded['errors'] as Map;
            final details = errMap.values
                .expand((v) => v is List ? v : [v])
                .map((e) => e.toString())
                .join('\n');
            if (details.isNotEmpty) {
              msg = details;
            }
          }
          throw Exception(msg);
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Memperbarui data mitra affiliate
  /// PUT /api/v1/affiliates/{id}
  Future<Map<String, dynamic>?> updateAffiliateApi(int id, Map<String, dynamic> data) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/$id');
        final response = await http.put(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as Map<String, dynamic>?;
          }
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          String msg = decoded['message'] ?? 'Gagal memperbarui mitra affiliate.';
          if (decoded['errors'] is Map) {
            final errMap = decoded['errors'] as Map;
            final details = errMap.values
                .expand((v) => v is List ? v : [v])
                .map((e) => e.toString())
                .join('\n');
            if (details.isNotEmpty) {
              msg = details;
            }
          }
          throw Exception(msg);
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Menghapus mitra affiliate
  /// DELETE /api/v1/affiliates/{id}
  Future<bool> deleteAffiliateApi(int id) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/$id');
        final response = await http.delete(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          return true;
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Gagal menghapus affiliate.';
          throw Exception(msg.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
    }
    return false;
  }

  /// Mengambil riwayat transfer iPhone
  /// GET /api/v1/affiliates/transfers
  Future<List<dynamic>?> getIphoneTransfersApi({String? status, int? affiliateId, String? type}) async {
    for (final base in candidateUrls) {
      try {
        final queryParams = <String, String>{};
        if (status != null && status.isNotEmpty) queryParams['status'] = status;
        if (affiliateId != null) queryParams['affiliate_id'] = affiliateId.toString();
        if (type != null) queryParams['type'] = type;

        final uri = Uri.parse('$base/affiliates/transfers').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as List<dynamic>?;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Membuat mutasi/transfer iPhone baru ke cabang
  /// POST /api/v1/affiliates/transfers
  Future<Map<String, dynamic>?> createIphoneTransferApi({
    required int iphoneId,
    required int toAffiliateId,
    int? fromAffiliateId,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'iphone_id': iphoneId,
      'to_affiliate_id': toAffiliateId,
      if (fromAffiliateId != null) 'from_affiliate_id': fromAffiliateId,
      if (notes != null) 'notes': notes,
    };

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/transfers');
        final response = await http.post(
          uri,
          headers: _buildHeaders(),
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded;
          }
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Gagal membuat transfer iPhone.';
          throw Exception(msg.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Menerima mutasi iPhone (konfirmasi penerimaan)
  /// POST /api/v1/affiliates/transfers/{id}/accept
  Future<Map<String, dynamic>?> acceptIphoneTransferApi(int transferId) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/transfers/$transferId/accept');
        final response = await http.post(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded;
          }
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Gagal menerima iPhone.';
          throw Exception(msg.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Mengambil rekap pendapatan affiliate
  /// GET /api/v1/affiliates/{id}/revenue
  Future<Map<String, dynamic>?> getAffiliateRevenueApi(int id, {String? startDate, String? endDate}) async {
    for (final base in candidateUrls) {
      try {
        final queryParams = <String, String>{};
        if (startDate != null) queryParams['start_date'] = startDate;
        if (endDate != null) queryParams['end_date'] = endDate;

        final uri = Uri.parse('$base/affiliates/$id/revenue').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as Map<String, dynamic>?;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil daftar unit iPhone cabang affiliate
  /// GET /api/v1/affiliates/{id}/iphones
  Future<List<dynamic>?> getAffiliateIphonesApi(int id) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/$id/iphones');
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as List<dynamic>?;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil daftar booking cabang affiliate
  /// GET /api/v1/affiliates/{id}/bookings
  Future<List<dynamic>?> getAffiliateBookingsApi(int id, {String? status}) async {
    for (final base in candidateUrls) {
      try {
        final queryParams = <String, String>{};
        if (status != null && status.isNotEmpty) queryParams['status'] = status;

        final uri = Uri.parse('$base/affiliates/$id/bookings').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as List<dynamic>?;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil daftar pengguna yang ditugaskan di affiliate
  /// GET /api/v1/affiliates/{id}/users
  Future<List<dynamic>?> getAffiliateUsersApi(int id) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/$id/users');
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as List<dynamic>?;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil daftar seluruh pengguna sistem untuk ditugaskan
  /// GET /api/v1/affiliates/{id}/available-users
  Future<List<dynamic>?> getAvailableUsersForAffiliateApi(int id, {String? search}) async {
    for (final base in candidateUrls) {
      try {
        final queryParams = <String, String>{};
        if (search != null && search.trim().isNotEmpty) {
          queryParams['search'] = search.trim();
        }

        final uri = Uri.parse('$base/affiliates/$id/available-users').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null,
        );
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as List<dynamic>?;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Menugaskan user ke affiliate
  /// POST /api/v1/affiliates/{id}/users
  Future<List<dynamic>?> assignUsersToAffiliateApi(int id, List<String> userIds) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/$id/users');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode({'user_ids': userIds}),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as List<dynamic>?;
          }
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Gagal menugaskan user ke affiliate.';
          throw Exception(msg.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
    }
    return null;
  }

  /// Melepas penugasan user dari affiliate
  /// DELETE /api/v1/affiliates/{id}/users/{userId}
  Future<bool> removeUserFromAffiliateApi(int id, String userId) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/affiliates/$id/users/$userId');
        final response = await http.delete(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          return true;
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Gagal melepas user dari affiliate.';
          throw Exception(msg.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatException')) {
          rethrow;
        }
      }
    }
    return false;
  }

  /// Mengambil daftar pengguna sistem
  /// GET /api/v1/users
  Future<List<Map<String, dynamic>>?> getUsersApi({String? search, String? role, int page = 1}) async {
    for (final base in candidateUrls) {
      try {
        final queryParams = <String, String>{};
        if (search != null && search.trim().isNotEmpty) {
          queryParams['search'] = search.trim();
        }
        if (role != null && role.isNotEmpty && role != 'all' && role != 'semua') {
          queryParams['role'] = role;
        }
        if (page > 1) {
          queryParams['page'] = page.toString();
        }

        final uri = Uri.parse('$base/users').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['data'] is List) {
            return (decoded['data'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil daftar role yang tersedia
  /// GET /api/v1/roles
  Future<List<Map<String, dynamic>>?> getRolesApi() async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/roles');
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['data'] is List) {
            return (decoded['data'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Mengambil daftar semua permissions hak akses
  /// GET /api/v1/permissions
  Future<List<Map<String, dynamic>>?> getPermissionsApi() async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/permissions');
        final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['data'] is List) {
            return (decoded['data'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Menetapkan / mengubah role dan permissions pengguna
  /// POST /api/v1/users/{userId}/assign-role
  Future<bool> assignUserRoleApi(String userId, String? role, {List<String>? permissions}) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/users/$userId/assign-role');
        final body = <String, dynamic>{
          if (role != null && role.isNotEmpty) 'role': role,
          if (permissions != null) 'permissions': permissions,
        };

        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          return true;
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Gagal menetapkan role dan permissions pengguna.';
          throw ApiException(msg.toString(), statusCode: response.statusCode);
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
    }
    return false;
  }

  /// Menambahkan pengguna baru
  /// POST /api/v1/users
  Future<Map<String, dynamic>> createUserApi({
    required String name,
    required String email,
    required String password,
    String? role,
  }) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/users');
        final response = await http.post(
          uri,
          headers: _buildHeaders(isJson: true),
          body: jsonEncode({
            'name': name.trim(),
            'email': email.trim(),
            'password': password.trim(),
            if (role != null && role.isNotEmpty && role != '-') 'role': role,
          }),
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 201 || response.statusCode == 200) {
          _saveWorkingUrl(base);
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['data'] != null) {
            return decoded['data'] as Map<String, dynamic>;
          }
          return decoded as Map<String, dynamic>;
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Gagal membuat user baru.';
          throw ApiException(msg.toString(), statusCode: response.statusCode);
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
    }
    throw ApiException('Tidak dapat terhubung ke server untuk membuat pengguna.');
  }

  /// Menghapus pengguna dari sistem
  /// DELETE /api/v1/users/{userId}
  Future<bool> deleteUserApi(String userId) async {
    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base/users/$userId');
        final response = await http.delete(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          _saveWorkingUrl(base);
          return true;
        } else if (response.statusCode >= 400) {
          final decoded = jsonDecode(response.body);
          final msg = decoded['message'] ?? 'Gagal menghapus pengguna.';
          throw ApiException(msg.toString(), statusCode: response.statusCode);
        }
      } catch (e) {
        if (e is ApiException) rethrow;
      }
    }
    return false;
  }
}

