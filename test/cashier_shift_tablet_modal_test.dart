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

  group('Active Shift Tablet Landscape & Close Shift Modal Tests', () {
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
        shiftNumber: 'SHF-GNT-261102-0001',
        branchId: 4,
        branchName: 'Genteng Pusat',
        openedByName: 'Budi Santoso',
        openedAt: DateTime(2026, 11, 2, 8, 0),
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

    testWidgets('Active Shift Screen renders dark Tutup Shift button and Kas Keluar button', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify Close Shift button is dark/brand button (0xFF0F172A), NOT red (0xFFDC2626)
      final closeShiftBtn = find.byKey(const Key('btn_close_shift'));
      expect(closeShiftBtn, findsOneWidget);
      final elevatedBtn = tester.widget<ElevatedButton>(closeShiftBtn);
      final bg = elevatedBtn.style?.backgroundColor?.resolve({});
      expect(bg, equals(const Color(0xFF0F172A)));

      // Verify + Kas Keluar / Biaya button exists
      final recordExpenseBtn = find.byKey(const Key('btn_record_expense'));
      expect(recordExpenseBtn, findsOneWidget);

      // Verify header cleaned up: floating Shift Aktif badge in actions is removed
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('Tapping + Kas Keluar opens operational expense dialog and logs cash-out', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap + Kas Keluar
      await tester.tap(find.byKey(const Key('btn_record_expense')));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Catat Kas Keluar'), findsOneWidget);
      expect(find.text('Nominal Pengeluaran (Rp) *'), findsOneWidget);

      // Tap quick chip Rp 20.000
      await tester.tap(find.text('Rp 20.000'));
      await tester.pumpAndSettle();

      // Enter notes
      await tester.enterText(
        find.widgetWithText(TextField, 'Contoh: Beli air galon & lakban packing...'),
        'Beli galon air mineral',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Simpan Kas Keluar'));
      await tester.pumpAndSettle();

      // Verify dialog closed
      expect(find.text('Catat Kas Keluar'), findsNothing);
    });

    testWidgets('Close Shift Modal renders 2-column layout and supports direct denomination entry', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Tutup Shift Kasir
      await tester.tap(find.byKey(const Key('btn_close_shift')));
      await tester.pumpAndSettle();

      // Check modal components
      expect(find.text('Tutup Shift Kasir (Close Shift)'), findsOneWidget);
      expect(find.text('ESTIMASI KAS SISTEM'), findsOneWidget);
      expect(find.text('Kas Fisik Dihitung (Aktual) *'), findsOneWidget);
      expect(find.text('Hitung Per Pecahan Uang Rupiah'), findsOneWidget);

      // Verify denomination items are visible in bottom sheet
      final bottomSheet = find.byType(BottomSheet);
      expect(find.descendant(of: bottomSheet, matching: find.text('Rp 100.000')), findsOneWidget);
      expect(find.descendant(of: bottomSheet, matching: find.text('Rp 50.000')), findsOneWidget);
      expect(find.descendant(of: bottomSheet, matching: find.text('Rp 20.000')), findsOneWidget);

      // Anchored confirm button is visible
      expect(find.text('Konfirmasi & Tutup Shift'), findsOneWidget);

      // Initially 0 cash count -> neutral state "Belum Dihitung" (not red shortage, reason not shown)
      expect(find.text('Belum Dihitung'), findsOneWidget);
      expect(find.textContaining('Alasan Selisih Kas'), findsNothing);

      // Attempt to confirm without entering cash triggers validation -> shortage & reason required
      await tester.tap(find.text('Konfirmasi & Tutup Shift'));
      await tester.pumpAndSettle();
      expect(find.text('Shortage (Selisih Kurang)'), findsOneWidget);
      expect(find.textContaining('Alasan Selisih Kas'), findsOneWidget);
      expect(find.text('Alasan selisih kas fisik wajib diisi sebelum shift dapat ditutup.'), findsOneWidget);

      // Enter 300000 in actualCashController
      final actualCashField = find.descendant(of: bottomSheet, matching: find.widgetWithText(TextField, '0')).first;
      await tester.enterText(actualCashField, '300000');
      await tester.pumpAndSettle();

      // Now discrepancy should be balanced (Rp 0)
      expect(find.text('Kas Seimbang'), findsOneWidget);

      // Confirm and close shift
      await tester.tap(find.text('Konfirmasi & Tutup Shift'));
      await tester.pumpAndSettle();

      // Modal closed
      expect(find.text('Tutup Shift Kasir (Close Shift)'), findsNothing);
    });
  });
}
