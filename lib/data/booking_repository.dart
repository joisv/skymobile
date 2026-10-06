import 'dart:math';
import '../models/admin_user_model.dart';
import '../models/affiliate_model.dart';
import '../models/affiliate_revenue_model.dart';
import '../models/affiliate_user_model.dart';
import '../models/booking_model.dart';
import '../models/iphone_model.dart';
import '../models/iphone_transfer_model.dart';
import '../models/notification_model.dart';
import '../models/payment_model.dart';
import '../models/receipt_model.dart';
import '../models/user_role_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import 'mock_booking_data.dart';
import 'mock_receipt_data.dart';

enum BookingSortBy {
  scheduleAsc,
  newest,
  priceDesc;

  String get label {
    switch (this) {
      case BookingSortBy.scheduleAsc:
        return 'Jadwal Terdekat';
      case BookingSortBy.newest:
        return 'Booking Terbaru';
      case BookingSortBy.priceDesc:
        return 'Biaya Terbesar';
    }
  }
}

class BookingFilterParams {
  final String? query;
  final BookingStatus? statusFilter;
  final PaymentStatus? paymentFilter;
  final String? pickupTypeFilter;
  final bool onlyToday;
  final BookingSortBy sortBy;

  const BookingFilterParams({
    this.query,
    this.statusFilter,
    this.paymentFilter,
    this.pickupTypeFilter,
    this.onlyToday = false,
    this.sortBy = BookingSortBy.scheduleAsc,
  });

  bool get hasActiveFilter =>
      (query != null && query!.trim().isNotEmpty) ||
      statusFilter != null ||
      paymentFilter != null ||
      pickupTypeFilter != null ||
      onlyToday;

  int get activeFilterCount {
    int count = 0;
    if (statusFilter != null) count++;
    if (paymentFilter != null) count++;
    if (pickupTypeFilter != null) count++;
    if (onlyToday) count++;
    return count;
  }

  BookingFilterParams copyWith({
    String? query,
    BookingStatus? Function()? statusFilter,
    PaymentStatus? Function()? paymentFilter,
    String? Function()? pickupTypeFilter,
    bool? onlyToday,
    BookingSortBy? sortBy,
  }) {
    return BookingFilterParams(
      query: query ?? this.query,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      paymentFilter: paymentFilter != null ? paymentFilter() : this.paymentFilter,
      pickupTypeFilter: pickupTypeFilter != null ? pickupTypeFilter() : this.pickupTypeFilter,
      onlyToday: onlyToday ?? this.onlyToday,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class BookingRepository {
  final ApiService _apiService = ApiService();
  final List<BookingModel> _bookings = List.from(MockBookingData.items);
  final List<IphoneModel> _inventory = [];
  Map<String, int>? _unitSummaryCache;
  bool _hasFetchedFromApi = false;

  /// Daftar unit iPhone yang saat ini tersimpan dalam cache inventaris
  List<IphoneModel> get inventory => (_hasFetchedFromApi || _inventory.isNotEmpty) ? _inventory : MockBookingData.inventory;

  Future<List<BookingModel>> getBookings({
    String? query,
    BookingStatus? statusFilter,
    PaymentStatus? paymentFilter,
    String? pickupTypeFilter,
    bool onlyToday = false,
    BookingSortBy sortBy = BookingSortBy.scheduleAsc,
  }) async {
    try {
      final apiList = await ApiService().getBookingsApi(
        query: query,
        status: statusFilter?.name,
        paymentStatus: paymentFilter?.name,
      );
      if (apiList != null) {
        _hasFetchedFromApi = true;
        final parsed = apiList.map((j) => BookingModel.fromJson(j)).toList();
        _bookings.clear();
        _bookings.addAll(parsed);
      }
    } catch (_) {}

    final now = DateTime.now();
    final auth = AuthService();
    final isStaff = auth.isStaff;
    final currentUserId = auth.currentUser?.userIdentifier;

    var filtered = _bookings.where((b) {
      if (isStaff && !auth.canViewAllBookings && currentUserId != null) {
        final bUserId = b.userId?.toLowerCase();
        if (bUserId != null && bUserId.isNotEmpty && bUserId != currentUserId.toLowerCase()) {
          return false;
        }
      }
      if (statusFilter != null && b.status != statusFilter) {
        return false;
      }
      if (paymentFilter != null && b.paymentStatus != paymentFilter) {
        return false;
      }
      if (pickupTypeFilter != null && pickupTypeFilter != 'Semua') {
        if (b.pickupType.toLowerCase() != pickupTypeFilter.toLowerCase()) {
          return false;
        }
      }
      if (onlyToday) {
        final isPickupToday = b.startDate.year == now.year &&
            b.startDate.month == now.month &&
            b.startDate.day == now.day;
        final isReturnToday = b.endDate.year == now.year &&
            b.endDate.month == now.month &&
            b.endDate.day == now.day;
        if (!isPickupToday && !isReturnToday) {
          return false;
        }
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchCode = b.bookingCode.toLowerCase().contains(q);
        final matchName = b.customerName.toLowerCase().contains(q);
        final matchPhone = b.customerPhone.toLowerCase().contains(q);
        final matchEmail = b.customerEmail.toLowerCase().contains(q);
        final matchStatus = b.status.name.toLowerCase().contains(q) || b.status.label.toLowerCase().contains(q);
        final matchPhoneModel = b.iphone.fullName.toLowerCase().contains(q) || b.iphone.name.toLowerCase().contains(q);
        final matchAsset = b.iphone.assetCode.toLowerCase().contains(q);
        final matchSerial = b.iphone.serialNumber.toLowerCase().contains(q);
        final matchUser = (b.userName ?? '').toLowerCase().contains(q);
        if (!matchCode &&
            !matchName &&
            !matchPhone &&
            !matchEmail &&
            !matchStatus &&
            !matchPhoneModel &&
            !matchAsset &&
            !matchSerial &&
            !matchUser) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sorting
    switch (sortBy) {
      case BookingSortBy.scheduleAsc:
        filtered.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;
      case BookingSortBy.newest:
        filtered.sort((a, b) => b.id.compareTo(a.id));
        break;
      case BookingSortBy.priceDesc:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
    }

    return filtered;
  }

  Future<BookingModel?> getBookingByCode(String code) async {
    try {
      final apiDetail = await ApiService().getBookingDetailApi(code);
      if (apiDetail != null) {
        final model = BookingModel.fromJson(apiDetail);
        final idx = _bookings.indexWhere((b) => b.bookingCode == model.bookingCode || b.id == model.id);
        if (idx != -1) {
          _bookings[idx] = model;
        } else {
          _bookings.insert(0, model);
        }
        return model;
      }
    } catch (_) {}

    try {
      return _bookings.firstWhere(
        (b) =>
            b.bookingCode.toLowerCase() == code.trim().toLowerCase() ||
            b.id.toString() == code.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  Map<BookingStatus, int> getStatusCounts() {
    final counts = <BookingStatus, int>{};
    for (final status in BookingStatus.values) {
      counts[status] = _bookings.where((b) => b.status == status).length;
    }
    return counts;
  }

  Future<List<BookingModel>> getRentals() => getActiveRentals();

  /// Mengambil daftar booking yang sedang disewa (rented) untuk halaman pengembalian dengan pencarian dan filter mendalam
  Future<List<BookingModel>> getActiveRentals({
    String? query,
    bool? isOverdueOnly,
    bool? isDueTodayOnly,
    bool? isUpcomingOnly,
    String? modelFilter,
    String? jaminanFilter,
    String sortBy = 'urgent', // 'urgent', 'newest', 'customerAsc', 'depositDesc'
  }) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final now = DateTime(2026, 9, 9, 14, 0); // Mock date 9 September 2026

    var filtered = _bookings.where((b) {
      if (b.status != BookingStatus.rented) return false;

      // Pencarian kata kunci (Multi-kriteria)
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchCode = b.bookingCode.toLowerCase().contains(q);
        final matchCustomer = b.customerName.toLowerCase().contains(q);
        final matchPhone = b.customerPhone.contains(q);
        final matchIphone = b.iphone.name.toLowerCase().contains(q);
        final matchAsset = b.iphone.assetCode.toLowerCase().contains(q);
        final matchSerial = b.iphone.serialNumber.toLowerCase().contains(q);
        final matchJaminan = b.jaminanType.toLowerCase().contains(q);
        if (!matchCode &&
            !matchCustomer &&
            !matchPhone &&
            !matchIphone &&
            !matchAsset &&
            !matchSerial &&
            !matchJaminan) {
          return false;
        }
      }

      final isOverdue = b.endDate.isBefore(now);
      final isDueToday = b.endDate.year == now.year &&
          b.endDate.month == now.month &&
          b.endDate.day == now.day;
      final isUpcoming = b.endDate.isAfter(now) && !isDueToday;

      if (isOverdueOnly == true && !isOverdue) return false;
      if (isDueTodayOnly == true && !isDueToday) return false;
      if (isUpcomingOnly == true && !isUpcoming) return false;

      // Filter Seri iPhone
      if (modelFilter != null && modelFilter != 'Semua' && modelFilter.isNotEmpty) {
        if (!b.iphone.name.toLowerCase().contains(modelFilter.toLowerCase())) {
          return false;
        }
      }

      // Filter Jenis Jaminan
      if (jaminanFilter != null && jaminanFilter != 'Semua' && jaminanFilter.isNotEmpty) {
        if (!b.jaminanType.toLowerCase().contains(jaminanFilter.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    // Pengurutan (Sorting)
    switch (sortBy) {
      case 'urgent':
        filtered.sort((a, b) {
          // Prioritaskan yang terlambat, lalu yang jatuh tempo hari ini, lalu waktu kembali terdekat
          final aOverdue = a.endDate.isBefore(now);
          final bOverdue = b.endDate.isBefore(now);
          if (aOverdue && !bOverdue) return -1;
          if (!aOverdue && bOverdue) return 1;
          return a.endDate.compareTo(b.endDate);
        });
        break;
      case 'newest':
        filtered.sort((a, b) => b.startDate.compareTo(a.startDate));
        break;
      case 'customerAsc':
        filtered.sort((a, b) => a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase()));
        break;
      case 'depositDesc':
        filtered.sort((a, b) => b.deposit.compareTo(a.deposit));
        break;
    }

    return filtered;
  }

  /// Mengambil ringkasan data operasional pengembalian unit
  Map<String, dynamic> getReturnSummary() {
    final now = DateTime(2026, 9, 9, 14, 0);
    final rented = _bookings.where((b) => b.status == BookingStatus.rented).toList();
    final overdue = rented.where((b) => b.endDate.isBefore(now)).toList();
    final dueToday = rented.where((b) =>
        b.endDate.year == now.year &&
        b.endDate.month == now.month &&
        b.endDate.day == now.day).toList();
    final totalDeposit = rented.fold<double>(0, (sum, b) => sum + b.deposit);

    return {
      'totalActiveRentals': rented.length,
      'totalOverdue': overdue.length,
      'totalDueToday': dueToday.length,
      'totalActiveDeposit': totalDeposit,
    };
  }

  Future<List<IphoneModel>> getInventoryUnits({
    String? modelName,
    String? query,
    bool onlyAvailable = true,
  }) async {
    final effectiveAffiliateId = AuthService().isAffiliateScoped ? AuthService().affiliateId : null;

    bool isBookable(IphoneModel unit) {
      final status = unit.status.toLowerCase().trim();
      if (!['tersedia', 'ready'].contains(status)) {
        return false;
      }

      final assetCode = unit.assetCode.toLowerCase().trim();
      final hasActiveRental = _bookings.any((booking) {
        final sameUnit = booking.iphone.assetCode.toLowerCase().trim() == assetCode;
        final bookingStatus = booking.status.name.toLowerCase().trim();
        final unitStatus = booking.iphone.status.toLowerCase().trim();
        return sameUnit &&
            (bookingStatus == 'rented' ||
                bookingStatus == 'disewa' ||
                unitStatus == 'rented' ||
                unitStatus == 'disewa');
      });
      return !hasActiveRental;
    }

    bool matchesFilters(IphoneModel unit) {
      if (effectiveAffiliateId != null) {
        if (unit.affiliateId != null && unit.affiliateId != effectiveAffiliateId) {
          return false;
        }
      }
      if (onlyAvailable && !isBookable(unit)) {
        return false;
      }
      if (modelName != null && modelName.trim().isNotEmpty) {
        if (!unit.name.toLowerCase().contains(modelName.trim().toLowerCase())) {
          return false;
        }
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchName = unit.fullName.toLowerCase().contains(q);
        final matchSerial = unit.serialNumber.toLowerCase().contains(q);
        final matchAsset = unit.assetCode.toLowerCase().contains(q);
        final matchColor = unit.color.toLowerCase().contains(q);
        if (!matchName && !matchSerial && !matchAsset && !matchColor) {
          return false;
        }
      }
      return true;
    }

    // 1. Ambil unit dari REST API Skyrent backend jika server tersedia
    try {
      if (onlyAvailable) {
        // Endpoint /iphones/available — hanya unit tersedia
        final apiUnits = await ApiService().getAvailableIphones(query: query, affiliateId: effectiveAffiliateId);
        if (apiUnits != null) {
          _hasFetchedFromApi = true;
          return apiUnits.where(matchesFilters).toList();
        }
      } else {
        // Endpoint /iphones — semua unit termasuk rented/maintenance
        final result = await ApiService().getAllIphonesApi(query: query, affiliateId: effectiveAffiliateId);
        if (result != null && result['data'] is List) {
          _hasFetchedFromApi = true;
          final allUnits = (result['data'] as List)
              .map((item) => IphoneModel.fromJson(item as Map<String, dynamic>))
              .toList();
          return allUnits.where(matchesFilters).toList();
        }
      }
    } catch (_) {
      // Fallback aman ke mock inventory jika server offline
    }

    if (_hasFetchedFromApi) {
      return [];
    }

    await Future.delayed(const Duration(milliseconds: 50));
    return MockBookingData.inventory.where(matchesFilters).toList();
  }

  /// Membuat booking baru untuk pelanggan walk-in atau reservasi langsung di outlet
  Future<BookingModel> createBooking({
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    String? address,
    required IphoneModel iphone,
    required DateTime startDate,
    required DateTime endDate,
    required int durationDays,
    required double price,
    required double deposit,
    required String jaminanType,
    String pickupType = 'Outlet',
    PaymentStatus paymentStatus = PaymentStatus.unpaid,
    double amountPaid = 0,
    String paymentMethod = 'Tunai',
    String? notes,
  }) async {
    if (AuthService().isAffiliateScoped && AuthService().affiliateId != null) {
      if (iphone.affiliateId != null && iphone.affiliateId != AuthService().affiliateId) {
        throw Exception('Akses ditolak: Unit iPhone ini tidak terdaftar pada cabang/affiliate Anda.');
      }
    }

    final normalizedStatus = iphone.status.toLowerCase().trim();
    if (['rented', 'disewa'].contains(normalizedStatus)) {
      throw Exception(
        'Unit iPhone ${iphone.name} (${iphone.assetCode}) sedang dalam masa sewa dan tidak dapat disewa lagi.',
      );
    }
    if (['maintenance', 'perawatan'].contains(normalizedStatus)) {
      throw Exception(
        'Unit iPhone ${iphone.name} (${iphone.assetCode}) sedang dalam perawatan/perbaikan dan tidak dapat disewa.',
      );
    }

    final normalizedAssetCode = iphone.assetCode.toLowerCase().trim();
    if (isUnitCurrentlyRented(normalizedAssetCode)) {
      throw Exception(
        'Unit iPhone ${iphone.name} (${iphone.assetCode}) saat ini sedang disewa dalam transaksi sewa aktif dan belum dikembalikan.',
      );
    }

    if (!isUnitAvailableForPeriod(iphone, startDate, endDate)) {
      throw Exception(
        'Unit iPhone ${iphone.name} (${iphone.serialNumber}) tidak tersedia untuk jadwal yang dipilih.',
      );
    }

    String bookingCode = '';
    int nextId = _bookings.isEmpty
        ? 1
        : (_bookings.map((b) => b.id).reduce((a, b) => a > b ? a : b) + 1);

    // Kirim request pembuatan booking ke REST API Skyrent backend
    try {
      final startH = startDate.hour.toString().padLeft(2, '0');
      final startM = startDate.minute.toString().padLeft(2, '0');
      final endH = endDate.hour.toString().padLeft(2, '0');
      final endM = endDate.minute.toString().padLeft(2, '0');

      final apiResult = await ApiService().createBookingApi(
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        customerEmail: customerEmail.trim(),
        address: address?.trim(),
        iphoneId: iphone.id,
        startDate: startDate,
        endDate: endDate,
        startTime: '$startH:$startM',
        endTime: '$endH:$endM',
        duration: durationDays,
        price: price,
        depositAmount: deposit,
        jaminanType: jaminanType,
        pickupType: pickupType,
        paymentStatus: paymentStatus.name,
        amountPaid: amountPaid,
        paymentMethod: paymentMethod,
        notes: notes?.trim(),
      );

      if (apiResult != null && apiResult['data'] != null) {
        final data = apiResult['data'] as Map<String, dynamic>;
        if (data['booking_code'] != null) {
          bookingCode = data['booking_code'].toString();
        }
        if (data['id'] != null && data['id'] is int) {
          nextId = data['id'] as int;
        }
      }
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('sewa') ||
          msg.contains('rented') ||
          msg.contains('perawatan') ||
          msg.contains('maintenance') ||
          msg.contains('akses ditolak') ||
          msg.contains('affiliate') ||
          msg.contains('cabang') ||
          msg.contains('tidak tersedia') ||
          msg.contains('jadwal') ||
          msg.contains('respons server')) {
        rethrow;
      }
      if (!msg.contains('socketexception') && !msg.contains('timeoutexception') && !msg.contains('clientexception')) {
        rethrow;
      }
      // Fallback ke generator kode lokal jika error jaringan / offline
    } catch (_) {
      // Fallback ke generator kode lokal jika offline
    }

    if (bookingCode.isEmpty) {
      final now = DateTime.now();
      final yearSuffix = now.year.toString().substring(2);
      final monthStr = now.month.toString().padLeft(2, '0');
      final dayStr = now.day.toString().padLeft(2, '0');
      final randHex = (nextId * 37 + now.millisecond).toRadixString(16).toUpperCase().padLeft(4, '0');
      bookingCode = 'SKY$yearSuffix$monthStr$dayStr$randHex';
    }

    // Perbarui status unit iPhone di inventory menjadi 'dibooking'
    final updatedIphone = iphone.copyWith(status: 'dibooking');
    final invIdx = MockBookingData.inventory.indexWhere((u) => u.assetCode == iphone.assetCode);
    if (invIdx != -1) {
      MockBookingData.inventory[invIdx] = updatedIphone;
    }

    final newBooking = BookingModel(
      id: nextId,
      bookingCode: bookingCode,
      customerName: customerName.trim(),
      customerPhone: customerPhone.trim(),
      customerEmail: customerEmail.trim(),
      address: address?.trim(),
      pickupType: pickupType,
      jaminanType: jaminanType,
      startDate: startDate,
      endDate: endDate,
      durationDays: durationDays,
      price: price,
      deposit: deposit,
      downPayment: amountPaid,
      status: BookingStatus.confirmed,
      paymentStatus: paymentStatus,
      iphone: updatedIphone,
      notes: notes?.trim(),
      userName: AuthService().currentUser?.name,
      userId: AuthService().currentUser?.userIdentifier,
    );

    _bookings.insert(0, newBooking);

    // Jika ada pembayaran awal, catat ke daftar transaksi pembayaran
    if (amountPaid > 0) {
      final tx = PaymentTransactionModel(
        id: MockBookingData.paymentTransactions.length + 1,
        bookingId: nextId,
        bookingCode: bookingCode,
        customerName: customerName.trim(),
        customerPhone: customerPhone.trim(),
        iphoneName: iphone.fullName,
        rentTotal: price,
        paidAmount: amountPaid,
        remainingAmount: (price - amountPaid).clamp(0.0, double.infinity),
        depositAmount: deposit,
        depositStatus: DepositStatus.held,
        refundAmount: 0,
        deductionAmount: 0,
        paymentStatus: amountPaid >= price ? 'paid' : 'partial',
        paymentMethod: paymentMethod,
        transactionDate: DateTime.now(),
        notes: 'Pembayaran awal saat pembuatan booking baru di outlet.',
      );
      MockBookingData.paymentTransactions.insert(0, tx);
    }

    return newBooking;
  }

  Future<List<PaymentTransactionModel>> getPaymentTransactions({
    String? query,
    String? paymentStatusFilter,
    DepositStatus? depositStatusFilter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return MockBookingData.paymentTransactions.where((tx) {
      if (paymentStatusFilter != null && paymentStatusFilter != 'Semua') {
        if (tx.paymentStatus.toLowerCase() != paymentStatusFilter.toLowerCase()) {
          return false;
        }
      }
      if (depositStatusFilter != null) {
        if (tx.depositStatus != depositStatusFilter) {
          return false;
        }
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchCode = tx.bookingCode.toLowerCase().contains(q);
        final matchName = tx.customerName.toLowerCase().contains(q);
        final matchPhone = tx.customerPhone.toLowerCase().contains(q);
        final matchIphone = tx.iphoneName.toLowerCase().contains(q);
        if (!matchCode && !matchName && !matchPhone && !matchIphone) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<List<PaymentTransactionModel>> getPaymentHistory({
    String? query,
    String? paymentStatusFilter,
    DepositStatus? depositStatusFilter,
    String? paymentMethodFilter,
    DateTime? startDate,
    DateTime? endDate,
    String sortBy = 'terbaru',
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final list = MockBookingData.paymentTransactions.where((tx) {
      if (paymentStatusFilter != null &&
          paymentStatusFilter.isNotEmpty &&
          paymentStatusFilter.toLowerCase() != 'semua') {
        if (tx.paymentStatus.toLowerCase() != paymentStatusFilter.toLowerCase()) {
          return false;
        }
      }
      if (depositStatusFilter != null) {
        if (tx.depositStatus != depositStatusFilter) {
          return false;
        }
      }
      if (paymentMethodFilter != null &&
          paymentMethodFilter.isNotEmpty &&
          paymentMethodFilter.toLowerCase() != 'semua') {
        if (tx.paymentMethod.toLowerCase() != paymentMethodFilter.toLowerCase()) {
          return false;
        }
      }
      if (startDate != null) {
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        if (tx.transactionDate.isBefore(startOfDay)) {
          return false;
        }
      }
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
        if (tx.transactionDate.isAfter(endOfDay)) {
          return false;
        }
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchCode = tx.bookingCode.toLowerCase().contains(q);
        final matchName = tx.customerName.toLowerCase().contains(q);
        final matchPhone = tx.customerPhone.toLowerCase().contains(q);
        final matchIphone = tx.iphoneName.toLowerCase().contains(q);
        if (!matchCode && !matchName && !matchPhone && !matchIphone) {
          return false;
        }
      }
      return true;
    }).toList();

    if (sortBy == 'terlama') {
      list.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    } else if (sortBy == 'terbesar') {
      list.sort((a, b) => b.rentTotal.compareTo(a.rentTotal));
    } else {
      list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    }

    return list;
  }

  Map<String, double> getFinancialSummary() {
    double totalPaid = 0;
    double totalHeldDeposit = 0;
    double totalRefunded = 0;
    double totalOutstanding = 0;

    for (final tx in MockBookingData.paymentTransactions) {
      totalPaid += tx.paidAmount;
      if (tx.depositStatus == DepositStatus.held) {
        totalHeldDeposit += tx.depositAmount;
      } else if (tx.depositStatus == DepositStatus.refunded) {
        totalRefunded += tx.refundAmount;
      }
      totalOutstanding += tx.remainingAmount;
    }

    return {
      'totalPaid': totalPaid,
      'totalHeldDeposit': totalHeldDeposit,
      'totalRefunded': totalRefunded,
      'totalOutstanding': totalOutstanding,
    };
  }

  /// Mencatat pembayaran sewa kasir (Pelunasan / DP / Penalty / Extend),
  /// menyinkronkan ke API backend, dan memperbarui status booking di memori lokal.
  Future<bool> submitBookingPayment({
    required String bookingCode,
    required double amount,
    required double pay,
    required String paymentMethod,
    required String type,
    DateTime? paidAt,
    String? note,
    bool sendWhatsapp = true,
  }) async {
    final paymentDate = paidAt ?? DateTime.now();

    // 1. Kirim transaksi pembayaran ke REST API backend
    try {
      await ApiService().recordPaymentApi(
        bookingCode: bookingCode,
        amount: amount,
        pay: pay,
        paymentMethod: paymentMethod,
        type: type,
        paidAt: paymentDate,
        note: note,
        sendWhatsapp: sendWhatsapp,
      );
    } catch (_) {
      // Jika offline, lanjutkan update lokal
    }

    // 2. Perbarui model BookingModel di _bookings
    final bookingIdx = _bookings.indexWhere((b) =>
        b.bookingCode.trim().toLowerCase() == bookingCode.trim().toLowerCase() ||
        b.id.toString() == bookingCode.trim());

    if (bookingIdx != -1) {
      final existing = _bookings[bookingIdx];
      if (type != 'penalty') {
        final newDownPayment = existing.downPayment + amount;
        final totalBill = existing.price + existing.deposit - existing.discount;
        final newRemaining = (totalBill - newDownPayment).clamp(0.0, double.infinity);
        final newStatus = newRemaining <= 0 ? PaymentStatus.paid : PaymentStatus.partial;

        _bookings[bookingIdx] = existing.copyWith(
          paymentStatus: newStatus,
          downPayment: newDownPayment,
        );
      }
    }

    // 3. Sinkronkan juga riwayat transaksi ke MockBookingData.paymentTransactions
    final txIdx = MockBookingData.paymentTransactions.indexWhere(
      (t) => t.bookingCode.toLowerCase() == bookingCode.trim().toLowerCase(),
    );

    if (txIdx != -1) {
      final existingTx = MockBookingData.paymentTransactions[txIdx];
      if (type == 'penalty') {
        MockBookingData.paymentTransactions[txIdx] = existingTx.copyWith(
          deductionAmount: existingTx.deductionAmount + amount,
          transactionDate: paymentDate,
          notes: note ?? existingTx.notes,
        );
      } else {
        final newPaid = existingTx.paidAmount + amount;
        final newRemaining = (existingTx.rentTotal - newPaid).clamp(0.0, double.infinity);
        final newStatus = newRemaining <= 0 ? 'paid' : 'partial';

        MockBookingData.paymentTransactions[txIdx] = PaymentTransactionModel(
          id: existingTx.id,
          bookingId: existingTx.bookingId,
          bookingCode: existingTx.bookingCode,
          customerName: existingTx.customerName,
          customerPhone: existingTx.customerPhone,
          iphoneName: existingTx.iphoneName,
          rentTotal: existingTx.rentTotal,
          paidAmount: newPaid,
          remainingAmount: newRemaining,
          depositAmount: existingTx.depositAmount,
          depositStatus: existingTx.depositStatus,
          refundAmount: existingTx.refundAmount,
          deductionAmount: existingTx.deductionAmount,
          paymentStatus: newStatus,
          paymentMethod: paymentMethod,
          transactionDate: paymentDate,
          notes: note ?? existingTx.notes,
        );
      }
    } else if (bookingIdx != -1) {
      final b = _bookings[bookingIdx];
      final isPenalty = type == 'penalty';
      final totalBill = b.price + b.deposit - b.discount;
      final newRemaining = isPenalty ? (totalBill - b.downPayment).clamp(0.0, double.infinity) : (totalBill - (b.downPayment + amount)).clamp(0.0, double.infinity);
      final newStatus = isPenalty ? (b.paymentStatus == PaymentStatus.paid ? 'paid' : 'partial') : (newRemaining <= 0 ? 'paid' : 'partial');

      MockBookingData.paymentTransactions.insert(
        0,
        PaymentTransactionModel(
          id: MockBookingData.paymentTransactions.length + 1,
          bookingId: b.id,
          bookingCode: b.bookingCode,
          customerName: b.customerName,
          customerPhone: b.customerPhone,
          iphoneName: b.iphone.fullName,
          rentTotal: b.price,
          paidAmount: isPenalty ? b.downPayment : (b.downPayment + amount),
          remainingAmount: newRemaining,
          depositAmount: b.deposit,
          depositStatus: DepositStatus.held,
          refundAmount: 0,
          deductionAmount: isPenalty ? amount : 0,
          paymentStatus: newStatus,
          paymentMethod: paymentMethod,
          transactionDate: paymentDate,
          notes: note ?? 'Pembayaran kasir via ${paymentMethod.toUpperCase()}',
        ),
      );
    }

    return true;
  }

  List<PaymentMethodOption> _cachedPaymentMethods = [];

  /// Mengambil daftar metode pembayaran aktif dari backend atau fallback lokal
  Future<List<PaymentMethodOption>> getPaymentMethods({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPaymentMethods.isNotEmpty) {
      return _cachedPaymentMethods;
    }

    try {
      final rawList = await ApiService().getPaymentMethods();
      if (rawList != null && rawList.isNotEmpty) {
        final methods = rawList
            .map((json) => PaymentMethodOption.fromJson(json))
            .where((m) => m.isActive)
            .toList();

        if (methods.isNotEmpty) {
          _cachedPaymentMethods = methods;
          return _cachedPaymentMethods;
        }
      }
    } catch (_) {}

    if (_cachedPaymentMethods.isEmpty) {
      _cachedPaymentMethods = PaymentMethodOption.defaultMethods();
    }
    return _cachedPaymentMethods;
  }

  Future<PaymentTransactionModel?> submitPayment({
    required String bookingCode,
    required double amountPaid,
    required String paymentMethod,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final idx = MockBookingData.paymentTransactions.indexWhere(
        (t) => t.bookingCode.toLowerCase() == bookingCode.trim().toLowerCase(),
      );

      if (idx != -1) {
        final existing = MockBookingData.paymentTransactions[idx];
        final newPaid = existing.paidAmount + amountPaid;
        final newRemaining = (existing.rentTotal - newPaid).clamp(0.0, double.infinity);
        final newStatus = newRemaining <= 0 ? 'paid' : 'partial';

        final updated = PaymentTransactionModel(
          id: existing.id,
          bookingId: existing.bookingId,
          bookingCode: existing.bookingCode,
          customerName: existing.customerName,
          customerPhone: existing.customerPhone,
          iphoneName: existing.iphoneName,
          rentTotal: existing.rentTotal,
          paidAmount: newPaid,
          remainingAmount: newRemaining,
          depositAmount: existing.depositAmount,
          depositStatus: existing.depositStatus,
          refundAmount: existing.refundAmount,
          deductionAmount: existing.deductionAmount,
          paymentStatus: newStatus,
          paymentMethod: paymentMethod,
          transactionDate: DateTime.now(),
          notes: notes ?? existing.notes,
        );

        MockBookingData.paymentTransactions[idx] = updated;
        return updated;
      }
    } catch (_) {}
    return null;
  }

  /// Memeriksa apakah booking dapat diperpanjang durasi jamnya (Tambah Jam)
  Future<bool> canExtendBooking(String bookingCode, int hours) async {
    if (hours <= 0) return false;

    // 1. Coba periksa via REST API backend
    try {
      final res = await ApiService().checkExtendAvailability(bookingCode, hours);
      if (res != null && res['available'] is bool) {
        return res['available'] as bool;
      }
    } catch (_) {
      // Fallback ke pengecekan offline lokal
    }

    // 2. Offline / local fallback
    final booking = _bookings.where((b) =>
        b.bookingCode.trim().toLowerCase() == bookingCode.trim().toLowerCase() ||
        b.id.toString() == bookingCode.trim()).firstOrNull;

    if (booking == null) return false;
    if (booking.status == BookingStatus.returned || booking.status == BookingStatus.cancelled) {
      return false;
    }

    final currentEnd = booking.endDate;
    final newEnd = currentEnd.add(Duration(hours: hours));

    // Cek apakah ada booking lain untuk iPhone yang sama di rentang waktu tersebut
    final hasConflict = _bookings.any((b) {
      if (b.id == booking.id || b.bookingCode == booking.bookingCode) return false;
      final sameIphone = booking.iphone.assetCode.isNotEmpty
          ? b.iphone.assetCode.toLowerCase().trim() == booking.iphone.assetCode.toLowerCase().trim()
          : b.iphone.id == booking.iphone.id;
      if (!sameIphone) return false;

      final isOtherActive = b.status == BookingStatus.pending ||
          b.status == BookingStatus.confirmed ||
          b.status == BookingStatus.rented;
      if (!isOtherActive) return false;

      // currentEnd < other.endDate && newEnd > other.startDate
      return currentEnd.isBefore(b.endDate) && newEnd.isAfter(b.startDate);
    });

    return !hasConflict;
  }

  /// Memperpanjang durasi rental booking (Tambah Jam)
  Future<BookingModel> extendBooking({
    required String bookingCode,
    required int hours,
    int? durationId,
    int? multiplier,
    double? price,
    String? paymentMethod,
    double? pay,
    String? note,
  }) async {
    // 1. Panggil API backend jika tersedia
    try {
      final apiRes = await ApiService().extendBookingApi(
        bookingCode,
        hours: hours,
        durationId: durationId,
        multiplier: multiplier,
        price: price,
        paymentMethod: paymentMethod,
        pay: pay,
        note: note,
      );

      if (apiRes != null && apiRes['data'] != null) {
        final updatedFromApi = BookingModel.fromJson(apiRes['data'] as Map<String, dynamic>);
        final idx = _bookings.indexWhere((b) =>
            b.bookingCode.trim().toLowerCase() == bookingCode.trim().toLowerCase() ||
            b.id.toString() == bookingCode.trim());
        if (idx != -1) {
          _bookings[idx] = updatedFromApi;
        } else {
          _bookings.insert(0, updatedFromApi);
        }
        return updatedFromApi;
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('jadwal') || msg.contains('bertabrakan') || msg.contains('tidak dapat diperpanjang')) {
        rethrow;
      }
      // Lanjutkan fallback lokal jika offline/network error
    }

    // 2. Update status & durasi lokal
    final idx = _bookings.indexWhere((b) =>
        b.bookingCode.trim().toLowerCase() == bookingCode.trim().toLowerCase() ||
        b.id.toString() == bookingCode.trim());

    if (idx == -1) {
      throw Exception('Booking dengan kode $bookingCode tidak ditemukan.');
    }

    final current = _bookings[idx];
    final addedPrice = price ?? 0.0;
    final newDuration = current.durationDays + hours;
    final newEndDate = current.endDate.add(Duration(hours: hours));
    final newPrice = current.price + addedPrice;

    final updated = current.copyWith(
      durationDays: newDuration,
      endDate: newEndDate,
      price: newPrice,
    );

    _bookings[idx] = updated;

    // Catat transaksi pembayaran extend jika ada
    if (paymentMethod != null && addedPrice > 0) {
      final payAmount = pay ?? addedPrice;
      final changeAmount = (payAmount - addedPrice).clamp(0.0, double.infinity);
      final changeNote = changeAmount > 0 ? ' (Kembalian: ${changeAmount.toInt()})' : '';
      final tx = PaymentTransactionModel(
        id: MockBookingData.paymentTransactions.length + 1,
        bookingId: updated.id,
        bookingCode: updated.bookingCode,
        customerName: updated.customerName,
        customerPhone: updated.customerPhone,
        iphoneName: updated.iphone.fullName,
        rentTotal: addedPrice,
        paidAmount: addedPrice,
        remainingAmount: 0.0,
        depositAmount: 0.0,
        depositStatus: DepositStatus.held,
        refundAmount: 0.0,
        deductionAmount: 0.0,
        paymentStatus: 'paid',
        paymentMethod: paymentMethod,
        transactionDate: DateTime.now(),
        notes: (note ?? 'Penambahan durasi sewa $hours jam via ${paymentMethod.toUpperCase()}') + changeNote,
      );
      MockBookingData.paymentTransactions.insert(0, tx);
    }

    return updated;
  }

  Future<PaymentTransactionModel?> updateDepositStatus({
    required String bookingCode,
    required DepositStatus newStatus,
    double deductionAmount = 0,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final idx = MockBookingData.paymentTransactions.indexWhere(
        (t) => t.bookingCode.toLowerCase() == bookingCode.trim().toLowerCase(),
      );

      if (idx != -1) {
        final existing = MockBookingData.paymentTransactions[idx];
        final newRefund = (existing.depositAmount - deductionAmount).clamp(0.0, double.infinity);

        final updated = PaymentTransactionModel(
          id: existing.id,
          bookingId: existing.bookingId,
          bookingCode: existing.bookingCode,
          customerName: existing.customerName,
          customerPhone: existing.customerPhone,
          iphoneName: existing.iphoneName,
          rentTotal: existing.rentTotal,
          paidAmount: existing.paidAmount,
          remainingAmount: existing.remainingAmount,
          depositAmount: existing.depositAmount,
          depositStatus: newStatus,
          refundAmount: newRefund,
          deductionAmount: deductionAmount,
          paymentStatus: existing.paymentStatus,
          paymentMethod: existing.paymentMethod,
          transactionDate: DateTime.now(),
          notes: notes ?? existing.notes,
        );

        MockBookingData.paymentTransactions[idx] = updated;
        return updated;
      }
    } catch (_) {}
    return null;
  }

  Future<PaymentTransactionModel?> executeRefund({
    required String bookingCode,
    required double refundAmount,
    required String refundMethod,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final idx = MockBookingData.paymentTransactions.indexWhere(
        (t) => t.bookingCode.toLowerCase() == bookingCode.trim().toLowerCase(),
      );

      if (idx != -1) {
        final existing = MockBookingData.paymentTransactions[idx];

        if (existing.depositStatus == DepositStatus.refunded) {
          throw Exception('Deposit untuk booking ini telah direfund sebelumnya.');
        }

        final combinedNotes = [
          if (notes != null && notes.isNotEmpty) notes,
          if (bankName != null && accountNumber != null)
            'Tujuan: $bankName $accountNumber ($accountHolder)',
        ].join(' | ');

        final updated = PaymentTransactionModel(
          id: existing.id,
          bookingId: existing.bookingId,
          bookingCode: existing.bookingCode,
          customerName: existing.customerName,
          customerPhone: existing.customerPhone,
          iphoneName: existing.iphoneName,
          rentTotal: existing.rentTotal,
          paidAmount: existing.paidAmount,
          remainingAmount: existing.remainingAmount,
          depositAmount: existing.depositAmount,
          depositStatus: DepositStatus.refunded,
          refundAmount: refundAmount,
          deductionAmount: existing.deductionAmount,
          paymentStatus: existing.paymentStatus,
          paymentMethod: refundMethod,
          transactionDate: DateTime.now(),
          notes: combinedNotes.isNotEmpty ? combinedNotes : existing.notes,
        );

        MockBookingData.paymentTransactions[idx] = updated;
        return updated;
      }
    } catch (_) {
      rethrow;
    }
    return null;
  }

  Future<List<ReceiptModel>> getReceiptHistory({
    String? query,
    ReceiptType? typeFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return MockReceiptData.items.where((r) {
      if (typeFilter != null && r.type != typeFilter) {
        return false;
      }
      if (startDate != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        if (r.date.isBefore(start)) return false;
      }
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
        if (r.date.isAfter(end)) return false;
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchNum = r.receiptNumber.toLowerCase().contains(q);
        final matchCode = r.bookingCode.toLowerCase().contains(q);
        final matchName = r.customerName.toLowerCase().contains(q);
        final matchPhone = r.customerPhone.toLowerCase().contains(q);
        final matchUnit = r.unitName.toLowerCase().contains(q);
        if (!matchNum && !matchCode && !matchName && !matchPhone && !matchUnit) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Memproses penyelesaian pengembalian iPhone dan mengembalikan status unit ke tersedia
  Future<BookingModel> completeReturn({
    required String bookingCode,
    required String physicalCondition,
    required int batteryHealthFinal,
    required double lateFee,
    required double damageFee,
    required double depositRefunded,
    required String refundMethod,
    required List<String> accessoriesReturned,
    String? staffNotes,
  }) async {
    // 1. Coba panggil API Backend jika tersedia
    try {
      await ApiService().completeReturnApi(
        bookingCode: bookingCode,
        payload: {
          'condition': physicalCondition,
          'battery_health_return': batteryHealthFinal,
          'late_fee': lateFee,
          'damage_fee': damageFee,
          'deposit_refunded': depositRefunded,
          'refund_method': refundMethod,
          'accessories_returned': accessoriesReturned,
          'staff_notes': staffNotes,
        },
      );
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 250));
    final idx = _bookings.indexWhere(
      (b) => b.bookingCode.toLowerCase() == bookingCode.trim().toLowerCase(),
    );

    if (idx == -1) {
      throw Exception('Booking dengan kode $bookingCode tidak ditemukan.');
    }

    final existing = _bookings[idx];

    // 1. Buat model unit terupdate dengan status 'tersedia' dan battery health terbaru
    final updatedIphone = IphoneModel(
      id: existing.iphone.id,
      name: existing.iphone.name,
      storage: existing.iphone.storage,
      color: existing.iphone.color,
      serialNumber: existing.iphone.serialNumber,
      assetCode: existing.iphone.assetCode,
      status: 'tersedia',
      batteryHealth: batteryHealthFinal,
    );

    // 2. Perbarui status booking menjadi returned
    final returnedBooking = BookingModel(
      id: existing.id,
      bookingCode: existing.bookingCode,
      customerName: existing.customerName,
      customerPhone: existing.customerPhone,
      customerEmail: existing.customerEmail,
      address: existing.address,
      pickupType: existing.pickupType,
      jaminanType: existing.jaminanType,
      startDate: existing.startDate,
      endDate: existing.endDate,
      durationDays: existing.durationDays,
      price: existing.price,
      deposit: existing.deposit,
      status: BookingStatus.returned,
      paymentStatus: existing.paymentStatus,
      iphone: updatedIphone,
      notes: [
        if (existing.notes != null) existing.notes,
        'Pengembalian selesai: Fisik $physicalCondition, BH $batteryHealthFinal%.',
        if (lateFee > 0) 'Denda telat: ${Formatters.currency(lateFee)}.',
        if (damageFee > 0) 'Denda kerusakan/kelengkapan: ${Formatters.currency(damageFee)}.',
        'Deposit dikembalikan: ${Formatters.currency(depositRefunded)} ($refundMethod).',
        if (staffNotes != null && staffNotes.isNotEmpty) 'Catatan: $staffNotes',
      ].join(' '),
    );

    _bookings[idx] = returnedBooking;

    // 3. Perbarui juga unit di inventory global
    final invIdx = MockBookingData.inventory.indexWhere((u) => u.assetCode == existing.iphone.assetCode);
    if (invIdx != -1) {
      MockBookingData.inventory[invIdx] = updatedIphone;
    }

    return returnedBooking;
  }

  Future<void> saveReceipt(ReceiptModel receipt) async {
    MockReceiptData.items.insert(0, receipt);
  }

  /// Memeriksa apakah unit fisik iPhone tersedia untuk rentang waktu booking tertentu
  bool isUnitAvailableForPeriod(IphoneModel unit, DateTime start, DateTime end, {int? excludeBookingId}) {
    final rawStatus = unit.status.toLowerCase().trim();
    if (['maintenance', 'perbaikan', 'perawatan', 'lost', 'hilang', 'retired', 'nonaktif', 'in_transit', 'transferred', 'mutasi'].contains(rawStatus)) {
      return false;
    }

    DateTime startDt = start;
    DateTime endDt = end;
    if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
      endDt = startDt.add(const Duration(hours: 1));
    }

    final now = DateTime.now();
    final source = _bookings.isNotEmpty ? _bookings : MockBookingData.items;

    for (final b in source) {
      if (excludeBookingId != null && b.id == excludeBookingId) {
        continue;
      }
      if (b.iphone.id != unit.id && b.iphone.assetCode.toLowerCase().trim() != unit.assetCode.toLowerCase().trim()) {
        continue;
      }

      final bStatus = b.status.name.toLowerCase().trim();
      if (!['pending', 'confirmed', 'rented', 'disewa'].contains(bStatus)) {
        continue;
      }

      // Check if pending has expired (> 30 mins)
      if (bStatus == 'pending') {
        final bCreated = b.startDate;
        if (now.difference(bCreated).inMinutes > 30) {
          continue;
        }
      }

      final bStart = DateTime(
        b.startDate.year,
        b.startDate.month,
        b.startDate.day,
        int.tryParse(b.startTime?.split(':').firstOrNull ?? '0') ?? 0,
        int.tryParse(b.startTime?.split(':').elementAtOrNull(1) ?? '0') ?? 0,
      );

      DateTime bEnd;
      if (b.endTime != null) {
        bEnd = DateTime(
          b.endDate.year,
          b.endDate.month,
          b.endDate.day,
          int.tryParse(b.endTime!.split(':').firstOrNull ?? '23') ?? 23,
          int.tryParse(b.endTime!.split(':').elementAtOrNull(1) ?? '59') ?? 59,
        );
      } else {
        bEnd = bStart.add(Duration(hours: b.durationDays > 0 ? b.durationDays : 24));
      }

      if (['rented', 'disewa'].contains(bStatus) && bEnd.isBefore(now)) {
        bEnd = now;
      }

      // Check interval overlap: [bStart, bEnd] overlaps with [startDt, endDt]
      if (bStart.isBefore(endDt) && bEnd.isAfter(startDt)) {
        return false;
      }
    }

    return true;
  }

  /// Memeriksa apakah unit iPhone dengan assetCode tertentu saat ini sedang disewa aktif di antrean transaksi
  bool isUnitCurrentlyRented(String assetCode) {
    final normalized = assetCode.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    final source = _bookings.isNotEmpty ? _bookings : MockBookingData.items;
    return source.any((b) {
      final sameUnit = b.iphone.assetCode.toLowerCase().trim() == normalized;
      final bookingStatus = b.status.name.toLowerCase().trim();
      final unitStatus = b.iphone.status.toLowerCase().trim();
      return sameUnit &&
          (bookingStatus == 'rented' ||
              bookingStatus == 'disewa' ||
              unitStatus == 'rented' ||
              unitStatus == 'disewa');
    });
  }

  /// Mengambil semua unit iPhone dari inventory dengan filter opsional
  Future<List<IphoneModel>> getAllInventoryUnits({
    String? query,
    String? statusFilter,
    String? modelFilter,
    String? branchFilter,
    String? sortBy,
    int? affiliateId,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    int? duration,
  }) async {
    final effectiveAffiliateId = AuthService().isAffiliateScoped ? AuthService().affiliateId : affiliateId;

    try {
      final res = await ApiService().getAllIphonesApi(
        query: query,
        status: statusFilter,
        model: modelFilter,
        branch: branchFilter,
        affiliateId: effectiveAffiliateId,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        duration: duration,
      );
      if (res != null && res['data'] is List) {
        _hasFetchedFromApi = true;
        final raw = res['data'] as List;
        final list = raw.map((j) {
          var u = IphoneModel.fromJson(j as Map<String, dynamic>);
          final isAlreadyLate = u.status.toLowerCase() == 'terlambat' || u.status.toLowerCase() == 'overdue' || u.status.toLowerCase() == 'late';
          if (!isAlreadyLate && (u.status.toLowerCase() == 'disewa' || u.status.toLowerCase() == 'rented' || isUnitCurrentlyRented(u.assetCode)) &&
              (u.customerName == null || u.customerName!.isEmpty)) {
            final b = getActiveBookingForUnitSync(u.assetCode);
            if (b != null) {
              u = u.copyWith(
                status: 'disewa',
                customerName: b.customerName,
                bookingCode: '#${b.bookingCode}',
                returnScheduleText: 'Kembali: ${Formatters.date(b.endDate)} • ${b.endTime ?? "18:00 WIB"}${b.jaminanType.isNotEmpty ? " (${b.jaminanType})" : ""}',
              );
            }
          }
          return u;
        }).toList();

        _inventory.clear();
        _inventory.addAll(list);
        if (res['summary'] is Map) {
          final s = res['summary'] as Map<String, dynamic>;
          _unitSummaryCache = {
            'total': int.tryParse(s['total']?.toString() ?? '0') ?? list.length,
            'tersedia': int.tryParse(s['tersedia']?.toString() ?? s['ready']?.toString() ?? '0') ?? 0,
            'disewa': int.tryParse(s['disewa']?.toString() ?? s['rented']?.toString() ?? '0') ?? 0,
            'terlambat': int.tryParse(s['terlambat']?.toString() ?? s['overdue']?.toString() ?? '0') ?? 0,
            'maintenance': int.tryParse(s['maintenance']?.toString() ?? '0') ?? 0,
            'dibooking': int.tryParse(s['dibooking']?.toString() ?? s['booked']?.toString() ?? '0') ?? 0,
          };
        }
        return list;
      }
    } catch (_) {}

    if (_hasFetchedFromApi && _inventory.isEmpty) {
      return [];
    }

    final rawSource = _inventory.isNotEmpty ? _inventory : MockBookingData.inventory;
    final source = rawSource.map((unit) {
      final isAlreadyLate = unit.status.toLowerCase() == 'terlambat' || unit.status.toLowerCase() == 'overdue' || unit.status.toLowerCase() == 'late';
      if (!isAlreadyLate && isUnitCurrentlyRented(unit.assetCode)) {
        final b = getActiveBookingForUnitSync(unit.assetCode);
        return unit.copyWith(
          status: 'disewa',
          customerName: unit.customerName ?? b?.customerName,
          bookingCode: unit.bookingCode ?? (b != null ? '#${b.bookingCode}' : null),
          returnScheduleText: unit.returnScheduleText ??
              (b != null ? 'Kembali: ${Formatters.date(b.endDate)} • ${b.endTime ?? "18:00 WIB"}${b.jaminanType.isNotEmpty ? " (${b.jaminanType})" : ""}' : null),
        );
      }
      return unit;
    }).toList();
    final filtered = source.where((unit) {
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toLowerCase() != 'semua') {
        final normStatus = unit.status.toLowerCase();
        final normFilter = statusFilter.toLowerCase();
        if (normFilter == 'tersedia' && normStatus != 'tersedia' && normStatus != 'ready') {
          return false;
        } else if (normFilter == 'disewa' && normStatus != 'disewa' && normStatus != 'rented') {
          return false;
        } else if ((normFilter == 'terlambat' || normFilter == 'overdue') &&
            normStatus != 'terlambat' && normStatus != 'overdue') {
          return false;
        } else if ((normFilter == 'maintenance' || normFilter == 'perawatan') &&
            normStatus != 'maintenance' && normStatus != 'perawatan') {
          return false;
        } else if ((normFilter == 'dibooking' || normFilter == 'booked') &&
            normStatus != 'dibooking' && normStatus != 'booked') {
          return false;
        } else if (normFilter != 'tersedia' &&
            normFilter != 'disewa' &&
            normFilter != 'terlambat' &&
            normFilter != 'overdue' &&
            normFilter != 'maintenance' &&
            normFilter != 'perawatan' &&
            normFilter != 'dibooking' &&
            normFilter != 'booked') {
          if (!normStatus.contains(normFilter)) return false;
        }
      }

      if (modelFilter != null && modelFilter.isNotEmpty && modelFilter.toLowerCase() != 'semua') {
        if (!unit.name.toLowerCase().contains(modelFilter.toLowerCase())) {
          return false;
        }
      }

      final effectiveAff = effectiveAffiliateId ?? affiliateId;
      if (effectiveAff != null) {
        if (unit.affiliateId != null && unit.affiliateId != effectiveAff) {
          return false;
        }
      }

      if (branchFilter != null &&
          branchFilter.isNotEmpty &&
          !branchFilter.toLowerCase().contains('semua')) {
        final normBranch = branchFilter.toLowerCase().replaceAll('•', '').trim();
        final unitBranch = (unit.branchName ?? unit.affiliateName ?? '').toLowerCase();
        if (!unitBranch.contains(normBranch)) {
          return false;
        }
      }

      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchName = unit.name.toLowerCase().contains(q);
        final matchAsset = unit.assetCode.toLowerCase().contains(q);
        final matchSerial = unit.serialNumber.toLowerCase().contains(q);
        final matchColor = unit.color.toLowerCase().contains(q);
        final matchStorage = unit.storage.toLowerCase().contains(q);
        final matchBranch = (unit.branchName ?? '').toLowerCase().contains(q);
        final matchCustomer = (unit.customerName ?? '').toLowerCase().contains(q);
        final matchBooking = (unit.bookingCode ?? '').toLowerCase().contains(q);
        if (!matchName && !matchAsset && !matchSerial && !matchColor && !matchStorage && !matchBranch && !matchCustomer && !matchBooking) {
          return false;
        }
      }

      return true;
    }).toList();

    if (sortBy != null && sortBy.isNotEmpty) {
      if (sortBy == 'bh_desc') {
        filtered.sort((a, b) => b.batteryHealth.compareTo(a.batteryHealth));
      } else if (sortBy == 'bh_asc') {
        filtered.sort((a, b) => a.batteryHealth.compareTo(b.batteryHealth));
      } else if (sortBy == 'name_asc') {
        filtered.sort((a, b) => a.name.compareTo(b.name));
      } else if (sortBy == 'asset_asc') {
        filtered.sort((a, b) => a.assetCode.compareTo(b.assetCode));
      }
    }

    return filtered;
  }

  /// Reset inventaris kembali ke data awal
  void resetInventory() {
    MockBookingData.resetInventory();
    _inventory.clear();
    _inventory.addAll(MockBookingData.inventory);
    _unitSummaryCache = null;
  }

  /// Tambah unit baru ke inventaris
  Future<IphoneModel> addInventoryUnit(IphoneModel unit) async {
    IphoneModel savedUnit = unit;
    try {
      final res = await ApiService().createIphoneApi(unit.toJson());
      if (res != null && res['data'] is Map<String, dynamic>) {
        savedUnit = IphoneModel.fromJson(res['data'] as Map<String, dynamic>);
      }
    } on ApiException {
      rethrow;
    } catch (_) {}

    _inventory.insert(0, savedUnit);
    MockBookingData.inventory.insert(0, savedUnit);
    _unitSummaryCache = null;
    return savedUnit;
  }

  /// Perbarui unit di inventaris
  Future<IphoneModel> updateInventoryUnit(IphoneModel unit) async {
    IphoneModel savedUnit = unit;
    try {
      final identifier = unit.id > 0 ? unit.id.toString() : unit.assetCode;
      final payload = unit.toJson();
      if (unit.durations.isNotEmpty) {
        payload['durations'] = unit.durations.map((d) => {
          'hours': d.hours,
          'price': d.price.round(),
        }).toList();
      }
      final res = await ApiService().updateIphoneApi(identifier, payload);
      if (res != null && res['data'] is Map<String, dynamic>) {
        savedUnit = IphoneModel.fromJson(res['data'] as Map<String, dynamic>);
      }
    } on ApiException {
      rethrow;
    } catch (_) {}

    final invIdx = _inventory.indexWhere((u) => (u.id > 0 && u.id == unit.id) || u.assetCode.toLowerCase() == unit.assetCode.toLowerCase());
    if (invIdx != -1) {
      _inventory[invIdx] = savedUnit;
    } else {
      _inventory.insert(0, savedUnit);
    }

    final mockIdx = MockBookingData.inventory.indexWhere((u) => (u.id > 0 && u.id == unit.id) || u.assetCode.toLowerCase() == unit.assetCode.toLowerCase());
    if (mockIdx != -1) {
      MockBookingData.inventory[mockIdx] = savedUnit;
    }

    // Update references in active bookings
    for (int i = 0; i < _bookings.length; i++) {
      if ((_bookings[i].iphone.id > 0 && _bookings[i].iphone.id == unit.id) ||
          _bookings[i].iphone.assetCode.toLowerCase() == unit.assetCode.toLowerCase()) {
        _bookings[i] = _bookings[i].copyWith(iphone: savedUnit);
      }
    }

    _unitSummaryCache = null;
    return savedUnit;
  }

  /// Hapus unit dari inventaris
  Future<void> deleteInventoryUnit(String assetCode) async {
    _inventory.removeWhere((u) => u.assetCode.toLowerCase() == assetCode.toLowerCase());
    MockBookingData.inventory.removeWhere((u) => u.assetCode.toLowerCase() == assetCode.toLowerCase());
    _unitSummaryCache = null;
  }

  /// Ringkasan status unit iPhone
  Future<Map<String, int>> getUnitStatusSummary() async {
    try {
      final res = await ApiService().getAllIphonesApi();
      if (res != null && res['summary'] is Map) {
        _hasFetchedFromApi = true;
        final s = res['summary'] as Map<String, dynamic>;
        _unitSummaryCache = {
          'total': int.tryParse(s['total']?.toString() ?? '0') ?? 0,
          'tersedia': int.tryParse(s['tersedia']?.toString() ?? s['ready']?.toString() ?? '0') ?? 0,
          'disewa': int.tryParse(s['disewa']?.toString() ?? s['rented']?.toString() ?? '0') ?? 0,
          'terlambat': int.tryParse(s['terlambat']?.toString() ?? s['overdue']?.toString() ?? '0') ?? 0,
          'maintenance': int.tryParse(s['maintenance']?.toString() ?? '0') ?? 0,
          'dibooking': int.tryParse(s['dibooking']?.toString() ?? s['booked']?.toString() ?? '0') ?? 0,
        };
        if (res['data'] is List) {
          final raw = res['data'] as List;
          final list = raw.map((j) => IphoneModel.fromJson(j as Map<String, dynamic>)).toList();
          _inventory.clear();
          _inventory.addAll(list);
        }
        return _unitSummaryCache!;
      }
    } catch (_) {}

    if (_unitSummaryCache != null) return _unitSummaryCache!;

    if (_hasFetchedFromApi) {
      return {
        'total': 0,
        'tersedia': 0,
        'disewa': 0,
        'terlambat': 0,
        'maintenance': 0,
        'dibooking': 0,
      };
    }

    final units = _inventory.isNotEmpty ? _inventory : MockBookingData.inventory;
    int total = units.length;
    int tersedia = 0;
    int disewa = 0;
    int terlambat = 0;
    int maintenance = 0;
    int dibooking = 0;

    for (final u in units) {
      final s = u.status.toLowerCase();
      if (s == 'tersedia' || s == 'ready') {
        tersedia++;
      } else if (s == 'disewa' || s == 'rented') {
        disewa++;
      } else if (s == 'terlambat' || s == 'overdue' || s == 'late') {
        terlambat++;
      } else if (s == 'maintenance' || s == 'perawatan') {
        maintenance++;
      } else if (s == 'dibooking' || s == 'booked') {
        dibooking++;
      } else {
        tersedia++;
      }
    }

    return {
      'total': total,
      'tersedia': tersedia,
      'disewa': disewa,
      'terlambat': terlambat,
      'maintenance': maintenance,
      'dibooking': dibooking,
    };
  }

  /// Mencari data booking aktif yang sedang menyewa unit ini (sinkron)
  BookingModel? getActiveBookingForUnitSync(String assetCode) {
    final normalized = assetCode.toLowerCase().trim();
    try {
      final source = _bookings.isNotEmpty ? _bookings : MockBookingData.items;
      return source.firstWhere(
        (b) =>
            b.iphone.assetCode.toLowerCase().trim() == normalized &&
            (b.status == BookingStatus.rented ||
                b.status == BookingStatus.confirmed ||
                b.iphone.status.toLowerCase() == 'disewa' ||
                b.iphone.status.toLowerCase() == 'rented'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Mencari data booking aktif yang sedang menyewa unit ini
  Future<BookingModel?> getActiveBookingForUnit(String assetCode) async {
    return getActiveBookingForUnitSync(assetCode);
  }

  /// Memperbarui status unit di inventory
  Future<IphoneModel> updateUnitStatus(
    String assetCode,
    String newStatus, {
    int? batteryHealth,
  }) async {
    try {
      await ApiService().updateUnitStatusApi(
        assetCode,
        newStatus,
        batteryHealth: batteryHealth,
      );
    } catch (_) {}

    final source = _inventory.isNotEmpty ? _inventory : MockBookingData.inventory;
    final idx = source.indexWhere(
      (u) => u.assetCode.toLowerCase() == assetCode.toLowerCase(),
    );
    if (idx != -1) {
      final current = source[idx];
      final updated = current.copyWith(
        status: newStatus,
        batteryHealth: batteryHealth ?? current.batteryHealth,
      );
      source[idx] = updated;

      final mockIdx = MockBookingData.inventory.indexWhere(
        (u) => u.assetCode.toLowerCase() == assetCode.toLowerCase(),
      );
      if (mockIdx != -1) {
        MockBookingData.inventory[mockIdx] = updated;
      }

      final bIdx = _bookings.indexWhere(
        (b) => b.iphone.assetCode.toLowerCase() == assetCode.toLowerCase(),
      );
      if (bIdx != -1) {
        _bookings[bIdx] = _bookings[bIdx].copyWith(
          iphone: updated,
        );
      }

      _unitSummaryCache = null;

      return updated;
    }

    return IphoneModel(
      id: 0,
      name: 'iPhone',
      storage: '128GB',
      color: 'Default',
      serialNumber: '-',
      assetCode: assetCode,
      status: newStatus,
      batteryHealth: batteryHealth ?? 100,
    );
  }

  /// Mengambil jadwal sewa sebuah unit iPhone (riwayat, aktif, mendatang)
  Future<List<BookingModel>> getUnitRentalSchedule(
    String assetCode, {
    String? timeframeFilter,
  }) async {
    try {
      final res = await ApiService().getUnitScheduleApi(assetCode, timeframe: timeframeFilter);
      if (res != null && res['data'] is List) {
        final list = (res['data'] as List)
            .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return list;
      }
    } catch (_) {}

    final normalizedCode = assetCode.trim().toLowerCase();

    // Filter booking berdasarkan kode aset dari database lokal
    List<BookingModel> list = _bookings.where((b) {
      return b.iphone.assetCode.toLowerCase() == normalizedCode;
    }).toList();

    // Urutkan berdasarkan tanggal mulai (terbaru ke terlama)
    list.sort((a, b) => b.startDate.compareTo(a.startDate));

    // Filter timeframe jika ada
    if (timeframeFilter != null && timeframeFilter.isNotEmpty && timeframeFilter.toLowerCase() != 'semua') {
      final tf = timeframeFilter.toLowerCase();
      if (tf == 'aktif') {
        list = list.where((b) => b.status == BookingStatus.rented).toList();
      } else if (tf == 'mendatang') {
        list = list.where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending).toList();
      } else if (tf == 'selesai') {
        list = list.where((b) => b.status == BookingStatus.returned || b.status == BookingStatus.cancelled).toList();
      }
    }

    return list;
  }


  /// Mengambil data metrik dan operasional lengkap untuk layar dashboard
  Future<Map<String, dynamic>> getOperationalDashboardData() async {
    // 1. Coba ambil dari REST API backend Skyrent
    try {
      final apiDashboard = await ApiService().getDashboardData();
      if (apiDashboard != null && apiDashboard['metrics'] != null) {
        final metrics = apiDashboard['metrics'] as Map<String, dynamic>;
        final financials = (apiDashboard['financials'] as Map<String, dynamic>?) ?? {};

        // Parse action items, recent bookings, dan all bookings dari API
        List<BookingModel> apiActionItems = [];
        final rawActions = apiDashboard['actionItems'] ?? apiDashboard['action_items'];
        if (rawActions is List) {
          apiActionItems = rawActions
              .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
              .toList();
        }

        List<BookingModel> apiRecentBookings = [];
        final rawRecent = apiDashboard['recentBookings'] ?? apiDashboard['recent_bookings'];
        if (rawRecent is List) {
          apiRecentBookings = rawRecent
              .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
              .toList();
        }

        List<BookingModel> apiAllBookings = [];
        final rawAll = apiDashboard['allBookings'] ?? apiDashboard['all_bookings'];
        if (rawAll is List) {
          apiAllBookings = rawAll
              .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
              .toList();
        }

        // KETIKA DATA DARI DATABASE BERHASIL DIAMBIL (termasuk saat antrean di database kosong):
        if (rawAll is List) {
          _hasFetchedFromApi = true;
          _bookings.clear();
          _bookings.addAll(apiAllBookings);
        }

        // Antrean transaksi murni dari database:
        final allQueue = (rawAll is List) ? apiAllBookings : List<BookingModel>.from(_bookings);
        final finalRecent = (rawRecent is List)
            ? apiRecentBookings
            : (allQueue.isNotEmpty ? allQueue.take(5).toList() : <BookingModel>[]);
        final finalActions = (rawActions is List)
            ? apiActionItems
            : <BookingModel>[];

        final availableUnitsVal = metrics['availableUnits'] ?? metrics['available_units'] ?? metrics['iphonesAvailable'] ?? 0;
        final unreturnedUnitsVal = metrics['unreturnedUnits'] ?? metrics['unreturned_units'] ?? metrics['returnToday'] ?? metrics['todayReturns'] ?? 0;
        final bookingTodayVal = metrics['bookingToday'] ?? metrics['booking_today'] ?? metrics['todayBookings'] ?? metrics['todayPickups'] ?? 0;
        final revenueTodayVal = (financials['totalRevenue'] ?? financials['total_revenue'] ?? metrics['revenueToday'] ?? metrics['revenue_today'] ?? 0).toDouble();

        return {
          'isOnline': true,
          'metrics': {
            // 4 Core Metrics dari booking-page.blade.php
            'availableUnits': availableUnitsVal,
            'unreturnedUnits': unreturnedUnitsVal,
            'bookingToday': bookingTodayVal,
            'revenueToday': revenueTodayVal,

            // General/legacy metrics
            'activeRentals': metrics['activeRentals'] ?? metrics['active_rentals'] ?? 0,
            'todayPickups': metrics['todayPickups'] ?? metrics['today_pickups'] ?? 0,
            'todayReturns': unreturnedUnitsVal,
            'overdueReturns': metrics['overdueReturns'] ?? metrics['overdue_returns'] ?? 0,
            'rentedUnits': metrics['rentedUnits'] ?? metrics['rented_units'] ?? 0,
            'maintenanceUnits': metrics['maintenanceUnits'] ?? metrics['maintenance_units'] ?? 0,
            'totalUnits': metrics['totalUnits'] ?? metrics['total_units'] ?? 0,
            'utilizationRate': (metrics['utilizationRate'] ?? metrics['utilization_rate'] ?? 0).round(),
          },
          'financials': {
            'totalRevenue': revenueTodayVal,
            'totalHeldDeposit': (financials['totalHeldDeposit'] ?? financials['total_held_deposit'] ?? 0).toDouble(),
            'totalRefundedDeposit': (financials['totalRefundedDeposit'] ?? financials['total_refunded_deposit'] ?? 0).toDouble(),
          },
          'actionItems': finalActions,
          'recentBookings': finalRecent,
          'allQueue': allQueue,
        };
      }
    } catch (_) {
      // Fallback lokal jika offline
    }

    await Future.delayed(const Duration(milliseconds: 50));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final allBookings = List<BookingModel>.from(_bookings);
    final inventory = List<IphoneModel>.from(MockBookingData.inventory);

    // 1. iPhone Tersedia: Unit iPhone yang tidak memiliki booking status 'confirmed' atau 'rented'
    final bookedIphoneIds = _bookings
        .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.rented)
        .map((b) => b.iphone.id)
        .toSet();
    final availableUnitsCount = inventory.where((u) =>
        !bookedIphoneIds.contains(u.id) &&
        !['maintenance', 'perawatan'].contains(u.status.toLowerCase())).length;

    // 2. iPhone Belum Kembali: Booking status 'confirmed' atau 'rented' yang end_booking_date <= today
    final unreturnedCount = _bookings.where((b) {
      if (b.status != BookingStatus.confirmed && b.status != BookingStatus.rented) return false;
      return b.endDate.isBefore(todayEnd) || b.endDate.isAtSameMomentAs(todayEnd);
    }).length;

    // 3. Booking Hari Ini: Booking dengan jadwal mulai hari ini
    final bookingTodayCount = _bookings.where((b) {
      final isStartToday = b.startDate.year == today.year &&
          b.startDate.month == today.month &&
          b.startDate.day == today.day;
      return isStartToday;
    }).length;

    // 4. Pendapatan Hari Ini: Total pembayaran hari ini
    double revenueToday = 0;
    for (final b in _bookings) {
      if (b.paymentStatus == PaymentStatus.paid || b.paymentStatus == PaymentStatus.partial) {
        final isStartToday = b.startDate.year == today.year &&
            b.startDate.month == today.month &&
            b.startDate.day == today.day;
        if (isStartToday) {
          revenueToday += b.price;
        }
      }
    }

    // Hitung status booking & antrean
    int activeRentals = 0;
    int todayPickups = 0;
    int todayReturns = unreturnedCount;
    int overdueReturns = 0;
    final List<BookingModel> actionItems = [];

    for (final b in allBookings) {
      if (b.status == BookingStatus.rented) {
        activeRentals++;
        final endDay = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
        if (endDay.isBefore(today)) {
          overdueReturns++;
          actionItems.add(b);
        } else if (endDay.isAtSameMomentAs(today)) {
          actionItems.add(b);
        }
      } else if (b.status == BookingStatus.confirmed) {
        final startDay = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
        if (startDay.isAtSameMomentAs(today) || startDay.isBefore(today)) {
          todayPickups++;
          actionItems.add(b);
        }
      } else if (b.status == BookingStatus.pending) {
        actionItems.add(b);
      }
    }

    int totalUnits = inventory.length;
    int rentedUnits = max(0, totalUnits - availableUnitsCount);
    int maintenanceUnits = inventory.where((u) => ['maintenance', 'perawatan'].contains(u.status.toLowerCase())).length;
    final double utilizationRate = totalUnits > 0 ? (rentedUnits / totalUnits) * 100 : 0;

    return {
      'isOnline': false,
      'metrics': {
        // 4 Core Metrics dari booking-page.blade.php
        'availableUnits': availableUnitsCount,
        'unreturnedUnits': unreturnedCount,
        'bookingToday': bookingTodayCount > 0 ? bookingTodayCount : todayPickups,
        'revenueToday': revenueToday,

        // General/legacy metrics
        'activeRentals': activeRentals,
        'todayPickups': todayPickups,
        'todayReturns': todayReturns,
        'overdueReturns': overdueReturns,
        'rentedUnits': rentedUnits,
        'maintenanceUnits': maintenanceUnits,
        'totalUnits': totalUnits,
        'utilizationRate': utilizationRate.round(),
      },
      'financials': {
        'totalRevenue': revenueToday,
        'totalHeldDeposit': 0.0,
        'totalRefundedDeposit': 0.0,
      },
      'actionItems': actionItems,
      'recentBookings': allBookings.take(5).toList(),
      'allQueue': allBookings,
    };
  }

  /// Mengambil data inspeksi pengembalian dari backend (estimasi denda)
  Future<Map<String, dynamic>?> getInspectionPreview(String bookingCode) async {
    try {
      final res = await ApiService().inspectReturn(bookingCode);
      if (res != null && res['status'] == 'success') {
        return res;
      }
    } catch (_) {}

    // Fallback kalkulasi offline berbasis model booking jika API tidak dapat dijangkau
    try {
      final b = _bookings.firstWhere(
        (item) =>
            item.bookingCode.toLowerCase() == bookingCode.toLowerCase() ||
            item.id.toString() == bookingCode,
      );
      final isLate = b.isCurrentlyLate;
      final h = b.currentLateHours;
      final m = b.currentLateMinutes;
      final fee = b.estimatedLateFee;

      return {
        'status': 'success',
        'data': {
          'booking_code': b.bookingCode,
          'customer_name': b.customerName,
          'customer_phone': b.customerPhone,
          'unit_name': b.iphone.fullName,
          'asset_code': b.iphone.assetCode,
          'serial_number': b.iphone.serialNumber,
          'current_battery_health': b.iphone.batteryHealth,
          'initial_deposit': b.deposit,
          'is_overdue': b.isCurrentlyOverdue,
          'is_late': isLate,
          'diff_hours': b.currentDiffHours,
          'hours_late': h,
          'late_hours': h,
          'late_minutes': m,
          'duration_text': b.lateDurationFormatted,
          'days_late': h ~/ 24,
          'estimated_late_fee': fee,
          'late_fee': fee,
          'estimated_deposit_refund': 0.0,
        }
      };
    } catch (_) {
      return null;
    }
  }

  /// Menghapus booking dari sistem (API dan memori lokal)
  Future<bool> deleteBooking(String idOrCode) async {
    bool apiSuccess = false;
    try {
      apiSuccess = await ApiService().deleteBooking(idOrCode);
    } catch (_) {}

    final initialCount = _bookings.length;
    _bookings.removeWhere((b) =>
        b.id.toString() == idOrCode.trim() ||
        b.bookingCode.toLowerCase() == idOrCode.trim().toLowerCase());

    final localSuccess = _bookings.length < initialCount;
    return apiSuccess || localSuccess;
  }

  /// Memvalidasi nomor WhatsApp menggunakan Fonnte API via backend
  Future<Map<String, dynamic>> validateWhatsApp(String phone) async {
    try {
      return await ApiService().validateWhatsApp(phone);
    } catch (e) {
      return {
        'status': 'error',
        'registered': false,
        'message': 'Gagal validasi nomor WhatsApp: $e',
      };
    }
  }

  /// Mengambil data laporan penjualan dan pendapatan sewa dengan filter
  Future<Map<String, dynamic>> getSalesReportData({
    String period = 'Hari Ini',
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await ApiService().getSalesReportApi(
        period: period,
        paymentMethod: paymentMethod,
        startDate: startDate,
        endDate: endDate,
        page: page,
        perPage: perPage,
      );
      if (res != null) {
        // Adapt API response to PaymentTransactionModel objects
        final resTxs = res['transactions'] as List<dynamic>? ?? [];
        res['transactions'] = resTxs.map((t) {
          final txMap = Map<String, dynamic>.from(t as Map);
          return PaymentTransactionModel(
            id: txMap['id'] is int ? txMap['id'] : int.tryParse(txMap['id']?.toString() ?? '0') ?? 0,
            bookingId: txMap['booking_id'] is int ? txMap['booking_id'] : int.tryParse(txMap['booking_id']?.toString() ?? '0') ?? 0,
            bookingCode: txMap['booking_code']?.toString() ?? '-',
            customerName: txMap['customer_name']?.toString() ?? 'Pelanggan',
            customerPhone: txMap['customer_phone']?.toString() ?? '-',
            iphoneName: txMap['iphone_name']?.toString() ?? 'iPhone',
            rentTotal: (txMap['rent_total'] as num?)?.toDouble() ?? (txMap['paid_amount'] as num?)?.toDouble() ?? 0,
            paidAmount: (txMap['paid_amount'] as num?)?.toDouble() ?? 0,
            remainingAmount: (txMap['remaining_amount'] as num?)?.toDouble() ?? 0,
            depositAmount: (txMap['deposit_amount'] as num?)?.toDouble() ?? 0,
            depositStatus: DepositStatus.fromString(txMap['deposit_status']?.toString() ?? 'held'),
            paymentStatus: txMap['payment_status']?.toString() ?? 'paid',
            paymentMethod: txMap['payment_method']?.toString() ?? 'Tunai Kasir',
            transactionDate: DateTime.tryParse(txMap['transaction_date']?.toString() ?? '') ?? DateTime.now(),
            notes: txMap['notes']?.toString() ?? txMap['type']?.toString() ?? 'Pelunasan',
          );
        }).toList();

        // Convert breakdowns to strong Map types to prevent cast errors
        final rawPm = res['paymentMethodBreakdown'] ?? res['payment_method_breakdown'];
        final Map<String, double> pmBreakdown = {};
        if (rawPm is Map) {
          rawPm.forEach((k, v) {
            if (v is num) pmBreakdown[k.toString()] = v.toDouble();
          });
        }
        res['paymentMethodBreakdown'] = pmBreakdown;

        final rawType = res['typeBreakdown'] ?? res['type_breakdown'];
        final Map<String, double> typeBreakdown = {};
        if (rawType is Map) {
          rawType.forEach((k, v) {
            if (v is num) typeBreakdown[k.toString()] = v.toDouble();
          });
        }
        res['typeBreakdown'] = typeBreakdown;

        final rawModelRev = res['modelRevenue'] ?? res['model_revenue'];
        final Map<String, double> modelRev = {};
        if (rawModelRev is Map) {
          rawModelRev.forEach((k, v) {
            if (v is num) modelRev[k.toString()] = v.toDouble();
          });
        }
        res['modelRevenue'] = modelRev;

        final rawModelCount = res['modelRentalCount'] ?? res['model_rental_count'];
        final Map<String, int> modelCount = {};
        if (rawModelCount is Map) {
          rawModelCount.forEach((k, v) {
            if (v is num) modelCount[k.toString()] = v.toInt();
          });
        }
        res['modelRentalCount'] = modelCount;

        final rawAffBreakdown = res['affiliateBreakdown'] ?? res['affiliate_breakdown'];
        if (rawAffBreakdown is List) {
          res['affiliateBreakdown'] = rawAffBreakdown.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        } else {
          res['affiliateBreakdown'] = <Map<String, dynamic>>[];
        }

        if (res['pagination'] is Map) {
          res['pagination'] = Map<String, dynamic>.from(res['pagination'] as Map);
        } else {
          final txsList = res['transactions'] as List;
          res['pagination'] = {
            'current_page': page,
            'per_page': perPage,
            'total': txsList.length,
            'last_page': 1,
          };
        }

        return res;
      }
    } catch (e) {
      // Fallback
    }

    // Fallback if offline: accurately match real database records
    await Future.delayed(const Duration(milliseconds: 60));
    final now = DateTime.now();

    final List<PaymentTransactionModel> sampleTxs = [
      PaymentTransactionModel(
        id: 9,
        bookingId: 19,
        bookingCode: 'SKY260923BZBO',
        customerName: 'test',
        customerPhone: '+62-8314-6838-432',
        iphoneName: 'iPhone 13 Pink',
        rentTotal: 100000,
        paidAmount: 100000,
        remainingAmount: 0,
        depositAmount: 0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'QRIS',
        transactionDate: DateTime(2026, 9, 23, 19, 14),
        notes: 'Pelunasan|Jaminan KTP',
      ),
      PaymentTransactionModel(
        id: 8,
        bookingId: 16,
        bookingCode: 'SKY260923C0B5',
        customerName: 'testt',
        customerPhone: '+62-8314-6838-432',
        iphoneName: 'iPhone 13 Pink',
        rentTotal: 100000,
        paidAmount: 100000,
        remainingAmount: 0,
        depositAmount: 0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'Tunai',
        transactionDate: DateTime(2026, 9, 23, 10, 37),
        notes: 'Pelunasan|Jaminan SIM',
      ),
      PaymentTransactionModel(
        id: 7,
        bookingId: 13,
        bookingCode: 'SKY260922CT1G',
        customerName: 'test_web',
        customerPhone: '+62-8314-6838-432',
        iphoneName: 'iPhone 13 Aja',
        rentTotal: 100000,
        paidAmount: 100000,
        remainingAmount: 0,
        depositAmount: 0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'Transfer / VA Bank',
        transactionDate: DateTime(2026, 9, 22, 18, 29),
        notes: 'Pelunasan|Jaminan KTP',
      ),
      PaymentTransactionModel(
        id: 6,
        bookingId: 12,
        bookingCode: 'SKY260921KF1K',
        customerName: 'test',
        customerPhone: '+62 83146838432',
        iphoneName: 'iPhone 13 Aja',
        rentTotal: 100000,
        paidAmount: 100000,
        remainingAmount: 0,
        depositAmount: 0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'Transfer / VA Bank',
        transactionDate: DateTime(2026, 9, 21, 15, 49),
        notes: 'Pelunasan|Jaminan KTP',
      ),
    ];

    // Gabungkan transaksi mock operasional dengan sample data (keyed by bookingCode to prevent ID collision)
    final Map<String, PaymentTransactionModel> combinedMap = {};
    for (final tx in MockBookingData.paymentTransactions) {
      combinedMap[tx.bookingCode] = tx;
    }
    for (final tx in sampleTxs) {
      combinedMap[tx.bookingCode] = tx;
    }
    final allTransactions = combinedMap.values.toList();

    DateTime filterStart;
    DateTime filterEnd;

    if (startDate != null && endDate != null) {
      filterStart = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      filterEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    } else {
      switch (period.toLowerCase()) {
        case 'hari ini':
        case 'today':
          filterStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
          filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case 'minggu ini':
        case 'this_week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          filterStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          filterEnd = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59, 999);
          break;
        case 'bulan ini':
        case 'this_month':
          filterStart = DateTime(now.year, now.month, 1, 0, 0, 0);
          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          filterEnd = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
          break;
        case 'semua':
        case 'all':
        default:
          filterStart = DateTime(2020, 1, 1, 0, 0, 0);
          filterEnd = DateTime(now.year + 1, 12, 31, 23, 59, 59, 999);
          break;
      }
    }

    List<PaymentTransactionModel> finalTxs = allTransactions.where((tx) {
      return !tx.transactionDate.isBefore(filterStart) && !tx.transactionDate.isAfter(filterEnd);
    }).toList();

    if (paymentMethod != null &&
        paymentMethod.isNotEmpty &&
        !['semua', 'all', 'semua metode'].contains(paymentMethod.toLowerCase())) {
      finalTxs = finalTxs.where((tx) => tx.paymentMethod.toLowerCase().contains(paymentMethod.toLowerCase())).toList();
    }

    final double totalRev = finalTxs.fold(0.0, (s, tx) => s + tx.paidAmount);
    final double cashAmount = finalTxs
        .where((tx) => tx.paymentMethod.toLowerCase().contains('tunai') || tx.paymentMethod.toLowerCase().contains('cash'))
        .fold(0.0, (s, tx) => s + tx.paidAmount);
    final double transferAmount = finalTxs
        .where((tx) => tx.paymentMethod.toLowerCase().contains('transfer') || tx.paymentMethod.toLowerCase().contains('bank') || tx.paymentMethod.toLowerCase().contains('va'))
        .fold(0.0, (s, tx) => s + tx.paidAmount);
    final double qrisAmount = finalTxs
        .where((tx) => tx.paymentMethod.toLowerCase().contains('qris'))
        .fold(0.0, (s, tx) => s + tx.paidAmount);
    final double heldDep = finalTxs.fold(0.0, (s, tx) => s + tx.depositAmount);

    final Map<String, double> payBreakdown = {};
    for (final tx in finalTxs) {
      payBreakdown[tx.paymentMethod] = (payBreakdown[tx.paymentMethod] ?? 0.0) + tx.paidAmount;
    }

    final Map<String, double> typeBreakdown = {
      'dp': 0.0,
      'payment': totalRev,
      'extend': 0.0,
      'penalty': 0.0,
    };

    final Map<String, double> modelRevenue = {};
    final Map<String, int> modelCount = {};
    for (final tx in finalTxs) {
      modelRevenue[tx.iphoneName] = (modelRevenue[tx.iphoneName] ?? 0.0) + tx.paidAmount;
      modelCount[tx.iphoneName] = (modelCount[tx.iphoneName] ?? 0) + 1;
    }

    return {
      'status': 'success',
      'period': period,
      'start_date': '${filterStart.year}-${filterStart.month.toString().padLeft(2, '0')}-${filterStart.day.toString().padLeft(2, '0')}',
      'end_date': '${filterEnd.year}-${filterEnd.month.toString().padLeft(2, '0')}-${filterEnd.day.toString().padLeft(2, '0')}',
      'summary': {
        'totalRevenue': totalRev,
        'totalDepositsHeld': heldDep,
        'totalDepositsRefunded': 0.0,
        'transactionCount': finalTxs.length,
        'averageTransactionValue': finalTxs.isNotEmpty ? totalRev / finalTxs.length : 0.0,
        'cashAmount': cashAmount,
        'transferAmount': transferAmount,
        'qrisAmount': qrisAmount,
        'total_revenue': totalRev,
        'total_deposits_held': heldDep,
        'total_deposits_refunded': 0.0,
        'transaction_count': finalTxs.length,
        'average_transaction_value': finalTxs.isNotEmpty ? totalRev / finalTxs.length : 0.0,
        'cash_amount': cashAmount,
        'transfer_amount': transferAmount,
        'qris_amount': qrisAmount,
      },
      'paymentMethodBreakdown': payBreakdown,
      'payment_method_breakdown': payBreakdown,
      'typeBreakdown': typeBreakdown,
      'type_breakdown': typeBreakdown,
      'modelRentalCount': modelCount,
      'model_rental_count': modelCount,
      'modelRevenue': modelRevenue,
      'model_revenue': modelRevenue,
      'affiliateBreakdown': _affiliates.map((aff) {
        return {
          'id': aff.id,
          'code': aff.code,
          'name': aff.name,
          'city': aff.city ?? '-',
          'revenue': aff.revenueToday,
          'booking_count': aff.bookingsCount,
          'is_active': aff.isActive,
          'iphones_count': aff.iphonesCount,
          'revenue_today': aff.revenueToday,
          'total_revenue': aff.totalRevenue,
        };
      }).toList(),
      'affiliate_breakdown': _affiliates.map((aff) {
        return {
          'id': aff.id,
          'code': aff.code,
          'name': aff.name,
          'city': aff.city ?? '-',
          'revenue': aff.revenueToday,
          'booking_count': aff.bookingsCount,
          'is_active': aff.isActive,
          'iphones_count': aff.iphonesCount,
          'revenue_today': aff.revenueToday,
          'total_revenue': aff.totalRevenue,
        };
      }).toList(),
      'transactions': finalTxs,
    };
  }

  static final List<NotificationModel> _notifications = [
    NotificationModel(
      id: 'NOTIF-001',
      title: 'Unit Terlambat Kembali',
      message: 'Penyewa Maya Anggraini (SKY260906N5P6) terlambat 1 hari mengembalikan iPhone 15 Black.',
      type: NotificationType.overdue,
      createdAt: DateTime(2026, 9, 9, 8, 30),
      bookingCode: 'SKY260906N5P6',
      assetCode: 'AST-IP15-004',
      isRead: false,
    ),
    NotificationModel(
      id: 'NOTIF-002',
      title: 'Jadwal Pickup Hari Ini',
      message: 'Ahmad Fauzi (SKY260909A8F1) dijadwalkan serah terima iPhone 15 Pro pukul 14:00 WIB di outlet.',
      type: NotificationType.pickupToday,
      createdAt: DateTime(2026, 9, 9, 9, 0),
      bookingCode: 'SKY260909A8F1',
      assetCode: 'AST-IP15P-001',
      isRead: false,
    ),
    NotificationModel(
      id: 'NOTIF-003',
      title: 'Pemeriksaan Servis Unit',
      message: 'Unit iPhone 13 Starlight (AST-IP13-002) dalam status maintenance memerlukan validasi teknisi.',
      type: NotificationType.maintenance,
      createdAt: DateTime(2026, 9, 9, 10, 15),
      assetCode: 'AST-IP13-002',
      isRead: false,
    ),
    NotificationModel(
      id: 'NOTIF-004',
      title: 'Tutup Buku Kasir Shift',
      message: 'Operasional shift pagi selesai. Siap cetak laporan penutupan kasir thermal 58mm.',
      type: NotificationType.closing,
      createdAt: DateTime(2026, 9, 9, 12, 0),
      isRead: true,
    ),
  ];

  /// Mengambil daftar notifikasi operasional
  Future<List<NotificationModel>> getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 60));
    return List<NotificationModel>.from(_notifications);
  }

  /// Menandai satu notifikasi telah dibaca
  Future<void> markNotificationAsRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    }
  }

  /// Menandai semua notifikasi telah dibaca
  Future<void> markAllNotificationsAsRead() async {
    await Future.delayed(const Duration(milliseconds: 50));
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
  }

  /// Menghitung jumlah notifikasi belum dibaca
  Future<int> getUnreadNotificationCount() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return _notifications.where((n) => !n.isRead).length;
  }

  /// Ekspor laporan penjualan ke format CSV teks
  String exportSalesReportCsv(Map<String, dynamic> reportData) {
    final transactions = (reportData['transactions'] as List<PaymentTransactionModel>?) ?? [];
    final buffer = StringBuffer();
    buffer.writeln('No,Kode Booking,Pelanggan,Nomor HP,Unit iPhone,Metode Pembayaran,Nominal Bayar,Deposit,Status Bayar,Tanggal');

    for (int i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final dateStr = '${t.transactionDate.year}-${t.transactionDate.month.toString().padLeft(2, '0')}-${t.transactionDate.day.toString().padLeft(2, '0')}';
      buffer.writeln(
        '${i + 1},"${t.bookingCode}","${t.customerName}","${t.customerPhone}","${t.iphoneName}","${t.paymentMethod}",${t.paidAmount.toInt()},${t.depositAmount.toInt()},"${t.paymentStatus}","$dateStr"',
      );
    }
    return buffer.toString();
  }

  /// Ekspor ringkasan laporan tutup kasir ke format thermal ESC/POS 58mm (tepat 32 kolom)
  String exportClosingReportEscPos(Map<String, dynamic> reportData) {
    const int width = 32;
    final divider = '=' * width;
    final subDivider = '-' * width;

    String center(String text) {
      if (text.length >= width) return text.substring(0, width);
      final left = (width - text.length) ~/ 2;
      final right = width - text.length - left;
      return ' ' * left + text + ' ' * right;
    }

    String twoCol(String left, String right) {
      if (left.length + right.length + 1 > width) {
        final maxLeft = width - right.length - 1;
        if (maxLeft > 0 && left.length > maxLeft) {
          left = left.substring(0, maxLeft);
        }
      }
      final spaces = width - left.length - right.length;
      return left + ' ' * (spaces > 0 ? spaces : 1) + right;
    }

    final summaryRaw = reportData['summary'];
    final Map<String, dynamic> summary = summaryRaw is Map ? Map<String, dynamic>.from(summaryRaw) : {};
    final rawBreakdown = reportData['paymentMethodBreakdown'] ?? reportData['payment_method_breakdown'];
    final Map<String, double> breakdown = {};
    if (rawBreakdown is Map) {
      rawBreakdown.forEach((k, v) {
        if (v is num) breakdown[k.toString()] = v.toDouble();
      });
    }
    final double totalRev = (summary['totalRevenue'] as num?)?.toDouble() ??
        (summary['total_revenue'] as num?)?.toDouble() ??
        0;
    final double heldDep = (summary['totalDepositsHeld'] as num?)?.toDouble() ??
        (summary['total_deposits_held'] as num?)?.toDouble() ??
        0;
    final double refundDep = (summary['totalDepositsRefunded'] as num?)?.toDouble() ??
        (summary['total_deposits_refunded'] as num?)?.toDouble() ??
        0;
    final int txCount = (summary['transactionCount'] as num?)?.toInt() ??
        (summary['transaction_count'] as num?)?.toInt() ??
        0;

    final lines = <String>[];
    lines.add(divider);
    lines.add(center('SKYRENTAL OUTLET'));
    lines.add(center('LAPORAN PENUTUPAN KASIR'));
    lines.add(center('OUTLET MALIOBORO'));
    lines.add(divider);

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    lines.add(twoCol('Waktu Cetak :', dateStr));
    lines.add(twoCol('Kasir/Admin :', 'Admin SKYRental'));
    lines.add(twoCol('Shift       :', 'Pagi (08:00-16:00)'));
    lines.add(subDivider);

    lines.add(center('RINGKASAN OMZET & KAS'));
    lines.add(twoCol('Total Omzet :', Formatters.currency(totalRev)));
    lines.add(twoCol('Total Trans :', '$txCount Transaksi'));
    lines.add(twoCol('Dep. Kasir  :', Formatters.currency(heldDep)));
    lines.add(twoCol('Dep. Refund :', Formatters.currency(refundDep)));
    lines.add(subDivider);

    lines.add(center('RINCIAN METODE BAYAR'));
    breakdown.forEach((method, amount) {
      lines.add(twoCol(method, Formatters.currency(amount)));
    });
    lines.add(subDivider);

    lines.add(center('STATUS TUTUP KASIR: VALID'));
    lines.add(center('DIARSIPKAN SECARA ELEKTRONIK'));
    lines.add(divider);
    lines.add('');
    lines.add('');

    return lines.join('\n');
  }

  ShopSettingsModel _shopSettings = ShopSettingsModel.defaultSettings();

  /// Mengambil konfigurasi toko dan outlet
  Future<ShopSettingsModel> getShopSettings() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _shopSettings;
  }

  /// Memperbarui konfigurasi toko dan outlet
  Future<ShopSettingsModel> updateShopSettings(ShopSettingsModel newSettings) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _shopSettings = newSettings;
    return _shopSettings;
  }

  // ==========================================
  // MANAJEMEN MITRA AFFILIATE & MUTASI IPHONE
  // ==========================================

  List<AffiliateModel> _affiliates = [];
  List<IphoneTransferModel> _iphoneTransfers = [];

  /// Mengambil daftar mitra affiliate (dengan sinkronisasi API jika terhubung)
  Future<List<AffiliateModel>> getAffiliates({
    String? search,
    bool? isActive,
    bool forceRefresh = false,
  }) async {
    try {
      final res = await _apiService.getAffiliatesApi(search: search, isActive: isActive);
      if (res != null && res['data'] is List) {
        final list = (res['data'] as List)
            .map((item) => AffiliateModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _affiliates = list;
        return List.unmodifiable(_affiliates);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403) rethrow;
    } catch (_) {}



    // Fallback in-memory filter jika offline
    var result = List<AffiliateModel>.from(_affiliates);
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      result = result.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.code.toLowerCase().contains(q) ||
          (a.city?.toLowerCase().contains(q) ?? false)).toList();
    }
    if (isActive != null) {
      result = result.where((a) => a.isActive == isActive).toList();
    }
    return List.unmodifiable(result);
  }

  /// Mengambil detail lengkap mitra affiliate
  Future<AffiliateModel?> getAffiliateDetail(int id) async {
    try {
      final data = await _apiService.getAffiliateDetailApi(id);
      if (data != null) {
        final aff = AffiliateModel.fromJson(data);
        final index = _affiliates.indexWhere((a) => a.id == id);
        if (index != -1) {
          _affiliates[index] = aff;
        } else {
          _affiliates.add(aff);
        }
        return aff;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403) rethrow;
    } catch (_) {}

    final match = _affiliates.where((a) => a.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  /// Mengambil daftar unit iPhone yang dialokasikan ke cabang affiliate tertentu
  Future<List<IphoneModel>> getAffiliateIphones(int affiliateId, {AffiliateModel? affiliate}) async {
    try {
      final list = await _apiService.getAffiliateIphonesApi(affiliateId);
      if (list != null) {
        return list
            .map((item) => IphoneModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback: check affiliate pusat logic & filter locally
    final aff = affiliate ?? _affiliates.where((a) => a.id == affiliateId).firstOrNull;
    final isPusat = (aff?.isPusat ?? false) || affiliateId == 4;
    final source = _inventory.isNotEmpty ? _inventory : MockBookingData.inventory;

    return source.where((unit) {
      if (isPusat) {
        return unit.affiliateId == null || unit.affiliateId == affiliateId;
      }
      if (unit.affiliateId != null) {
        return unit.affiliateId == affiliateId;
      }
      if (aff != null && aff.code.isNotEmpty) {
        return unit.assetCode.toLowerCase().contains(aff.code.toLowerCase());
      }
      return false;
    }).toList();
  }

  /// Mengambil daftar booking yang terkait dengan cabang affiliate tertentu
  Future<List<BookingModel>> getAffiliateBookings(int affiliateId, {AffiliateModel? affiliate}) async {
    try {
      final list = await _apiService.getAffiliateBookingsApi(affiliateId);
      if (list != null) {
        return list
            .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback: filter locally
    final aff = affiliate ?? _affiliates.where((a) => a.id == affiliateId).firstOrNull;
    final isPusat = (aff?.isPusat ?? false) || affiliateId == 4;
    final source = _bookings.isNotEmpty ? _bookings : MockBookingData.items;

    if (isPusat) {
      return List.unmodifiable(source);
    }

    return source.where((b) {
      if (aff != null && aff.code.isNotEmpty) {
        return b.bookingCode.toLowerCase().contains(aff.code.toLowerCase()) ||
            b.iphone.assetCode.toLowerCase().contains(aff.code.toLowerCase());
      }
      return false;
    }).toList();
  }

  /// Menambah mitra affiliate baru
  Future<AffiliateModel> createAffiliate(AffiliateModel newAffiliate) async {
    try {
      final res = await _apiService.createAffiliateApi(newAffiliate.toJson());
      if (res != null) {
        final created = AffiliateModel.fromJson(res);
        _affiliates.insert(0, created);
        return created;
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
    }

    final localId = _affiliates.isEmpty
        ? 1
        : (_affiliates.map((a) => a.id).reduce(max) + 1);
    final fallback = newAffiliate.copyWith(
      id: localId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _affiliates.insert(0, fallback);
    return fallback;
  }

  /// Memperbarui data mitra affiliate
  Future<AffiliateModel> updateAffiliate(AffiliateModel updated) async {
    try {
      final res = await _apiService.updateAffiliateApi(updated.id, updated.toJson());
      if (res != null) {
        final serverUpdated = AffiliateModel.fromJson(res);
        final index = _affiliates.indexWhere((a) => a.id == updated.id);
        if (index != -1) _affiliates[index] = serverUpdated;
        return serverUpdated;
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
    }

    final index = _affiliates.indexWhere((a) => a.id == updated.id);
    if (index != -1) {
      _affiliates[index] = updated.copyWith(updatedAt: DateTime.now());
      return _affiliates[index];
    }
    return updated;
  }

  /// Menghapus mitra affiliate
  Future<bool> deleteAffiliate(int id) async {
    try {
      final success = await _apiService.deleteAffiliateApi(id);
      if (success) {
        _affiliates.removeWhere((a) => a.id == id);
        return true;
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
    }

    _affiliates.removeWhere((a) => a.id == id);
    return true;
  }

  /// Mengambil daftar riwayat transfer / mutasi iPhone
  Future<List<IphoneTransferModel>> getIphoneTransfers({
    String? status,
    int? affiliateId,
    String? type,
    bool forceRefresh = false,
  }) async {
    try {
      final list = await _apiService.getIphoneTransfersApi(
        status: status,
        affiliateId: affiliateId,
        type: type,
      );
      if (list != null) {
        final transfers = list
            .map((item) => IphoneTransferModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _iphoneTransfers = transfers;
        return List.unmodifiable(_iphoneTransfers);
      }
    } catch (_) {}

    var result = List<IphoneTransferModel>.from(_iphoneTransfers);
    if (status != null && status.isNotEmpty) {
      result = result.where((t) => t.status.toLowerCase() == status.toLowerCase()).toList();
    }
    if (affiliateId != null) {
      if (type == 'inbound') {
        result = result.where((t) => t.toAffiliateId == affiliateId).toList();
      } else if (type == 'outbound') {
        result = result.where((t) => t.fromAffiliateId == affiliateId).toList();
      } else {
        result = result.where((t) => t.fromAffiliateId == affiliateId || t.toAffiliateId == affiliateId).toList();
      }
    }
    return List.unmodifiable(result);
  }

  /// Mengirim iPhone ke cabang affiliate lain
  Future<IphoneTransferModel> createIphoneTransfer({
    required int iphoneId,
    required int toAffiliateId,
    int? fromAffiliateId,
    String? notes,
  }) async {
    // Cari unit di inventaris lokal jika fromAffiliateId tidak dispesifikasikan
    final matchingUnit = _inventory.where((u) => u.id == iphoneId).firstOrNull;
    final effectiveFromAffiliateId = fromAffiliateId ??
        matchingUnit?.affiliateId ??
        AuthService().affiliateId;

    try {
      final res = await _apiService.createIphoneTransferApi(
        iphoneId: iphoneId,
        toAffiliateId: toAffiliateId,
        fromAffiliateId: effectiveFromAffiliateId,
        notes: notes,
      );
      if (res != null && res['data'] != null) {
        final tr = IphoneTransferModel.fromJson(res['data'] as Map<String, dynamic>);
        _iphoneTransfers.insert(0, tr);

        // Update status unit di inventaris lokal menjadi transferred / in_transit
        final invIdx = _inventory.indexWhere((u) => u.id == iphoneId);
        if (invIdx != -1) {
          _inventory[invIdx] = _inventory[invIdx].copyWith(status: 'transferred');
        }
        return tr;
      }
    } catch (e) {
      if (e is ApiException || e.toString().contains('Exception:')) rethrow;
    }

    final targetAffiliate = _affiliates.firstWhere(
      (a) => a.id == toAffiliateId,
      orElse: () => AffiliateModel(id: toAffiliateId, code: 'CAB', name: 'Cabang Tujuan', slug: 'cabang'),
    );

    final localId = _iphoneTransfers.isEmpty
        ? 1
        : (_iphoneTransfers.map((t) => t.id).reduce(max) + 1);

    final tr = IphoneTransferModel(
      id: localId,
      iphoneId: iphoneId,
      iphoneName: matchingUnit?.name ?? 'iPhone #$iphoneId',
      iphoneSerial: matchingUnit?.serialNumber ?? 'SN-$iphoneId',
      fromAffiliateId: effectiveFromAffiliateId,
      fromAffiliateName: 'Pusat (SkyRent)',
      fromAffiliateCode: 'PST',
      toAffiliateId: toAffiliateId,
      toAffiliateName: targetAffiliate.name,
      toAffiliateCode: targetAffiliate.code,
      senderName: AuthService().currentUser?.name ?? 'Admin',
      status: 'in_transit',
      notes: notes,
      sentAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    _iphoneTransfers.insert(0, tr);
    final invIdx = _inventory.indexWhere((u) => u.id == iphoneId);
    if (invIdx != -1) {
      _inventory[invIdx] = _inventory[invIdx].copyWith(status: 'transferred');
    }
    return tr;
  }

  /// Menerima mutasi iPhone di cabang tujuan
  Future<IphoneTransferModel> acceptIphoneTransfer(int transferId) async {
    try {
      final res = await _apiService.acceptIphoneTransferApi(transferId);
      if (res != null && res['data'] != null) {
        final tr = IphoneTransferModel.fromJson(res['data'] as Map<String, dynamic>);
        final index = _iphoneTransfers.indexWhere((t) => t.id == transferId);
        if (index != -1) _iphoneTransfers[index] = tr;

        // Perbarui status unit iPhone di inventaris lokal menjadi tersedia dan cabang tujuan
        if (_inventory.isEmpty) {
          _inventory.addAll(MockBookingData.inventory);
        }
        final invIdx = _inventory.indexWhere((u) => u.id == tr.iphoneId);
        if (invIdx != -1) {
          _inventory[invIdx] = _inventory[invIdx].copyWith(
            status: 'tersedia',
            affiliateId: tr.toAffiliateId,
            branchName: tr.toAffiliateName,
          );
        }
        return tr;
      }
    } catch (e) {
      if (e is ApiException || e.toString().contains('Exception:')) rethrow;
    }

    final index = _iphoneTransfers.indexWhere((t) => t.id == transferId);
    if (index != -1) {
      final updated = _iphoneTransfers[index].copyWith(
        status: 'received',
        receiverName: 'Admin Cabang',
        receivedAt: DateTime.now(),
      );
      _iphoneTransfers[index] = updated;

      if (_inventory.isEmpty) {
        _inventory.addAll(MockBookingData.inventory);
      }
      final invIdx = _inventory.indexWhere((u) => u.id == updated.iphoneId);
      if (invIdx != -1) {
        _inventory[invIdx] = _inventory[invIdx].copyWith(
          status: 'tersedia',
          affiliateId: updated.toAffiliateId,
          branchName: updated.toAffiliateName,
        );
      }
      return updated;
    }
    throw Exception('Transfer iPhone #$transferId tidak ditemukan.');
  }

  /// Mengambil rekap pendapatan affiliate
  Future<AffiliateRevenueSummaryModel> getAffiliateRevenue(
    int affiliateId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final data = await _apiService.getAffiliateRevenueApi(
        affiliateId,
        startDate: startDate,
        endDate: endDate,
      );
      if (data != null) {
        return AffiliateRevenueSummaryModel.fromJson(data);
      }
    } catch (_) {}

    final aff = _affiliates.firstWhere(
      (a) => a.id == affiliateId,
      orElse: () => AffiliateModel(id: affiliateId, code: 'AFF', name: 'Mitra Affiliate', slug: 'affiliate'),
    );
    return AffiliateRevenueSummaryModel(
      affiliateId: aff.id,
      affiliateName: aff.name,
      affiliateCode: aff.code,
      startDate: startDate ?? DateTime.now().subtract(const Duration(days: 6)).toIso8601String().substring(0, 10),
      endDate: endDate ?? DateTime.now().toIso8601String().substring(0, 10),
      affiliateRevenue: 0.0,
      affiliateBookingCount: 0,
      revenueToday: 0.0,
      bookingToday: 0,
      paymentsCount: 0,
      payments: const [],
    );
  }

  /// Mengambil daftar pengguna yang ditugaskan ke affiliate
  Future<List<AffiliateUserModel>> getAffiliateUsers(int affiliateId) async {
    try {
      final list = await _apiService.getAffiliateUsersApi(affiliateId);
      if (list != null) {
        final users = list
            .map((item) => AffiliateUserModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // Perbarui cache affiliate lokal jika ada
        final index = _affiliates.indexWhere((a) => a.id == affiliateId);
        if (index != -1) {
          _affiliates[index] = _affiliates[index].copyWith(
            users: users,
            usersCount: users.length,
          );
        }
        return List.unmodifiable(users);
      }
    } catch (_) {}

    final index = _affiliates.indexWhere((a) => a.id == affiliateId);
    if (index != -1 && _affiliates[index].users != null) {
      return List.unmodifiable(_affiliates[index].users!);
    }
    return const [];
  }

  /// Mengambil daftar seluruh pengguna sistem yang tersedia untuk ditugaskan
  Future<List<AffiliateUserModel>> getAvailableUsersForAffiliate(int affiliateId, {String? search}) async {
    try {
      final list = await _apiService.getAvailableUsersForAffiliateApi(affiliateId, search: search);
      if (list != null) {
        return list
            .map((item) => AffiliateUserModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback users for offline/testing
    final mockAll = [
      const AffiliateUserModel(
        id: 'mock-u1',
        name: 'Budi Santoso',
        email: 'budi.santoso@skyrent.id',
        phone: '0812-3456-7890',
        role: 'Staff Cabang',
        affiliateId: 1,
        isAssigned: true,
      ),
      const AffiliateUserModel(
        id: 'mock-u2',
        name: 'Siti Rahma',
        email: 'siti.rahma@skyrent.id',
        phone: '0812-9876-5432',
        role: 'Admin Kasir',
        affiliateId: 1,
        isAssigned: true,
      ),
      const AffiliateUserModel(
        id: 'mock-u3',
        name: 'Rian Pratama',
        email: 'rian.pratama@skyrent.id',
        phone: '0813-1122-3344',
        role: 'Staff Operasional',
        affiliateId: null,
        isAssigned: false,
      ),
      const AffiliateUserModel(
        id: 'mock-u4',
        name: 'Dewi Lestari',
        email: 'dewi.lestari@skyrent.id',
        phone: '0814-5566-7788',
        role: 'Customer Service',
        affiliateId: null,
        isAssigned: false,
      ),
    ];
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return mockAll.where((u) => u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)).toList();
    }
    return mockAll;
  }

  /// Menugaskan user ke affiliate
  Future<List<AffiliateUserModel>> assignUsersToAffiliate(int affiliateId, List<String> userIds) async {
    try {
      final res = await _apiService.assignUsersToAffiliateApi(affiliateId, userIds);
      if (res != null) {
        final updatedUsers = res
            .map((item) => AffiliateUserModel.fromJson(item as Map<String, dynamic>))
            .toList();

        final index = _affiliates.indexWhere((a) => a.id == affiliateId);
        if (index != -1) {
          _affiliates[index] = _affiliates[index].copyWith(
            users: updatedUsers,
            usersCount: updatedUsers.length,
          );
        }
        return updatedUsers;
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
    }

    // Fallback for offline/testing: update local cache
    final index = _affiliates.indexWhere((a) => a.id == affiliateId);
    if (index != -1) {
      final currentUsers = List<AffiliateUserModel>.from(_affiliates[index].users ?? []);
      for (final uid in userIds) {
        if (!currentUsers.any((u) => u.id == uid)) {
          currentUsers.add(AffiliateUserModel(
            id: uid,
            name: uid == 'mock-u3' ? 'Rian Pratama' : (uid == 'mock-u4' ? 'Dewi Lestari' : 'User $uid'),
            email: '$uid@skyrent.id',
            role: 'Staff Cabang',
            affiliateId: affiliateId,
            isAssigned: true,
          ));
        }
      }
      _affiliates[index] = _affiliates[index].copyWith(
        users: currentUsers,
        usersCount: currentUsers.length,
      );
      return currentUsers;
    } else {
      final newUsers = userIds.map((uid) => AffiliateUserModel(
        id: uid,
        name: uid == 'mock-u3' ? 'Rian Pratama' : (uid == 'mock-u4' ? 'Dewi Lestari' : 'User $uid'),
        email: '$uid@skyrent.id',
        role: 'Staff Cabang',
        affiliateId: affiliateId,
        isAssigned: true,
      )).toList();
      _affiliates.add(AffiliateModel(
        id: affiliateId,
        code: 'CAB',
        name: 'Cabang #$affiliateId',
        slug: 'cabang-$affiliateId',
        users: newUsers,
        usersCount: newUsers.length,
      ));
      return newUsers;
    }
  }

  /// Melepas penugasan user dari affiliate
  Future<bool> removeUserFromAffiliate(int affiliateId, String userId) async {
    try {
      final success = await _apiService.removeUserFromAffiliateApi(affiliateId, userId);
      if (success) {
        final index = _affiliates.indexWhere((a) => a.id == affiliateId);
        if (index != -1 && _affiliates[index].users != null) {
          final updatedUsers = _affiliates[index].users!.where((u) => u.id != userId).toList();
          _affiliates[index] = _affiliates[index].copyWith(
            users: updatedUsers,
            usersCount: updatedUsers.length,
          );
        }
        return true;
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
    }

    // Fallback offline
    final index = _affiliates.indexWhere((a) => a.id == affiliateId);
    if (index != -1 && _affiliates[index].users != null) {
      final updatedUsers = _affiliates[index].users!.where((u) => u.id != userId).toList();
      _affiliates[index] = _affiliates[index].copyWith(
        users: updatedUsers,
        usersCount: updatedUsers.length,
      );
      return true;
    }
    return true;
  }

  // =========================================================================
  // USER & ROLE PERMISSION MANAGEMENT (Matches web admin/roles-permissions)
  // =========================================================================

  final List<UserRoleModel> _mockUsers = [
    const UserRoleModel(
      id: 'mock-u1',
      name: 'Super Admin SKYRental',
      email: 'admin@skyrental.id',
      roles: ['super-admin'],
      role: 'super-admin',
      createdAtFormatted: '15 Sep 2026, 10:00',
      updatedAtFormatted: '15 Sep 2026',
    ),
    const UserRoleModel(
      id: 'mock-u2',
      name: 'Budi Kasir',
      email: 'kasir@skyrental.id',
      roles: ['admin'],
      role: 'admin',
      createdAtFormatted: '16 Sep 2026, 09:30',
      updatedAtFormatted: '16 Sep 2026',
    ),
    const UserRoleModel(
      id: 'mock-u3',
      name: 'Rian Pratama',
      email: 'rian@skyrental.id',
      roles: ['staff'],
      role: 'staff',
      createdAtFormatted: '18 Sep 2026, 14:15',
      updatedAtFormatted: '18 Sep 2026',
    ),
    const UserRoleModel(
      id: 'mock-u4',
      name: 'Dewi Lestari',
      email: 'dewi@skyrental.id',
      roles: [],
      role: '-',
      createdAtFormatted: '20 Sep 2026, 11:20',
      updatedAtFormatted: '20 Sep 2026',
    ),
  ];

  final List<RoleItemModel> _mockRoles = [
    const RoleItemModel(
      id: 1,
      name: 'super-admin',
      displayName: 'Super Admin',
      permissionsCount: 3,
      permissions: ['create', 'update', 'delete'],
    ),
    const RoleItemModel(
      id: 2,
      name: 'admin',
      displayName: 'Admin',
      permissionsCount: 2,
      permissions: ['create', 'update'],
    ),
    const RoleItemModel(
      id: 3,
      name: 'staff',
      displayName: 'Staff Kasir',
      permissionsCount: 2,
      permissions: ['create', 'update'],
    ),
  ];

  static final List<PermissionItemModel> _mockPermissions = [
    const PermissionItemModel(id: 1, name: 'create', displayName: 'Create (Tambah Data)'),
    const PermissionItemModel(id: 2, name: 'update', displayName: 'Update (Ubah Data)'),
    const PermissionItemModel(id: 3, name: 'delete', displayName: 'Delete (Hapus Data)'),
  ];

  /// Mengambil daftar pengguna sistem
  Future<List<UserRoleModel>> getUsers({String? search, String? role}) async {
    try {
      final list = await _apiService.getUsersApi(search: search, role: role);
      if (list != null) {
        final users = list.map((item) => UserRoleModel.fromJson(item)).toList();
        return List.unmodifiable(users);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403) rethrow;
    } catch (_) {}

    // Fallback offline / test
    List<UserRoleModel> result = List.from(_mockUsers);
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      result = result.where((u) => u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q)).toList();
    }
    if (role != null && role.isNotEmpty && role != 'all' && role != 'semua') {
      result = result.where((u) => u.role.toLowerCase() == role.toLowerCase()).toList();
    }
    return List.unmodifiable(result);
  }

  /// Mengambil daftar role yang tersedia
  Future<List<RoleItemModel>> getRoles() async {
    try {
      final list = await _apiService.getRolesApi();
      if (list != null) {
        final roles = list.map((item) => RoleItemModel.fromJson(item)).toList();
        return List.unmodifiable(roles);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403) rethrow;
    } catch (_) {}

    return List.unmodifiable(_mockRoles);
  }

  /// Mengambil daftar semua izin hak akses (permissions)
  Future<List<PermissionItemModel>> getPermissions() async {
    try {
      final list = await _apiService.getPermissionsApi();
      if (list != null) {
        final perms = list.map((item) => PermissionItemModel.fromJson(item)).toList();
        return List.unmodifiable(perms);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403) rethrow;
    } catch (_) {}

    return List.unmodifiable(_mockPermissions);
  }

  /// Menetapkan (assign / sync) role dan/atau permissions untuk pengguna
  Future<bool> assignUserRole(String userId, String? role, {List<String>? permissions}) async {
    try {
      final success = await _apiService.assignUserRoleApi(userId, role, permissions: permissions);
      if (success) {
        final index = _mockUsers.indexWhere((u) => u.id == userId);
        if (index != -1) {
          final current = _mockUsers[index];
          final newRole = role ?? current.role;
          _mockUsers[index] = current.copyWith(
            role: newRole,
            roles: role != null ? [role] : current.roles,
            permissions: permissions ?? current.permissions,
            directPermissions: permissions ?? current.directPermissions,
          );
        }
        return true;
      }
    } catch (_) {}

    // Fallback offline / test
    final index = _mockUsers.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final current = _mockUsers[index];
      final newRole = role ?? current.role;
      _mockUsers[index] = current.copyWith(
        role: newRole,
        roles: role != null ? [role] : current.roles,
        permissions: permissions ?? current.permissions,
        directPermissions: permissions ?? current.directPermissions,
      );
      return true;
    }
    return true;
  }

  /// Menambahkan pengguna baru
  Future<UserRoleModel> createUser({
    required String name,
    required String email,
    required String password,
    String? role,
  }) async {
    try {
      final res = await _apiService.createUserApi(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      final newUser = UserRoleModel.fromJson(res);
      _mockUsers.insert(0, newUser);
      return newUser;
    } catch (_) {}

    // Fallback offline / test
    final newUser = UserRoleModel(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: role ?? '-',
      roles: role != null && role.isNotEmpty && role != '-' ? [role] : [],
      createdAtFormatted: 'Hari ini',
      updatedAtFormatted: 'Hari ini',
    );
    _mockUsers.insert(0, newUser);
    return newUser;
  }

  /// Menghapus pengguna
  Future<bool> deleteUser(String userId) async {
    try {
      final success = await _apiService.deleteUserApi(userId);
      if (success) {
        _mockUsers.removeWhere((u) => u.id == userId);
        return true;
      }
    } catch (_) {}

    _mockUsers.removeWhere((u) => u.id == userId);
    return true;
  }
}
