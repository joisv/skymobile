import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/models/print_result_model.dart';
import 'package:skyrental_admin/models/printer_device_model.dart';
import 'package:skyrental_admin/models/receipt_model.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';
import 'package:skyrental_admin/services/thermal_print_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingRepository repository;
  late IphoneModel testIphone;
  late BookingModel lateBooking;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrinterStorageService().init();
    ThermalPrintService().resetSimulation();
    repository = BookingRepository();

    testIphone = const IphoneModel(
      id: 201,
      name: 'iPhone 15 Pro 128GB',
      storage: '128GB',
      color: 'Natural Titanium',
      serialNumber: 'SN-IP15P-LATE01',
      assetCode: 'AST-IP15P-LATE01',
      status: 'disewa',
      batteryHealth: 99,
    );

    lateBooking = BookingModel(
      id: 201,
      bookingCode: 'SKY261027LATE1',
      customerName: 'Rian Pratama',
      customerPhone: '081298765432',
      customerEmail: 'rian.pratama@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: DateTime.now().subtract(const Duration(hours: 48)),
      endDate: DateTime.now().subtract(const Duration(hours: 24)),
      durationDays: 1,
      price: 350000,
      deposit: 200000,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: testIphone,
      estimatedLateFee: 30000,
    );
    repository.rawBookings.add(lateBooking);
  });

  group('Bug Fix: Include Amount Paid and Change on Late iPhone Return Receipts', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Late-return fee paid with exact cash
    // -------------------------------------------------------------------------
    test('Scenario 1: Late-return fee paid with exact cash shows late fee, exact cash received, and Rp 0 change', () {
      final receipt = ReceiptModel(
        receiptNumber: 'STR-202610-3001',
        date: DateTime(2026, 10, 27, 11, 30),
        adminName: 'Budi Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.returnUnit,
        bookingCode: 'SKY261027LATE1',
        customerName: 'Rian Pratama',
        customerPhone: '081298765432',
        unitName: 'iPhone 15 Pro 128GB',
        serialNumber: 'SN-IP15P-LATE01',
        assetCode: 'AST-IP15P-LATE01',
        rentalDuration: '1 Hari (Terlambat 24 Jam)',
        rentalDates: '25/10 - 26/10/2026',
        rentFee: 350000,
        depositFee: 0,
        finesFee: 30000,
        discountFee: 0,
        totalAmount: 30000,
        paidAmount: 30000,
        remainingAmount: 0,
        paymentMethod: 'TUNAI',
        paymentStatus: 'Lunas',
        cashGiven: 30000,
        cashChange: 0,
        depositStatus: 'Tanpa Deposit',
        refundAmount: 0,
        notes: 'Pengembalian terlambat 1 hari dengan pelunasan denda',
      );

      final receiptText = receipt.toEscPos58mm();
      final lines = receiptText.split('\n');

      // Verify 32-column paper width constraints
      for (final line in lines) {
        if (line.contains('[STORE_NAME:') || line.contains('[BARCODE:')) continue;
        expect(line.length, lessThanOrEqualTo(32), reason: 'Line exceeds 32 chars: "$line"');
      }

      // Verify business & customer info
      expect(receiptText, contains('STRUK PENGEMBALIAN UNIT'));
      expect(receiptText, contains('SKY261027LATE1'));
      expect(receiptText, contains('Rian Pratama'));
      expect(receiptText, contains('iPhone 15 Pro 128GB'));

      // Verify late fee, exact cash tender, and change
      expect(receiptText, contains('Biaya Keterlambatan:'));
      expect(receiptText, contains('Rp 30.000'));
      expect(receiptText, contains('Uang Diterima:'));
      expect(receiptText, contains('Kembalian   :'));
      expect(receiptText, contains('Rp 0'));
      expect(receiptText, contains('TUNAI'));
      expect(receiptText, contains('LUNAS / SELESAI'));
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Late-return fee paid with excess cash and change returned
    // -------------------------------------------------------------------------
    test('Scenario 2: Late-return fee paid with excess cash shows amount due, actual cash received, and positive change', () {
      const double lateFee = 30000;
      const double cashTendered = 50000;
      const double expectedChange = cashTendered - lateFee; // 20000

      final receipt = ReceiptModel(
        receiptNumber: 'STR-202610-3002',
        date: DateTime(2026, 10, 27, 11, 45),
        adminName: 'Budi Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.returnUnit,
        bookingCode: 'SKY261027LATE1',
        customerName: 'Rian Pratama',
        customerPhone: '081298765432',
        unitName: 'iPhone 15 Pro 128GB',
        serialNumber: 'SN-IP15P-LATE01',
        assetCode: 'AST-IP15P-LATE01',
        rentalDuration: '1 Hari',
        rentFee: 350000,
        depositFee: 0,
        finesFee: lateFee,
        discountFee: 0,
        totalAmount: lateFee,
        paidAmount: lateFee,
        remainingAmount: 0,
        paymentMethod: 'Tunai Kasir',
        paymentStatus: 'Lunas',
        cashGiven: cashTendered,
        cashChange: expectedChange,
        depositStatus: 'Tanpa Deposit',
        refundAmount: 0,
      );

      final receiptText = receipt.toEscPos58mm();
      final lines = receiptText.split('\n');

      for (final line in lines) {
        if (line.contains('[STORE_NAME:') || line.contains('[BARCODE:')) continue;
        expect(line.length, lessThanOrEqualTo(32), reason: 'Line exceeds 32 chars: "$line"');
      }

      // Expected calculation relationship:
      // Amount Due: Rp 30.000, Cash Received: Rp 50.000, Change: Rp 20.000
      expect(receiptText, contains('Biaya Keterlambatan:'));
      expect(receiptText, contains('Rp 30.000'));
      expect(receiptText, contains('Uang Diterima:'));
      expect(receiptText, contains('Rp 50.000'));
      expect(receiptText, contains('Kembalian   :'));
      expect(receiptText, contains('Rp 20.000'));
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Late-return fee paid using a non-cash payment method
    // -------------------------------------------------------------------------
    test('Scenario 3: Late-return fee paid using non-cash (QRIS) does not display cash details', () {
      final receipt = ReceiptModel(
        receiptNumber: 'STR-202610-3003',
        date: DateTime(2026, 10, 27, 12, 00),
        adminName: 'Budi Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.returnUnit,
        bookingCode: 'SKY261027LATE1',
        customerName: 'Rian Pratama',
        customerPhone: '081298765432',
        unitName: 'iPhone 15 Pro 128GB',
        serialNumber: 'SN-IP15P-LATE01',
        assetCode: 'AST-IP15P-LATE01',
        rentalDuration: '1 Hari',
        rentFee: 350000,
        depositFee: 0,
        finesFee: 30000,
        discountFee: 0,
        totalAmount: 30000,
        paidAmount: 30000,
        remainingAmount: 0,
        paymentMethod: 'QRIS',
        paymentStatus: 'Lunas',
        cashGiven: 0,
        cashChange: 0,
        depositStatus: 'Tanpa Deposit',
        refundAmount: 0,
      );

      final receiptText = receipt.toEscPos58mm();

      // Must clearly display late fee and non-cash method
      expect(receiptText, contains('Biaya Keterlambatan:'));
      expect(receiptText, contains('Rp 30.000'));
      expect(receiptText, contains('Terbayar  :'));
      expect(receiptText, contains('Metode    :'));
      expect(receiptText, contains('QRIS'));

      // MUST NOT incorrectly label the transaction amount as physical cash received
      expect(receiptText, isNot(contains('Uang Diterima:')));
      expect(receiptText, isNot(contains('Kembalian   :')));
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Late-return fee paid without a change amount
    // -------------------------------------------------------------------------
    test('Scenario 4: Late-return fee paid without change (exact cash or non-cash) avoids phantom change', () {
      // 4A: Exact cash payment shows Rp 0 change, never missing or miscalculated
      final exactCashReceipt = ReceiptModel(
        receiptNumber: 'STR-202610-3004A',
        date: DateTime(2026, 10, 27, 12, 15),
        adminName: 'Staff Admin',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.returnUnit,
        bookingCode: 'SKY261027LATE1',
        customerName: 'Rian Pratama',
        customerPhone: '081298765432',
        unitName: 'iPhone 15 Pro',
        rentalDuration: '1 Hari',
        rentFee: 350000,
        depositFee: 0,
        finesFee: 30000,
        totalAmount: 30000,
        paidAmount: 30000,
        remainingAmount: 0,
        paymentMethod: 'Tunai',
        paymentStatus: 'Lunas',
        cashGiven: 30000,
        cashChange: 0,
      );
      final exactText = exactCashReceipt.toEscPos58mm();
      expect(exactText, contains('Uang Diterima:'));
      expect(exactText, contains('Kembalian   :'));
      expect(exactText, contains('Rp 0'));

      // 4B: Transfer Bank (non-cash) completely omits cash and change labels
      final transferReceipt = exactCashReceipt.copyWith(
        receiptNumber: 'STR-202610-3004B',
        paymentMethod: 'Transfer Bank BCA',
        cashGiven: 0,
        cashChange: 0,
      );
      final transferText = transferReceipt.toEscPos58mm();
      expect(transferText, contains('Biaya Keterlambatan:'));
      expect(transferText, contains('Terbayar  :'));
      expect(transferText, isNot(contains('Uang Diterima:')));
      expect(transferText, isNot(contains('Kembalian   :')));
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Receipt printing retried after a printer error
    // -------------------------------------------------------------------------
    test('Scenario 5: Receipt printing can be retried without duplicate payments or corrupting receipt data', () async {
      final receipt = ReceiptModel(
        receiptNumber: 'STR-202610-3005',
        date: DateTime.now(),
        adminName: 'Budi Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.returnUnit,
        bookingCode: lateBooking.bookingCode,
        customerName: lateBooking.customerName,
        customerPhone: lateBooking.customerPhone,
        unitName: lateBooking.iphone.fullName,
        rentalDuration: '1 Hari',
        rentFee: lateBooking.price,
        depositFee: 0,
        finesFee: 30000,
        totalAmount: 30000,
        paidAmount: 30000,
        remainingAmount: 0,
        paymentMethod: 'Tunai',
        paymentStatus: 'Lunas',
        cashGiven: 50000,
        cashChange: 20000,
      );

      final thermalService = ThermalPrintService();

      // Simulate disconnected printer attempt
      const disconnectedPrinter = PrinterDeviceModel(
        name: 'VSC Disconnected Printer',
        address: '00:11:22:33:44:55',
        connectionType: 'bluetooth',
        isConnected: false,
      );

      final failedAttempt = await thermalService.printReceipt(
        receipt,
        targetPrinter: disconnectedPrinter,
      );
      expect(failedAttempt.isSuccess, isFalse);
      expect(failedAttempt.status, anyOf(PrintResultStatus.printerNotConnected, PrintResultStatus.timeout));

      // Receipt data remains intact after failure
      expect(receipt.finesFee, 30000);
      expect(receipt.cashGiven, 50000);
      expect(receipt.cashChange, 20000);

      // Retry print with online printer
      final onlinePrinter = PrinterDeviceModel.defaultVsc().copyWith(isConnected: true);
      final retryAttempt = await thermalService.printReceipt(
        receipt,
        targetPrinter: onlinePrinter,
      );
      expect(retryAttempt.isSuccess, isTrue);

      // Verify that the printed ESC/POS output contains correct cash information
      final escPosOutput = receipt.toEscPos58mm();
      expect(escPosOutput, contains('Biaya Keterlambatan:'));
      expect(escPosOutput, contains('Uang Diterima:'));
      expect(escPosOutput, contains('Kembalian   :'));
      expect(escPosOutput, contains('Rp 20.000'));
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Receipt regenerated from persisted transaction data
    // -------------------------------------------------------------------------
    test('Scenario 6: Receipt regenerated from JSON / persisted transaction preserves all payment fields', () {
      final originalReceipt = ReceiptModel(
        receiptNumber: 'STR-202610-3006',
        date: DateTime(2026, 10, 27, 10, 15),
        adminName: 'Budi Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.returnUnit,
        bookingCode: 'SKY261027LATE1',
        customerName: 'Rian Pratama',
        customerPhone: '081298765432',
        unitName: 'iPhone 15 Pro 128GB',
        serialNumber: 'SN-IP15P-LATE01',
        assetCode: 'AST-IP15P-LATE01',
        rentalDuration: '1 Hari',
        rentalDates: '25/10 - 26/10/2026',
        rentFee: 350000,
        depositFee: 0,
        finesFee: 30000,
        discountFee: 0,
        totalAmount: 30000,
        paidAmount: 30000,
        remainingAmount: 0,
        paymentMethod: 'TUNAI',
        paymentStatus: 'Lunas',
        cashGiven: 50000,
        cashChange: 20000,
        depositStatus: 'Tanpa Deposit',
        refundAmount: 0,
        notes: 'Denda keterlambatan diselesaikan',
      );

      // Serialize to JSON (simulating database / cache persistence)
      final json = originalReceipt.toJson();
      expect(json['receipt_number'], 'STR-202610-3006');
      expect(json['fines_fee'], 30000);
      expect(json['cash_given'], 50000);
      expect(json['cash_change'], 20000);
      expect(json['paid_amount'], 30000);
      expect(json['payment_method'], 'TUNAI');

      // Deserialize from JSON (simulating receipt re-generation)
      final regenerated = ReceiptModel.fromJson(json);

      expect(regenerated.receiptNumber, originalReceipt.receiptNumber);
      expect(regenerated.type, ReceiptType.returnUnit);
      expect(regenerated.finesFee, originalReceipt.finesFee);
      expect(regenerated.cashGiven, originalReceipt.cashGiven);
      expect(regenerated.cashChange, originalReceipt.cashChange);
      expect(regenerated.paidAmount, originalReceipt.paidAmount);
      expect(regenerated.paymentMethod, originalReceipt.paymentMethod);

      // Verify ESC/POS output is 100% identical
      expect(regenerated.toEscPos58mm(), equals(originalReceipt.toEscPos58mm()));
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Normal rental and extension receipts remain intact
    // -------------------------------------------------------------------------
    test('Scenario 7: Normal rental (pickup) and extension (extend) receipts are unaffected and remain correct', () {
      // 7A: Normal Pickup Receipt
      final pickupReceipt = ReceiptModel(
        receiptNumber: 'STR-PICKUP-001',
        date: DateTime(2026, 10, 27, 9, 0),
        adminName: 'Budi Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.pickup,
        bookingCode: 'SKY261027NORM1',
        customerName: 'Ahmad Fauzi',
        customerPhone: '081234567890',
        unitName: 'iPhone 15 Pro 128GB',
        rentalDuration: '3 Hari',
        rentFee: 450000,
        depositFee: 200000,
        totalAmount: 650000,
        paidAmount: 650000,
        remainingAmount: 0,
        paymentMethod: 'Tunai',
        paymentStatus: 'Lunas',
        cashGiven: 700000,
        cashChange: 50000,
      );

      final pickupText = pickupReceipt.toEscPos58mm();
      expect(pickupText, contains('PICKUP IPHONE'));
      expect(pickupText, contains('TOTAL BIAYA :'));
      expect(pickupText, contains('Rp 650.000'));
      expect(pickupText, contains('Uang Diterima:'));
      expect(pickupText, contains('Rp 700.000'));
      expect(pickupText, contains('Kembalian   :'));
      expect(pickupText, contains('Rp 50.000'));

      // 7B: Extension Receipt
      final extendReceipt = ReceiptModel(
        receiptNumber: 'STR-EXT-001',
        date: DateTime(2026, 10, 27, 10, 0),
        adminName: 'Budi Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.extend,
        bookingCode: 'SKY261027NORM1',
        customerName: 'Ahmad Fauzi',
        customerPhone: '081234567890',
        unitName: 'iPhone 15 Pro 128GB',
        rentalDuration: '6 Jam (Tambah Durasi)',
        rentFee: 50000,
        depositFee: 0,
        totalAmount: 50000,
        paidAmount: 50000,
        remainingAmount: 0,
        paymentMethod: 'Tunai',
        paymentStatus: 'Lunas',
        cashGiven: 100000,
        cashChange: 50000,
      );

      final extendText = extendReceipt.toEscPos58mm();
      expect(extendText, contains('STRUK PERPANJANGAN SEWA'));
      expect(extendText, contains('TAMBAH JAM (EXTEND)'));
      expect(extendText, contains('Biaya Ext :'));
      expect(extendText, contains('TOTAL     :'));
      expect(extendText, contains('Uang Diterima:'));
      expect(extendText, contains('Rp 100.000'));
      expect(extendText, contains('Kembalian   :'));
      expect(extendText, contains('Rp 50.000'));

      // 7C: On-time Return Unit Receipt with Deposit Refund
      final onTimeReturnReceipt = ReceiptModel(
        receiptNumber: 'STR-RETURN-ONTIME',
        date: DateTime(2026, 10, 27, 11, 0),
        adminName: 'Budi Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.returnUnit,
        bookingCode: 'SKY261027NORM1',
        customerName: 'Ahmad Fauzi',
        customerPhone: '081234567890',
        unitName: 'iPhone 15 Pro 128GB',
        rentalDuration: '3 Hari',
        rentFee: 450000,
        depositFee: 200000,
        finesFee: 0,
        totalAmount: 450000,
        paidAmount: 450000,
        remainingAmount: 0,
        refundAmount: 200000,
        paymentMethod: 'Tunai Kasir',
        paymentStatus: 'Lunas',
        depositStatus: 'Telah Direfund',
      );

      final onTimeText = onTimeReturnReceipt.toEscPos58mm();
      expect(onTimeText, contains('STRUK PENGEMBALIAN UNIT'));
      expect(onTimeText, contains('Deposit   :'));
      expect(onTimeText, contains('Rp 200.000'));
      expect(onTimeText, contains('Refund Dep. :'));
      expect(onTimeText, isNot(contains('Biaya Keterlambatan:')));
      expect(onTimeText, isNot(contains('Pot. Denda:')));
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Existing payment records and financial totals remain unchanged
    // -------------------------------------------------------------------------
    test('Scenario 8: Submitting late return payment and generating receipt preserves original booking totals', () async {
      final initialPrice = lateBooking.price;
      final initialDeposit = lateBooking.deposit;
      const double lateFeeAmount = 30000;
      const double cashTendered = 50000;

      // Submit payment for penalty
      final paymentResult = await repository.submitBookingPaymentDetail(
        bookingCode: lateBooking.bookingCode,
        amount: lateFeeAmount,
        pay: cashTendered,
        paymentMethod: 'cash',
        type: 'penalty',
        note: 'Pembayaran Denda Keterlambatan',
      );

      expect(paymentResult.amount, lateFeeAmount);
      expect(paymentResult.cashReceived, cashTendered);
      expect(paymentResult.change, 20000);
      expect(paymentResult.isSettled, isTrue);

      // Complete the return
      final returnedBooking = await repository.completeReturn(
        bookingCode: lateBooking.bookingCode,
        physicalCondition: 'Mulus',
        batteryHealthFinal: 99,
        lateFee: lateFeeAmount,
        damageFee: 0,
        depositRefunded: 0,
        refundMethod: 'Tunai Kasir',
        accessoriesReturned: ['Lengkap'],
      );

      // Original contract totals remain intact
      expect(returnedBooking.price, initialPrice);
      expect(returnedBooking.deposit, initialDeposit);
      expect(returnedBooking.status, BookingStatus.returned);
      expect(returnedBooking.iphone.status, 'tersedia');

      // Verify receipt created from the payment result
      final receipt = ReceiptModel(
        receiptNumber: paymentResult.receiptNumber,
        date: paymentResult.paidAt,
        adminName: 'Admin Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.returnUnit,
        bookingCode: paymentResult.bookingCode,
        customerName: paymentResult.customerName,
        customerPhone: lateBooking.customerPhone,
        unitName: paymentResult.unitName,
        rentalDuration: '${lateBooking.durationDays} Hari',
        rentFee: returnedBooking.price,
        depositFee: 0,
        finesFee: paymentResult.amount,
        totalAmount: paymentResult.amount,
        paidAmount: paymentResult.amount,
        remainingAmount: 0,
        paymentMethod: paymentResult.paymentMethod.toUpperCase(),
        paymentStatus: 'Lunas',
        cashGiven: paymentResult.cashReceived,
        cashChange: paymentResult.change,
        depositStatus: 'Tanpa Deposit',
      );

      await repository.saveReceipt(receipt);

      final history = await repository.getReceiptHistory();
      final savedReceipt = history.firstWhere((r) => r.receiptNumber == paymentResult.receiptNumber);
      expect(savedReceipt.finesFee, 30000);
      expect(savedReceipt.cashGiven, 50000);
      expect(savedReceipt.cashChange, 20000);

      final escPos = savedReceipt.toEscPos58mm();
      expect(escPos, contains('Biaya Keterlambatan:'));
      expect(escPos, contains('Rp 30.000'));
      expect(escPos, contains('Uang Diterima:'));
      expect(escPos, contains('Rp 50.000'));
      expect(escPos, contains('Kembalian   :'));
      expect(escPos, contains('Rp 20.000'));
    });
  });
}
