import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/receipt_format_settings.dart';
import 'package:skyrental_admin/models/receipt_model.dart';
import 'package:skyrental_admin/screens/payment/payment_deposit_screen.dart';

void main() {
  group('Extension Payment and Receipt Regression Tests', () {
    late BookingRepository repository;

    setUp(() {
      repository = BookingRepository();
    });

    test('ReceiptType.extend has correct label and json parsing', () {
      expect(ReceiptType.extend.label, 'TAMBAH JAM (EXTEND)');

      final json = {
        'receipt_number': 'REC-EXT-001',
        'type': 'extend',
        'date': '2026-10-26T10:00:00Z',
        'booking_code': 'SKY-EXT-001',
        'customer_name': 'Budi Santoso',
        'customer_phone': '081234567890',
        'unit_name': 'iPhone 11',
        'serial_number': 'DNPP9811M991',
        'rental_duration': '6 Jam (Tambah Durasi)',
        'rent_fee': 50000.0,
        'deposit_fee': 0.0,
        'total_amount': 50000.0,
        'paid_amount': 50000.0,
        'remaining_amount': 0.0,
        'payment_method': 'TUNAI (CASH)',
        'payment_status': 'LUNAS',
      };

      final receipt = ReceiptModel.fromJson(json);
      expect(receipt.type, ReceiptType.extend);
      expect(receipt.totalAmount, 50000.0);
      expect(receipt.paidAmount, 50000.0);
      expect(receipt.remainingAmount, 0.0);
    });

    test('PaymentTypeOption.extend maps to ReceiptType.extend', () {
      expect(PaymentTypeOption.extend.receiptType, ReceiptType.extend);
      expect(PaymentTypeOption.extend.id, 'extend');
    });

    test('ReceiptModel.toEscPos58mm generates correct 32-col layout for extend', () {
      final receipt = ReceiptModel(
        receiptNumber: 'REC-EXT-261026-001',
        date: DateTime(2026, 10, 26, 14, 30),
        adminName: 'Admin Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.extend,
        bookingCode: 'SKY11TEST01',
        customerName: 'Budi Santoso',
        customerPhone: '081234567890',
        unitName: 'iPhone 11',
        serialNumber: 'DNPP9811M991',
        rentalDuration: '6 Jam (Tambah Durasi)',
        rentFee: 50000.0,
        depositFee: 0.0,
        totalAmount: 50000.0,
        paidAmount: 50000.0,
        remainingAmount: 0.0,
        paymentMethod: 'Tunai (Cash)',
        paymentStatus: 'LUNAS',
        cashGiven: 50000.0,
        cashChange: 0.0,
      );

      final rawText = receipt.toEscPos58mm(formatSettings: const ReceiptFormatSettings());
      final lines = rawText.split('\n');

      // Every line must not exceed 32 characters (excluding special formatting tags)
      for (final line in lines) {
        if (line.contains('[STORE_NAME:') || line.contains('[BARCODE:')) continue;
        expect(line.length, lessThanOrEqualTo(32), reason: 'Line exceeds 32 chars: "$line"');
      }

      expect(rawText, contains('STRUK PERPANJANGAN SEWA'));
      expect(rawText, contains('TAMBAH JAM (EXTEND)'));
      expect(rawText, contains('Biaya Ext :'));
      expect(rawText, contains('Rp 50.000'));
      expect(rawText, contains('TOTAL     :'));
      expect(rawText, contains('Terbayar  :'));
      // Must NOT show 70.000 as extension transaction total
      expect(rawText, isNot(contains('TOTAL     :        Rp 70.000')));
    });

    test('Test A — Fully paid original rental followed by an extension preserves price and status', () async {
      final bookings = await repository.getBookings();
      final target = bookings.first;
      final contractPrice = target.price;
      final initialDuration = target.durationDays;

      // Fully pay the booking
      await repository.submitBookingPaymentDetail(
        bookingCode: target.bookingCode,
        amount: target.totalBill,
        pay: target.totalBill,
        paymentMethod: 'cash',
        type: 'payment',
      );

      // Execute extension: 6 hours for Rp50,000
      final updated = await repository.extendBooking(
        bookingCode: target.bookingCode,
        hours: 6,
        price: 50000.0,
        paymentMethod: 'cash',
        pay: 50000.0,
        note: 'Penambahan durasi sewa 6 jam',
      );

      // Expected results:
      // - Original rental price remains intact (not increased by extension fee)
      expect(updated.price, contractPrice);
      // - Duration is updated: original + 6
      expect(updated.durationDays, initialDuration + 6);
      // - Booking payment status remains paid (not reset to partial/dp)
      expect(updated.paymentStatus, PaymentStatus.paid);
      // - Outstanding balance is 0
      final outstanding = (updated.totalBill - updated.downPayment).clamp(0.0, double.infinity);
      expect(outstanding, 0.0);
    });

    test('Test B — Partially paid original rental preserves partial status after extension', () async {
      final bookings = await repository.getBookings();
      final target = bookings.first;

      // Update booking to partial state (price target.price, paid DP 30,000)
      await repository.submitBookingPaymentDetail(
        bookingCode: target.bookingCode,
        amount: 30000.0,
        pay: 30000.0,
        paymentMethod: 'cash',
        type: 'dp',
      );

      // Execute extension: 6 hours for Rp50,000
      final updated = await repository.extendBooking(
        bookingCode: target.bookingCode,
        hours: 6,
        price: 50000.0,
        paymentMethod: 'cash',
        pay: 50000.0,
        note: 'Penambahan durasi sewa 6 jam',
      );

      // Must remain partial because original rental still has unpaid balance!
      expect(updated.paymentStatus, PaymentStatus.partial);
    });

    test('Test D — Multiple extensions accumulate duration while preserving contract price', () async {
      final bookings = await repository.getBookings();
      final target = bookings.first;
      final initialDuration = target.durationDays;
      final contractPrice = target.price;

      // First extension: 6 hours, Rp50,000
      final ext1 = await repository.extendBooking(
        bookingCode: target.bookingCode,
        hours: 6,
        price: 50000.0,
        paymentMethod: 'cash',
      );
      expect(ext1.durationDays, initialDuration + 6);
      expect(ext1.price, contractPrice);

      // Second extension: 12 hours, Rp75,000
      final ext2 = await repository.extendBooking(
        bookingCode: target.bookingCode,
        hours: 12,
        price: 75000.0,
        paymentMethod: 'cash',
      );
      expect(ext2.durationDays, initialDuration + 18);
      expect(ext2.price, contractPrice);
    });

    test('Test F — Initial rental receipt retains initial rental details', () {
      final receipt = ReceiptModel(
        receiptNumber: 'REC-INIT-001',
        date: DateTime(2026, 10, 25, 10, 0),
        adminName: 'Admin Kasir',
        branchName: 'SKYRENTAL YOGYAKARTA',
        type: ReceiptType.paymentSettlement,
        bookingCode: 'SKY-INIT-001',
        customerName: 'Maya Indah',
        customerPhone: '081234567895',
        unitName: 'iPhone 11',
        rentalDuration: '1 Hari (24 Jam)',
        rentFee: 70000.0,
        depositFee: 0.0,
        totalAmount: 70000.0,
        paidAmount: 70000.0,
        remainingAmount: 0.0,
        paymentMethod: 'Tunai (Cash)',
        paymentStatus: 'LUNAS',
      );

      final rawText = receipt.toEscPos58mm();
      expect(rawText, contains('Biaya Sewa'));
      expect(rawText, contains('Rp 70.000'));
      expect(rawText, contains('TOTAL BIAYA :'));
      expect(rawText, contains('Terbayar    :'));
    });
  });
}
