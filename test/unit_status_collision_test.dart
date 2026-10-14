import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';

void main() {
  group('Unit Status Collision & Asset Code Isolation Tests', () {
    late BookingRepository repository;

    const unitA = IphoneModel(
      id: 22,
      name: 'iPhone 11 Hijau',
      storage: '128GB',
      color: 'Hijau',
      serialNumber: 'G0NH902VN72P',
      assetCode: '-',
      status: 'ready',
    );

    const unitB = IphoneModel(
      id: 59,
      name: 'iPhone XR Merah',
      storage: '64GB',
      color: 'Merah',
      serialNumber: 'DX4F9WZDKXKN',
      assetCode: '-',
      status: 'ready',
    );

    final bookingForUnitB = BookingModel(
      id: 4282,
      bookingCode: 'SKY261012FENZ',
      customerName: 'Nafis Inesya',
      customerPhone: '081234567890',
      customerEmail: 'nafis@example.com',
      address: 'Genteng',
      pickupType: 'Outlet',
      jaminanType: 'KTP',
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 1)),
      durationDays: 2,
      price: 200000,
      deposit: 0,
      status: BookingStatus.rented,
      paymentStatus: PaymentStatus.paid,
      iphone: unitB.copyWith(status: 'disewa'),
    );

    setUp(() {
      repository = BookingRepository();
      repository.rawBookings.clear();
      repository.rawBookings.add(bookingForUnitB);
    });

    test('Unit A (iPhone 11 Hijau) with assetCode "-" must NOT be marked as currently rented', () {
      final isRented = repository.isUnitCurrentlyRented(
        unitA.assetCode,
        unitId: unitA.id,
        serialNumber: unitA.serialNumber,
      );
      expect(isRented, isFalse);
    });

    test('Unit B (iPhone XR Merah) with active booking IS correctly marked as currently rented', () {
      final isRented = repository.isUnitCurrentlyRented(
        unitB.assetCode,
        unitId: unitB.id,
        serialNumber: unitB.serialNumber,
      );
      expect(isRented, isTrue);
    });

    test('getActiveBookingForUnitSync for Unit A returns null (no cross-contamination from Unit B)', () {
      final booking = repository.getActiveBookingForUnitSync(
        unitA.assetCode,
        unitId: unitA.id,
        serialNumber: unitA.serialNumber,
      );
      expect(booking, isNull);
    });

    test('getActiveBookingForUnitSync for Unit B correctly returns booking 4282 for Nafis Inesya', () {
      final booking = repository.getActiveBookingForUnitSync(
        unitB.assetCode,
        unitId: unitB.id,
        serialNumber: unitB.serialNumber,
      );
      expect(booking, isNotNull);
      expect(booking!.id, equals(4282));
      expect(booking.customerName, equals('Nafis Inesya'));
      expect(booking.iphone.id, equals(59));
      expect(booking.iphone.serialNumber, equals('DX4F9WZDKXKN'));
    });

    test('isUnitCurrentlyRented with generic "-" and no unitId or serial returns false', () {
      final isRented = repository.isUnitCurrentlyRented('-');
      expect(isRented, isFalse);
    });

    test('getActiveBookingForUnitSync with generic "-" and no unitId or serial returns null', () {
      final booking = repository.getActiveBookingForUnitSync('-');
      expect(booking, isNull);
    });
  });
}
