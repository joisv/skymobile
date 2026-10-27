import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/models/receipt_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingRepository repository;

  final primaryIphone = const IphoneModel(
    id: 101,
    name: 'iPhone 15 Pro',
    storage: '128GB',
    color: 'Natural Titanium',
    serialNumber: 'F2LNK98XK0G',
    assetCode: 'AST-IP15P-001',
    status: 'ready',
    durations: [
      IphoneDurationOption(id: 1, name: '24 Jam', hours: 24, price: 150000.0),
      IphoneDurationOption(id: 2, name: '12 Jam', hours: 12, price: 90000.0),
    ],
  );

  final gimbalAddon = const IphoneModel(
    id: 501,
    name: 'DJI Osmo Mobile 6 Gimbal',
    storage: '',
    color: 'Slate Gray',
    serialNumber: 'OSMO6-9812',
    assetCode: 'AST-ADD-001',
    status: 'ready',
    isAddon: true,
    durations: [
      IphoneDurationOption(id: 5011, name: '24 Jam', hours: 24, price: 45000.0),
      IphoneDurationOption(id: 5012, name: '12 Jam', hours: 12, price: 30000.0),
    ],
  );

  final powerbankAddon = const IphoneModel(
    id: 502,
    name: 'Anker MagSafe Powerbank 10000mAh',
    storage: '',
    color: 'Black',
    serialNumber: 'ANKER10K-441',
    assetCode: 'AST-ADD-002',
    status: 'ready',
    isAddon: true,
    durations: [
      IphoneDurationOption(id: 5021, name: '24 Jam', hours: 24, price: 25000.0),
      IphoneDurationOption(id: 5022, name: '12 Jam', hours: 12, price: 15000.0),
    ],
  );

  setUp(() {
    repository = BookingRepository();
    repository.setTestInventory([primaryIphone, gimbalAddon, powerbankAddon]);
  });

  group('Add-on Device Booking, Pricing & Payment Integration', () {
    test('Scenario 1: Legacy booking with 0 add-ons calculates correct single unit price and omits add-on section on receipt', () async {
      final now = DateTime.now();
      final booking = await repository.createBooking(
        customerName: 'Budi Santoso',
        customerPhone: '+62-812-3456-7890',
        customerEmail: 'budi@customer.local',
        iphone: primaryIphone,
        startDate: now,
        endDate: now.add(const Duration(hours: 24)),
        durationDays: 24,
        price: 150000.0,
        deposit: 0.0,
        jaminanType: 'KTP Asli Fisik',
      );

      expect(booking.addonDevices, isEmpty);
      expect(booking.hasAddons, isFalse);
      expect(booking.primarySubtotal, 150000.0);
      expect(booking.addonSubtotal, 0.0);
      expect(booking.price, 150000.0);

      // Verify receipt output
      final receipt = ReceiptModel(
        receiptNumber: 'STR-20261027-001',
        date: now,
        adminName: 'Kasir Utama',
        type: ReceiptType.paymentSettlement,
        bookingCode: booking.bookingCode,
        customerName: booking.customerName,
        customerPhone: booking.customerPhone,
        unitName: booking.iphone.modelName,
        serialNumber: booking.iphone.serialNumber,
        assetCode: booking.iphone.assetCode,
        rentalDuration: '24 Jam',
        rentFee: booking.price,
        depositFee: 0.0,
        totalAmount: 150000.0,
        paidAmount: 150000.0,
        remainingAmount: 0.0,
        paymentMethod: 'TUNAI',
        paymentStatus: 'LUNAS',
        cashGiven: 150000.0,
        cashChange: 0.0,
      );

      final escPos = receipt.toEscPos58mm();
      expect(escPos, isNot(contains('ITEM TAMBAHAN / ADD-ON:')));
      expect(escPos, contains('Biaya Sewa  :'));
      expect(escPos, contains('Rp 150.000'));
    });

    test('Scenario 2: Booking with 1 primary iPhone + 1 add-on aggregates subtotals and prints itemized receipt', () async {
      final now = DateTime.now();
      const primaryPrice = 150000.0;
      const addonPrice = 45000.0;
      final totalRent = primaryPrice + addonPrice;

      final booking = await repository.createBooking(
        customerName: 'Siti Rahma',
        customerPhone: '+62-857-1234-5678',
        customerEmail: 'siti@customer.local',
        iphone: primaryIphone,
        addonDevices: [gimbalAddon],
        primarySubtotal: primaryPrice,
        addonSubtotal: addonPrice,
        startDate: now,
        endDate: now.add(const Duration(hours: 24)),
        durationDays: 24,
        price: totalRent,
        deposit: 0.0,
        jaminanType: 'SIM A/C Aktif',
      );

      expect(booking.addonDevices.length, 1);
      expect(booking.hasAddons, isTrue);
      expect(booking.addonDevices.first.name, 'DJI Osmo Mobile 6 Gimbal');
      expect(booking.primarySubtotal, 150000.0);
      expect(booking.addonSubtotal, 45000.0);
      expect(booking.price, 195000.0);

      // Verify thermal receipt
      final receipt = ReceiptModel(
        receiptNumber: 'STR-20261027-002',
        date: now,
        adminName: 'Kasir Utama',
        type: ReceiptType.paymentSettlement,
        bookingCode: booking.bookingCode,
        customerName: booking.customerName,
        customerPhone: booking.customerPhone,
        unitName: booking.iphone.modelName,
        serialNumber: booking.iphone.serialNumber,
        assetCode: booking.iphone.assetCode,
        addonItems: [
          ReceiptAddonItem(
            name: gimbalAddon.name,
            assetCode: gimbalAddon.assetCode,
            serialNumber: gimbalAddon.serialNumber,
            price: addonPrice,
          ),
        ],
        primaryRentFee: booking.primarySubtotal,
        addonRentFee: booking.addonSubtotal,
        rentalDuration: '24 Jam',
        rentFee: booking.price,
        depositFee: 0.0,
        totalAmount: 195000.0,
        paidAmount: 195000.0,
        remainingAmount: 0.0,
        paymentMethod: 'TUNAI',
        paymentStatus: 'LUNAS',
        cashGiven: 200000.0,
        cashChange: 5000.0,
      );

      final escPos = receipt.toEscPos58mm();
      expect(escPos, contains('ITEM TAMBAHAN / ADD-ON:'));
      expect(escPos, contains('1. DJI Osmo Mobile 6 Gimbal'));
      expect(escPos, contains('[AST-ADD-001]'));
      expect(escPos, contains('Sewa iPhone :'));
      expect(escPos, contains('Rp 150.000'));
      expect(escPos, contains('Sewa Add-on :'));
      expect(escPos, contains('Rp 45.000'));
      expect(escPos, contains('TOTAL BIAYA :'));
      expect(escPos, contains('Rp 195.000'));
      expect(escPos, contains('Uang Diterima:'));
      expect(escPos, contains('Rp 200.000'));
      expect(escPos, contains('Kembalian   :'));
      expect(escPos, contains('Rp 5.000'));
    });

    test('Scenario 3: Booking with 1 primary iPhone + multiple add-ons aggregates all items correctly', () async {
      final now = DateTime.now();
      const primaryPrice = 150000.0;
      const addon1Price = 45000.0;
      const addon2Price = 25000.0;
      final totalAddons = addon1Price + addon2Price;
      final totalRent = primaryPrice + totalAddons;

      final booking = await repository.createBooking(
        customerName: 'Kevin Wijaya',
        customerPhone: '+62-813-9988-7766',
        customerEmail: 'kevin@customer.local',
        iphone: primaryIphone,
        addonDevices: [gimbalAddon, powerbankAddon],
        primarySubtotal: primaryPrice,
        addonSubtotal: totalAddons,
        startDate: now,
        endDate: now.add(const Duration(hours: 24)),
        durationDays: 24,
        price: totalRent,
        deposit: 50000.0,
        jaminanType: 'KTP Asli Fisik',
      );

      expect(booking.addonDevices.length, 2);
      expect(booking.addonSubtotal, 70000.0);
      expect(booking.primarySubtotal, 150000.0);
      expect(booking.price, 220000.0);
      expect(booking.totalBill, 270000.0); // 220.000 rent + 50.000 deposit

      final receipt = ReceiptModel(
        receiptNumber: 'STR-20261027-003',
        date: now,
        adminName: 'Kasir Utama',
        type: ReceiptType.paymentSettlement,
        bookingCode: booking.bookingCode,
        customerName: booking.customerName,
        customerPhone: booking.customerPhone,
        unitName: booking.iphone.modelName,
        serialNumber: booking.iphone.serialNumber,
        assetCode: booking.iphone.assetCode,
        addonItems: [
          ReceiptAddonItem(name: gimbalAddon.name, assetCode: gimbalAddon.assetCode, price: addon1Price),
          ReceiptAddonItem(name: powerbankAddon.name, assetCode: powerbankAddon.assetCode, price: addon2Price),
        ],
        primaryRentFee: booking.primarySubtotal,
        addonRentFee: booking.addonSubtotal,
        rentalDuration: '24 Jam',
        rentFee: booking.price,
        depositFee: 50000.0,
        totalAmount: 270000.0,
        paidAmount: 270000.0,
        remainingAmount: 0.0,
        paymentMethod: 'TUNAI',
        paymentStatus: 'LUNAS',
        cashGiven: 300000.0,
        cashChange: 30000.0,
      );

      final escPos = receipt.toEscPos58mm();
      expect(escPos, contains('1. DJI Osmo Mobile 6 Gimbal'));
      expect(escPos, contains('2. Anker MagSafe Powerbank'));
      expect(escPos, contains('Sewa iPhone :'));
      expect(escPos, contains('Rp 150.000'));
      expect(escPos, contains('Sewa Add-on :'));
      expect(escPos, contains('Rp 70.000'));
      expect(escPos, contains('Deposit     :'));
      expect(escPos, contains('Rp 50.000'));
      expect(escPos, contains('TOTAL BIAYA :'));
      expect(escPos, contains('Rp 270.000'));
      expect(escPos, contains('Uang Diterima:'));
      expect(escPos, contains('Rp 300.000'));
      expect(escPos, contains('Kembalian   :'));
      expect(escPos, contains('Rp 30.000'));
    });

    test('Scenario 4 & 5: Cash payments show exact Rp 0 change for exact cash and positive change for excess cash', () {
      final now = DateTime.now();
      // Exact cash
      final exactReceipt = ReceiptModel(
        receiptNumber: 'STR-EXACT-001',
        date: now,
        adminName: 'Kasir',
        type: ReceiptType.paymentSettlement,
        bookingCode: 'SKY-EXACT',
        customerName: 'Ahmad',
        customerPhone: '+62',
        unitName: 'iPhone 15 Pro',
        rentalDuration: '24 Jam',
        rentFee: 195000.0,
        depositFee: 0.0,
        totalAmount: 195000.0,
        paidAmount: 195000.0,
        remainingAmount: 0.0,
        paymentMethod: 'TUNAI',
        paymentStatus: 'LUNAS',
        cashGiven: 195000.0,
        cashChange: 0.0,
      );

      final exactOutput = exactReceipt.toEscPos58mm();
      expect(exactOutput, contains('Uang Diterima:'));
      expect(exactOutput, contains('Rp 195.000'));
      expect(exactOutput, contains('Kembalian   :'));
      expect(exactOutput, contains('Rp 0'));

      // Excess cash
      final excessReceipt = exactReceipt.copyWith(
        cashGiven: 200000.0,
        cashChange: 5000.0,
      );
      final excessOutput = excessReceipt.toEscPos58mm();
      expect(excessOutput, contains('Uang Diterima:'));
      expect(excessOutput, contains('Rp 200.000'));
      expect(excessOutput, contains('Kembalian   :'));
      expect(excessOutput, contains('Rp 5.000'));
    });

    test('Scenario 6: Non-cash (QRIS Kasir) payments omit physical cash given and change lines', () {
      final now = DateTime.now();
      final qrisReceipt = ReceiptModel(
        receiptNumber: 'STR-QRIS-001',
        date: now,
        adminName: 'Kasir',
        type: ReceiptType.paymentSettlement,
        bookingCode: 'SKY-QRIS',
        customerName: 'Rina',
        customerPhone: '+62',
        unitName: 'iPhone 15 Pro',
        rentalDuration: '24 Jam',
        rentFee: 195000.0,
        depositFee: 0.0,
        totalAmount: 195000.0,
        paidAmount: 195000.0,
        remainingAmount: 0.0,
        paymentMethod: 'QRIS Kasir',
        paymentStatus: 'LUNAS',
        cashGiven: 0.0,
        cashChange: 0.0,
      );

      final qrisOutput = qrisReceipt.toEscPos58mm();
      expect(qrisOutput, contains('Metode      :'));
      expect(qrisOutput, contains('QRIS Kasir'));
      expect(qrisOutput, isNot(contains('Uang Diterima:')));
      expect(qrisOutput, isNot(contains('Kembalian   :')));
    });

    test('Scenario 7: Thermal receipt ESC/POS 58mm strictly satisfies the 32-column monospace budget for all lines', () {
      final now = DateTime.now();
      final receipt = ReceiptModel(
        receiptNumber: 'STR-WIDTH-VERIFY-001',
        date: now,
        adminName: 'Kasir Super Lengkap dan Panjang',
        type: ReceiptType.paymentSettlement,
        bookingCode: 'SKY260909A8F1',
        customerName: 'Muhammad Aditya Bagus Prakoso Wibowo',
        customerPhone: '+62 812-3456-7890-1234',
        unitName: 'iPhone 15 Pro Max Natural Titanium 256GB',
        serialNumber: 'F2LNK98XK0G991823',
        assetCode: 'AST-IP15PM-001-BRANCH-YOGYA',
        addonItems: const [
          ReceiptAddonItem(
            name: 'DJI Osmo Mobile 6 Gimbal Smartphone Stabilizer',
            assetCode: 'AST-ADD-DJIOSMO6-001',
            price: 45000.0,
          ),
          ReceiptAddonItem(
            name: 'Anker MagSafe Wireless Powerbank Ultra Slim 10000mAh',
            assetCode: 'AST-ADD-ANKER10K-002',
            price: 25000.0,
          ),
        ],
        primaryRentFee: 250000.0,
        addonRentFee: 70000.0,
        rentalDuration: '2 Hari (48 Jam)',
        rentalDates: '27 Okt 2026 - 29 Okt 2026',
        rentFee: 320000.0,
        depositFee: 100000.0,
        discountFee: 20000.0,
        totalAmount: 400000.0,
        paidAmount: 400000.0,
        remainingAmount: 0.0,
        paymentMethod: 'TUNAI',
        paymentStatus: 'LUNAS',
        cashGiven: 450000.0,
        cashChange: 50000.0,
        notes: 'Pelanggan meminta invoice tambahan dan tutorial singkat cara pairing gimbal.',
      );

      final escPos = receipt.toEscPos58mm();
      final lines = escPos.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip typography tags and barcode control markers
        if (line.startsWith('[STORE_NAME:') || line.startsWith('[BARCODE:')) continue;
        expect(
          line.length,
          lessThanOrEqualTo(32),
          reason: 'Line $i exceeds 32 characters: "$line" (length: ${line.length})',
        );
      }
    });

    test('Scenario 8: Historical booking JSON serialization & deserialization without add-on fields parses without error', () {
      final legacyJson = {
        'id': 999,
        'booking_code': 'SKY-LEGACY-001',
        'customer_name': 'Pelanggan Lama',
        'customer_phone': '08123456789',
        'pickup_type': 'Outlet',
        'jaminan_type': 'KTP',
        'start_booking_date': '2026-09-01T10:00:00',
        'end_booking_date': '2026-09-02T10:00:00',
        'duration': 24,
        'price': 150000.0,
        'deposit': 0.0,
        'status': 'confirmed',
        'payment_status': 'paid',
        'iphone': {
          'id': 1,
          'name': 'iPhone 13',
          'storage': '128GB',
          'color': 'Midnight',
          'serial_number': 'SN-IP13-01',
          'asset_code': 'AST-IP13-001',
          'status': 'ready',
        },
      };

      final parsed = BookingModel.fromJson(legacyJson);
      expect(parsed.id, 999);
      expect(parsed.addonDevices, isEmpty);
      expect(parsed.hasAddons, isFalse);
      expect(parsed.primarySubtotal, 150000.0);
      expect(parsed.addonSubtotal, 0.0);
      expect(parsed.price, 150000.0);

      // Verify toJson roundtrip
      final serialized = parsed.toJson();
      expect(serialized['addon_devices'], isEmpty);
      expect(serialized['addon_subtotal'], 0.0);
      expect(serialized['primary_subtotal'], 150000.0);
    });
  });
}
