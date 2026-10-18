import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/affiliate_model.dart';
import 'package:skyrental_admin/models/expense_model.dart';
import 'package:skyrental_admin/screens/dashboard/expenses_screen.dart';
import 'package:skyrental_admin/services/auth_service.dart';

class MockExpenseBookingRepository extends BookingRepository {
  List<ExpenseModel> mockExpenses = [
    ExpenseModel(
      id: 1,
      affiliateId: 4,
      affiliateName: 'Genteng Pusat',
      userId: '1',
      userName: 'Admin SKYRental',
      amount: 50000.0,
      amountFormatted: 'Rp 50.000',
      category: 'operasional',
      categoryLabel: 'Operasional Toko',
      notes: 'Beli galon & tisu outlet',
      spentAt: DateTime(2026, 10, 18, 10, 0),
      spentAtFormatted: '18 Oct 2026, 10:00',
    ),
    ExpenseModel(
      id: 2,
      affiliateId: 4,
      affiliateName: 'Genteng Pusat',
      userId: '1',
      userName: 'Admin SKYRental',
      amount: 100000.0,
      amountFormatted: 'Rp 100.000',
      category: 'listrik_internet',
      categoryLabel: 'Listrik & Internet',
      notes: 'Token listrik counter',
      spentAt: DateTime(2026, 10, 18, 11, 30),
      spentAtFormatted: '18 Oct 2026, 11:30',
    ),
  ];

  @override
  Future<ExpenseResponseModel> getExpensesData({
    String period = 'Hari Ini',
    DateTime? startDate,
    DateTime? endDate,
    int? affiliateId,
    String? category,
  }) async {
    var filtered = mockExpenses;
    if (affiliateId != null) {
      filtered = filtered.where((e) => e.affiliateId == affiliateId).toList();
    }
    if (category != null && category != 'all') {
      filtered = filtered.where((e) => e.category == category).toList();
    }
    final total = filtered.fold<double>(0.0, (sum, e) => sum + e.amount);
    return ExpenseResponseModel(
      status: 'success',
      period: period,
      startDate: '2026-10-18',
      endDate: '2026-10-18',
      summary: ExpenseSummaryModel(
        totalExpenses: total,
        totalExpensesFormatted: 'Rp ${total.toInt()}',
        count: filtered.length,
        categories: {'operasional': 50000.0, 'listrik_internet': 100000.0},
      ),
      data: filtered,
    );
  }

  @override
  Future<List<AffiliateModel>> getAffiliates({
    String? search,
    bool? isActive,
    bool forceRefresh = false,
  }) async {
    return [
      AffiliateModel(
        id: 4,
        code: 'AFF-001',
        name: 'Genteng Pusat',
        slug: 'genteng-pusat',
        isActive: true,
      ),
      AffiliateModel(
        id: 2,
        code: 'AFF-002',
        name: 'Purwoharjo',
        slug: 'purwoharjo',
        isActive: true,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expense Feature Models and ESC/POS Tests', () {
    test('ExpenseModel fromJson and toJson serialization', () {
      final json = {
        'id': 10,
        'affiliate_id': 4,
        'affiliate_name': 'Genteng Pusat',
        'user_id': '1',
        'user_name': 'Kasir Utama',
        'amount': 75000.0,
        'amount_formatted': 'Rp 75.000',
        'category': 'transport',
        'category_label': 'Transport & BBM',
        'notes': 'Bensin kurir antar unit',
        'spent_at': '2026-10-18T14:00:00Z',
        'spent_at_formatted': '18 Oct 2026, 14:00',
        'created_at': '2026-10-18T14:00:00Z',
      };

      final model = ExpenseModel.fromJson(json);
      expect(model.id, 10);
      expect(model.affiliateId, 4);
      expect(model.affiliateName, 'Genteng Pusat');
      expect(model.amount, 75000.0);
      expect(model.category, 'transport');
      expect(model.notes, 'Bensin kurir antar unit');

      final serialized = model.toJson();
      expect(serialized['id'], 10);
      expect(serialized['amount'], 75000.0);
    });

    test('exportClosingReportEscPos contains branch expenses and drawer reconciliation', () {
      final repo = BookingRepository();
      final reportData = {
        'status': 'success',
        'branch_name': 'Genteng Pusat',
        'period': 'Hari Ini',
        'summary': {
          'totalRevenue': 500000.0,
          'transactionCount': 5,
          'totalDepositsHeld': 0.0,
          'totalDepositsRefunded': 0.0,
          'cashAmount': 300000.0,
          'grossCash': 300000.0,
          'totalExpenses': 80000.0,
          'netCash': 220000.0,
        },
        'paymentMethodBreakdown': {
          'Tunai Kasir': 300000.0,
          'Transfer BCA': 200000.0,
        },
        'expenseBreakdown': {
          'operasional': 50000.0,
          'transport': 30000.0,
        },
      };

      final escPos = repo.exportClosingReportEscPos(reportData, branchName: 'Genteng Pusat');
      expect(escPos, contains('LAPORAN PENUTUPAN KASIR'));
      expect(escPos, contains('OUTLET GENTENG PUSAT'));
      expect(escPos, contains('RINGKASAN OMZET & KAS'));
      expect(escPos, contains('PENGELUARAN CABANG'));
      expect(escPos, contains('Operasional'));
      expect(escPos, contains('Transport'));
      expect(escPos, contains('Total Biaya :'));
      expect(escPos, contains('REKONSILIASI KAS LACI'));
      expect(escPos, contains('Kas Fisik   :'));
      expect(escPos, contains('Pengeluaran :'));
      expect(escPos, contains('Net Kas Laci:'));
    });
  });

  group('ExpensesScreen Widget Tests', () {
    late MockExpenseBookingRepository repository;

    setUp(() {
      repository = MockExpenseBookingRepository();
      AuthService().setCurrentUserForTest(
        AdminUserModel.defaultAdmin().copyWith(
          role: 'super-admin',
          roles: ['super-admin'],
        ),
      );
    });

    tearDown(() {
      AuthService().setCurrentUserForTest(null);
    });

    testWidgets('ExpensesScreen displays summary, items, and categories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExpensesScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Pengeluaran Cabang'), findsOneWidget);
      expect(find.text('Rincian Biaya Operasional'), findsOneWidget);
      expect(find.text('Beli galon & tisu outlet'), findsOneWidget);
      expect(find.text('Token listrik counter'), findsOneWidget);
      expect(find.text('Catat Biaya'), findsOneWidget);
    });
  });
}
