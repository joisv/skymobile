import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/affiliate_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/unit_status/unit_status_list_screen.dart';
import 'package:skyrental_admin/screens/unit_status/widgets/create_iphone_dialog.dart';
import 'package:skyrental_admin/services/auth_service.dart';

class MockMobileUnitStatusRepository extends BookingRepository {
  final List<IphoneModel> allUnits;
  final List<AffiliateModel> affiliates;
  String? lastStatusFilter;
  String? lastSortBy;

  MockMobileUnitStatusRepository({
    required this.allUnits,
    required this.affiliates,
  });

  @override
  Future<List<AffiliateModel>> getAffiliates({
    String? search,
    bool? isActive,
    bool forceRefresh = false,
  }) async {
    return affiliates;
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
    lastStatusFilter = statusFilter;
    lastSortBy = sortBy;

    var filtered = List<IphoneModel>.from(allUnits);
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toLowerCase() != 'semua') {
      final sf = statusFilter.toLowerCase();
      filtered = filtered.where((u) {
        final s = u.status.toLowerCase();
        if (sf == 'tersedia') return s == 'ready' || s == 'tersedia';
        if (sf == 'disewa') return s == 'rented' || s == 'disewa';
        if (sf == 'terlambat') return s == 'overdue' || s == 'terlambat';
        return s == sf;
      }).toList();
    }

    final summary = {
      'total': allUnits.length,
      'tersedia': allUnits.where((u) => u.status.toLowerCase() == 'ready' || u.status.toLowerCase() == 'tersedia').length,
      'disewa': allUnits.where((u) => u.status.toLowerCase() == 'rented' || u.status.toLowerCase() == 'disewa').length,
      'terlambat': allUnits.where((u) => u.status.toLowerCase() == 'overdue' || u.status.toLowerCase() == 'terlambat').length,
      'maintenance': 0,
      'dibooking': 0,
    };

    return PaginatedIphonesResult(
      units: filtered,
      total: filtered.length,
      currentPage: 1,
      lastPage: 1,
      summary: summary,
    );
  }
}

void main() {
  final sampleUnits = [
    const IphoneModel(
      id: 1,
      name: 'iPhone 15 Pro Max',
      storage: '256GB',
      color: 'Natural Titanium',
      serialNumber: 'SN-001',
      assetCode: 'IPH-15PM-01',
      status: 'ready',
      branchName: 'Genteng Pusat',
      batteryHealth: 98,
    ),
    const IphoneModel(
      id: 2,
      name: 'iPhone 14 Pro',
      storage: '128GB',
      color: 'Deep Purple',
      serialNumber: 'SN-002',
      assetCode: 'IPH-14P-01',
      status: 'rented',
      branchName: 'Genteng Pusat',
      customerName: 'Ahmad Rizki',
      batteryHealth: 95,
    ),
    const IphoneModel(
      id: 3,
      name: 'iPhone 13',
      storage: '128GB',
      color: 'Midnight',
      serialNumber: 'SN-003',
      assetCode: 'IPH-13-01',
      status: 'overdue',
      branchName: 'Genteng Pusat',
      customerName: 'Siti Sarah',
      batteryHealth: 88,
    ),
  ];

  final sampleAffiliates = [
    const AffiliateModel(
      id: 1,
      code: 'GTG',
      name: 'Genteng Pusat',
      slug: 'genteng-pusat',
      iphonesCount: 3,
    ),
  ];

  setUp(() {
    AuthService().setCurrentUserForTest(
      AdminUserModel.defaultAdmin().copyWith(role: 'admin'),
    );
  });

  group('Unit Status Screen Mobile Viewport Refactoring Tests', () {
    testWidgets('1. Merge Metric Cards with Status Filtering & Eliminate Redundant Chips', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockMobileUnitStatusRepository(
        allUnits: sampleUnits,
        affiliates: sampleAffiliates,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UnitStatusListScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 4 metric cards exist
      expect(find.text('Total Unit'), findsOneWidget);
      expect(find.text('Tersedia'), findsWidgets);
      expect(find.text('Disewa'), findsWidgets);
      expect(find.text('Terlambat'), findsWidgets);

      // Verify redundant chips from UnitStatusFilterChips are eliminated (no "Semua 3" chip listview)
      expect(find.text('Semua 3'), findsNothing);

      // Initially "Total Unit" shows 3 units
      expect(find.text('IPH-15PM-01'), findsOneWidget);
      expect(find.text('IPH-14P-01'), findsOneWidget);
      expect(find.text('IPH-13-01'), findsOneWidget);

      // Tap "Tersedia" card -> filters units to available
      await tester.tap(find.text('Tersedia').first);
      await tester.pumpAndSettle();

      expect(repo.lastStatusFilter, 'Tersedia');
      expect(find.text('IPH-15PM-01'), findsOneWidget);
      expect(find.text('IPH-14P-01'), findsNothing);
      expect(find.text('IPH-13-01'), findsNothing);

      // Tap "Disewa" card -> filters units to rented
      await tester.tap(find.text('Disewa').first);
      await tester.pumpAndSettle();

      expect(repo.lastStatusFilter, 'Disewa');
      expect(find.text('IPH-15PM-01'), findsNothing);
      expect(find.text('IPH-14P-01'), findsOneWidget);
      expect(find.text('IPH-13-01'), findsNothing);

      // Tap "Terlambat" card -> filters units to overdue
      await tester.tap(find.text('Terlambat').first);
      await tester.pumpAndSettle();

      expect(repo.lastStatusFilter, 'Terlambat');
      expect(find.text('IPH-15PM-01'), findsNothing);
      expect(find.text('IPH-14P-01'), findsNothing);
      expect(find.text('IPH-13-01'), findsOneWidget);

      // Tap "Total Unit" card -> resets status filter to all units
      await tester.tap(find.text('Total Unit').first);
      await tester.pumpAndSettle();

      expect(repo.lastStatusFilter, isNull);
      expect(find.text('IPH-15PM-01'), findsOneWidget);
      expect(find.text('IPH-14P-01'), findsOneWidget);
      expect(find.text('IPH-13-01'), findsOneWidget);
    });

    testWidgets('2. Streamline Search & Branch Controls: full-width search, integrated sort, 40px branch dropdown', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockMobileUnitStatusRepository(
        allUnits: sampleUnits,
        affiliates: sampleAffiliates,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UnitStatusListScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Search field is present with full hint text
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cari iPhone, kode aset, SN, penyewa...'), findsOneWidget);

      // QR Scanner icon is present inside search bar
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

      // Integrated Sort icon button is present inside search bar
      final sortButton = find.byIcon(Icons.sort_rounded);
      expect(sortButton, findsOneWidget);

      // Tapping sort button opens popup menu with sort options
      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      expect(find.text('Battery Health (Tertinggi)'), findsOneWidget);
      expect(find.text('Battery Health (Terendah)'), findsOneWidget);
      expect(find.text('Model iPhone (A - Z)'), findsOneWidget);
      expect(find.text('Kode Aset (A - Z)'), findsOneWidget);

      // Close popup menu
      await tester.tap(find.text('Battery Health (Tertinggi)'));
      await tester.pumpAndSettle();
      expect(repo.lastSortBy, 'bh_desc');

      // Verify sleek Branch Selector is rendered below search row with height 40px
      final branchDropdownFinder = find.byType(DropdownButton<String>);
      expect(branchDropdownFinder, findsOneWidget);

      final branchContainerFinder = find.ancestor(
        of: branchDropdownFinder,
        matching: find.byType(Container),
      ).first;
      final RenderBox branchBox = tester.renderObject(branchContainerFinder);
      expect(branchBox.size.height, equals(40.0));
    });

    testWidgets('3. Move "Tambah Unit" to Floating Action Button (FAB)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockMobileUnitStatusRepository(
        allUnits: sampleUnits,
        affiliates: sampleAffiliates,
      );

      // As Admin: FAB should be visible
      await tester.pumpWidget(
        MaterialApp(
          home: UnitStatusListScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      expect(find.text('Tambah Unit'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Verify the ListView has bottom padding 80px so last card is never obscured by FAB
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);
      final ListView listView = tester.widget<ListView>(listViewFinder);
      expect(listView.padding, const EdgeInsets.fromLTRB(16, 6, 16, 80));

      // Tap FAB -> triggers CreateIphoneDialog
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      expect(find.byType(CreateIphoneDialog), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byType(CreateIphoneDialog), findsNothing);

      // As Staff Kasir: FAB should NOT be visible
      AuthService().setCurrentUserForTest(
        AdminUserModel.defaultAdmin().copyWith(
          role: 'Staff Kasir',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UnitStatusListScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('4. Header & Vertical Spacing: Zero RenderFlex overflow on narrow 360x640 screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      AuthService().setCurrentUserForTest(
        AdminUserModel.defaultAdmin().copyWith(role: 'admin'),
      );

      final repo = MockMobileUnitStatusRepository(
        allUnits: sampleUnits,
        affiliates: sampleAffiliates,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UnitStatusListScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      // Zero RenderFlex errors on 360x640 mobile screen
      expect(tester.takeException(), isNull);
    });
  });
}
