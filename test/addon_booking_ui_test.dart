import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/booking/create_booking_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingRepository repository;

  final testIphone = const IphoneModel(
    id: 101,
    name: 'iPhone 15 Pro',
    storage: '128GB',
    color: 'Natural Titanium',
    serialNumber: 'F2LNK98XK0G',
    assetCode: 'AST-IP15P-001',
    status: 'tersedia',
    durations: [
      IphoneDurationOption(id: 1, name: '24 Jam', hours: 24, price: 150000.0),
    ],
  );

  final testGimbal = const IphoneModel(
    id: 501,
    name: 'DJI Osmo Mobile 6 Gimbal',
    storage: '',
    color: 'Slate Gray',
    serialNumber: 'OSMO6-9812',
    assetCode: 'AST-ADD-001',
    status: 'tersedia',
    isAddon: true,
    durations: [
      IphoneDurationOption(id: 5011, name: '24 Jam', hours: 24, price: 45000.0),
    ],
  );

  setUp(() {
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
    repository = BookingRepository();
    repository.setTestInventory([testIphone, testGimbal]);
  });

  Widget createTestWidget() {
    return MaterialApp(
      routes: {
        '/payment-deposit': (context) => const Scaffold(body: Text('Payment Screen')),
      },
      home: CreateBookingScreen(
        repository: repository,
        initialIphone: testIphone,
      ),
    );
  }

  testWidgets('CreateBookingScreen Step 2 renders Add-on selection card and updates totals dynamically', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Fill Step 1 Form
    await tester.enterText(find.byType(TextFormField).at(0), 'Budi Santoso');
    await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
    await tester.enterText(find.byType(TextFormField).at(3), 'Jl. Gatot Subroto No. 5');
    await tester.pumpAndSettle();

    // Advance to Step 2
    final nextBtn = find.byKey(const Key('btn_next_to_step_2'));
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // Verify Add-on Section is rendered
    expect(find.text('Item Tambahan / Add-on (Opsional)'), findsWidgets);
    expect(find.text('DJI Osmo Mobile 6 Gimbal'), findsWidgets);
    expect(find.text('+ Rp 45.000'), findsWidgets);

    // Toggle add-on
    final addonTile = find.byKey(const Key('addon_tile_501'));
    expect(addonTile, findsOneWidget);
    await tester.ensureVisible(addonTile);
    await tester.pumpAndSettle();
    await tester.tap(addonTile);
    await tester.pumpAndSettle();

    // Badge indicates 1 selected
    expect(find.text('1 dipilih'), findsOneWidget);

    // Live preview shows total: Rp 150.000 + Rp 45.000 = Rp 195.000
    expect(find.text('Rp 195.000'), findsWidgets);

    // Advance to Step 3
    final step3Btn = find.byKey(const Key('btn_next_to_step_3'));
    expect(step3Btn, findsOneWidget);
    await tester.tap(step3Btn);
    await tester.pumpAndSettle();

    // In Step 3 Review, verify itemized summary
    expect(find.text('Add-on: DJI Osmo Mobile 6 Gimbal'), findsWidgets);
    expect(find.text('Subtotal Add-on'), findsWidgets);
    expect(find.text('+ Rp 45.000'), findsWidgets);
    expect(find.text('Rp 195.000'), findsWidgets);
  });
}
