import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/affiliate_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
import 'package:skyrental_admin/screens/dashboard/sales_report_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

class MockTrackingBookingRepository extends BookingRepository {
  int? lastRequestedAffiliateId;
  int getSalesReportCallCount = 0;

  @override
  Future<Map<String, dynamic>> getSalesReportData({
    String period = 'Hari Ini',
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int perPage = 20,
    int? affiliateId,
  }) async {
    lastRequestedAffiliateId = affiliateId;
    getSalesReportCallCount++;
    return {
      'status': 'success',
      'period': period,
      'summary': {
        'totalRevenue': 97740000.0,
        'transactionCount': 1418,
        'totalDepositsHeld': 0.0,
        'totalDepositsRefunded': 0.0,
        'cashAmount': 50000000.0,
        'transferAmount': 40000000.0,
        'qrisAmount': 7740000.0,
      },
      'paymentMethodBreakdown': <String, double>{'Tunai Kasir': 50000000.0},
      'typeBreakdown': <String, double>{'payment': 97740000.0},
      'modelRevenue': <String, double>{'iPhone 13': 97740000.0},
      'modelRentalCount': <String, int>{'iPhone 13': 1418},
      'affiliateBreakdown': <Map<String, dynamic>>[],
      'pagination': {
        'current_page': page,
        'last_page': 1,
        'per_page': perPage,
        'total': 1418,
      },
      'transactions': <PaymentTransactionModel>[],
      'branch_name': affiliateId == 4 ? 'Genteng Pusat' : (affiliateId == 2 ? 'Affiliate Purwoharjo' : 'Semua Cabang'),
    };
  }

  @override
  Future<List<AffiliateModel>> getAffiliates({
    String? search,
    bool? isActive,
    bool forceRefresh = false,
  }) async {
    return [
      const AffiliateModel(
        id: 4,
        code: 'GTG',
        name: 'Genteng Pusat',
        slug: 'genteng-pusat',
      ),
      const AffiliateModel(
        id: 2,
        code: 'PWH',
        name: 'Affiliate Purwoharjo',
        slug: 'affiliate-purwoharjo',
      ),
      const AffiliateModel(
        id: 5,
        code: 'SKN',
        name: 'Affiliate Sukonatar',
        slug: 'affiliate-sukonatar',
      ),
    ];
  }
}

void main() {
  setUp(() {
    MockBookingData.resetInventory();
  });

  tearDown(() {
    AuthService().setCurrentUserForTest(null);
  });

  group('Branch Revenue Filtering Tests', () {
    test('BookingRepository fallback filters by affiliateId correctly', () async {
      final repo = BookingRepository();

      // All branches combined
      final allData = await repo.getSalesReportData(period: 'all');
      final totalAll = (allData['summary']['totalRevenue'] as num).toDouble();

      // Filtered to Genteng Pusat (ID 4)
      final gtgData = await repo.getSalesReportData(period: 'all', affiliateId: 4);
      final totalGtg = (gtgData['summary']['totalRevenue'] as num).toDouble();

      // Filtered to Purwoharjo (ID 2)
      final pwhData = await repo.getSalesReportData(period: 'all', affiliateId: 2);
      final totalPwh = (pwhData['summary']['totalRevenue'] as num).toDouble();

      expect(allData['status'], 'success');
      expect(gtgData['status'], 'success');
      expect(pwhData['status'], 'success');
      // GTG and PWH totals must be positive and less than or equal to allData total
      expect(totalAll, greaterThanOrEqualTo(totalGtg));
      expect(totalAll, greaterThanOrEqualTo(totalPwh));
    });

    test('ESC/POS and CSV exports format branch name correctly', () {
      final repo = BookingRepository();
      final sampleData = {
        'summary': {'totalRevenue': 15000000, 'transactionCount': 10},
        'paymentMethodBreakdown': {'Tunai Kasir': 15000000.0},
        'branch_name': 'Genteng Pusat',
        'transactions': [],
      };

      final escPos = repo.exportClosingReportEscPos(sampleData, branchName: 'Genteng Pusat');
      expect(escPos, contains('OUTLET GENTENG PUSAT'));

      final csv = repo.exportSalesReportCsv(sampleData, branchName: 'Genteng Pusat');
      expect(csv, contains('# Cabang/Outlet: Genteng Pusat'));
    });

    testWidgets('Super-admin defaults to Genteng Pusat (ID 4) on initialization', (tester) async {
      AuthService().setCurrentUserForTest(
        const AdminUserModel(
          id: 1,
          name: 'Super Admin SKYRental',
          email: 'admin@skyrental.id',
          phone: '+62 812-3456-7890',
          role: 'super-admin',
          roles: ['super-admin'],
          outletName: 'Pusat',
          shiftName: 'All Shift',
          affiliateId: 4,
        ),
      );

      final mockRepo = MockTrackingBookingRepository();

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: SalesReportScreen(repository: mockRepo),
      ));
      await tester.pumpAndSettle();

      // Verify that the initial call to getSalesReportData requested affiliateId: 4 (Genteng Pusat)
      expect(mockRepo.lastRequestedAffiliateId, 4);

      // Verify that the UI displays 'Genteng Pusat' on the branch selector
      expect(find.text('Genteng Pusat'), findsWidgets);
    });

    testWidgets('Super-admin can open branch selector popup and view options', (tester) async {
      AuthService().setCurrentUserForTest(
        const AdminUserModel(
          id: 1,
          name: 'Super Admin SKYRental',
          email: 'admin@skyrental.id',
          phone: '+62 812-3456-7890',
          role: 'super-admin',
          roles: ['super-admin'],
          outletName: 'Pusat',
          shiftName: 'All Shift',
          affiliateId: 4,
        ),
      );

      final mockRepo = MockTrackingBookingRepository();

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: SalesReportScreen(repository: mockRepo),
      ));
      await tester.pumpAndSettle();

      // Tap on branch selector button
      final branchSelectorFinder = find.byTooltip('Pilih Cabang / Outlet');
      expect(branchSelectorFinder, findsOneWidget);
      await tester.tap(branchSelectorFinder);
      await tester.pumpAndSettle();

      // Verify popup options exist
      expect(find.widgetWithText(PopupMenuItem<int>, 'Semua Cabang (Gabungan)'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<int>, 'Affiliate Purwoharjo'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<int>, 'Affiliate Sukonatar'), findsOneWidget);

      // Select 'Affiliate Purwoharjo' from the popup menu
      await tester.tap(find.widgetWithText(PopupMenuItem<int>, 'Affiliate Purwoharjo'));
      await tester.pumpAndSettle();

      // Verify reload was triggered with affiliateId = 2
      expect(mockRepo.lastRequestedAffiliateId, 2);
      expect(find.text('Affiliate Purwoharjo'), findsWidgets);
    });

    testWidgets('Super-admin selecting Semua Cabang passes null affiliateId', (tester) async {
      AuthService().setCurrentUserForTest(
        const AdminUserModel(
          id: 1,
          name: 'Super Admin SKYRental',
          email: 'admin@skyrental.id',
          phone: '+62 812-3456-7890',
          role: 'super-admin',
          roles: ['super-admin'],
          outletName: 'Pusat',
          shiftName: 'All Shift',
          affiliateId: 4,
        ),
      );

      final mockRepo = MockTrackingBookingRepository();

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: SalesReportScreen(repository: mockRepo),
      ));
      await tester.pumpAndSettle();

      // Tap branch selector
      await tester.tap(find.byTooltip('Pilih Cabang / Outlet'));
      await tester.pumpAndSettle();

      // Select 'Semua Cabang (Gabungan)' from popup menu
      await tester.tap(find.widgetWithText(PopupMenuItem<int>, 'Semua Cabang (Gabungan)'));
      await tester.pumpAndSettle();

      // Verify null was passed for combined company-wide view
      expect(mockRepo.lastRequestedAffiliateId, isNull);
      expect(find.text('Semua Cabang (Gabungan)'), findsWidgets);
    });

    testWidgets('Branch admin cannot change branch and selector dropdown is hidden', (tester) async {
      AuthService().setCurrentUserForTest(
        const AdminUserModel(
          id: 5,
          name: 'Admin Purwoharjo',
          email: 'admin.purwoharjo@skyrental.id',
          phone: '+62 812-3456-7899',
          role: 'affiliate-admin',
          roles: ['affiliate-admin'],
          outletName: 'Outlet Purwoharjo',
          shiftName: 'Pagi',
          affiliateId: 2,
        ),
      );

      final mockRepo = MockTrackingBookingRepository();

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: SalesReportScreen(repository: mockRepo),
      ));
      await tester.pumpAndSettle();

      // Verify that the query was locked to branch admin's own affiliateId (2)
      expect(mockRepo.lastRequestedAffiliateId, 2);

      // Verify branch selector popup button does NOT exist
      expect(find.byTooltip('Pilih Cabang / Outlet'), findsNothing);
    });
  });
}
