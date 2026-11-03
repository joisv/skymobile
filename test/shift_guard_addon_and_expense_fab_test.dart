import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/screens/dashboard/expenses_screen.dart';
import 'package:skyrental_admin/screens/dashboard/widgets/operational_metric_detail_sheet.dart';
import 'package:skyrental_admin/screens/payment/payment_deposit_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/widgets/app_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingRepository repository;

  BookingModel createTestBooking({
    required int id,
    required String code,
    required String customerName,
    required String customerPhone,
    required IphoneModel iphone,
    required DateTime startDate,
    required DateTime endDate,
    BookingStatus status = BookingStatus.rented,
    PaymentStatus paymentStatus = PaymentStatus.paid,
    double price = 250000.0,
    double deposit = 0.0,
    String jaminanType = 'KTP',
    String pickupType = 'Outlet',
    int durationDays = 1,
    String? startTime = '10:00',
    String? endTime = '18:00',
    List<IphoneModel> addonDevices = const [],
  }) {
    return BookingModel(
      id: id,
      bookingCode: code,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: '$customerName@example.com'.toLowerCase().replaceAll(' ', ''),
      address: 'Jl. Merdeka No. 10',
      pickupType: pickupType,
      jaminanType: jaminanType,
      startDate: startDate,
      endDate: endDate,
      durationDays: durationDays,
      startTime: startTime,
      endTime: endTime,
      price: price,
      deposit: deposit,
      status: status,
      paymentStatus: paymentStatus,
      iphone: iphone,
      addonDevices: addonDevices,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    repository = BookingRepository();
    // Default: pastikan shift kasir belum dibuka (null)
    repository.setTestShift(null);
  });

  group('Requirement 1: Shift Guard for Penalty & Late Return Payments', () {
    testWidgets('Blocks return processing in detail drawer when no shift is open and shows warning dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool returnProcessed = false;

      final overdueBooking = createTestBooking(
        id: 991,
        code: 'SKY-TEST-GUARD-1',
        customerName: 'Budi Santoso',
        customerPhone: '081234567890',
        iphone: const IphoneModel(
          id: 101,
          name: 'iPhone 15 Pro Max',
          storage: '256GB',
          color: 'Natural Titanium',
          serialNumber: 'SN-IP15PM-001',
          assetCode: 'AST-IP15PM-001',
          status: 'disewa',
          batteryHealth: 95,
        ),
        startDate: DateTime.now().subtract(const Duration(days: 3)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        status: BookingStatus.rented,
        price: 400000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationalMetricDetailSheet(
              initialType: OperationalMetricType.returnToday,
              metrics: const {'returnToday': 1},
              allQueue: [overdueBooking],
              pickupItems: const [],
              returnItems: [overdueBooking],
              repository: repository,
              onClose: () {},
              onProcessReturn: (b) {
                returnProcessed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pastikan tombol Proses Pengembalian muncul
      final processButton = find.byKey(Key('btn_proses_pengembalian_${overdueBooking.bookingCode}'));
      expect(processButton, findsOneWidget);

      // Tap tombol Proses Pengembalian tanpa ada shift aktif
      await tester.tap(processButton);
      await tester.pumpAndSettle();

      // Return flow HARUS diblokir
      expect(returnProcessed, isFalse);

      // Warning dialog harus muncul dengan teks lengkap sesuai spesifikasi
      expect(find.text('Shift Kasir Belum Dibuka'), findsOneWidget);
      expect(
        find.text(
          'Shift Kasir Belum Dibuka: Anda harus membuka shift kasir terlebih dahulu sebelum menerima pembayaran denda atau memproses pengembalian unit',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn_buka_shift_kasir')), findsOneWidget);
      expect(find.byKey(const Key('btn_batal_shift_dialog')), findsOneWidget);

      // Batal menutup dialog
      await tester.tap(find.byKey(const Key('btn_batal_shift_dialog')));
      await tester.pumpAndSettle();
      expect(find.text('Shift Kasir Belum Dibuka'), findsNothing);
    });

    testWidgets('Allows return processing in detail drawer when active shift is open', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Buka shift aktif
      final activeShift = CashDrawerShiftModel(
        id: 77,
        shiftNumber: 'SHF-BALI-001',
        branchId: 1,
        branchName: 'Skyrent Bali Denpasar',
        openedByName: 'Kasir Denpasar',
        openedAt: DateTime.now().subtract(const Duration(hours: 2)),
        openingCashFloat: 500000.0,
        expectedCashTotal: 500000.0,
        actualCashCounted: 500000.0,
        status: ShiftStatus.open,
      );
      repository.setTestShift(activeShift);

      bool returnProcessed = false;
      final overdueBooking = createTestBooking(
        id: 992,
        code: 'SKY-TEST-GUARD-2',
        customerName: 'Siti Rahma',
        customerPhone: '081234567891',
        iphone: const IphoneModel(
          id: 102,
          name: 'iPhone 14 Pro',
          storage: '128GB',
          color: 'Deep Purple',
          serialNumber: 'SN-IP14P-002',
          assetCode: 'AST-IP14P-002',
          status: 'disewa',
          batteryHealth: 90,
        ),
        startDate: DateTime.now().subtract(const Duration(days: 2)),
        endDate: DateTime.now().subtract(const Duration(hours: 4)),
        status: BookingStatus.rented,
        price: 350000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperationalMetricDetailSheet(
              initialType: OperationalMetricType.returnToday,
              metrics: const {'returnToday': 1},
              allQueue: [overdueBooking],
              pickupItems: const [],
              returnItems: [overdueBooking],
              repository: repository,
              onClose: () {},
              onProcessReturn: (b) {
                returnProcessed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final processButton = find.byKey(Key('btn_proses_pengembalian_${overdueBooking.bookingCode}'));
      await tester.tap(processButton);
      await tester.pumpAndSettle();

      // Return processing diperbolehkan karena shift aktif
      expect(returnProcessed, isTrue);
      expect(find.text('Shift Kasir Belum Dibuka'), findsNothing);
    });

    testWidgets('Blocks payment confirmation on PaymentDepositScreen in return/penalty flow without active shift',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final booking = createTestBooking(
        id: 993,
        code: 'SKY-TEST-GUARD-3',
        customerName: 'Joko Widodo',
        customerPhone: '081299887766',
        iphone: const IphoneModel(
          id: 103,
          name: 'iPhone 13',
          storage: '128GB',
          color: 'Midnight',
          serialNumber: 'SN-IP13-003',
          assetCode: 'AST-IP13-003',
          status: 'disewa',
          batteryHealth: 88,
        ),
        startDate: DateTime.now().subtract(const Duration(days: 2)),
        endDate: DateTime.now().subtract(const Duration(hours: 6)),
        status: BookingStatus.rented,
        price: 200000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PaymentDepositScreen(
            booking: booking,
            repository: repository,
            isReturnFlow: true,
            initialPaymentType: PaymentTypeOption.penalty,
            initialAmount: 50000.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cari tombol konfirmasi pengembalian & bayar denda
      final submitButton = find.widgetWithText(ElevatedButton, 'Bayar Denda & Selesaikan Pengembalian');
      expect(submitButton, findsOneWidget);

      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Harus menampilkan dialog peringatan shift belum dibuka
      expect(find.text('Shift Kasir Belum Dibuka'), findsOneWidget);
      expect(
        find.text(
          'Shift Kasir Belum Dibuka: Anda harus membuka shift kasir terlebih dahulu sebelum menerima pembayaran denda atau memproses pengembalian unit',
        ),
        findsOneWidget,
      );
    });
  });

  group('Requirement 2: Fix Empty Add-ons List on Booking Wizard (Step 2)', () {
    testWidgets('Add-ons list automatically initializes schedule and loads available accessories',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Pastikan repository memiliki add-on units di mock
      final addons = await repository.getAvailableAddonUnits();
      expect(addons, isNotEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: CreateBookingScreen(
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Isi Step 1 form data tamu menggunakan FormFields
      await tester.enterText(find.byType(TextFormField).at(0), 'Tablet Customer');
      await tester.enterText(find.byType(TextFormField).at(1), '081299998888');
      await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Sudirman 10');
      await tester.pumpAndSettle();

      // Klik Lanjut ke Langkah 2
      final nextButton = find.byKey(const Key('btn_next_to_step_2'));
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Verifikasi berada di Langkah 2 (Unit iPhone & Durasi)
      expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);

      // Pilih unit iPhone pertama yang tersedia
      final unitFinder = find.textContaining('SN: P9ZX44MN67');
      expect(unitFinder, findsOneWidget);
      await tester.tap(unitFinder);
      await tester.pumpAndSettle();

      // Verifikasi add-on TIDAK kosong dan menampilkan item aksesoris
      expect(find.text('Item Tambahan / Add-on (Opsional)'), findsOneWidget);
      expect(find.text('Tidak ada perangkat add-on tersedia untuk jadwal sewa ini.'), findsNothing);
      expect(find.textContaining('DJI Osmo Mobile 6'), findsOneWidget);
      expect(find.textContaining('Anker MagSafe Powerbank'), findsOneWidget);
    });
  });

  group('Requirement 3: Add-on Inventory Release on Rental Return & Completion', () {
    test('Add-on status is restored to "tersedia" in inventory upon completeReturn', () async {
      const addonId = 502; // Anker MagSafe Powerbank
      final inventoryAll = await repository.getInventoryUnits(onlyAvailable: false, forBooking: true);
      final initialAddon = inventoryAll.firstWhere((u) => u.id == addonId);
      expect(initialAddon.status.toLowerCase(), 'tersedia');

      // Buat booking yang meminjam add-on tersebut
      final primaryIphone = inventoryAll.firstWhere((u) => !u.isAddon);
      final booking = await repository.createBooking(
        customerName: 'Test Addon Renter',
        customerPhone: '081234567899',
        customerEmail: 'addonrenter@example.com',
        iphone: primaryIphone,
        addonDevices: [initialAddon],
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now(),
        durationDays: 1,
        price: 250000.0,
        deposit: 0,
        jaminanType: 'KTP',
      );

      // Sebelum dikembalikan: unit iPhone dan add-on berstatus 'dibooking'
      final inventoryDuringBooking = await repository.getInventoryUnits(onlyAvailable: false, forBooking: true);
      final bookedAddon = inventoryDuringBooking.firstWhere((u) => u.id == addonId);
      expect(bookedAddon.status.toLowerCase(), 'dibooking');

      // Eksekusi completeReturn
      final completed = await repository.completeReturn(
        bookingCode: booking.bookingCode,
        physicalCondition: 'Mulus (Sempurna)',
        batteryHealthFinal: 100,
        lateFee: 0,
        damageFee: 0,
        depositRefunded: 0,
        refundMethod: 'Tunai',
        accessoriesReturned: ['kabel', 'box'],
      );

      expect(completed.status, BookingStatus.returned);

      // Verifikasi status add-on di inventory telah dipulihkan kembali ke 'tersedia'
      final inventoryAfterReturn = await repository.getInventoryUnits(onlyAvailable: false, forBooking: true);
      final releasedAddon = inventoryAfterReturn.firstWhere((u) => u.id == addonId);
      expect(releasedAddon.status.toLowerCase(), 'tersedia');

      // Verifikasi add-on langsung dapat disewa kembali
      final availableAddons = await repository.getAvailableAddonUnits();
      expect(availableAddons.any((a) => a.id == addonId), isTrue);
    });
  });

  group('Requirement 4: Move "Catat Biaya" to a Floating Action Button (FAB)', () {
    testWidgets('ExpensesScreen renders FAB with Key btn_fab_catat_biaya and no top action button',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi AppHeader tidak lagi memiliki tombol Catat Biaya di AppBar actions
      final headerFinder = find.byType(AppHeader);
      expect(headerFinder, findsOneWidget);
      final elevatedInHeader = find.descendant(
        of: headerFinder,
        matching: find.byType(ElevatedButton),
      );
      expect(elevatedInHeader, findsNothing);

      // Verifikasi FloatingActionButton.extended hadir di bagian kanan bawah
      final fabFinder = find.byKey(const Key('btn_fab_catat_biaya'));
      expect(fabFinder, findsOneWidget);
      expect(find.descendant(of: fabFinder, matching: find.text('Catat Biaya')), findsOneWidget);
      expect(find.descendant(of: fabFinder, matching: find.byIcon(Icons.add_rounded)), findsOneWidget);

      // Tap FAB dan verifikasi modal pencatatan pengeluaran terbuka
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      expect(find.text('Catat Biaya Operasional'), findsOneWidget);
      expect(find.textContaining('Nominal Pengeluaran'), findsOneWidget);
    });
  });
}
