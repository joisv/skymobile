import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/screens/cashier/cashier_shift_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mobile Viewport Shift Dashboard & Tutup Shift Modal Tests', () {
    late BookingRepository repo;
    late CashDrawerShiftModel activeShift;

    setUp(() {
      AuthService().setCurrentUserForTest(
        const AdminUserModel(
          id: 1,
          name: 'Budi Santoso',
          email: 'kasir@skyrental.id',
          phone: '081234567890',
          role: 'Staff Kasir',
          outletName: 'Genteng Pusat',
          shiftName: 'Shift Pagi (08:00 - 16:00)',
          affiliateId: 4,
          roles: ['staff'],
        ),
      );

      MockBookingData.resetShifts();
      repo = BookingRepository();

      activeShift = CashDrawerShiftModel(
        id: 10,
        shiftNumber: 'SHF-GTG-261103-0001',
        branchId: 4,
        branchName: 'Genteng Pusat',
        openedByName: 'Budi Santoso',
        openedAt: DateTime(2026, 11, 3, 8, 0),
        closedAt: null,
        openingCashFloat: 200000.0,
        currentCashInflow: 100000.0,
        currentCashRefund: 0.0,
        currentCashExpenses: 0.0,
        expectedCashNow: 300000.0,
        status: ShiftStatus.open,
      );

      repo.setTestShift(activeShift);
    });

    testWidgets('Mobile Viewport (390x844): Active shift header does not overflow and renders 2-tier button layout', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Verify Active Shift Header components exist without overflow
      expect(find.text('SHF-GTG-261103-0001'), findsOneWidget);
      expect(find.text('SHIFT AKTIF'), findsOneWidget);

      // Verify no RenderFlex overflow occurred in header
      expect(tester.takeException(), isNull);

      // 2. Verify 2-tier Action Buttons layout on Mobile
      final closeShiftBtn = find.byKey(const Key('btn_close_shift'));
      expect(closeShiftBtn, findsOneWidget);
      final elevatedBtn = tester.widget<ElevatedButton>(closeShiftBtn);
      final bg = elevatedBtn.style?.backgroundColor?.resolve({});
      expect(bg, equals(const Color(0xFF0F172A)));

      // Primary top button has full text 'Tutup Shift Kasir'
      expect(find.text('Tutup Shift Kasir'), findsOneWidget);

      // Secondary row has 'Cetak Ringkasan' and '+ Catat Kas'
      expect(find.text('Cetak Ringkasan'), findsOneWidget);
      final recordExpenseBtn = find.byKey(const Key('btn_record_expense'));
      expect(recordExpenseBtn, findsOneWidget);
      expect(find.text('+ Catat Kas'), findsOneWidget);
    });

    testWidgets('Mobile Viewport (390x844): Tutup Shift Bottom Sheet has sticky footer, neutral alert, and clean denomination rows', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Tutup Shift Kasir
      await tester.tap(find.byKey(const Key('btn_close_shift')));
      await tester.pumpAndSettle();

      final bottomSheet = find.byType(BottomSheet);
      expect(bottomSheet, findsOneWidget);

      // Verify modal header
      expect(find.descendant(of: bottomSheet, matching: find.text('Tutup Shift Kasir (Close Shift)')), findsOneWidget);

      // Verify denomination inputs exist without stepper buttons
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      expect(find.descendant(of: bottomSheet, matching: find.text('Rp 100.000')), findsOneWidget);
      expect(find.descendant(of: bottomSheet, matching: find.text('Rp 50.000')), findsOneWidget);

      // Verify Non-Intrusive Discrepancy Alert:
      // Initially 0 cash count -> shows neutral "Belum Dihitung", reason field NOT shown
      expect(find.text('Belum Dihitung'), findsOneWidget);
      expect(find.textContaining('Alasan Selisih Kas'), findsNothing);

      // Sticky Action Footer: Summary Card and Primary Confirm Button are visible
      expect(find.text('Total Kas Dihitung'), findsOneWidget);
      final confirmBtn = find.byKey(const Key('btn_confirm_close_shift'));
      expect(confirmBtn, findsOneWidget);

      // Enter physical cash 200,000 (discrepancy: 200k - 300k = -100k shortage)
      final actualCashField = find.descendant(of: bottomSheet, matching: find.widgetWithText(TextField, '0')).first;
      await tester.enterText(actualCashField, '200000');
      await tester.pumpAndSettle();

      // Now discrepancy alert updates to Shortage and reason field appears
      expect(find.text('Shortage (Selisih Kurang)'), findsOneWidget);
      expect(find.textContaining('Alasan Selisih Kas'), findsOneWidget);

      // Attempt to close shift without reason -> shows snackbar
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(find.text('Alasan selisih kas fisik wajib diisi sebelum shift dapat ditutup.'), findsOneWidget);

      // Fill in reason
      final reasonField = find.descendant(
        of: bottomSheet,
        matching: find.widgetWithText(TextField, 'Contoh: Selisih uang kembalian receh parkir / pembulatan'),
      );
      await tester.enterText(reasonField, 'Uang kembalian receh');
      await tester.pumpAndSettle();

      // Confirm close shift
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Bottom sheet is closed
      expect(find.text('Tutup Shift Kasir (Close Shift)'), findsNothing);
    });

    testWidgets('Mobile Viewport (390x844): Denomination row inputs calculate subtotal in monospace and auto-update actual cash', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // Open Close Shift modal
      await tester.tap(find.byKey(const Key('btn_close_shift')));
      await tester.pumpAndSettle();

      final bottomSheet = find.byType(BottomSheet);

      // Find the TextFormField for Rp 100.000 denomination
      // Since actualCashField is the first TextField with '0', the denomination TextFormFields follow
      final zeroFields = find.descendant(of: bottomSheet, matching: find.widgetWithText(TextField, '0'));
      expect(zeroFields, findsWidgets);

      // Enter 3 into Rp 100.000 denomination field (second TextField with '0')
      final c100kField = zeroFields.at(1);
      await tester.enterText(c100kField, '3');
      await tester.pumpAndSettle();

      // Verify subtotal on the right for 3 x 100k = Rp 300.000
      expect(find.descendant(of: bottomSheet, matching: find.text('Total: Rp 300.000')), findsOneWidget);

      // Status should become 'Kas Seimbang' since 300k equals expectedCashNow (300k)
      expect(find.text('Kas Seimbang'), findsOneWidget);
      expect(find.textContaining('Alasan Selisih Kas'), findsNothing);

      // Confirm close shift succeeds without reason because discrepancy is 0
      final confirmBtn = find.byKey(const Key('btn_confirm_close_shift'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text('Tutup Shift Kasir (Close Shift)'), findsNothing);
    });
  });
}
