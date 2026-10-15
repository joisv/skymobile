import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/affiliate_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/unit_status/unit_status_list_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

class MockUnitStatusRepository extends BookingRepository {
  final List<AffiliateModel> mockAffiliates;
  final Map<String, PaginatedIphonesResult> branchResults;

  MockUnitStatusRepository({
    required this.mockAffiliates,
    required this.branchResults,
  });

  @override
  Future<List<AffiliateModel>> getAffiliates({
    String? search,
    bool? isActive,
    bool forceRefresh = false,
  }) async {
    return mockAffiliates;
  }

  @override
  Future<PaginatedIphonesResult> getInventoryUnitsPaginated({
    String? query,
    String? statusFilter,
    String? modelFilter,
    String? branchFilter,
    String? sortBy,
    int? affiliateId,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? endTime,
    int? duration,
    bool forBooking = false,
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    if (branchFilter != null && branchResults.containsKey(branchFilter)) {
      return branchResults[branchFilter]!;
    }
    return branchResults['Semua Cabang'] ??
        const PaginatedIphonesResult(units: [], total: 0, currentPage: 1, lastPage: 1);
  }
}

void main() {
  setUp(() {
    AuthService().setCurrentUserForTest(AdminUserModel.defaultAdmin());
  });

  testWidgets('UnitStatusListScreen renders branch dropdown with actual iphonesCount', (tester) async {
    final mockAffiliates = [
      const AffiliateModel(
        id: 4,
        code: 'GTG',
        name: 'Genteng Pusat',
        slug: 'genteng-pusat',
        iphonesCount: 54,
      ),
      const AffiliateModel(
        id: 2,
        code: 'PWJ',
        name: 'Affiliate Purwoharjo',
        slug: 'affiliate-purwoharjo',
        iphonesCount: 11,
      ),
      const AffiliateModel(
        id: 5,
        code: 'SKN',
        name: 'Affiliate Sukonatar',
        slug: 'affiliate-sukonatar',
        iphonesCount: 5,
      ),
    ];

    final repo = MockUnitStatusRepository(
      mockAffiliates: mockAffiliates,
      branchResults: {
        'Semua Cabang': const PaginatedIphonesResult(
          units: [
            IphoneModel(
              id: 1,
              name: 'iPhone 15 Pro',
              storage: '128GB',
              color: 'Natural',
              serialNumber: 'SN001',
              assetCode: 'IPH-001',
              status: 'ready',
              branchName: 'Genteng Pusat',
            ),
          ],
          total: 70,
          currentPage: 1,
          lastPage: 4,
          summary: {
            'total': 70,
            'tersedia': 50,
            'disewa': 15,
            'terlambat': 3,
            'maintenance': 2,
            'dibooking': 0,
          },
        ),
        'Genteng Pusat': const PaginatedIphonesResult(
          units: [
            IphoneModel(
              id: 1,
              name: 'iPhone 15 Pro',
              storage: '128GB',
              color: 'Natural',
              serialNumber: 'SN001',
              assetCode: 'IPH-001',
              status: 'ready',
              branchName: 'Genteng Pusat',
            ),
          ],
          total: 54,
          currentPage: 1,
          lastPage: 3,
          summary: {
            'total': 54,
            'tersedia': 40,
            'disewa': 10,
            'terlambat': 2,
            'maintenance': 2,
            'dibooking': 0,
          },
        ),
      },
    );

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitStatusListScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "Semua Cabang (70)" is displayed initially (sum of 54 + 11 + 5 = 70)
    expect(find.text('Semua Cabang (70)'), findsWidgets);

    // Open dropdown by tapping on it
    await tester.tap(find.text('Semua Cabang (70)').first);
    await tester.pumpAndSettle();

    // Verify all branch options display their actual iphonesCount
    expect(find.text('Genteng Pusat (54)'), findsWidgets);
    expect(find.text('Affiliate Purwoharjo (11)'), findsWidgets);
    expect(find.text('Affiliate Sukonatar (5)'), findsWidgets);

    // Select Genteng Pusat
    await tester.tap(find.text('Genteng Pusat (54)').last);
    await tester.pumpAndSettle();

    // Verify metric cards update to Genteng Pusat summary total (54)
    expect(find.text('54'), findsWidgets);
  });
}
