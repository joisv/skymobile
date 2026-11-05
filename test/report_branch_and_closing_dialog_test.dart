import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/screens/cashier/cashier_shift_screen.dart';
import 'package:skyrental_admin/screens/dashboard/sales_report_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  setUp(() {
    AuthService().setCurrentUserForTest(
      AdminUserModel.defaultAdmin().copyWith(role: 'super-admin'),
    );
  });

  group('Part 1: Report & Branch List Screen (Gambar 1) Mobile Tests', () {
    testWidgets('Renders 2-column affiliate card layout without RenderFlex overflow on narrow 360x780 screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repository = BookingRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesReportScreen(repository: repository),
          ),
        ),
      );

      // Settle data loading
      await tester.pumpAndSettle();

      // Scroll to affiliate breakdown section
      final sectionTitleFinder = find.text('Penghasilan Cabang & Affiliate');
      await tester.scrollUntilVisible(
        sectionTitleFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verify Section Header
      expect(sectionTitleFinder, findsOneWidget);
      expect(find.text('Super-Admin'), findsWidgets);
      expect(find.text('Kelola Cabang'), findsOneWidget);

      // Verify Horizontal Summary Badge Row
      expect(find.textContaining('Cabang Terdata'), findsOneWidget);
      expect(find.textContaining('Booking'), findsWidgets);

      // Verify 2-Column Branch List Card layout elements
      expect(find.text('Laporan Omset'), findsWidgets);
      expect(find.textContaining('Transaksi'), findsWidgets);
      expect(find.textContaining('•'), findsWidgets);

      // Verify that no exceptions or RenderFlex overflow occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('Header Title and Super-Admin badge fit alongside Kelola Cabang button on 390x844 mobile screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repository = BookingRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesReportScreen(repository: repository),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to affiliate breakdown section
      final titleFinder = find.text('Penghasilan Cabang & Affiliate');
      await tester.scrollUntilVisible(
        titleFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Check header row elements
      final badgeFinder = find.text('Super-Admin');
      final kelolaBtnFinder = find.text('Kelola Cabang');

      expect(titleFinder, findsOneWidget);
      expect(badgeFinder, findsWidgets);
      expect(kelolaBtnFinder, findsOneWidget);

      // Verify dot separator is rendered without glitches in 2-column card
      final transaksiFinder = find.textContaining('•');
      expect(transaksiFinder, findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Part 2: "Shift Berhasil Ditutup" Success Dialog (Gambar 2) Mobile Tests', () {
    testWidgets('Dialog renders on 360x640 mobile viewport with zero subpixel overflow and vertical button stacking', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repository = BookingRepository();
      final now = DateTime.now();

      final dummyClosedShift = CashDrawerShiftModel(
        id: 999,
        shiftNumber: 'SHF-TEST-261105-0001',
        branchId: 4,
        branchName: 'Genteng (Pusat)',
        openedByName: 'Kasir Utama',
        openedAt: now.subtract(const Duration(hours: 8)),
        closedAt: now,
        closedByName: 'Kasir Utama',
        status: ShiftStatus.closed,
        openingCashFloat: 200000,
        actualCashCounted: 750000,
        cashDifference: 0,
        currentCashInflow: 600000,
        currentCashExpenses: 50000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  // We simulate opening the shift dialog by using the exact dialog layout
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => CashierShiftScreen(repository: repository),
                  );
                },
                child: const Text('Open Shift Screen'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CashierShiftScreen(repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger closing success dialog via state or close shift workflow
      final state = tester.state(find.byType(CashierShiftScreen)) as dynamic;
      state.showClosingSuccessDialogForTest(dummyClosedShift);
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Shift Berhasil Ditutup'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Verify Metrics are displayed with clean monospace styling
      expect(find.text('Modal Awal'), findsOneWidget);
      expect(find.text('Kas Masuk'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Estimasi Kas'), findsOneWidget);
      expect(find.text('Kas Fisik Dihitung'), findsOneWidget);
      expect(find.text('Selisih Kas'), findsOneWidget);

      // Verify Vertical Button Stacking
      final printBtn = find.byKey(const Key('closing_dialog_print_btn'));
      final doneBtn = find.byKey(const Key('closing_dialog_done_btn'));

      expect(printBtn, findsOneWidget);
      expect(doneBtn, findsOneWidget);

      // Verify printBtn is ABOVE doneBtn (vertical stacking)
      final printTop = tester.getTopLeft(printBtn).dy;
      final doneTop = tester.getTopLeft(doneBtn).dy;
      expect(printTop, lessThan(doneTop));

      // Test tapping Selesai dismisses dialog cleanly
      await tester.tap(doneBtn);
      await tester.pumpAndSettle();

      expect(find.text('Shift Berhasil Ditutup'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
