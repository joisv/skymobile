import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';

void main() {
  group('Issue 2: Storage Capacity Dynamic Display Tests', () {
    test('IphoneModel without storage does not append 128GB to fullName', () {
      const unit = IphoneModel(
        id: 1,
        name: 'iPhone 13 Pink',
        storage: '',
        color: 'Pink',
        serialNumber: 'MGHRYH75VK',
        assetCode: 'IPH-01',
        status: 'tersedia',
      );

      expect(unit.storage, equals(''));
      expect(unit.fullName, equals('iPhone 13 Pink'));
      expect(unit.modelName, equals('iPhone 13 Pink'));
      expect(unit.fullDisplayName, equals('iPhone 13 Pink - Pink'));
    });

    test('IphoneModel with storage dynamically appends storage to fullName', () {
      const unit = IphoneModel(
        id: 2,
        name: 'iPhone 15 Pro',
        storage: '256GB',
        color: 'Natural Titanium',
        serialNumber: 'SN-IPH15-256',
        assetCode: 'IPH-02',
        status: 'tersedia',
      );

      expect(unit.storage, equals('256GB'));
      expect(unit.fullName, equals('iPhone 15 Pro 256GB'));
      expect(unit.modelName, equals('iPhone 15 Pro 256GB'));
      expect(unit.fullDisplayName, equals('iPhone 15 Pro 256GB - Natural Titanium'));
    });

    test('IphoneModel.fromJson parses null/empty storage as empty string without defaulting to 128GB', () {
      final jsonWithoutStorage = {
        'id': 10,
        'name': 'iPhone 11 Putih',
        'color': 'Putih',
        'serial_number': 'FFXH3ZAAN72J',
        'asset_code': 'IPH-11-01',
        'status': 'ready',
      };

      final parsed = IphoneModel.fromJson(jsonWithoutStorage);

      expect(parsed.storage, equals(''));
      expect(parsed.fullName, equals('iPhone 11 Putih'));
      expect(parsed.fullName, isNot(contains('128GB')));
    });

    test('IphoneModel.fromJson preserves actual storage when provided', () {
      final jsonWithStorage = {
        'id': 11,
        'name': 'iPhone 14 Biru',
        'storage': '512GB',
        'color': 'Biru',
        'serial_number': 'W4D6NNPQJR',
        'asset_code': 'IPH-14-01',
        'status': 'ready',
      };

      final parsed = IphoneModel.fromJson(jsonWithStorage);

      expect(parsed.storage, equals('512GB'));
      expect(parsed.fullName, equals('iPhone 14 Biru 512GB'));
    });

    test('BookingModel.fromJson fallback iphoneModel does not invent 128GB', () {
      final minimalBookingJson = {
        'id': 100,
        'booking_code': 'BK-TEST-NOIPH',
        'customer_name': 'Ahmad',
        'customer_phone': '08123456789',
      };

      final booking = BookingModel.fromJson(minimalBookingJson);

      expect(booking.iphone.storage, equals(''));
      expect(booking.iphone.fullName, equals('iPhone Unit'));
      expect(booking.iphone.fullName, isNot(contains('128GB')));
    });
  });

  group('Issue 1: Transaction Queue Search by Serial Number Tests', () {
    late List<BookingModel> queue;
    final now = DateTime(2026, 10, 16, 10, 0);

    setUp(() {
      queue = [
        BookingModel(
          id: 1,
          bookingCode: 'BK-001',
          customerName: 'Budi Santoso',
          customerPhone: '0811111111',
          customerEmail: 'budi@test.com',
          pickupType: 'Outlet',
          jaminanType: 'KTP',
          startDate: now,
          endDate: now.add(const Duration(days: 1)),
          durationDays: 1,
          price: 150000,
          deposit: 0,
          status: BookingStatus.confirmed,
          paymentStatus: PaymentStatus.paid,
          iphone: const IphoneModel(
            id: 1,
            name: 'iPhone 13 Pink',
            storage: '',
            color: 'Pink',
            serialNumber: 'MGHRYH75VK',
            assetCode: 'IPH-13-01',
            status: 'tersedia',
          ),
        ),
        BookingModel(
          id: 2,
          bookingCode: 'BK-002',
          customerName: 'Siti Rahma',
          customerPhone: '0822222222',
          customerEmail: 'siti@test.com',
          pickupType: 'Delivery',
          jaminanType: 'SIM',
          startDate: now,
          endDate: now.add(const Duration(days: 2)),
          durationDays: 2,
          price: 300000,
          deposit: 100000,
          status: BookingStatus.rented,
          paymentStatus: PaymentStatus.paid,
          iphone: const IphoneModel(
            id: 2,
            name: 'iPhone 11 Putih',
            storage: '',
            color: 'Putih',
            serialNumber: 'FFXH3ZAAN72J',
            assetCode: 'IPH-11-02',
            status: 'disewa',
          ),
        ),
        BookingModel(
          id: 3,
          bookingCode: 'BK-003',
          customerName: 'Dewi Lestari',
          customerPhone: '0833333333',
          customerEmail: 'dewi@test.com',
          pickupType: 'Outlet',
          jaminanType: 'KTP',
          startDate: now,
          endDate: now.add(const Duration(days: 1)),
          durationDays: 1,
          price: 200000,
          deposit: 0,
          status: BookingStatus.confirmed,
          paymentStatus: PaymentStatus.paid,
          iphone: const IphoneModel(
            id: 3,
            name: 'iPhone 14 Biru',
            storage: '256GB',
            color: 'Biru',
            serialNumber: 'W4D6NNPQJR',
            assetCode: 'IPH-14-03',
            status: 'tersedia',
          ),
        ),
      ];
    });

    List<BookingModel> filterQueue(List<BookingModel> baseItems, String searchQuery) {
      if (searchQuery.trim().isEmpty) {
        return List<BookingModel>.from(baseItems);
      }
      final q = searchQuery.trim().toLowerCase();
      return baseItems.where((b) {
        final matchSerial = b.iphone.serialNumber.isNotEmpty &&
            b.iphone.serialNumber != '-' &&
            b.iphone.serialNumber.toLowerCase().contains(q);
        final matchAsset = b.iphone.assetCode.isNotEmpty &&
            b.iphone.assetCode != '-' &&
            b.iphone.assetCode.toLowerCase().contains(q);
        return b.customerName.toLowerCase().contains(q) ||
            b.bookingCode.toLowerCase().contains(q) ||
            b.customerPhone.toLowerCase().contains(q) ||
            b.iphone.modelName.toLowerCase().contains(q) ||
            b.iphone.name.toLowerCase().contains(q) ||
            matchSerial ||
            matchAsset;
      }).toList();
    }

    test('Searching with complete serial number finds the matching transaction', () {
      final results = filterQueue(queue, 'MGHRYH75VK');
      expect(results.length, equals(1));
      expect(results.first.bookingCode, equals('BK-001'));
      expect(results.first.iphone.serialNumber, equals('MGHRYH75VK'));
    });

    test('Searching with partial serial number finds the matching transaction', () {
      final results = filterQueue(queue, 'FFXH');
      expect(results.length, equals(1));
      expect(results.first.bookingCode, equals('BK-002'));
      expect(results.first.customerName, equals('Siti Rahma'));
    });

    test('Searching is case-insensitive for serial number', () {
      final results = filterQueue(queue, 'w4d6nnpqjr');
      expect(results.length, equals(1));
      expect(results.first.bookingCode, equals('BK-003'));
      expect(results.first.iphone.serialNumber, equals('W4D6NNPQJR'));
    });

    test('Searching by asset code also works', () {
      final results = filterQueue(queue, 'IPH-11-02');
      expect(results.length, equals(1));
      expect(results.first.bookingCode, equals('BK-002'));
    });

    test('Existing searches by customer name, booking code, and iPhone name still work', () {
      expect(filterQueue(queue, 'budi').length, equals(1));
      expect(filterQueue(queue, 'BK-002').length, equals(1));
      expect(filterQueue(queue, 'iPhone 14').length, equals(1));
      expect(filterQueue(queue, '083333').length, equals(1));
    });

    test('Searching for non-existent serial number returns empty list', () {
      final results = filterQueue(queue, 'NONEXISTENT_SN_123');
      expect(results, isEmpty);
    });

    test('Empty or whitespace search query restores all items', () {
      final resultsEmpty = filterQueue(queue, '');
      expect(resultsEmpty.length, equals(3));

      final resultsWhitespace = filterQueue(queue, '   ');
      expect(resultsWhitespace.length, equals(3));
    });
  });
}
