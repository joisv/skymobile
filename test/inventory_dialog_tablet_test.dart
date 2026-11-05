import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/unit_status/widgets/create_iphone_dialog.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().setCurrentUserForTest(
      AdminUserModel.defaultAdmin().copyWith(role: 'admin'),
    );
  });

  testWidgets('Tablet Modal Container Architecture: Centered Dialog with 680px maxWidth and 16px radius', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repository = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => CreateIphoneDialog(repository: repository),
                  );
                },
                child: const Text('Buka Modal Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open Dialog
    await tester.tap(find.text('Buka Modal Dialog'));
    await tester.pumpAndSettle();

    // Verify Centered Dialog
    expect(find.byType(Dialog), findsOneWidget);

    // Sizing & Constraints check
    final formFinder = find.byType(Form);
    expect(formFinder, findsOneWidget);
    final RenderBox formBox = tester.renderObject(formFinder);
    expect(formBox.size.width, lessThanOrEqualTo(680.0));

    // Verify Clean Header
    expect(find.text('Tambah Unit Baru'), findsOneWidget);
    expect(find.text('Sistem Katalog & Sinkronisasi Web SKYRental'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Test close button dismisses dialog
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Single Unified Form with Minimal Toggle Switch: Adapts labels, asset codes, and buttons dynamically', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repository = BookingRepository();
    IphoneModel? createdItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => CreateIphoneDialog(
                      repository: repository,
                      onCreated: (item) => createdItem = item,
                    ),
                  );
                },
                child: const Text('Buka Modal Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Modal Dialog'));
    await tester.pumpAndSettle();

    // Dual tab bar is eliminated
    expect(find.text('iPhone (Utama)'), findsNothing);
    expect(find.text('Aksesoris / Add-on'), findsNothing);

    // Minimal toggle switch is present
    expect(find.text('Item ini merupakan Aksesoris / Add-on'), findsOneWidget);
    expect(find.text('Aktifkan jika perangkat berupa tripod, lensa, atau kelengkapan tambahan'), findsOneWidget);

    // Default OFF: iPhone state
    expect(find.text('Tambah Unit Baru'), findsOneWidget);
    expect(find.text('MODEL UNIT IPHONE *'), findsOneWidget);
    expect(find.text('Simpan Unit iPhone'), findsOneWidget);

    final assetCodeField = find.byKey(const Key('create_iphone_asset_code_field'));
    expect(assetCodeField, findsOneWidget);
    final initialAssetCode = (tester.widget(assetCodeField) as TextFormField).controller?.text ?? '';
    expect(initialAssetCode.startsWith('IPHSKY'), isTrue);

    // Toggle ON -> Switch to Add-on mode
    final toggle = find.byKey(const Key('create_iphone_addon_toggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // Verify dynamic adaptation for Add-on
    expect(find.text('Tambah Add-on Baru'), findsOneWidget);
    expect(find.text('NAMA AKSESORIS / ADD-ON *'), findsOneWidget);
    expect(find.text('Simpan Add-on'), findsOneWidget);

    final addonAssetCode = (tester.widget(assetCodeField) as TextFormField).controller?.text ?? '';
    expect(addonAssetCode.startsWith('ADDON'), isTrue);

    // Fill form and save Add-on
    final nameField = find.byKey(const Key('create_iphone_name_field'));
    await tester.enterText(nameField, 'DJI Osmo Mobile 6');
    await tester.pump();

    final saveButton = find.byKey(const Key('create_iphone_submit_btn'));
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(createdItem, isNotNull);
    expect(createdItem!.name, 'DJI Osmo Mobile 6');
    expect(createdItem!.isAddon, isTrue);
    expect(createdItem!.assetCode.startsWith('ADDON'), isTrue);
  });

  testWidgets('Visual De-pollution & Automated Slug: Slug updates automatically and manual field collapses', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repository = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateIphoneDialog(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Manual slug text field is collapsed by default to save prime vertical space
    expect(find.byKey(const Key('create_iphone_slug_field')), findsNothing);
    expect(find.text('Kustomisasi Permalink Web (Slug)'), findsOneWidget);

    // Typing model name automatically updates slug preview
    final nameField = find.byKey(const Key('create_iphone_name_field'));
    await tester.enterText(nameField, 'iPhone 16 Pro Max 256GB');
    await tester.pump();

    expect(find.text('/iphone-16-pro-max-256gb'), findsOneWidget);

    // Expand accordion to reveal manual editor
    await tester.ensureVisible(find.byKey(const Key('toggle_slug_accordion')));
    await tester.tap(find.byKey(const Key('toggle_slug_accordion')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create_iphone_slug_field')), findsOneWidget);
    expect(find.text('Sembunyikan Permalink Web'), findsOneWidget);
    expect(find.text('Reset Auto'), findsOneWidget);

    // Manual edit
    await tester.enterText(find.byKey(const Key('create_iphone_slug_field')), 'custom-unit-slug');
    await tester.pump();

    // Tap Reset Auto
    await tester.tap(find.text('Reset Auto'));
    await tester.pump();

    final slugControllerText = (tester.widget(find.byKey(const Key('create_iphone_slug_field'))) as TextFormField).controller?.text;
    expect(slugControllerText, 'iphone-16-pro-max-256gb');
  });

  testWidgets('Optimized Duration & Rate Management: Horizontal rows, thousand separator, and row add/delete', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repository = BookingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CreateIphoneDialog(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Section title
    expect(find.text('Paket Durasi & Tarif *'), findsOneWidget);

    // Crowded old shortcut chips are removed
    expect(find.text('+ 12 Jam...'), findsNothing);
    expect(find.text('+ 24 Jam...'), findsNothing);

    // Single row present initially with 24 hours and 100.000
    expect(find.byKey(const Key('create_iphone_duration_hours_0')), findsOneWidget);
    expect(find.byKey(const Key('create_iphone_duration_price_0')), findsOneWidget);
    expect(find.text('100.000'), findsWidgets);

    // Trash delete button is HIDDEN when only 1 row exists
    expect(find.byKey(const Key('create_iphone_duration_delete_0')), findsNothing);

    // Add a second row
    await tester.ensureVisible(find.byKey(const Key('create_iphone_add_duration_btn')));
    await tester.tap(find.byKey(const Key('create_iphone_add_duration_btn')));
    await tester.pumpAndSettle();

    // Now 2 rows exist, trash icons should be visible on both
    expect(find.byKey(const Key('create_iphone_duration_hours_1')), findsOneWidget);
    expect(find.byKey(const Key('create_iphone_duration_price_1')), findsOneWidget);
    expect(find.byKey(const Key('create_iphone_duration_delete_0')), findsOneWidget);
    expect(find.byKey(const Key('create_iphone_duration_delete_1')), findsOneWidget);

    // Enter a new custom rate with formatting test
    final priceField1 = find.byKey(const Key('create_iphone_duration_price_1'));
    await tester.enterText(priceField1, '1500000');
    await tester.pump();
    expect(find.text('1.500.000'), findsOneWidget);

    // Delete the second row
    await tester.tap(find.byKey(const Key('create_iphone_duration_delete_1')));
    await tester.pumpAndSettle();

    // Row 1 deleted, back to 1 row, delete button hidden again
    expect(find.byKey(const Key('create_iphone_duration_hours_1')), findsNothing);
    expect(find.byKey(const Key('create_iphone_duration_delete_0')), findsNothing);
  });

  testWidgets('Dialog Actions & Ergonomics: Fixed footer with Batal and 48px high action button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repository = BookingRepository();
    bool dialogClosed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (ctx) => CreateIphoneDialog(repository: repository),
                  );
                  dialogClosed = true;
                },
                child: const Text('Buka Modal'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Modal'));
    await tester.pumpAndSettle();

    // Fixed footer buttons
    expect(find.text('Batal'), findsOneWidget);
    final submitBtn = find.byKey(const Key('create_iphone_submit_btn'));
    expect(submitBtn, findsOneWidget);

    // Verify 48px height requirement
    final RenderBox submitBox = tester.renderObject(submitBtn);
    expect(submitBox.size.height, greaterThanOrEqualTo(48.0));

    // Tap Batal closes dialog cleanly
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(dialogClosed, isTrue);
    expect(find.byType(Dialog), findsNothing);
  });
}
