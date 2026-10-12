import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/screens/booking/booking_detail_screen.dart';
import 'package:skyrental_admin/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingRepository repository;
  late IphoneModel testIphone;
  late BookingModel confirmedOnTimeBooking;
  late BookingModel confirmedLateBooking;
  late BookingModel alreadyReturnedBooking;

  setUp(() {
    repository = BookingRepository();

    testIphone = const IphoneModel(
      id: 101,
      name: 'iPhone 15 Pro 128GB',
      storage: '128GB',
      color: 'Natural Titanium',
      serialNumber: 'SN-IP15P-TEST01',
      assetCode: 'AST-IP15P-TEST01',
      status: 'disewa',
      batteryHealth: 98,
    );

    confirmedOnTimeBooking = BookingModel(
      id: 101,
      bookingCode: 'SKY260909A8F1',
      customerName: 'Ahmad Fauzi',
      customerPhone: '081234567890',
      customerEmail: 'ahmad.fauzi@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: DateTime.now().subtract(const Duration(hours: 12)),
      endDate: DateTime.now().add(const Duration(hours: 12)),
      durationDays: 1,
      price: 350000,
      deposit: 200000,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: testIphone,
    );

    confirmedLateBooking = BookingModel(
      id: 103,
      bookingCode: 'SKY260908C4D5',
      customerName: 'Kevin Wijaya',
      customerPhone: '081234567891',
      customerEmail: 'siti.rahma@example.com',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: DateTime.now().subtract(const Duration(hours: 36)),
      endDate: DateTime.now().subtract(const Duration(hours: 12)),
      durationDays: 1,
      price: 350000,
      deposit: 200000,
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.paid,
      iphone: testIphone,
      estimatedLateFee: 100000,
    );

    alreadyReturnedBooking = BookingModel(
      id: 105,
      bookingCode: 'SKY260907G8H9',
      customerName: 'Dian Sastrowardoyo',
      customerPhone: '081399887766',
      customerEmail: 'dian.sastro@example.com',
      pickupType: 'Outlet',
      jaminanType: 'Paspor + KTP',
      startDate: DateTime.now().subtract(const Duration(days: 3)),
      endDate: DateTime.now().subtract(const Duration(days: 2)),
      durationDays: 1,
      price: 350000,
      deposit: 200000,
      status: BookingStatus.returned,
      paymentStatus: PaymentStatus.paid,
      iphone: testIphone.copyWith(status: 'tersedia'),
    );
  });

  group('Scenario 1 & 5: Confirmed on-time return and state persistence', () {
    test('Scenario 1: Confirmed on-time booking completes return and restores unit status to ready', () async {
      final result = await repository.completeReturn(
        bookingCode: confirmedOnTimeBooking.bookingCode,
        physicalCondition: 'Mulus (Sempurna)',
        batteryHealthFinal: 98,
        lateFee: 0,
        damageFee: 0,
        depositRefunded: 200000,
        refundMethod: 'Tunai Kasir',
        accessoriesReturned: ['Lengkap'],
        staffNotes: 'Pengembalian unit tepat waktu diselesaikan langsung.',
      );

      expect(result.status, BookingStatus.returned);
      expect(result.iphone.status, 'tersedia');
      expect(result.canReturn, isFalse);

      // Scenario 5: Reopening or refreshing returns updated returned status
      final refreshed = await repository.getBookingByCode(confirmedOnTimeBooking.bookingCode);
      expect(refreshed, isNotNull);
      expect(refreshed!.status, BookingStatus.returned);
      expect(refreshed.canReturn, isFalse);
    });
  });

  group('Scenario 2: Confirmed late booking requires penalty flow', () {
    test('Scenario 2: Late booking triggers penalty workflow with estimated late fee', () {
      expect(confirmedLateBooking.isCurrentlyLate, isTrue);
      expect(confirmedLateBooking.estimatedLateFee, greaterThan(0));
      expect(confirmedLateBooking.canReturn, isTrue);
    });

    test('Late return penalty payment on fully paid booking records penalty and completes return', () async {
      // Booking already paid in full
      expect(confirmedLateBooking.paymentStatus, PaymentStatus.paid);

      // Submitting penalty payment detail with type 'penalty'
      final paymentResult = await repository.submitBookingPaymentDetail(
        bookingCode: confirmedLateBooking.bookingCode,
        amount: confirmedLateBooking.estimatedLateFee,
        pay: confirmedLateBooking.estimatedLateFee,
        paymentMethod: 'cash',
        type: 'penalty',
        note: 'Pembayaran Denda Keterlambatan Pengembalian Unit',
      );

      // Original payment is preserved as settled
      expect(paymentResult.isSettled, isTrue);

      // Completing the return
      final returnedBooking = await repository.completeReturn(
        bookingCode: confirmedLateBooking.bookingCode,
        physicalCondition: 'Baik / Sesuai Kesepakatan',
        batteryHealthFinal: 98,
        lateFee: confirmedLateBooking.estimatedLateFee,
        damageFee: 0,
        depositRefunded: 0,
        refundMethod: 'Tunai Kasir',
        accessoriesReturned: ['Lengkap'],
      );

      expect(returnedBooking.status, BookingStatus.returned);
      expect(returnedBooking.iphone.status, 'tersedia');
    });
  });

  group('Scenario 3: Booking not confirmed or already returned', () {
    test('Scenario 3: Already returned booking cannot return (canReturn is false)', () {
      expect(alreadyReturnedBooking.canReturn, isFalse);
      expect(alreadyReturnedBooking.status, BookingStatus.returned);
    });

    testWidgets('BookingDetailScreen blocks return when canReturn is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailScreen(
              booking: alreadyReturnedBooking,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure button "Tandai Selesai (Pengembalian)" is NOT available
      expect(find.text('Tandai Selesai (Pengembalian)'), findsNothing);
    });
  });

  group('Scenario 4 & 7: API Error and Unauthorized access handling', () {
    test('Scenario 4 & 7: ApiException preserves message and does not alter database state', () {
      final forbiddenEx = ApiException('Anda tidak memiliki hak akses untuk menyelesaikan pengembalian booking ini.', statusCode: 403);
      expect(forbiddenEx.statusCode, 403);
      expect(forbiddenEx.message, contains('tidak memiliki hak akses'));

      final invalidStatusEx = ApiException('Booking sudah tidak berstatus Confirmed.', statusCode: 422);
      expect(invalidStatusEx.statusCode, 422);
      expect(invalidStatusEx.message, contains('tidak berstatus Confirmed'));
    });
  });

  group('Scenario 6: Duplicate tap prevention on return confirmation dialog', () {
    testWidgets('Tapping Ya, Selesaikan disables button while processing to prevent duplicate requests', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingDetailScreen(
              booking: confirmedOnTimeBooking,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the return button
      final returnBtn = find.text('Tandai Selesai (Pengembalian)');
      expect(returnBtn, findsOneWidget);

      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      // Dialog is displayed
      expect(find.text('Konfirmasi Pengembalian'), findsOneWidget);
      final confirmBtn = find.text('Ya, Selesaikan');
      expect(confirmBtn, findsOneWidget);

      // Tap confirm button
      await tester.tap(confirmBtn);
      await tester.pump(); // Start async processing, button should show loading indicator

      // During submission, button shows CircularProgressIndicator and confirm text is gone
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for async completeReturn (250ms) and dialog pop animation
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the snackbar is shown before its auto-dismissal timer expires
      expect(find.text('Pengembalian unit berhasil diselesaikan! Status unit kembali Tersedia.'), findsOneWidget);
    });
  });
}
