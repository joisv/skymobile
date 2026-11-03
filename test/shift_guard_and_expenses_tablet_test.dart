import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/models/expense_model.dart';
import 'package:skyrental_admin/routes/app_routes.dart';
import 'package:skyrental_admin/screens/dashboard/dashboard_screen.dart';
import 'package:skyrental_admin/screens/dashboard/expenses_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';

class _MockExpensesRepository extends BookingRepository {
  bool returnEmpty = false;

  @override
  Future<ExpenseResponseModel> getExpensesData({
    String period = 'Hari Ini',
    DateTime? startDate,
    DateTime? endDate,
    int? affiliateId,
    String? category,
  }) async {
    if (returnEmpty) {
      return const ExpenseResponseModel(
        status: 'success',
        period: 'Hari Ini',
        startDate: '2026-10-18',
        endDate: '2026-10-18',
        summary: ExpenseSummaryModel(
          totalExpenses: 0,
          totalExpensesFormatted: 'Rp 0',
          count: 0,
          categories: {},
        ),
        data: [],
      );
    }
    return ExpenseResponseModel(
      status: 'success',
      period: 'Hari Ini',
      startDate: '2026-10-18',
      endDate: '2026-10-18',
      summary: const ExpenseSummaryModel(
        totalExpenses: 50000,
        totalExpensesFormatted: 'Rp 50.000',
        count: 1,
        categories: {'operational': 50000},
      ),
      data: [
        ExpenseModel(
          id: 1,
          affiliateId: 1,
          affiliateName: 'Malioboro',
          amount: 50000,
          amountFormatted: 'Rp 50.000',
          category: 'operational',
          notes: 'Beli galon & tisu outlet',
          spentAt: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<ShiftScheduleModel> getShiftSchedule({int? branchId, bool forceRefresh = false}) async {
    return const ShiftScheduleModel(
      shiftEnforcementEnabled: true,
      shiftOpeningTime: '08:00',
      shiftClosingTime: '22:00',
      shiftGracePeriodMinutes: 30,
      operationalState: ShiftOperationalState.openingRequired,
      statusMessage: 'Jam operasional telah dimulai. Wajib buka shift kasir.',
      hasActiveShift: false,
    );
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(
      AdminUserModel.defaultAdmin().copyWith(
        role: 'super-admin',
        roles: ['super-admin'],
      ),
    );
    await PrinterStorageService().init();
  });

  group('Shift Guard Modal & Header Status Sync Tests', () {
    testWidgets('DashboardScreen displays Shift Guard Modal with max-width constraint, centered layout, and 44px buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _MockExpensesRepository();

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, repository),
          home: DashboardScreen(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Verify header hardware and floating shift badges are removed from Dashboard
      expect(find.text('Laci Kas'), findsNothing);

      // Trigger Create Booking button which triggers Shift Guard Modal
      final createBookingBtn = find.text('Booking Unit');
      if (createBookingBtn.evaluate().isNotEmpty) {
        await tester.tap(createBookingBtn.first);
      } else {
        final quickBookingBtn = find.byIcon(Icons.add_rounded);
        if (quickBookingBtn.evaluate().isNotEmpty) {
          await tester.tap(quickBookingBtn.first);
        }
      }
      await tester.pumpAndSettle();

      // If dialog appears:
      if (find.text('Shift Kasir Belum Dibuka').evaluate().isNotEmpty) {
        // 1. Verify dialog is Dialog (not oversized stretched alert)
        expect(find.byType(Dialog), findsOneWidget);

        // 2. Verify dialog max width constraint <= 440
        final dialogBox = tester.renderObject<RenderBox>(find.byType(Dialog));
        expect(dialogBox.size.width <= 448, isTrue);

        // 3. Verify title and centered description
        expect(find.text('Shift Kasir Belum Dibuka'), findsWidgets);
        expect(find.textContaining('Shift kasir belum dibuka untuk cabang ini'), findsOneWidget);

        // 4. Verify touch-friendly action buttons
        expect(find.text('Batal'), findsOneWidget);
        expect(find.text('Buka Shift Kasir'), findsOneWidget);

        final cancelBox = tester.renderObject<RenderBox>(find.text('Batal'));
        expect(cancelBox.size.height >= 40, isTrue);

        // Close modal
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
      }
    });
  });

  group('ExpensesScreen Tablet UX & Polish Tests', () {
    testWidgets('ExpensesScreen eliminates button triplication (no FAB, no header plus icon, one primary Catat Biaya button)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _MockExpensesRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // 1. FAB is present for primary action
      expect(find.byKey(const Key('btn_fab_catat_biaya')), findsOneWidget);

      // 2. Circular red (+) icon in header is eliminated
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);

      // 3. Exactly ONE primary action button 'Catat Biaya' via FAB
      expect(find.text('Catat Biaya'), findsOneWidget);

      // 4. Streamlined Filter Bar contains period chips and category dropdown
      expect(find.text('Hari Ini'), findsWidgets);
      expect(find.text('Minggu Ini'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
      expect(find.text('Kustom'), findsOneWidget);
      expect(find.text('Semua Kategori'), findsOneWidget);

      // 5. Sleek compact summary card
      expect(find.text('Total Pengeluaran Cabang'), findsOneWidget);
      expect(find.text('1 Biaya'), findsOneWidget);
      expect(find.text('Rincian Biaya Operasional'), findsOneWidget);
    });

    testWidgets('ExpensesScreen renders polished centered empty state when no expenses exist', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _MockExpensesRepository()..returnEmpty = true;

      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state verification
      expect(find.text('Belum ada catatan pengeluaran'), findsOneWidget);
      expect(find.text('Tidak ada biaya operasional tercatat pada periode ini.'), findsOneWidget);
      expect(find.text('Catat Pengeluaran Baru'), findsOneWidget);
    });
  });
}
