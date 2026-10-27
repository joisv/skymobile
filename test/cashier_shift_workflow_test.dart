import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/models/expense_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
import 'package:skyrental_admin/models/receipt_model.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('POS Cashier Shift Management & Cash Book Tests', () {
    late BookingRepository repository;

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
      repository = BookingRepository();
    });

    test('Scenario 1: Open Shift creates active session and rejects duplicate open shift', () async {
      // 1. Awal: tidak ada shift aktif
      var current = await repository.getCurrentShift(branchId: 4, forceRefresh: true);
      expect(current, isNull);

      // 2. Buka Shift baru dengan modal Rp 200.000
      final openedShift = await repository.openShift(
        openingCashFloat: 200000.0,
        notes: 'Modal awal uang receh kasir pagi',
        branchId: 4,
      );

      expect(openedShift.status, ShiftStatus.open);
      expect(openedShift.isOpen, isTrue);
      expect(openedShift.openingCashFloat, 200000.0);
      expect(openedShift.shiftNumber, startsWith('SHF-GNT-'));
      expect(openedShift.openedByName, 'Budi Santoso');

      // 3. Verifikasi getCurrentShift mengembalikan shift yang baru dibuka
      current = await repository.getCurrentShift(branchId: 4);
      expect(current, isNotNull);
      expect(current!.shiftNumber, openedShift.shiftNumber);

      // 4. Mencegah duplikasi shift aktif di cabang yang sama
      expect(
        () => repository.openShift(openingCashFloat: 100000.0, branchId: 4),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Shift kasir masih terbuka'),
        )),
      );
    });

    test('Scenario 2: Cash calculation distinguishes physical cash from non-cash (QRIS) & calculates expected cash correctly', () async {
      final now = DateTime.now();

      // Buka Shift dengan modal awal Rp 250.000
      final shift = await repository.openShift(
        openingCashFloat: 250000.0,
        branchId: 4,
      );
      expect(shift.isOpen, isTrue);

      // Tambahkan transaksi tunai (Inflow): Rp 300.000
      final cashTx = PaymentTransactionModel(
        id: 881,
        bookingId: 101,
        bookingCode: 'SKY-CASH-001',
        customerName: 'Ahmad Pelanggan',
        customerPhone: '081234567890',
        iphoneName: 'iPhone 15 Pro',
        rentTotal: 300000.0,
        paidAmount: 300000.0,
        remainingAmount: 0.0,
        depositAmount: 0.0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'Tunai Kasir',
        transactionDate: now.add(const Duration(minutes: 10)),
      );

      // Tambahkan transaksi non-tunai (QRIS Kasir): Rp 500.000 -> TIDAK BOLEH MENAMBAH KAS FISIK
      final qrisTx = PaymentTransactionModel(
        id: 882,
        bookingId: 102,
        bookingCode: 'SKY-QRIS-002',
        customerName: 'Siti Rahma',
        customerPhone: '081987654321',
        iphoneName: 'iPhone 14',
        rentTotal: 500000.0,
        paidAmount: 500000.0,
        remainingAmount: 0.0,
        depositAmount: 0.0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'QRIS Kasir',
        transactionDate: now.add(const Duration(minutes: 20)),
      );

      // Tambahkan pengembalian deposit tunai (Refund Outflow): Rp 50.000
      final refundTx = PaymentTransactionModel(
        id: 883,
        bookingId: 103,
        bookingCode: 'SKY-REF-003',
        customerName: 'Budi Santoso',
        customerPhone: '085712345678',
        iphoneName: 'iPhone 13',
        rentTotal: 0.0,
        paidAmount: 0.0,
        remainingAmount: 0.0,
        depositAmount: 50000.0,
        depositStatus: DepositStatus.refunded,
        refundAmount: 50000.0,
        paymentStatus: 'paid',
        paymentMethod: 'Tunai',
        transactionDate: now.add(const Duration(minutes: 30)),
      );

      // Injeksi transaksi ke repository
      repository.setTestTransactions([cashTx, qrisTx, refundTx]);

      // Tambahkan pengeluaran kas laci (Disbursed Cash Drawer Expense): Rp 30.000
      final expense = ExpenseModel(
        id: 771,
        affiliateId: 4,
        amount: 30000.0,
        category: 'supplies',
        categoryLabel: 'Perlengkapan Toko',
        notes: 'Beli kertas thermal kasir',
        spentAt: now.add(const Duration(minutes: 40)),
      );
      repository.setTestExpenses([expense]);

      // Perbarui metrics shift aktif
      final active = await repository.getCurrentShift(branchId: 4, forceRefresh: true);
      expect(active, isNotNull);

      // Verifikasi komponen finansial
      expect(active!.openingCashFloat, 250000.0);
      expect(active.currentCashInflow, 300000.0); // Hanya cashTx (QRIS diabaikan dari kas fisik laci)
      expect(active.currentCashRefund, 50000.0);
      expect(active.currentCashExpenses, 30000.0);

      // Expected Cash = 250.000 + 300.000 - 50.000 - 30.000 = 470.000
      expect(active.effectiveExpectedCash, 470000.0);
    });

    test('Scenario 3: Close Shift with exact cash balance is recorded as balanced', () async {
      final shift = await repository.openShift(openingCashFloat: 300000.0, branchId: 4);

      // Tutup shift dengan hitungan fisik Rp 300.000 (tepat seimbang)
      final closedShift = await repository.closeShift(
        actualCashCounted: 300000.0,
        closingNotes: 'Shift selesai, kas seimbang sempurna',
        shiftId: shift.id,
      );

      expect(closedShift.status, ShiftStatus.closed);
      expect(closedShift.isClosed, isTrue);
      expect(closedShift.actualCashCounted, 300000.0);
      expect(closedShift.cashDifference, 0.0);
      expect(closedShift.isBalanced, isTrue);
      expect(closedShift.hasDiscrepancy, isFalse);

      // Setelah ditutup, getCurrentShift harus bernilai null (tidak ada shift terbuka)
      final current = await repository.getCurrentShift(branchId: 4, forceRefresh: true);
      expect(current, isNull);
    });

    test('Scenario 4: Close Shift with cash surplus is recorded with positive difference', () async {
      final shift = await repository.openShift(openingCashFloat: 200000.0, branchId: 4);

      // Tutup shift dengan kas fisik Rp 215.000 (Surplus Rp 15.000)
      final closedShift = await repository.closeShift(
        actualCashCounted: 215000.0,
        differenceReason: 'Kelebihan uang tip dari pelanggan',
        shiftId: shift.id,
      );

      expect(closedShift.actualCashCounted, 215000.0);
      expect(closedShift.cashDifference, 15000.0);
      expect(closedShift.isSurplus, isTrue);
      expect(closedShift.isShortage, isFalse);
    });

    test('Scenario 5: Close Shift with shortage > Rp 5.000 requires explanation reason', () async {
      final shift = await repository.openShift(openingCashFloat: 200000.0, branchId: 4);

      // Menutup dengan selisih kurang Rp 20.000 tanpa keterangan wajib gagal
      expect(
        () => repository.closeShift(
          actualCashCounted: 180000.0, // Kurang Rp 20.000
          differenceReason: '', // Kosong!
          shiftId: shift.id,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Keterangan/alasan selisih kas wajib diisi'),
        )),
      );

      // Menutup dengan selisih kurang Rp 20.000 disertai alasan valid harus berhasil
      final closedShift = await repository.closeShift(
        actualCashCounted: 180000.0,
        differenceReason: 'Uang kembalian receh belum ditukar dari bank',
        shiftId: shift.id,
      );

      expect(closedShift.actualCashCounted, 180000.0);
      expect(closedShift.cashDifference, -20000.0);
      expect(closedShift.isShortage, isTrue);
      expect(closedShift.differenceReason, 'Uang kembalian receh belum ditukar dari bank');
    });

    test('Scenario 6: Shift Cash Book produces chronological ledger with accurate running balance', () async {
      final now = DateTime.now();

      final shift = await repository.openShift(openingCashFloat: 200000.0, branchId: 4);

      final tx1 = PaymentTransactionModel(
        id: 901,
        bookingId: 101,
        bookingCode: 'SKY-BK-001',
        customerName: 'Budi Santoso',
        customerPhone: '081234567890',
        iphoneName: 'iPhone 15 Pro',
        rentTotal: 150000.0,
        paidAmount: 150000.0,
        remainingAmount: 0.0,
        depositAmount: 0.0,
        depositStatus: DepositStatus.held,
        paymentStatus: 'paid',
        paymentMethod: 'Tunai (Cash)',
        transactionDate: now.add(const Duration(minutes: 10)),
      );

      final exp1 = ExpenseModel(
        id: 902,
        affiliateId: 4,
        amount: 25000.0,
        category: 'operational',
        categoryLabel: 'Operasional',
        notes: 'Beli air mineral & snack kantor',
        spentAt: now.add(const Duration(minutes: 20)),
      );

      repository.setTestTransactions([tx1]);
      repository.setTestExpenses([exp1]);

      final entries = await repository.getCashBookEntries(shift: shift);

      // Verifikasi urutan buku kas
      expect(entries.length, 3);

      // Entry 1: Modal Awal
      expect(entries[0].entryType, CashBookEntryType.openingFloat);
      expect(entries[0].inflowAmount, 200000.0);
      expect(entries[0].runningBalance, 200000.0);

      // Entry 2: Pembayaran Sewa Masuk (+150.000)
      expect(entries[1].entryType, CashBookEntryType.cashInflow);
      expect(entries[1].inflowAmount, 150000.0);
      expect(entries[1].runningBalance, 350000.0);

      // Entry 3: Pengeluaran Kasir (-25.000)
      expect(entries[2].entryType, CashBookEntryType.cashExpense);
      expect(entries[2].outflowAmount, 25000.0);
      expect(entries[2].runningBalance, 325000.0);
    });

    test('Scenario 7: Thermal receipt 58mm ESC/POS strictly satisfies 32-column limit', () async {
      final shift = CashDrawerShiftModel(
        id: 991,
        shiftNumber: 'SHF-GNT-261027-0001',
        branchId: 4,
        branchName: 'Genteng Pusat',
        openedByName: 'Budi Santoso',
        closedByName: 'Budi Santoso',
        openedAt: DateTime(2026, 10, 27, 8, 0),
        closedAt: DateTime(2026, 10, 27, 16, 0),
        openingCashFloat: 200000.0,
        currentCashInflow: 450000.0,
        currentCashRefund: 50000.0,
        currentCashExpenses: 30000.0,
        expectedCashTotal: 570000.0,
        actualCashCounted: 570000.0,
        cashDifference: 0.0,
        status: ShiftStatus.closed,
        closingNotes: 'Shift selesai lancar',
      );

      final escPos = ReceiptModel.generateShiftClosingEscPos58mm(shift: shift);

      expect(escPos, contains('LAPORAN PENUTUPAN KASIR'));
      expect(escPos, contains('SHF-GNT-261027-0001'));
      expect(escPos, contains('Modal Awal (Float) :'));
      expect(escPos, contains('ESTIMASI KAS LACI  :'));
      expect(escPos, contains('FISIK DIHITUNG     :'));
      expect(escPos, contains('SELISIH KAS        :'));
      expect(escPos, contains('SEIMBANG'));

      // Verifikasi batas kolom monospace 32 karakter untuk setiap baris
      final lines = escPos.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        expect(
          line.length,
          lessThanOrEqualTo(32),
          reason: 'Line $i exceeds 32 characters: "$line" (length: ${line.length})',
        );
      }
    });
  });
}
