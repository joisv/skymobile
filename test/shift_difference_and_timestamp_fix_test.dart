import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/models/receipt_model.dart';
import 'package:skyrental_admin/screens/cashier/cashier_shift_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/utils/formatters.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
  });

  group('Issue 1: Shift Closing Physical Cash Difference Verification', () {
    test('Denomination calculator with Rp 290,000 produces exact Rp 290,000 total', () {
      final counter = DenominationCounter();
      counter.n100k = 2; // Rp 200,000
      counter.n50k = 1;  // Rp 50,000
      counter.n20k = 2;  // Rp 40,000

      expect(counter.total, equals(290000.0));
      expect(counter.total.toInt().toString(), equals('290000'));
    });

    test('BookingRepository.closeShift preserves remote expectedCashNow of Rp 290,000 and closes with Rp 0 discrepancy', () async {
      final repo = BookingRepository();

      // Simulate active shift fetched from remote API with float 200,000 + remote cash payment 90,000
      final remoteActiveShift = CashDrawerShiftModel(
        id: 2,
        shiftNumber: 'SHF-GTG-261027-0002',
        branchId: 1,
        branchName: 'Genteng',
        openedByName: 'Budi Kasir',
        openedAt: DateTime(2026, 10, 27, 18, 15, 51),
        openingCashFloat: 200000.0,
        currentCashInflow: 90000.0,
        expectedCashNow: 290000.0,
        status: ShiftStatus.open,
      );

      repo.setTestShift(remoteActiveShift);

      // Verify effective expected cash is 290,000
      expect(repo.activeShift!.effectiveExpectedCash, equals(290000.0));

      // Close shift with actual counted cash = Rp 290,000
      final closedShift = await repo.closeShift(
        actualCashCounted: 290000.0,
      );

      expect(closedShift.status, equals(ShiftStatus.closed));
      expect(closedShift.actualCashCounted, equals(290000.0));
      expect(closedShift.expectedCashTotal, equals(290000.0));
      expect(closedShift.cashDifference, equals(0.0));
      expect(closedShift.isBalanced, isTrue);
      expect(closedShift.hasDiscrepancy, isFalse);
    });

    test('BookingRepository.closeShift enforces mandatory explanation reason if real physical cash difference > Rp 5,000', () async {
      final repo = BookingRepository();

      final remoteActiveShift = CashDrawerShiftModel(
        id: 2,
        shiftNumber: 'SHF-GTG-261027-0002',
        branchId: 1,
        branchName: 'Genteng',
        openedByName: 'Budi Kasir',
        openedAt: DateTime(2026, 10, 27, 18, 15, 51),
        openingCashFloat: 200000.0,
        currentCashInflow: 90000.0,
        expectedCashNow: 290000.0,
        status: ShiftStatus.open,
      );

      repo.setTestShift(remoteActiveShift);

      // Entering only Rp 200,000 when expected is Rp 290,000 (shortage Rp 90,000) without reason must throw
      expect(
        () => repo.closeShift(actualCashCounted: 200000.0),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Terdapat selisih kas fisik'),
        )),
      );

      // Supplying explanation reason allows closing with recorded shortage
      final closedWithReason = await repo.closeShift(
        actualCashCounted: 200000.0,
        differenceReason: 'Uang kembalian tertinggal di laci cadangan',
      );

      expect(closedWithReason.status, equals(ShiftStatus.closed));
      expect(closedWithReason.cashDifference, equals(-90000.0));
      expect(closedWithReason.differenceReason, equals('Uang kembalian tertinggal di laci cadangan'));
      expect(closedWithReason.isShortage, isTrue);
    });
  });

  group('Issue 2: Shift History Timestamps & Timezone Normalization Verification', () {
    test('CashDrawerShiftModel.fromJson normalizes ISO 8601 UTC and offset strings to Asia/Jakarta (WIB)', () {
      final jsonShift = {
        'id': 2,
        'shift_number': 'SHF-GTG-261027-0002',
        'branch_id': 1,
        'branch_name': 'Genteng',
        'opened_by_name': 'Budi Kasir',
        'closed_by_name': 'Budi Kasir',
        'opening_cash_float': 200000.0,
        'opened_at': '2026-10-27T18:15:51+07:00',
        'closed_at': '2026-10-27T18:17:30+07:00',
        'status': 'closed',
      };

      final shift = CashDrawerShiftModel.fromJson(jsonShift);

      // Opened at 18:15:51 WIB
      expect(shift.openedAt.year, equals(2026));
      expect(shift.openedAt.month, equals(10));
      expect(shift.openedAt.day, equals(27));
      expect(shift.openedAt.hour, equals(18));
      expect(shift.openedAt.minute, equals(15));

      // Closed at 18:17:30 WIB
      expect(shift.closedAt!.year, equals(2026));
      expect(shift.closedAt!.month, equals(10));
      expect(shift.closedAt!.day, equals(27));
      expect(shift.closedAt!.hour, equals(18));
      expect(shift.closedAt!.minute, equals(17));
    });

    test('CashDrawerShiftModel.fromJson handles ISO UTC Z strings and midnight date crossovers correctly', () {
      // 2026-10-27 19:30:00 UTC corresponds to 2026-10-28 02:30:00 WIB (crossing midnight into next day)
      final jsonMidnight = {
        'id': 3,
        'shift_number': 'SHF-GTG-261028-0001',
        'branch_id': 1,
        'opened_at': '2026-10-27T19:30:00.000000Z',
        'closed_at': '2026-10-28T03:30:00.000000Z', // 10:30 WIB on 28 Oct
        'opening_cash_float': 200000.0,
        'status': 'closed',
      };

      final shift = CashDrawerShiftModel.fromJson(jsonMidnight);

      // Normalized to 28 Oct 02:30 WIB
      expect(shift.openedAt.year, equals(2026));
      expect(shift.openedAt.month, equals(10));
      expect(shift.openedAt.day, equals(28));
      expect(shift.openedAt.hour, equals(2));
      expect(shift.openedAt.minute, equals(30));

      // Closed at 28 Oct 10:30 WIB
      expect(shift.closedAt!.day, equals(28));
      expect(shift.closedAt!.hour, equals(10));
      expect(shift.closedAt!.minute, equals(30));
    });

    test('Formatters correctly formats dates and times with WIB convention', () {
      final utcTime = DateTime.parse('2026-10-27T11:15:51.000000Z');

      final formattedDate = Formatters.date(utcTime);
      final formattedTime = Formatters.time(utcTime);
      final formattedDateTime = Formatters.dateTime(utcTime);

      expect(formattedDate, equals('27 Okt 2026'));
      expect(formattedTime, equals('18:15'));
      expect(formattedDateTime, equals('27 Okt 2026, 18:15'));
    });

    test('Active open shift maintains closedAt as null without fabricated timestamp', () {
      final jsonOpen = {
        'id': 4,
        'shift_number': 'SHF-GTG-261027-0004',
        'branch_id': 1,
        'opened_at': '2026-10-27T18:15:51+07:00',
        'closed_at': null,
        'opening_cash_float': 200000.0,
        'status': 'open',
      };

      final shift = CashDrawerShiftModel.fromJson(jsonOpen);
      expect(shift.isOpen, isTrue);
      expect(shift.closedAt, isNull);
    });

    test('Thermal receipt generates correct Waktu Buka and Waktu Tutup in WIB', () {
      final shift = CashDrawerShiftModel(
        id: 1,
        shiftNumber: 'SHF-GTG-261027-0001',
        branchId: 1,
        branchName: 'Genteng',
        openedByName: 'Budi Kasir',
        closedByName: 'Budi Kasir',
        openedAt: DateTime.parse('2026-10-27T11:15:51.000000Z'), // UTC 11:15 -> WIB 18:15
        closedAt: DateTime.parse('2026-10-27T11:45:00.000000Z'), // UTC 11:45 -> WIB 18:45
        openingCashFloat: 200000.0,
        status: ShiftStatus.closed,
      );

      final plainText = ReceiptModel.generateShiftClosingEscPos58mm(shift: shift);

      expect(plainText, contains('2026-10-27 18:15'));
      expect(plainText, contains('2026-10-27 18:45'));
    });

    testWidgets('CashierShiftScreen renders history timestamps accurately and handles active shift without fabricated closing date', (tester) async {
      final repo = BookingRepository();

      final openShift = CashDrawerShiftModel(
        id: 2,
        shiftNumber: 'SHF-GTG-261027-0002',
        branchId: 1,
        branchName: 'Genteng',
        openedByName: 'Budi Kasir',
        openedAt: DateTime(2026, 10, 27, 18, 15),
        closedAt: null,
        openingCashFloat: 200000,
        status: ShiftStatus.open,
      );

      final closedShift = CashDrawerShiftModel(
        id: 1,
        shiftNumber: 'SHF-GTG-261027-0001',
        branchId: 1,
        branchName: 'Genteng',
        openedByName: 'Budi Kasir',
        closedByName: 'Budi Kasir',
        openedAt: DateTime(2026, 10, 27, 8, 0),
        closedAt: DateTime(2026, 10, 27, 16, 0),
        openingCashFloat: 200000,
        expectedCashTotal: 290000,
        actualCashCounted: 290000,
        cashDifference: 0,
        status: ShiftStatus.closed,
      );

      repo.setTestShift(openShift);
      MockBookingData.shiftHistory.clear();
      MockBookingData.shiftHistory.addAll([openShift, closedShift]);

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CashierShiftScreen(repository: repo),
        ),
      ));
      await tester.pumpAndSettle();

      // Check Active Shift displays Buka timestamp
      expect(find.textContaining('Waktu Buka: 27 Okt 2026, 18:15 WIB'), findsOneWidget);

      // Switch to Shift History tab
      await tester.tap(find.text('Riwayat Shift'));
      await tester.pumpAndSettle();

      // Check active shift in history displays "Shift Masih Aktif (Belum Ditutup)"
      expect(find.text('Shift Masih Aktif (Belum Ditutup)'), findsWidgets);

      // Check closed shift displays actual closing time
      expect(find.text('Tutup: 27 Okt 2026, 16:00'), findsOneWidget);
    });
  });
}
