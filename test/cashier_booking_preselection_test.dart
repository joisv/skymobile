import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingRepository repository;
  late IphoneModel testUnit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    repository = BookingRepository();
    repository.resetInventory();

    testUnit = const IphoneModel(
      id: 9999,
      name: 'iPhone 15 Pro Max',
      storage: '256GB',
      color: 'Natural Titanium',
      serialNumber: 'SN-CASHIER-PRESELECT-01',
      assetCode: 'IPH-PRESELECT-01',
      status: 'tersedia',
      isAvailable: true,
      batteryHealth: 100,
      durations: [
        IphoneDurationOption(id: 1, name: '24 Jam', hours: 24, price: 250000),
        IphoneDurationOption(id: 2, name: '12 Jam', hours: 12, price: 150000),
      ],
    );
  });

  tearDown(() {
    AuthService().setCurrentUserForTest(null);
  });

  testWidgets('CreateBookingScreen accepts initialIphone and preselects it', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: CreateBookingScreen(
          repository: repository,
          initialIphone: testUnit,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: Fill guest info
    await tester.enterText(find.byType(TextFormField).at(0), 'Ahmad Kasir');
    await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
    await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Kaliurang KM 5');
    await tester.pumpAndSettle();

    // Proceed to Step 2
    await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
    await tester.pumpAndSettle();

    // In step 2, unit selection should show the preselected unit with 'Terpilih' badge
    expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);
    expect(find.text('Terpilih'), findsAtLeastNWidgets(1));
    expect(find.textContaining('iPhone 15 Pro Max'), findsAtLeastNWidgets(1));
  });

  testWidgets('AppRoutes.onGenerateRoute correctly parses selectedIphone argument', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.createBooking,
                  arguments: {'selectedIphone': testUnit},
                );
              },
              child: const Text('Go to Booking'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap button to navigate
    await tester.tap(find.text('Go to Booking'));
    await tester.pumpAndSettle();

    // Advance to Step 2
    await tester.enterText(find.byType(TextFormField).at(0), 'Budi Santoso');
    await tester.enterText(find.byType(TextFormField).at(1), '081399998888');
    await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Gejayan No. 45');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn_next_to_step_2')));
    await tester.pumpAndSettle();

    // The preselected iPhone should be present and selected
    expect(find.text('2. Unit iPhone & Durasi'), findsOneWidget);
    expect(find.text('Terpilih'), findsAtLeastNWidgets(1));
    expect(find.textContaining('iPhone 15 Pro Max'), findsAtLeastNWidgets(1));
  });
}
