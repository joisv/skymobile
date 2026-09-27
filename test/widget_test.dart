import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/main.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/models/printer_device_model.dart';
import 'package:skyrental_admin/models/receipt_format_settings.dart';
import 'package:skyrental_admin/models/receipt_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/main_navigation_screen.dart';
import 'package:skyrental_admin/screens/booking/booking_detail_screen.dart';
import 'package:skyrental_admin/screens/receipt/receipt_screen.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';
import 'package:skyrental_admin/services/thermal_print_service.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/screens/booking/widgets/booking_card_skeleton.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/screens/dashboard/widgets/dashboard_skeleton.dart';
import 'package:skyrental_admin/widgets/skeleton_loading.dart';

import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
import 'package:skyrental_admin/screens/payment/payment_deposit_screen.dart';
import 'package:skyrental_admin/screens/return/return_inspection_screen.dart';
import 'package:skyrental_admin/screens/unit_status/unit_status_list_screen.dart';
import 'package:skyrental_admin/screens/unit_status/widgets/unit_status_skeleton.dart';
import 'package:skyrental_admin/screens/receipt/printer_settings_screen.dart';
import 'package:skyrental_admin/screens/booking/widgets/extend_duration_modal.dart';
import 'package:skyrental_admin/models/affiliate_model.dart';
import 'package:skyrental_admin/screens/affiliate/affiliate_list_screen.dart';
import 'package:skyrental_admin/screens/affiliate/affiliate_detail_screen.dart';
import 'package:skyrental_admin/screens/affiliate/affiliate_form_screen.dart';
import 'package:skyrental_admin/screens/affiliate/iphone_transfer_list_screen.dart';
import 'package:skyrental_admin/screens/affiliate/affiliate_revenue_screen.dart';
import 'package:skyrental_admin/screens/account/account_screen.dart';
import 'package:skyrental_admin/screens/account/theme_settings_screen.dart';
import 'package:skyrental_admin/screens/dashboard/sales_report_screen.dart';
import 'package:skyrental_admin/screens/unit_status/widgets/create_iphone_dialog.dart';
import 'package:skyrental_admin/services/theme_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    await PrinterStorageService().init();
  });

  testWidgets('SkyRentalAdminApp smoke test', (WidgetTester tester) async {
    final repository = BookingRepository();
    await tester.pumpWidget(SkyRentalAdminApp(bookingRepository: repository));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets(
      'DashboardScreen shows Buat Booking floating action button and navigates to CreateBookingScreen',
      (WidgetTester tester) async {
    final repository = BookingRepository();
    await tester.pumpWidget(SkyRentalAdminApp(bookingRepository: repository));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify FAB Buat Booking is present on Dashboard
    final fabFinder = find.widgetWithText(FloatingActionButton, 'Buat Booking');
    expect(fabFinder, findsOneWidget);

    // Tap FAB to navigate to CreateBookingScreen
    await tester.tap(fabFinder);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify CreateBookingScreen is rendered at Step 1 (Data Tamu)
    expect(find.byType(CreateBookingScreen), findsOneWidget);
    expect(find.text('Buat Booking Baru'), findsWidgets);
    expect(find.text('1. Data Tamu'), findsOneWidget);
    expect(find.text('2. Unit & Durasi'), findsOneWidget);
    expect(find.text('3. Konfirmasi'), findsOneWidget);
    expect(find.text('1. Data & Jaminan Customer'), findsOneWidget);

    // Enter customer info since form fields are now empty by default
    await tester.enterText(find.byType(TextFormField).at(0), 'Rian Hidayat');
    await tester.enterText(find.byType(TextFormField).at(1), '081298765432');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'Jl. Radio Dalam No. 14');
    await tester.pump(const Duration(milliseconds: 300));

    // Section 1 has 'Lanjut ke Unit & Durasi' button in bottom dock
    final nextToStep2Finder = find.byKey(const Key('btn_next_to_step_2'));
    expect(nextToStep2Finder, findsOneWidget);

    // Tap to navigate to Section 2 (Unit & Durasi)
    await tester.tap(nextToStep2Finder);
    await tester.pumpAndSettle();

    // Verify Section 2 is rendered
    expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);
    // Unit disewa (X9M456KL8N) tetap muncul di daftar tapi dengan badge "Sedang Disewa"
    expect(find.textContaining('X9M456KL8N'), findsOneWidget);
    expect(find.textContaining('Sedang Disewa'), findsWidgets);

    // Tap to select an available unit (since units are unselected by default)
    await tester.tap(find.text('Tersedia').first);
    await tester.pumpAndSettle();

    final nextToStep3Finder = find.byKey(const Key('btn_next_to_step_3'));
    expect(nextToStep3Finder, findsOneWidget);

    // Tap to navigate to Section 3 (Kalkulasi, Rincian & Konfirmasi)
    await tester.tap(nextToStep3Finder);
    await tester.pumpAndSettle();

    // Verify Section 3 is rendered and confirmation button is ready
    expect(find.text('3. Estimasi Biaya & Konfirmasi'), findsOneWidget);
    expect(find.byKey(const Key('btn_confirm_booking')), findsOneWidget);
  });

  testWidgets(
      'CreateBookingScreen adapts customer form and duration grid for tablet',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = BookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: CreateBookingScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreateBookingScreen), findsOneWidget);
    expect(find.text('1. Data & Jaminan Customer'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));

    final nameField = find.ancestor(
      of: find.text('Nama Lengkap Customer'),
      matching: find.byType(SizedBox),
    );
    expect(nameField, findsOneWidget);
    expect(tester.getSize(nameField).width, greaterThan(320));
    expect(find.text('Pratinjau Data Booking'), findsOneWidget);
    // Simulate software keyboard opening on tablet
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pump();
    expect(find.text('1. Data & Jaminan Customer'), findsOneWidget);
    expect(find.text('Pratinjau Data Booking'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Tablet Customer');
    await tester.enterText(find.byType(TextFormField).at(1), '081298765432');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'Jl. Tablet No. 1');
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
    await tester.pumpAndSettle();
    expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);
    expect(find.byType(Wrap), findsWidgets);
  });

  test('BookingRepository createBooking adds new booking to repository',
      () async {
    final repository = BookingRepository();
    final availableUnits =
        await repository.getInventoryUnits(onlyAvailable: true);
    expect(availableUnits.isNotEmpty, isTrue);
    expect(
      availableUnits.every(
        (unit) =>
            !['rented', 'disewa'].contains(unit.status.toLowerCase().trim()),
      ),
      isTrue,
    );
    expect(
      availableUnits.any((unit) => unit.assetCode == 'AST-IP15PM-002'),
      isFalse,
    );

    final initialCount = (await repository.getBookings()).length;

    final created = await repository.createBooking(
      customerName: 'Budi Test Customer',
      customerPhone: '081299998888',
      customerEmail: 'budi@test.com',
      address: 'Jl. Kaliurang No 10',
      iphone: availableUnits.first,
      startDate: DateTime(2026, 9, 10, 10, 0),
      endDate: DateTime(2026, 9, 12, 10, 0),
      durationDays: 2,
      price: 300000,
      deposit: 200000,
      jaminanType: 'KTP Asli',
      amountPaid: 150000,
      paymentMethod: 'QRIS',
    );

    expect(created.customerName, equals('Budi Test Customer'));
    expect(created.bookingCode.startsWith('SKY'), isTrue);

    final allBookings = await repository.getBookings();
    expect(allBookings.length, equals(initialCount + 1));
    expect(
        allBookings.any((b) => b.bookingCode == created.bookingCode), isTrue);
  });

  testWidgets(
      'CreateBookingScreen completes submission and navigates to PaymentDepositScreen',
      (WidgetTester tester) async {
    final repository = BookingRepository();
    await tester.pumpWidget(SkyRentalAdminApp(bookingRepository: repository));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Navigate to CreateBookingScreen
    final fabFinder = find.widgetWithText(FloatingActionButton, 'Buat Booking');
    await tester.tap(fabFinder);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Step 1: Fill customer info
    await tester.enterText(find.byType(TextFormField).at(0), 'Siti Nurhaliza');
    await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'siti@example.com');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'Jl. Malioboro No. 45 Yogyakarta');
    await tester.pump(const Duration(milliseconds: 300));

    // Go to Step 2
    final nextToStep2Finder = find.byKey(const Key('btn_next_to_step_2'));
    await tester.tap(nextToStep2Finder);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Tap on available unit first so duration choices are displayed
    await tester.tap(find.text('Tersedia').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Pilih Durasi'), findsOneWidget);
    expect(find.text('Durasi Custom'), findsOneWidget);

    // Scroll to and toggle custom duration
    await tester.ensureVisible(find.text('Durasi Custom'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Durasi Custom'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Masukkan Durasi Sendiri'), findsOneWidget);

    // Go to Step 3
    final nextToStep3Finder = find.byKey(const Key('btn_next_to_step_3'));
    await tester.tap(nextToStep3Finder);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('3. Estimasi Biaya & Konfirmasi'), findsOneWidget);

    // Submit booking
    final submitBtn = find.byKey(const Key('btn_confirm_booking'));
    expect(submitBtn, findsOneWidget);
    await tester.ensureVisible(submitBtn);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(submitBtn);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    // Verification: user is directed to Payment Deposit Screen (Screen 7)
    expect(find.text('Konfirmasi Pembayaran'), findsOneWidget);
    expect(find.text('Siti Nurhaliza'), findsWidgets);
  });

  test(
      'PrinterStorageService and ThermalPrintService ensurePrimaryConnected persistence',
      () async {
    final storage = PrinterStorageService();
    await storage.init();

    const rpp = PrinterDeviceModel(
      name: 'RPP02N Thermal Printer',
      address: '66:22:33:44:55:66',
      isConnected: true,
    );
    await storage.savePrimaryPrinter(rpp);

    final loaded = await storage.getPrimaryPrinter();
    expect(loaded.name, equals('RPP02N Thermal Printer'));
    expect(loaded.address, equals('66:22:33:44:55:66'));

    final printService = ThermalPrintService();
    final primary = await printService.ensurePrimaryConnected();
    expect(primary.name, equals('RPP02N Thermal Printer'));
    expect(printService.activePrinterNotifier.value?.name,
        equals('RPP02N Thermal Printer'));
  });

  test('ReceiptFormatSettings persistence and customized receipt rendering',
      () async {
    final storage = PrinterStorageService();
    await storage.init();

    // 1. Verify default settings
    final defaultSettings = await storage.getReceiptFormatSettings();
    expect(defaultSettings.businessName, equals('SKYRENTAL'));
    expect(defaultSettings.separatorChar, equals('='));

    // 2. Customize settings and save
    const customSettings = ReceiptFormatSettings(
      businessName: 'SKYRENTAL PRO JOGJA',
      businessTagline: 'Pusat Rental iPhone #1',
      branchName: 'Cabang Gejayan',
      showHeader: true,
      footerLine1: 'Garansi Unit Original 100%',
      footerLine2: 'Simpan bukti sewa ini dengan baik',
      footerLine3: 'Terima kasih atas kunjungan Anda',
      contactInfo: 'WA: 0811-2233-4455',
      showFooter: true,
      showSerialNumber: false, // hidden
      showAssetCode: true,
      separatorChar: '*',
      subSeparatorChar: '~',
    );

    await storage.saveReceiptFormatSettings(customSettings);

    // 3. Verify retrieved settings match saved
    final retrieved = await storage.getReceiptFormatSettings();
    expect(retrieved.businessName, equals('SKYRENTAL PRO JOGJA'));
    expect(retrieved.branchName, equals('Cabang Gejayan'));
    expect(retrieved.separatorChar, equals('*'));
    expect(retrieved.subSeparatorChar, equals('~'));
    expect(retrieved.showSerialNumber, isFalse);

    // 4. Test ReceiptModel rendering with custom settings
    final receipt = ReceiptModel(
      receiptNumber: 'REC-TEST-001',
      date: DateTime(2026, 9, 10, 14, 30),
      adminName: 'Admin Kasir',
      type: ReceiptType.pickup,
      bookingCode: 'SKY-2026-999',
      customerName: 'Ahmad Pelanggan',
      customerPhone: '081234567890',
      unitName: 'iPhone 15 Pro Max',
      serialNumber: 'F2LLD34509',
      assetCode: 'AST-IP15PM-01',
      rentalDuration: '2 Hari',
      rentFee: 300000,
      depositFee: 200000,
      totalAmount: 500000,
      paidAmount: 500000,
      remainingAmount: 0,
      paymentMethod: 'Tunai',
      paymentStatus: 'Lunas',
    );

    final formattedText = receipt.toEscPos58mm(formatSettings: retrieved);

    // Verify custom header and separators exist in output
    expect(formattedText.contains('SKYRENTAL PRO JOGJA'), isTrue);
    expect(formattedText.contains('Pusat Rental iPhone #1'), isTrue);
    expect(formattedText.contains('Cabang Gejayan'), isTrue);
    expect(formattedText.contains('********************************'), isTrue);
    expect(formattedText.contains('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'), isTrue);

    // Verify serial number was omitted because showSerialNumber is false
    expect(formattedText.contains('Serial No'), isFalse);
    expect(formattedText.contains('F2LLD34509'), isFalse);

    // Verify asset code is still shown
    expect(formattedText.contains('AST-IP15PM-01'), isTrue);

    // Verify custom footer exists
    expect(formattedText.contains('Garansi Unit Original 100%'), isTrue);
    expect(formattedText.contains('WA: 0811-2233-4455'), isTrue);
  });

  test('Operational Dashboard metrics and deleteBooking in BookingRepository',
      () async {
    final repository = BookingRepository();
    final dashboardData = await repository.getOperationalDashboardData();

    expect(dashboardData.containsKey('metrics'), isTrue);
    final metrics = dashboardData['metrics'] as Map<String, dynamic>;

    // Verify 4 core metrics matching database & booking-page.blade.php
    expect(metrics.containsKey('availableUnits'), isTrue);
    expect(metrics.containsKey('unreturnedUnits'), isTrue);
    expect(metrics.containsKey('bookingToday'), isTrue);
    expect(metrics.containsKey('revenueToday'), isTrue);

    // Verify queue and action items
    expect(dashboardData.containsKey('allQueue'), isTrue);
    final allQueue = dashboardData['allQueue'] as List<BookingModel>;
    expect(allQueue.isNotEmpty, isTrue);

    // Test deleteBooking
    final targetBooking = allQueue.first;
    final initialCount = allQueue.length;
    final deleteResult =
        await repository.deleteBooking(targetBooking.bookingCode);
    expect(deleteResult, isTrue);

    final updatedBookings = await repository.getBookings();
    expect(
        updatedBookings.any((b) => b.bookingCode == targetBooking.bookingCode),
        isFalse);
    expect(updatedBookings.length, equals(initialCount - 1));
  });

  testWidgets(
      'DashboardSkeleton and BookingListSkeleton render properly during data loading',
      (WidgetTester tester) async {
    // 1. Test mobile skeleton
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardSkeleton(),
        ),
      ),
    );

    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.byType(SkeletonShimmer), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(SkeletonText), findsWidgets);
    expect(find.byType(SkeletonCircle), findsWidgets);
    expect(tester.takeException(), isNull);

    // 2. Test tablet landscape skeleton
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardSkeleton(isTablet: true),
        ),
      ),
    );

    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.byType(SkeletonShimmer), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(SkeletonText), findsWidgets);
    expect(find.byType(SkeletonCircle), findsWidgets);
    expect(tester.takeException(), isNull);

    // Reset view size before next test
    tester.view.reset();

    // 3. Test BookingListSkeleton
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookingListSkeleton(itemCount: 3),
        ),
      ),
    );

    expect(find.byType(BookingListSkeleton), findsOneWidget);
    expect(find.byType(SkeletonShimmer), findsOneWidget);
  });

  testWidgets(
      'BookingDetailScreen matches screenshot layout and print buttons work',
      (WidgetTester tester) async {
    final testBooking = BookingModel(
      id: 999,
      bookingCode: 'SKY260910FGS8',
      customerName: 'Rian Hidayat',
      customerPhone: '+62 81298765432',
      customerEmail: 'rian.hidayat@gmail.com',
      address: 'Jl. Radio Dalam No. 14, Gandaria Utara, Kebayoran Baru',
      pickupType: 'pickup',
      jaminanType: 'KTP Asli',
      startDate: DateTime(2026, 9, 10, 0, 0),
      endDate: DateTime(2026, 9, 11, 0, 0),
      durationDays: 12,
      price: 1440000,
      deposit: 500000,
      discount: 50000,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: const IphoneModel(
        id: 1,
        name: 'iPhone 13 Pink',
        storage: '128GB',
        color: 'Pink',
        serialNumber: 'DX3GGKS9SAA',
        assetCode: 'IPHSKY1002',
        status: 'ready',
        batteryHealth: 100,
      ),
      notes: 'Customer request pickup tepat waktu.',
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) =>
            AppRoutes.onGenerateRoute(settings, BookingRepository()),
        home: BookingDetailScreen(booking: testBooking),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Sub-header
    expect(find.text('Detail Booking'), findsOneWidget);
    expect(find.text(AuthService().currentUser?.outletName ?? 'Store Pusat'), findsOneWidget);

    // Verify Hero Card
    expect(find.text('KODE BOOKING'), findsOneWidget);
    expect(find.text('SKY260910FGS8'), findsOneWidget);
    expect(find.text('Dikonfirmasi'), findsOneWidget);
    expect(find.text('Status Pembayaran'), findsOneWidget);
    expect(find.text('LUNAS'), findsWidgets);

    // Verify Customer Info Card
    expect(find.text('Informasi Pelanggan'), findsOneWidget);
    expect(find.text('Terverifikasi'), findsOneWidget);
    expect(find.text('Rian Hidayat'), findsOneWidget);
    expect(find.text('+62 81298765432'), findsOneWidget);
    expect(find.text('rian.hidayat@gmail.com'), findsOneWidget);
    expect(find.text('KTP Asli'), findsOneWidget);

    // Verify Unit iPhone Card
    expect(find.text('Unit iPhone & Hardware'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('iPhone 13 Pink 128GB'), findsOneWidget);
    expect(find.text('Default (Pink)'), findsOneWidget);
    expect(find.text('DX3GGKS9SAA'), findsOneWidget);
    expect(find.text('IPHSKY1002'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // Verify Schedule Card
    expect(find.text('Jadwal & Durasi Rental'), findsOneWidget);
    expect(find.text('Terjadwal'), findsOneWidget);
    expect(find.text('12 Jam'), findsWidgets);

    // Verify Financial Card
    expect(find.text('Ringkasan Biaya & Deposit'), findsOneWidget);
    expect(find.text('Tarif Sewa (12 Jam)'), findsOneWidget);
    expect(find.text('Deposit Jaminan Fisik'), findsOneWidget);
    expect(find.text('Diskon Promo Early Bird'), findsOneWidget);
    expect(find.text('Total Dibayarkan'), findsOneWidget);
    expect(find.text('Rp 1.890.000'), findsOneWidget);

    // Verify Bottom Actions
    // Removed by user request: expect(find.text('Proses Pickup (Serah Terima)'), findsOneWidget);
    final printButtonFinder = find.text('Lihat & Cetak Struk');
    expect(printButtonFinder, findsOneWidget);

    // Test tapping 'Lihat & Cetak Struk' navigates to ReceiptScreen
    await tester.tap(printButtonFinder);
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptScreen), findsOneWidget);
    expect(find.text('Pratinjau Struk ESC/POS'), findsOneWidget);

    // Pop back to detail screen
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    // Test tapping Sub-header Print Icon opens bottom sheet
    final printIconFinder = find.byTooltip('Cetak Resi');
    expect(printIconFinder, findsOneWidget);
    await tester.tap(printIconFinder);
    await tester.pumpAndSettle();

    expect(find.text('Cetak Resi Booking'), findsOneWidget);
    expect(find.text('Cetak Langsung ke Thermal Printer'), findsOneWidget);
    expect(find.text('Buka Pratinjau & Atur Format Resi'), findsOneWidget);
  });

  testWidgets(
      'BookingDetailScreen renders tablet landscape 2-column layout matching design',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final testBooking = BookingModel(
      id: 999,
      bookingCode: 'SKY260910FGS8',
      customerName: 'Rian Hidayat',
      customerPhone: '+62 81298765432',
      customerEmail: 'rian.hidayat@gmail.com',
      address: 'Jl. Radio Dalam No. 14, Gandaria Utara, Kebayoran Baru',
      pickupType: 'pickup',
      jaminanType: 'KTP Asli',
      startDate: DateTime(2026, 9, 10, 0, 0),
      endDate: DateTime(2026, 9, 11, 0, 0),
      durationDays: 12,
      price: 1440000,
      deposit: 500000,
      discount: 50000,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: const IphoneModel(
        id: 1,
        name: 'iPhone 15 Pro Max',
        storage: '256GB',
        color: 'Natural Titanium',
        serialNumber: 'DX3GGKS9SAA',
        assetCode: 'IPHSKY1002',
        status: 'ready',
        batteryHealth: 100,
      ),
      notes: 'Customer request pickup tepat waktu.',
    );

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) =>
            AppRoutes.onGenerateRoute(settings, BookingRepository()),
        home: BookingDetailScreen(
          booking: testBooking,
          repository: BookingRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Tablet Header
    expect(find.text('Antrean Transaksi'), findsOneWidget);
    expect(find.text('#SKY260910FGS8'), findsOneWidget);
    expect(find.text(AuthService().currentUser?.outletName ?? 'Store Pusat'), findsOneWidget);

    // Verify Left Column - Identitas Penyewa
    expect(find.text('IDENTITAS PENYEWA'), findsOneWidget);
    expect(find.text('Rian Hidayat'), findsOneWidget);
    expect(find.text('+62 81298765432'), findsOneWidget);
    expect(find.text('rian.hidayat@gmail.com'), findsOneWidget);
    expect(find.text('KTP Asli Fisik'), findsOneWidget);
    expect(find.text('Jl. Radio Dalam No. 14, Gandaria Utara, Kebayoran Baru'), findsOneWidget);

    // Verify Left Column - Spesifikasi Inventaris
    expect(find.text('SPESIFIKASI INVENTARIS'), findsOneWidget);
    expect(find.text('iPhone 15 Pro Max 256GB'), findsOneWidget);
    expect(find.text('DX3GGKS9SAA'), findsOneWidget);
    expect(find.text('IPHSKY1002'), findsOneWidget);
    expect(find.text('Log Fisik'), findsOneWidget);
    expect(find.text('Kabel Data C-Lightning'), findsOneWidget);
    expect(find.text('Adaptor 20W PD'), findsOneWidget);
    expect(find.text('Clear Case & Tempered'), findsOneWidget);

    // Verify Left Column - Durasi Pemakaian & Return / Penalty Action
    expect(find.text('DURASI PEMAKAIAN'), findsOneWidget);
    expect(find.text('Mulai Sewa (Handover)'), findsOneWidget);
    expect(find.text('Batas Kembali (Deadline)'), findsOneWidget);
    expect(find.text('TOTAL DURASI'), findsOneWidget);
    expect(find.textContaining('Counter Pickup'), findsNothing);
    expect(find.byKey(const Key('btn_tablet_return')), findsOneWidget);
    expect(find.byKey(const Key('btn_tablet_penalty')), findsOneWidget);
    expect(find.text('Pengembalian Unit'), findsOneWidget);
    expect(find.textContaining('Denda'), findsWidgets);

    // Verify Right Column - Keuangan & Kasir
    expect(find.text('KEUANGAN & KASIR'), findsOneWidget);
    expect(find.text('TOTAL TERBAYAR LUNAS'), findsOneWidget);
    expect(find.text('Rp 1.890.000'), findsWidgets);

    // Verify Right Column - Printer Kasir & Thermal Preview
    expect(find.text('VSC MP-58C Kasir'), findsOneWidget);
    expect(find.text('Test Roll'), findsOneWidget);
    expect(find.text('PRATINJAU NOTA KASIR'), findsOneWidget);
    expect(find.text('Preview Struk (58mm Thermal)'), findsOneWidget);
    expect(find.text('Siap Cetak'), findsOneWidget);
    expect(find.text('Cetak Nota'), findsOneWidget);

    // Tap Log Fisik and verify SnackBar
    await tester.tap(find.text('Log Fisik'));
    await tester.pumpAndSettle();
    expect(find.text('Kondisi fisik: Mulus / Siap Pakai (BH: 100%)'), findsOneWidget);

    // Tap Test Roll
    await tester.tap(find.text('Test Roll'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Ensure Cetak Nota is visible and tap it
    await tester.ensureVisible(find.text('Cetak Nota'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cetak Nota'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'CreateBookingScreen validates WhatsApp number and rejects invalid repetitive numbers',
      (WidgetTester tester) async {
    final repository = BookingRepository();
    await tester.pumpWidget(SkyRentalAdminApp(bookingRepository: repository));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Navigate to CreateBookingScreen
    final fabFinder = find.widgetWithText(FloatingActionButton, 'Buat Booking');
    await tester.tap(fabFinder);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Fill customer info with invalid phone 000000000000
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Customer');
    await tester.enterText(find.byType(TextFormField).at(1), '000000000000');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang');
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Next
    final nextToStep2Finder = find.byKey(const Key('btn_next_to_step_2'));
    await tester.tap(nextToStep2Finder);
    await tester.pumpAndSettle();

    // Verify rejection: error text is shown and screen stays on Step 1
    expect(
        find.text(
            'Nomor WhatsApp tidak valid. Format harus diawali 08/628 dan 10-13 digit.'),
        findsWidgets);
    expect(find.text('Pilih Durasi'), findsNothing);
  });

  test(
      'BookingRepository submitBookingPayment updates booking payment status to paid',
      () async {
    final repository = BookingRepository();
    // Use a fresh unit with unique ID to avoid conflicting with rented mock bookings
    const freshUnit = IphoneModel(
      id: 999,
      name: 'iPhone 15 Pro Test',
      storage: '128GB',
      color: 'Test Gold',
      serialNumber: 'TESTSERIAL999',
      assetCode: 'AST-TEST-999',
      status: 'tersedia',
      batteryHealth: 100,
    );
    final booking = await repository.createBooking(
      customerName: 'Ahmad Selesai Bayar',
      customerPhone: '081298765432',
      customerEmail: 'ahmad@example.com',
      address: 'Jl. Sudirman No 1',
      iphone: freshUnit,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(hours: 24)),
      durationDays: 24,
      price: 250000,
      deposit: 0,
      jaminanType: 'KTP',
      paymentStatus: PaymentStatus.unpaid,
      amountPaid: 0,
      paymentMethod: 'Kasir',
    );

    expect(booking.paymentStatus, equals(PaymentStatus.unpaid));

    // Submit payment
    final success = await repository.submitBookingPayment(
      bookingCode: booking.bookingCode,
      amount: 250000,
      pay: 300000,
      paymentMethod: 'tunai',
      type: 'payment',
    );

    expect(success, isTrue);

    // Verify updated booking in repository
    final updatedList = await repository.getBookings();
    final updatedBooking =
        updatedList.firstWhere((b) => b.bookingCode == booking.bookingCode);
    expect(updatedBooking.paymentStatus, equals(PaymentStatus.paid));
  });

  test(
      'BookingModel correctly computes late duration and penalty fee matching DetailBooking',
      () {
    final now = DateTime.now();
    // Booking that ended 4 hours and 30 minutes ago
    final lateBooking = BookingModel(
      id: 999,
      bookingCode: 'TEST-LATE-01',
      customerName: 'Test Customer',
      customerPhone: '08123456789',
      customerEmail: 'test@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: now.subtract(const Duration(hours: 28)),
      endDate: now.subtract(const Duration(hours: 4, minutes: 30)),
      durationDays: 24,
      price: 200000,
      deposit: 0,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: const IphoneModel(
        id: 1,
        name: 'iPhone 13',
        storage: '128GB',
        color: 'Midnight',
        serialNumber: 'SN12345',
        assetCode: 'AST-01',
        status: 'ready',
      ),
      isLate: true,
      diffHours: 4.5,
      hoursLate: 4,
      lateMinutes: 30,
      estimatedLateFee: 15000,
    );

    expect(lateBooking.isCurrentlyOverdue, isTrue);
    expect(lateBooking.isCurrentlyLate, isTrue);
    expect(lateBooking.currentLateHours, equals(4));
    expect(lateBooking.currentLateMinutes, equals(30));
    expect(lateBooking.lateDurationFormatted, equals('4 jam 30 menit'));
    expect(lateBooking.estimatedLateFee, equals(15000));

    // Scenario 2: Within 90 minute grace period (e.g. 45 min late)
    final graceBooking = BookingModel(
      id: 998,
      bookingCode: 'TEST-GRACE',
      customerName: 'Customer Grace',
      customerPhone: '08123456788',
      customerEmail: 'grace@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: now.subtract(const Duration(hours: 25)),
      endDate: now.subtract(const Duration(minutes: 45)),
      durationDays: 24,
      price: 200000,
      deposit: 0,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: const IphoneModel(
        id: 1,
        name: 'iPhone 13',
        storage: '128GB',
        color: 'Midnight',
        serialNumber: 'SN12345',
        assetCode: 'AST-01',
        status: 'ready',
      ),
    );
    expect(graceBooking.isCurrentlyLate, isFalse);
    expect(graceBooking.estimatedLateFee, equals(0.0));

    // Scenario 3: 2 hours late -> 2 - 1 = 1 hour billable -> 1 * 5000 = Rp 5.000
    final twoHourBooking = BookingModel(
      id: 997,
      bookingCode: 'TEST-2H',
      customerName: 'Customer 2h',
      customerPhone: '08123456787',
      customerEmail: '2h@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: now.subtract(const Duration(hours: 26)),
      endDate: now.subtract(const Duration(hours: 2)),
      durationDays: 24,
      price: 200000,
      deposit: 0,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: const IphoneModel(
        id: 1,
        name: 'iPhone 13',
        storage: '128GB',
        color: 'Midnight',
        serialNumber: 'SN12345',
        assetCode: 'AST-01',
        status: 'ready',
      ),
    );
    expect(twoHourBooking.isCurrentlyLate, isTrue);
    expect(twoHourBooking.currentLateHours, equals(2));
    expect(twoHourBooking.estimatedLateFee, equals(5000.0));

    // Scenario 4: 14 hours late -> 14 - 1 = 13 hours -> 12h pkg (65k) + 1h (5k) = Rp 70.000
    final fourteenHourBooking = BookingModel(
      id: 996,
      bookingCode: 'TEST-14H',
      customerName: 'Customer 14h',
      customerPhone: '08123456786',
      customerEmail: '14h@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: now.subtract(const Duration(hours: 38)),
      endDate: now.subtract(const Duration(hours: 14)),
      durationDays: 24,
      price: 200000,
      deposit: 0,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: const IphoneModel(
        id: 1,
        name: 'iPhone 13',
        storage: '128GB',
        color: 'Midnight',
        serialNumber: 'SN12345',
        assetCode: 'AST-01',
        status: 'ready',
      ),
    );
    expect(fourteenHourBooking.isCurrentlyLate, isTrue);
    expect(fourteenHourBooking.currentLateHours, equals(14));
    expect(fourteenHourBooking.estimatedLateFee, equals(70000.0));
  });

  testWidgets(
      'PaymentDepositScreen handles penalty payment type and prefilled late fee nominal',
      (WidgetTester tester) async {
    final repository = BookingRepository();
    final now = DateTime.now();
    final lateBooking = BookingModel(
      id: 99,
      bookingCode: 'SKY-TEST-LATE',
      customerName: 'Budi Santoso',
      customerPhone: '08123456789',
      customerEmail: 'budi@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: now.subtract(const Duration(hours: 30)),
      endDate: now.subtract(const Duration(hours: 3)),
      durationDays: 24,
      price: 150000,
      deposit: 0,
      status: BookingStatus.rented,
      paymentStatus: PaymentStatus.paid,
      iphone: const IphoneModel(
        id: 99,
        name: 'iPhone 15 Pro',
        storage: '256GB',
        color: 'Natural Titanium',
        serialNumber: 'SN-PRO-99',
        assetCode: 'AST-PRO-99',
        status: 'disewa',
      ),
      isLate: true,
      diffHours: 3.0,
      hoursLate: 3,
      lateMinutes: 0,
      estimatedLateFee: 75000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PaymentDepositScreen(
          repository: repository,
          booking: lateBooking,
          initialPaymentType: PaymentTypeOption.penalty,
          initialAmount: 75000,
          isReturnFlow: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TOTAL DENDA KETERLAMBATAN'), findsOneWidget);
    expect(find.text('Bayar Denda & Selesaikan Pengembalian'), findsOneWidget);
    expect(find.text('Rp 75.000'), findsWidgets);
    expect(find.text('Sisa Refund ke Pelanggan'), findsNothing);
    expect(find.text('Uji Kelayakan & Hardware'), findsNothing);
  });

  testWidgets(
      'ReturnInspectionScreen displays late fee and navigates without hardware tests',
      (WidgetTester tester) async {
    final repository = BookingRepository();
    final now = DateTime.now();
    final lateBooking = BookingModel(
      id: 100,
      bookingCode: 'SKY-TEST-INSPECT',
      customerName: 'Siti Aminah',
      customerPhone: '08129876543',
      customerEmail: 'siti@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: now.subtract(const Duration(hours: 30)),
      endDate: now.subtract(const Duration(hours: 2)),
      durationDays: 24,
      price: 150000,
      deposit: 0,
      status: BookingStatus.rented,
      paymentStatus: PaymentStatus.paid,
      iphone: const IphoneModel(
        id: 100,
        name: 'iPhone 14 Pro',
        storage: '128GB',
        color: 'Space Black',
        serialNumber: 'SN-14-100',
        assetCode: 'AST-14-100',
        status: 'disewa',
      ),
      isLate: true,
      diffHours: 2.0,
      hoursLate: 2,
      lateMinutes: 0,
      estimatedLateFee: 50000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReturnInspectionScreen(
          repository: repository,
          booking: lateBooking,
          initialLateFee: 50000,
          daysLate: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pengembalian Unit'), findsOneWidget);
    expect(find.text('Kalkulasi Keterlambatan'), findsOneWidget);
    expect(find.text('Bayar Denda (Rp 5.000) di Kasir'), findsOneWidget);
    expect(find.text('Uji Kelayakan & Hardware'), findsNothing);
    expect(find.text('Kelengkapan Aksesoris Sewa'), findsNothing);
    expect(find.text('Sisa Refund Ke Pelanggan'), findsNothing);
    expect(find.text('Metode Refund Saldo'), findsNothing);
  });

  testWidgets(
      'UnitStatusListSkeleton renders properly with shimmer and card structure',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UnitStatusListSkeleton(itemCount: 3),
        ),
      ),
    );

    expect(find.byType(UnitStatusListSkeleton), findsOneWidget);
    expect(find.byType(SkeletonShimmer), findsOneWidget);
    expect(find.byType(UnitStatusCardSkeleton), findsNWidgets(3));
  });

  testWidgets(
      'UnitStatusListScreen displays skeleton loading initially and renders unit cards after data loads',
      (WidgetTester tester) async {
    final repository = BookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: UnitStatusListScreen(repository: repository),
      ),
    );

    // Initial frame shows skeleton loading
    expect(find.byType(UnitStatusListSkeleton), findsOneWidget);

    // Settle to complete _loadData
    await tester.pumpAndSettle();

    // After loading, skeleton is gone and content is visible
    expect(find.byType(UnitStatusListSkeleton), findsNothing);
    expect(find.text('Status Unit iPhone'), findsOneWidget);
    expect(find.text('Total Unit'), findsOneWidget);
    expect(find.text('Tersedia'), findsWidgets);
  });

  test(
      'BookingRepository getAllInventoryUnits and updateUnitStatus manage inventory correctly',
      () async {
    final repository = BookingRepository();
    final units = await repository.getAllInventoryUnits();
    expect(units.isNotEmpty, isTrue);

    final summary = await repository.getUnitStatusSummary();
    expect(summary.containsKey('total'), isTrue);
    expect(summary['total']! >= 1, isTrue);

    // Update status
    final target = units.first;
    final updated = await repository
        .updateUnitStatus(target.assetCode, 'maintenance', batteryHealth: 95);
    expect(updated.status.toLowerCase(),
        anyOf(equals('maintenance'), equals('perawatan')));
    expect(updated.batteryHealth, equals(95));

    // Restore unit status to maintain test suite isolation
    await repository.updateUnitStatus(target.assetCode, target.status, batteryHealth: target.batteryHealth);
  });

  test('BookingRepository createBooking rejects rented unit with Exception',
      () async {
    final repository = BookingRepository();
    const rentedUnit = IphoneModel(
      id: 888,
      name: 'iPhone 15 Pro',
      storage: '128GB',
      color: 'Gold',
      serialNumber: 'RENTED-TEST-001',
      assetCode: 'AST-RENTED-001',
      status: 'disewa',
      batteryHealth: 98,
    );

    expect(
      () => repository.createBooking(
        customerName: 'Test Pelanggan',
        customerPhone: '081299887766',
        customerEmail: 'test@rented.com',
        address: 'Jl. Test',
        iphone: rentedUnit,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(hours: 24)),
        durationDays: 24,
        price: 200000,
        deposit: 0,
        jaminanType: 'KTP',
        paymentStatus: PaymentStatus.unpaid,
        amountPaid: 0,
        paymentMethod: 'Kasir',
      ),
      throwsA(isA<Exception>().having(
        (e) => e.toString(),
        'message',
        contains('sedang dalam masa sewa'),
      )),
    );
  });

  test(
      'BookingRepository createBooking rejects maintenance unit with Exception',
      () async {
    final repository = BookingRepository();
    const maintenanceUnit = IphoneModel(
      id: 887,
      name: 'iPhone 14',
      storage: '128GB',
      color: 'Blue',
      serialNumber: 'MAINT-TEST-001',
      assetCode: 'AST-MAINT-001',
      status: 'perawatan',
      batteryHealth: 85,
    );

    expect(
      () => repository.createBooking(
        customerName: 'Test Pelanggan 2',
        customerPhone: '081299887755',
        customerEmail: 'test@maint.com',
        address: 'Jl. Test 2',
        iphone: maintenanceUnit,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(hours: 24)),
        durationDays: 24,
        price: 200000,
        deposit: 0,
        jaminanType: 'KTP',
        paymentStatus: PaymentStatus.unpaid,
        amountPaid: 0,
        paymentMethod: 'Kasir',
      ),
      throwsA(isA<Exception>().having(
        (e) => e.toString(),
        'message',
        contains('perawatan/perbaikan'),
      )),
    );
  });

  test('BookingRepository canExtendBooking and extendBooking successfully adds hours and updates schedule', () async {
    final repository = BookingRepository();
    // Buat booking dengan unit unik untuk memastikan pengujian tidak bentrok dengan mock lain
    final testBooking = await repository.createBooking(
      customerName: 'Extend Test User',
      customerPhone: '081299881122',
      customerEmail: 'extend@test.com',
      address: 'Jl. Extend No 1',
      iphone: const IphoneModel(
        id: 777,
        name: 'iPhone 15 Pro Max',
        storage: '256GB',
        color: 'Titanium Black',
        serialNumber: 'EXT-TEST-SN01',
        assetCode: 'AST-EXT-777',
        status: 'tersedia',
        batteryHealth: 100,
      ),
      startDate: DateTime(2026, 10, 1, 10, 0),
      endDate: DateTime(2026, 10, 3, 10, 0),
      durationDays: 2,
      price: 300000,
      deposit: 0,
      jaminanType: 'KTP',
      paymentStatus: PaymentStatus.paid,
      amountPaid: 300000,
      paymentMethod: 'Kasir',
    );

    final canExtend = await repository.canExtendBooking(testBooking.bookingCode, 6);
    expect(canExtend, isTrue);

    final initialDuration = testBooking.durationDays;
    final initialEnd = testBooking.endDate;
    final initialPrice = testBooking.price;

    final updated = await repository.extendBooking(
      bookingCode: testBooking.bookingCode,
      hours: 6,
      price: 50000,
      paymentMethod: 'tunai',
      pay: 50000,
      note: 'Test extend 6 jam',
    );

    expect(updated.durationDays, equals(initialDuration + 6));
    expect(updated.price, equals(initialPrice + 50000));
    expect(updated.endDate, equals(initialEnd.add(const Duration(hours: 6))));
  });

  testWidgets('ExtendDurationModal renders duration options and calculates preview', (WidgetTester tester) async {
    final repository = BookingRepository();
    final bookings = await repository.getBookings();
    final sampleBooking = bookings.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExtendDurationModal(
            booking: sampleBooking,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('Tambah Durasi Sewa'), findsOneWidget);
    expect(find.text('Pilih Durasi'), findsOneWidget);
    expect(find.text('Jumlah'), findsOneWidget);
    expect(find.text('Total Tambah Waktu'), findsOneWidget);
    expect(find.textContaining('Bayar di Kasir'), findsOneWidget);

    // Increment multiplier
    final addFinder = find.byIcon(Icons.add_rounded);
    expect(addFinder, findsOneWidget);
    await tester.tap(addFinder);
    await tester.pumpAndSettle();

    // Verify multiplier increased to 2
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('BookingDetailScreen renders Tambah Durasi button and opens modal on tap', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = BookingRepository();
    final bookings = await repository.getBookings();
    final activeBooking = bookings.firstWhere(
      (b) => b.status == BookingStatus.rented || b.status == BookingStatus.confirmed,
      orElse: () => bookings.first,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BookingDetailScreen(
          booking: activeBooking,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check Tambah Jam chip in Schedule card & Tambah Durasi button in Return section
    expect(find.text('+ Tambah Jam'), findsOneWidget);
    final tambahDurasiFinder = find.text('Tambah Durasi');
    expect(tambahDurasiFinder, findsOneWidget);

    // Tap Tambah Durasi button to open modal
    await tester.tap(tambahDurasiFinder);
    await tester.pumpAndSettle();

    // Verify modal appeared
    expect(find.byType(ExtendDurationModal), findsOneWidget);
    expect(find.text('Tambah Durasi Sewa'), findsOneWidget);
  });

  testWidgets(
      'DashboardScreen header displays user login data, printer status, and removes outlet malioboro and brand icon',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = BookingRepository();
    await tester.pumpWidget(SkyRentalAdminApp(bookingRepository: repository));
    await tester.pumpAndSettle();

    // 1. Check brand logo icon 'brand_logo.png' is removed from the header
    expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage), findsNothing);

    // 2. Check 'Outlet Utama Malioboro' is NOT present in the header or operational banner
    expect(find.text('Outlet Utama Malioboro'), findsNothing);
    expect(find.text('OUTLET UTAMA MALIOBORO • AKTIF'), findsNothing);
    expect(find.text('SISTEM OPERASIONAL • AKTIF'), findsNothing);

    // 3. Check user login info is rendered dynamically
    final user = AuthService().currentUser;
    expect(find.text(user?.name ?? 'Admin SKYRental'), findsWidgets);
    expect(find.text('KASIR'), findsOneWidget);
    expect(find.text(user?.role ?? 'Staff Operasional'), findsOneWidget);

    // 4. Set test printer state and check printer status badge
    ThermalPrintService().activePrinterNotifier.value = PrinterDeviceModel.defaultVsc();
    ThermalPrintService().isConnectedNotifier.value = false;
    await tester.pump();

    expect(find.text('VSC MP-58C'), findsOneWidget);
    expect(find.text('Belum Terhubung'), findsOneWidget);

    // 5. Connect printer and verify reactive update to 'Terhubung'
    ThermalPrintService().isConnectedNotifier.value = true;
    await tester.pump();
    expect(find.text('Terhubung'), findsOneWidget);

    // 6. Tap printer status badge and verify navigation to PrinterSettingsScreen
    await tester.tap(find.text('VSC MP-58C'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PrinterSettingsScreen), findsOneWidget);
  });

  testWidgets(
      'DashboardScreen renders responsive 2-column landscape tablet layout without overflow',
      (WidgetTester tester) async {
    // Landscape tablet resolution
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = BookingRepository();
    await tester.pumpWidget(SkyRentalAdminApp(bookingRepository: repository));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // 0. Verify Tablet Top Header (Stitch AppBar on Tablet)
    expect(find.text('SKYRental'), findsWidgets);
    expect(find.textContaining('Shift Pagi • POS-01'), findsWidgets);
    expect(find.byType(CircleAvatar), findsWidgets);

    // 1. Verify Welcome Banner is removed per user request
    expect(find.text('STATUS SISTEM'), findsNothing);
    expect(find.text('Inspeksi Siap'), findsNothing);
    expect(find.text('Metrik Operasional Hari Ini'), findsOneWidget);

    // 2. Verify 4 Metrics in a row
    expect(find.text('Pickup Hari Ini'), findsOneWidget);
    expect(find.text('Return Hari Ini'), findsOneWidget);
    expect(find.text('Unit Disewa'), findsOneWidget);
    expect(find.text('Omzet Hari Ini'), findsOneWidget);

    // 3. Verify Right Sidebar: Aksi Cepat Kasir, Printer Kasir, Stok Siap Sewa
    expect(find.text('Aksi Cepat Kasir'), findsOneWidget);
    expect(find.text('Buat Booking Baru'), findsWidgets);
    expect(find.text('Scan QR Booking'), findsOneWidget);
    expect(find.text('Cek Stok Unit'), findsOneWidget);

    expect(find.text('Printer Kasir'), findsOneWidget);
    expect(find.text('Tes Cetak Nota Struk'), findsOneWidget);

    expect(find.text('Stok Siap Sewa'), findsOneWidget);

    // 4. Verify transaction queue cards & action buttons
    expect(find.text('Antrean Transaksi'), findsOneWidget);
    expect(find.text('Proses Serah Terima'), findsNothing);

    // 5. Check no overflow exceptions were logged
    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardScreen transaction queue supports search filtering and reset', (WidgetTester tester) async {
    final repository = BookingRepository();
    await tester.pumpWidget(SkyRentalAdminApp(bookingRepository: repository));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify search bar is present
    final searchFinder = find.byType(TextField);
    expect(searchFinder, findsOneWidget);

    // Search for non-existent customer
    await tester.enterText(searchFinder, 'ZzzzRandomQuery12345');
    await tester.pump();

    // Verify empty state is displayed
    expect(find.text('Tidak Ditemukan'), findsOneWidget);
    expect(find.text('Tidak ada transaksi yang cocok dengan "ZzzzRandomQuery12345".'), findsOneWidget);

    // Reset search
    await tester.enterText(searchFinder, '');
    await tester.pump();

    expect(find.text('Tidak Ditemukan'), findsNothing);
  });

  testWidgets('AffiliateListScreen renders empty state when no affiliates exist', (WidgetTester tester) async {
    final repository = BookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: AffiliateListScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and empty state
    expect(find.text('Mitra Cabang & Affiliate'), findsOneWidget);
    expect(find.text('Belum Ada Mitra Affiliate'), findsOneWidget);
    expect(find.text('Tambah Mitra Sekarang'), findsOneWidget);
  });

  testWidgets('AffiliateListScreen renders KPI summary, branch list, and filter chips', (WidgetTester tester) async {
    final repository = BookingRepository();
    await repository.createAffiliate(const AffiliateModel(
      id: 1,
      code: 'BWI',
      name: 'Affiliate Banyuwangi Kota',
      slug: 'affiliate-banyuwangi-kota',
      city: 'Banyuwangi',
      isActive: true,
      iphonesCount: 6,
    ));

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: AffiliateListScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and KPI summaries
    expect(find.text('Mitra Cabang & Affiliate'), findsOneWidget);
    expect(find.text('Total Mitra'), findsOneWidget);
    expect(find.text('Unit Tersebar'), findsOneWidget);

    // Verify search and filter chips
    expect(find.textContaining('Semua Mitra'), findsOneWidget);
    expect(find.textContaining('Aktif'), findsWidgets);
    expect(find.textContaining('Nonaktif'), findsWidgets);

    // Verify FAB Tambah Mitra
    expect(find.text('Tambah Mitra'), findsOneWidget);

    // Verify affiliate branch is loaded
    expect(find.textContaining('Banyuwangi'), findsWidgets);
  });

  testWidgets('AffiliateDetailScreen renders branch details, tabs, and action menus', (WidgetTester tester) async {
    final repository = BookingRepository();
    final mockAffiliate = AffiliateModel.mockMalioboro();

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: AffiliateDetailScreen(
          affiliate: mockAffiliate,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and header
    expect(find.textContaining(mockAffiliate.code), findsWidgets);
    expect(find.textContaining(mockAffiliate.name), findsWidgets);

    // Verify KPI cards
    expect(find.text('Unit iPhone'), findsWidgets);
    expect(find.text('Total Booking'), findsWidgets);
    expect(find.text('Pendapatan Hari Ini'), findsWidgets);
    expect(find.text('Mutasi / Transfer'), findsWidgets);

    // Verify Tabs
    expect(find.text('Unit iPhone'), findsWidgets);
    expect(find.widgetWithText(Tab, 'Booking'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Pengguna'), findsOneWidget);
    expect(find.text('Informasi'), findsOneWidget);
  });

  testWidgets('AffiliateDetailScreen user management tab and assign user modal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = BookingRepository();
    final mockAffiliate = AffiliateModel.mockMalioboro();

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: AffiliateDetailScreen(
          affiliate: mockAffiliate,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on the 'Pengguna' Tab
    await tester.tap(find.widgetWithText(Tab, 'Pengguna'));
    await tester.pumpAndSettle();

    // Verify Users Tab content
    expect(find.textContaining('Staf & Pengguna'), findsWidgets);
    expect(find.text('Tugaskan Pengguna'), findsWidgets);

    // Tap 'Tugaskan Pengguna' button to open assign user modal
    await tester.tap(find.text('Tugaskan Pengguna').first);
    await tester.pumpAndSettle();

    // Verify bottom sheet modal opened
    expect(find.text('Assign Affiliate to User'), findsOneWidget);
    expect(find.textContaining('Pilih salah satu user'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);

    // Close modal
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify modal closed
    expect(find.text('Assign Affiliate to User'), findsNothing);
  });

  test('BookingRepository affiliate user assignment and removal unit test', () async {
    final repository = BookingRepository();
    final users = await repository.getAvailableUsersForAffiliate(1);
    expect(users.isNotEmpty, true);

    // Assign mock users
    final assigned = await repository.assignUsersToAffiliate(1, ['mock-u1', 'mock-u3']);
    expect(assigned.any((u) => u.id == 'mock-u3'), true);

    // Remove mock user
    final removed = await repository.removeUserFromAffiliate(1, 'mock-u3');
    expect(removed, true);
  });

  testWidgets('AffiliateDetailScreen renders iPhones and Bookings tabs for Pusat affiliate', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = BookingRepository();
    const pusatAffiliate = AffiliateModel(
      id: 4,
      code: 'GTG PUSAT',
      name: 'Pusat',
      slug: 'pusat',
      city: 'Genteng Banyuwangi',
      isActive: true,
      iphonesCount: 2,
      bookingsCount: 2,
    );
    await repository.createAffiliate(pusatAffiliate);

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: AffiliateDetailScreen(
          affiliate: pusatAffiliate,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header banner
    expect(find.textContaining('GTG PUSAT'), findsWidgets);
    expect(find.textContaining('Pusat'), findsWidgets);

    // Verify Unit iPhone tab shows header
    expect(find.textContaining('Daftar Unit di Pusat'), findsOneWidget);

    // Switch to Booking Tab
    await tester.tap(find.widgetWithText(Tab, 'Booking'));
    await tester.pumpAndSettle();

    // Verify Booking Tab header
    expect(find.textContaining('Aktivitas Sewa di Cabang Ini'), findsOneWidget);

    // Test repository getAffiliateIphones and getAffiliateBookings for Pusat
    final iphones = await repository.getAffiliateIphones(4);
    expect(iphones.isNotEmpty, true);

    final bookings = await repository.getAffiliateBookings(4);
    expect(bookings.isNotEmpty, true);
  });

  testWidgets('AffiliateFormScreen allows creating new affiliate branch', (WidgetTester tester) async {
    final repository = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: AffiliateFormScreen(
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title
    expect(find.text('Tambah Mitra Cabang'), findsOneWidget);
    expect(find.text('INFORMASI UTAMA CABANG'), findsOneWidget);
    expect(find.text('ALAMAT & LOKASI'), findsOneWidget);

    // Enter required fields
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'BDG-01'); // Kode Cabang
    await tester.enterText(textFields.at(1), 'Cabang Bandung Dago'); // Nama Cabang
    await tester.enterText(textFields.at(2), '081234567890'); // Telepon

    await tester.pump();

    // Verify button
    final saveButton = find.text('Buat Mitra Cabang');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('IphoneTransferListScreen renders tabs and shows Kirim Unit iPhone button', (WidgetTester tester) async {
    final repository = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: IphoneTransferListScreen(
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and tabs
    expect(find.text('Mutasi & Transfer Unit'), findsOneWidget);
    expect(find.textContaining('Semua'), findsWidgets);
    expect(find.textContaining('Terkirim'), findsWidgets);
    expect(find.textContaining('Selesai'), findsWidgets);

    // Verify FAB
    expect(find.text('Kirim Unit iPhone'), findsOneWidget);

    // Tap FAB to open modal
    await tester.tap(find.text('Kirim Unit iPhone'));
    await tester.pumpAndSettle();

    // Modal sheet appears
    expect(find.text('Kirim & Mutasi iPhone'), findsOneWidget);
    expect(find.text('Unit iPhone *'), findsOneWidget);
    expect(find.text('Cabang Mitra Tujuan *'), findsOneWidget);
  });

  testWidgets('AffiliateRevenueScreen displays omset KPIs and financial transactions', (WidgetTester tester) async {
    final repository = BookingRepository();
    final mockAffiliate = AffiliateModel.mockMalioboro();

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: AffiliateRevenueScreen(
          affiliate: mockAffiliate,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title & header
    expect(find.textContaining('Omset -'), findsOneWidget);
    expect(find.text('TOTAL OMSET CABANG'), findsOneWidget);
    expect(find.text('Booking Hari Ini'), findsOneWidget);
    expect(find.text('Total Transaksi'), findsOneWidget);

    // Verify filters
    expect(find.text('Semua Periode'), findsOneWidget);
    expect(find.text('Hari Ini'), findsWidgets);
    expect(find.text('7 Hari Terakhir'), findsOneWidget);
    expect(find.text('Bulan Ini'), findsOneWidget);

    // Verify transaction section
    expect(find.text('Riwayat Transaksi Masuk'), findsOneWidget);
  });

  testWidgets('AccountScreen displays Tema & Warna menu and opens ThemeSettingsScreen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ThemeService().init();
    final repository = BookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: AccountScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    final themeMenu = find.text('Tema & Warna Aplikasi');
    await tester.ensureVisible(themeMenu);
    expect(themeMenu, findsOneWidget);

    await tester.tap(themeMenu);
    await tester.pumpAndSettle();

    expect(find.byType(ThemeSettingsScreen), findsOneWidget);
    expect(find.text('Pratinjau Langsung Tema'), findsOneWidget);
  });

  test('PaymentTransactionModel copyWith updates fields properly', () {
    final tx = PaymentTransactionModel(
      id: 10,
      bookingId: 1,
      bookingCode: 'BK-10',
      customerName: 'Budi',
      customerPhone: '08123',
      iphoneName: 'iPhone 13',
      rentTotal: 200000,
      depositAmount: 100000,
      paidAmount: 300000,
      remainingAmount: 0,
      paymentMethod: 'cash',
      paymentStatus: 'paid',
      depositStatus: DepositStatus.held,
      transactionDate: DateTime(2026, 1, 1),
    );

    final updated = tx.copyWith(
      paidAmount: 350000,
      notes: 'Updated note',
      depositStatus: DepositStatus.refunded,
    );

    expect(updated.paidAmount, 350000);
    expect(updated.notes, 'Updated note');
    expect(updated.depositStatus, DepositStatus.refunded);
    expect(updated.bookingCode, 'BK-10');
  });

  test('BookingRepository submitBookingPayment penalty does not alter downPayment or rental paymentStatus', () async {
    final repository = BookingRepository();
    const penaltyUnit = IphoneModel(
      id: 998,
      name: 'iPhone 14 Test Penalty',
      storage: '128GB',
      color: 'Black',
      serialNumber: 'TESTSERIAL998',
      assetCode: 'AST-TEST-998',
      status: 'tersedia',
      batteryHealth: 100,
    );
    final booking = await repository.createBooking(
      customerName: 'Joko Denda',
      customerPhone: '081299998888',
      customerEmail: 'joko@example.com',
      address: 'Jl. Malioboro No 2',
      iphone: penaltyUnit,
      startDate: DateTime.now().subtract(const Duration(days: 3)),
      endDate: DateTime.now().subtract(const Duration(days: 1)),
      durationDays: 48,
      price: 300000,
      deposit: 100000,
      jaminanType: 'KTP',
      paymentStatus: PaymentStatus.partial,
      amountPaid: 100000,
      paymentMethod: 'Kasir',
    );

    // Pay penalty (Rp 75.000)
    final success = await repository.submitBookingPayment(
      bookingCode: booking.bookingCode,
      amount: 75000,
      pay: 100000,
      paymentMethod: 'tunai',
      type: 'penalty',
    );

    expect(success, isTrue);

    final updatedList = await repository.getBookings();
    final updatedBooking = updatedList.firstWhere((b) => b.bookingCode == booking.bookingCode);
    // downPayment should remain 100000 (not modified by penalty)
    expect(updatedBooking.downPayment, 100000);
    // paymentStatus should still be partial (not marked paid)
    expect(updatedBooking.paymentStatus, PaymentStatus.partial);
  });

  testWidgets('PaymentDepositScreen loads active booking from repository without arguments and avoids crash', (WidgetTester tester) async {
    final repository = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: PaymentDepositScreen(
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify screen loaded dynamically from repository bookings
    expect(find.text('Konfirmasi Pembayaran'), findsOneWidget);
    expect(find.textContaining('Booking SKY'), findsOneWidget);
  });

  testWidgets(
      'PaymentDepositScreen renders responsive 2-column landscape tablet layout matching design',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    AuthService().setCurrentUserForTest(const AdminUserModel(
      id: 2,
      name: 'Budi Santoso',
      email: 'budi@skyrental.id',
      phone: '08123456789',
      role: 'KASIR',
      outletName: 'SKYRental - Gandaria',
      shiftName: 'Shift Pagi • POS-01',
    ));
    addTearDown(() {
      tester.view.reset();
      AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    });

    final repository = BookingRepository();
    final now = DateTime(2026, 9, 9, 10, 0);
    final booking = BookingModel(
      id: 8821,
      bookingCode: 'BK-8821',
      customerName: 'Rian Hidayat',
      customerPhone: '081298765432',
      customerEmail: 'rian@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: now,
      endDate: now.add(const Duration(days: 3)),
      durationDays: 3,
      price: 450000,
      deposit: 0,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.unpaid,
      iphone: const IphoneModel(
        id: 15,
        name: 'iPhone 15 Pro 128GB',
        storage: '128GB',
        color: 'Natural Titanium',
        serialNumber: 'SN-PRO-99',
        assetCode: 'AST-PRO-99',
        status: 'tersedia',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: PaymentDepositScreen(
          repository: repository,
          booking: booking,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Top Navigation Bar
    expect(find.text('SKYRental'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('KASIR'), findsOneWidget);
    expect(find.text('Shift Pagi • POS-01'), findsOneWidget);

    // 2. Verify Sub-Header
    expect(find.text('Konfirmasi Kasir & Settlement'), findsOneWidget);
    expect(find.textContaining('BK-8821'), findsWidgets);
    expect(find.text('MENUNGGU BAYAR'), findsOneWidget);

    // 3. Verify Left Column (Customer & Unit Info, Receipt Preview, Printer Status)
    expect(find.text('Rian Hidayat'), findsWidgets);
    expect(find.text('iPhone 15 Pro 128GB'), findsWidgets);
    expect(find.text('3 JAM SEWA (AKTIF)'), findsOneWidget);
    expect(find.text('WhatsApp Aktif'), findsOneWidget);
    expect(find.text('KYC TERVERIFIKASI'), findsOneWidget);
    expect(find.text('Pratinjau Struk Termal'), findsOneWidget);
    expect(find.text('Format 58mm'), findsOneWidget);
    expect(find.text('Uji Cetak Sample'), findsOneWidget);
    expect(find.text('VSC MP-58C Kasir'), findsOneWidget);
    expect(find.text('Bluetooth Online • Kertas 58mm Siap'), findsOneWidget);
    expect(find.text('Ping Printer'), findsOneWidget);

    // 4. Verify Right Column (Billing Hero, Payment Types, Methods, Inputs)
    expect(find.text('Wajib Bayar'), findsOneWidget);
    expect(find.text('Rp 450.000'), findsWidgets);
    expect(find.text('Menunggu Transaksi'), findsOneWidget);
    expect(find.text('Lunas'), findsOneWidget);
    expect(find.text('DP / Uang Muka'), findsOneWidget);
    expect(find.text('Denda'), findsOneWidget);
    expect(find.text('Extend / Sewa'), findsOneWidget);
    expect(find.text('QRIS'), findsOneWidget);
    expect(find.text('Tunai'), findsOneWidget);
    expect(find.text('VA Bank'), findsOneWidget);
    expect(find.text('EDC Mesin'), findsOneWidget);
    expect(find.text('UANG PAS'), findsOneWidget);
    expect(find.textContaining('Uang Tunai Diterima'), findsOneWidget);
    expect(find.textContaining('KEMBALIAN KASIR'), findsOneWidget);
    expect(
      find.text('Kirim Bukti Pembayaran via WhatsApp'),
      findsOneWidget,
    );
    expect(
      find.text('Cetak Struk Thermal Kasir 2 Rangkap'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('btn_confirm_payment_tablet')), findsOneWidget);
    expect(find.text('Konfirmasi Pembayaran & Cetak Struk'), findsOneWidget);

    // 5. Verify Bottom Navigation Bar
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Unit iPhone'), findsOneWidget);
    expect(find.text('Printer & Shift'), findsOneWidget);

    // 6. Verify column proportions: Right column is smaller than Left column (flex 60 vs flex 40)
    final leftColumnScroll = find.descendant(
      of: find.byType(Row),
      matching: find.byType(SingleChildScrollView),
    ).first;
    final rightColumnScroll = find.descendant(
      of: find.byType(Row),
      matching: find.byType(SingleChildScrollView),
    ).last;
    expect(
      tester.getSize(leftColumnScroll).width,
      greaterThan(tester.getSize(rightColumnScroll).width),
    );

    // 7. Verify zero lag under keyboard opening simulation
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pump();
    expect(find.byKey(const Key('btn_confirm_payment_tablet')), findsOneWidget);
    expect(find.text('Rp 450.000'), findsWidgets);
  });

  testWidgets(
      'MainNavigationScreen renders tablet bottom nav matching payment confirmation screen on tablet viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
    });

    final repository = BookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MainNavigationScreen(repository: repository),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify tablet bottom nav matching payment confirmation screen (4 items)
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Unit iPhone'), findsOneWidget);
    expect(find.text('Printer & Shift'), findsOneWidget);

    // Verify creator name is displayed in transaction queue cards
    expect(find.textContaining('Dibuat oleh:'), findsWidgets);
  });

  testWidgets(
      'DashboardScreen displays creator name on mobile transaction queue cards',
      (WidgetTester tester) async {
    final repository = BookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: DashboardScreen(repository: repository)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify creator row on mobile queue items
    expect(find.textContaining('Dibuat oleh:'), findsWidgets);
  });

  testWidgets(
      'AccountScreen renders responsive tablet Master-Detail layout matching design mockup',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = BookingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        onGenerateRoute: (settings) =>
            AppRoutes.onGenerateRoute(settings, repository),
        home: AccountScreen(repository: repository),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // 1. Verify Top App Bar Badges & Cashier Info consistent with Dashboard
    expect(find.text('SKYRental'), findsWidgets);
    expect(find.text('Shift Pagi • POS-01'), findsWidgets);
    expect(find.text('Outlet Utama Malioboro'), findsWidgets);

    // 2. Verify Page Header and Sync ID are removed
    expect(find.text('TERMINAL KASIR MALIOBORO • KONFIGURASI SISTEM'), findsNothing);
    expect(find.text('Akun & Pengaturan Sistem'), findsNothing);
    expect(find.textContaining('Kelola profil kasir, outlet, perangkat keras'), findsNothing);
    expect(find.textContaining('POS-MLBR-04'), findsNothing);
    expect(find.textContaining('Sync ID'), findsNothing);

    // 3. Verify Profile Card (directly below App Bar)
    expect(find.text('Admin SKYRental'), findsWidgets);
    expect(find.text('SUPER-ADMIN'), findsWidgets);
    expect(find.text('Ganti Akun'), findsOneWidget);

    // 4. Verify Master Sidebar Categories & Menu Items
    expect(find.text('TOKO & OUTLET'), findsOneWidget);
    expect(find.text('Pengaturan Nama Toko & Outlet'), findsOneWidget);
    expect(find.text('Shift Operasional Kasir'), findsOneWidget);
    expect(find.text('MITRA & CABANG AFFILIATE'), findsOneWidget);
    expect(find.text('HARDWARE & RESI'), findsOneWidget);
    expect(find.text('NOTIFIKASI OPERASIONAL'), findsOneWidget);
    expect(find.text('KEAMANAN & AKUN'), findsOneWidget);
    expect(find.text('TAMPILAN & TEMA'), findsOneWidget);
    expect(find.text('TENTANG SISTEM'), findsOneWidget);
    expect(find.text('Keluar dari Akun Kasir'), findsOneWidget);

    // 5. Verify Default Active Detail Pane: Pengaturan Nama Toko & Outlet
    expect(find.text('Identitas Toko & Konfigurasi Outlet'), findsOneWidget);
    expect(find.text('Simpan Pengaturan'), findsOneWidget);
    expect(find.text('PRATINJAU KERTAS THERMAL 58MM (LIVE RECEIPT PREVIEW)'), findsOneWidget);
    expect(find.text('58mm Thermal Print Mode'), findsOneWidget);
    expect(find.text('VALIDASI OUTLET RESMI'), findsOneWidget);
    expect(find.text('IDENTITAS RENTAL'), findsOneWidget);
    expect(find.text('Nama Bisnis / Toko'), findsOneWidget);
    expect(find.text('Nama Cabang / Outlet'), findsOneWidget);
    expect(find.text('TEKS KAKI STRUK (FOOTER STRUK THERMAL)'), findsOneWidget);
    expect(find.text('WIFI OUTLET (FASILITAS PELANGGAN)'), findsOneWidget);
    expect(find.text('Tampil di QR & Struk'), findsOneWidget);

    // 6. Test Switching to another menu: Shift Operasional Kasir
    await tester.tap(find.text('Shift Operasional Kasir'));
    await tester.pumpAndSettle();

    expect(find.text('Shift Operasional Kasir & Laci Kas'), findsOneWidget);
    expect(find.text('STATUS SHIFT KASIR AKTIF'), findsOneWidget);
    expect(find.text('MODAL AWAL & SALDO LACI KASIR'), findsOneWidget);

    // 7. Test Switching to Ubah Kata Sandi
    final ubahKataSandiFinder = find.text('Ubah Kata Sandi');
    await tester.ensureVisible(ubahKataSandiFinder);
    await tester.pumpAndSettle();
    await tester.tap(ubahKataSandiFinder);
    await tester.pumpAndSettle();

    expect(find.text('Keamanan Akun & Ubah Kata Sandi'), findsOneWidget);
    expect(find.text('FORMULIR GANTI KATA SANDI'), findsOneWidget);
    expect(find.text('Simpan Kata Sandi'), findsOneWidget);

    // 8. Test Switching to Mitra Cabang & Affiliate (embedded directly, button removed)
    final mitraMenuFinder = find.text('Mitra Cabang & Affiliate');
    await tester.ensureVisible(mitraMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(mitraMenuFinder);
    await tester.pumpAndSettle();

    // Verify "Buka Manajemen Mitra" button is removed
    expect(find.text('Buka Manajemen Mitra'), findsNothing);

    // Verify affiliate management content is embedded directly
    expect(find.text('RINGKASAN JARINGAN CABANG MITRA'), findsOneWidget);
    expect(find.text('Tambah Mitra'), findsOneWidget);

    // Test Switching to Mutasi & Transfer Unit iPhone (embedded directly, button removed)
    final transferMenuFinder = find.text('Mutasi & Transfer Unit iPhone');
    await tester.ensureVisible(transferMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(transferMenuFinder);
    await tester.pumpAndSettle();

    // Verify "Buka Mutasi Unit" button is removed
    expect(find.text('Buka Mutasi Unit'), findsNothing);

    // Verify transfer management content is embedded directly
    expect(find.text('STATISTIK TRANSFER TERBARU'), findsOneWidget);
    expect(find.text('Kirim Unit iPhone'), findsOneWidget);

    // Test Switching to Pengaturan Thermal Printer (embedded directly, button removed)
    final printerMenuFinder = find.text('Pengaturan Thermal Printer');
    await tester.ensureVisible(printerMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(printerMenuFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify "Kelola Printer" button is removed
    expect(find.text('Kelola Printer'), findsNothing);

    // Verify printer settings content is embedded directly
    expect(find.text('Pengaturan & Uji Thermal Printer POS'), findsOneWidget);
    expect(find.text('Daftar Printer Bluetooth'), findsOneWidget);
    expect(find.text('Uji Cetak Sekarang'), findsOneWidget);

    // Test Switching to Format & Tampilan Resi (embedded directly, button removed)
    final receiptFormatMenuFinder = find.text('Format & Tampilan Resi');
    await tester.ensureVisible(receiptFormatMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(receiptFormatMenuFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify "Atur Format Lengkap" button is removed
    expect(find.text('Atur Format Lengkap'), findsNothing);
    expect(find.text('Format & Kustomisasi Resi 58mm'), findsOneWidget);
    expect(find.text('Simpan Format'), findsOneWidget);
    expect(find.text('Header Toko & Tipografi'), findsOneWidget);

    // Test Switching to Riwayat Cetak & Cetak Ulang (embedded directly, button removed)
    final reprintMenuFinder = find.text('Riwayat Cetak & Cetak Ulang');
    await tester.ensureVisible(reprintMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(reprintMenuFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify "Buka Riwayat Resi" button is removed
    expect(find.text('Buka Riwayat Resi'), findsNothing);
    expect(find.text('Riwayat Cetak & Cetak Ulang Struk'), findsOneWidget);

    // Test Switching to Pusat Notifikasi Operasional (embedded directly, button removed)
    final notificationsMenuFinder = find.text('Pusat Notifikasi Operasional');
    await tester.ensureVisible(notificationsMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(notificationsMenuFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify "Buka Notifikasi" button is removed
    expect(find.text('Buka Notifikasi'), findsNothing);
    expect(find.text('Pusat Notifikasi Operasional'), findsWidgets);

    // Test Switching to Tema & Warna Aplikasi (embedded directly, button removed)
    final themeMenuFinder = find.text('Tema & Warna Aplikasi');
    await tester.ensureVisible(themeMenuFinder);
    await tester.pumpAndSettle();
    await tester.tap(themeMenuFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify "Buka Pengaturan Tema" button is removed
    expect(find.text('Buka Pengaturan Tema'), findsNothing);
    expect(find.text('MODE TAMPILAN'), findsOneWidget);
    expect(find.text('PILIHAN TEMA PRESET'), findsOneWidget);
    expect(find.text('KUSTOMISASI WARNA MANDIRI'), findsOneWidget);
    expect(find.text('Reset Standar'), findsOneWidget);

    // 9. Test Sticky Sidebar Menu when detail is scrolled
    // Switch back to shopSettings
    final shopSettingsFinder = find.text('Pengaturan Nama Toko & Outlet');
    await tester.ensureVisible(shopSettingsFinder);
    await tester.pumpAndSettle();
    await tester.tap(shopSettingsFinder);
    await tester.pumpAndSettle();

    // Scroll down 400px on the right detail pane
    await tester.drag(
      find.text('PRATINJAU KERTAS THERMAL 58MM (LIVE RECEIPT PREVIEW)'),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    // Verify Sticky Menu sidebar remains fixed in viewport (under AppBar dy >= 62)
    final sidebarItemBox = tester.renderObject<RenderBox>(
        find.text('Pengaturan Nama Toko & Outlet'));
    final sidebarItemGlobalPos = sidebarItemBox.localToGlobal(Offset.zero);
    expect(sidebarItemGlobalPos.dy >= 62, isTrue);
    expect(sidebarItemGlobalPos.dy < 800, isTrue);

    // Verify user can scroll the menu sidebar directly all the way down to bottom
    final logoutFinder = find.text('Keluar dari Akun Kasir');
    await tester.ensureVisible(logoutFinder);
    await tester.pumpAndSettle();

    // Verify bottom items (Keluar dari Akun Kasir) are visible on screen
    expect(logoutFinder, findsOneWidget);
    final logoutBox = tester.renderObject<RenderBox>(logoutFinder);
    final logoutPos = logoutBox.localToGlobal(Offset.zero);
    expect(logoutPos.dy < 800, isTrue);
    expect(logoutPos.dy >= 62, isTrue);

    // Verify user can tap a menu item
    await tester.tap(find.text('Tentang SKYRental POS'));
    await tester.pumpAndSettle();
    expect(find.text('Tentang SKYRental POS'), findsWidgets);
  });

  testWidgets('SalesReportScreen renders responsive tablet 2-column layout matching design mockup', (WidgetTester tester) async {
    final repository = BookingRepository();
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());

    // Configure tablet landscape viewport (1200 x 800)
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: SalesReportScreen(repository: repository),
      ),
    );

    // Allow repository Future to load
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    // 1. Verify Top Header
    expect(find.text('SKYRental'), findsWidgets);
    expect(find.text('POS Station #01'), findsOneWidget);
    expect(find.textContaining('Budi Santoso'), findsWidgets);

    // 2. Verify Sub-header & Filter section
    expect(find.text('Laporan Penjualan & Kasir'), findsOneWidget);
    expect(find.text('Hari Ini'), findsOneWidget);
    expect(find.text('Minggu Ini'), findsOneWidget);
    expect(find.text('Bulan Ini'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Unduh Rekap'), findsOneWidget);

    // 3. Verify Left Column: Hero Omzet Card
    expect(find.text('Kas Masuk'), findsOneWidget);
    expect(find.text('Rp 2.450.000'), findsWidgets);
    expect(find.text('Total Transaksi'), findsOneWidget);
    expect(find.text('Deposit Kasir'), findsOneWidget);

    // 4. Verify Left Column: Proporsi Metode Pembayaran
    expect(find.text('Proporsi Metode Pembayaran'), findsOneWidget);
    expect(find.text('TRANSAKSI'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Transfer Bank'), findsWidgets);
    expect(find.text('QRIS Dinamis'), findsWidgets);
    expect(find.text('Kas Fisik Tunai'), findsWidgets);

    // 5. Verify Left Column: Jenis Pembayaran 2x2 Grid
    expect(find.text('Jenis Pembayaran'), findsOneWidget);
    expect(find.text('DP (UANG MUKA)'), findsOneWidget);
    expect(find.text('PELUNASAN'), findsOneWidget);
    expect(find.text('EXTEND SEWA'), findsOneWidget);
    expect(find.text('PENALTY / DENDA'), findsOneWidget);

    // 6. Verify Right Column: 4 Stat Cards Row
    expect(find.text('Kas Tunai'), findsOneWidget);
    expect(find.text('Total Masuk'), findsOneWidget);

    // 7. Verify Right Column: Top Models
    expect(find.text('Model iPhone Paling Populer & Omzet'), findsOneWidget);
    expect(find.text('Top Performa Hari Ini'), findsOneWidget);
    expect(find.textContaining('iPhone 15 Pro 256GB'), findsWidgets);

    // 8. Verify Right Column: Riwayat Transaksi Table
    expect(find.text('Riwayat Transaksi Penjualan'), findsOneWidget);
    expect(find.text('NO. RESI / JAM'), findsOneWidget);
    expect(find.text('CUSTOMER'), findsOneWidget);
    expect(find.text('UNIT & TIPE'), findsOneWidget);
    expect(find.text('METODE'), findsOneWidget);
    expect(find.text('NOMINAL'), findsOneWidget);
    expect(find.text('STRUK'), findsOneWidget);

    // Verify sample transactions rendered
    expect(find.text('#SKY-8421'), findsOneWidget);
    expect(find.text('Dimas Pratama'), findsOneWidget);
    expect(find.text('Siti Rahmawati'), findsOneWidget);

    // 9. Verify Simulasi Kosong toggle
    final simulasiBtn = find.text('Simulasi Kosong');
    expect(simulasiBtn, findsOneWidget);
    await tester.ensureVisible(simulasiBtn);
    await tester.pumpAndSettle();
    await tester.tap(simulasiBtn);
    await tester.pumpAndSettle();

    // Verify empty state is displayed
    expect(find.text('Tidak ada transaksi penjualan pada filter ini'), findsOneWidget);
    final restoreBtn = find.text('Tampilkan Data');
    expect(restoreBtn, findsOneWidget);

    // Tap back to restore data
    await tester.ensureVisible(restoreBtn);
    await tester.pumpAndSettle();
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();
    expect(find.text('#SKY-8421'), findsOneWidget);

    // 10. Verify Full-width Bottom Action Button
    final cetakRekapBtn = find.text('Cetak Rekap Kasir (58mm)');
    expect(cetakRekapBtn, findsOneWidget);
    await tester.ensureVisible(cetakRekapBtn);
    await tester.pumpAndSettle();
    await tester.tap(cetakRekapBtn);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Tutup Kasir 58mm'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'UnitStatusListScreen renders responsive tablet landscape layout matching design mockup',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AuthService().setCurrentUserForTest(
      AdminUserModel.defaultAdmin().copyWith(
        name: 'Budi Santoso',
        role: 'Kasir',
      ),
    );

    final repository = BookingRepository();
    repository.resetInventory();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: UnitStatusListScreen(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header Elements
    expect(find.text('SKYRental'), findsWidgets);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Kasir • Shift Pagi'), findsOneWidget);

    // 2. Verify Sub-header Bar
    expect(find.text('Status Unit & Inventaris iPhone'), findsOneWidget);
    expect(find.text('+ Tambah iPhone Baru'), findsOneWidget);

    // 3. Verify 4 Summary KPI Cards
    expect(find.text('TOTAL UNIT'), findsOneWidget);
    expect(find.text('24'), findsWidgets);
    expect(find.text('Terdaftar di Gerai Gandaria'), findsOneWidget);

    expect(find.text('TERSEDIA'), findsOneWidget);
    expect(find.text('18'), findsWidgets);
    expect(find.text('Siap Sewa / Ready Stock'), findsOneWidget);

    expect(find.text('DISEWA'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('Sedang Digunakan Customer'), findsOneWidget);

    expect(find.text('PERAWATAN'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Inspeksi & Maintenance'), findsOneWidget);

    // 4. Verify Affiliate Chips
    expect(find.text('AFFILIATE:'), findsOneWidget);
    expect(find.text('Semua Cabang'), findsOneWidget);
    expect(find.text('Genteng'), findsWidgets);
    expect(find.text('Siliragung'), findsWidgets);
    expect(find.text('Purwoharjo'), findsWidgets);

    // 5. Verify Unit Cards rendered on screen
    expect(find.text('IPHSKY1048'), findsOneWidget);
    expect(find.text('IPHSKY1032'), findsOneWidget);
    expect(find.text('IPHSKY1002'), findsOneWidget);
    expect(find.text('IPHSKY1015'), findsOneWidget);
    expect(find.text('IPHSKY1009'), findsOneWidget);
    expect(find.text('IPHSKY1020'), findsOneWidget);

    // 6. Verify Action Buttons for respective states
    expect(find.text('Booking Kasir'), findsWidgets);
    expect(find.text('Pengembalian'), findsWidgets);
    expect(find.text('Selesai Servis'), findsWidgets);

    // 7. Verify Context Box Content
    expect(find.text('Customer: Dimas Pratama'), findsOneWidget);
    expect(find.text('Customer: Siti Rahmawati'), findsOneWidget);
    expect(find.text('Inspeksi Servis:'), findsOneWidget);
  });

  testWidgets('CreateIphoneDialog renders fields matching Livewire Create.php and adds unit', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repository = BookingRepository();
    IphoneModel? createdUnit;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => CreateIphoneDialog(
                    repository: repository,
                    onCreated: (unit) {
                      createdUnit = unit;
                    },
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Tambah iPhone Baru'), findsOneWidget);
    expect(find.text('Sistem Katalog & Sinkronisasi Web SKYRental'), findsOneWidget);

    // Verify Model Name Input and Placeholder
    expect(find.text('MODEL UNIT IPHONE *'), findsOneWidget);

    // Verify Deskripsi Section
    expect(find.text('DESKRIPSI & CATATAN UNIT'), findsOneWidget);

    // Verify Physical Specs
    expect(find.text('SPESIFIKASI FISIK & OPERASIONAL'), findsOneWidget);
    expect(find.text('128GB'), findsOneWidget);
    expect(find.text('256GB'), findsOneWidget);
    expect(find.text('512GB'), findsOneWidget);
    expect(find.text('1TB'), findsOneWidget);

    // Verify Setelan Series & Registrasi (matching Livewire/Iphones/Create.php)
    expect(find.text('Setelan Series & Registrasi'), findsOneWidget);
    expect(find.text('Poster / Foto Unit'), findsOneWidget);
    expect(find.text('Tanggal Registrasi'), findsOneWidget);
    expect(find.text('Permalink (Slug)'), findsOneWidget);
    expect(find.text('Serial & Asset Code *'), findsOneWidget);
    expect(find.text('Paket Durasi & Tarif'), findsOneWidget);

    // Verify Dynamic Duration Repeater components
    expect(find.text('Tambah Baris'), findsOneWidget);
    expect(find.text('24'), findsWidgets);
    expect(find.text('100000'), findsWidgets);

    // Test entering model name and check auto-slug update
    final nameField = find.widgetWithText(TextFormField, 'iPhone 16 pro MAX');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'iPhone 16 Pro Max');
    await tester.pump();

    expect(find.text('iphone-16-pro-max'), findsWidgets);

    // Test adding a duration row
    await tester.tap(find.text('Tambah Baris'));
    await tester.pump();

    // Now there should be multiple duration rows
    expect(find.text('Jam'), findsWidgets);

    // Submit form
    final saveButton = find.text('Simpan Unit iPhone');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify unit was saved into repository
    expect(createdUnit, isNotNull);
    expect(createdUnit!.name, 'iPhone 16 Pro Max');
    expect(createdUnit!.slug, 'iphone-16-pro-max');
    expect(createdUnit!.durations.isNotEmpty, isTrue);
  });

  testWidgets('CreateIphoneDialog handles dynamic affiliate options safely without assertion error', (WidgetTester tester) async {
    final repository = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateIphoneDialog(
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CreateIphoneDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}


