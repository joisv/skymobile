import 'package:flutter_test/flutter_test.dart';
import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/cash_drawer_shift_model.dart';
import 'package:skyrental_admin/models/iphone_model.dart';
import 'package:skyrental_admin/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shift Schedule & Operational States Tests', () {
    test('State 1: notOpened when current time is before opening time and no shift open', () {
      final now = DateTime(2026, 10, 27, 7, 30); // 07:30 WIB
      final schedule = ShiftScheduleModel.resolveLocal(
        activeShift: null,
        openingTime: '08:00',
        closingTime: '22:00',
        graceMinutes: 30,
        enforcementEnabled: true,
        now: now,
      );

      expect(schedule.operationalState, ShiftOperationalState.notOpened);
      expect(schedule.hasActiveShift, isFalse);
      expect(schedule.isOvernight, isFalse);
    });

    test('State 2: openingRequired when current time is within operational hours but shift is not opened', () {
      final now = DateTime(2026, 10, 27, 10, 0); // 10:00 WIB
      final schedule = ShiftScheduleModel.resolveLocal(
        activeShift: null,
        openingTime: '08:00',
        closingTime: '22:00',
        graceMinutes: 30,
        enforcementEnabled: true,
        now: now,
      );

      expect(schedule.operationalState, ShiftOperationalState.openingRequired);
      expect(schedule.hasActiveShift, isFalse);
      expect(schedule.statusMessage, contains('Wajib buka shift'));
    });

    test('State 3: open when active shift exists during operational hours', () {
      final now = DateTime(2026, 10, 27, 14, 0); // 14:00 WIB
      final activeShift = CashDrawerShiftModel(
        id: 1,
        shiftNumber: 'SHF-GNT-20261027-001',
        branchId: 4,
        branchName: 'Genteng Pusat',
        openedByName: 'Budi Santoso',
        openedAt: DateTime(2026, 10, 27, 8, 5),
        status: ShiftStatus.open,
        openingCashFloat: 200000.0,
      );

      final schedule = ShiftScheduleModel.resolveLocal(
        activeShift: activeShift,
        openingTime: '08:00',
        closingTime: '22:00',
        graceMinutes: 30,
        enforcementEnabled: true,
        now: now,
      );

      expect(schedule.operationalState, ShiftOperationalState.open);
      expect(schedule.hasActiveShift, isTrue);
      expect(schedule.activeShiftId, 1);
    });

    test('State 4: closingSoon when active shift is within 60 minutes before closing time', () {
      final now = DateTime(2026, 10, 27, 21, 15); // 21:15 WIB (Closing is 22:00)
      final activeShift = CashDrawerShiftModel(
        id: 1,
        shiftNumber: 'SHF-GNT-20261027-001',
        branchId: 4,
        branchName: 'Genteng Pusat',
        openedByName: 'Budi Santoso',
        openedAt: DateTime(2026, 10, 27, 8, 5),
        status: ShiftStatus.open,
        openingCashFloat: 200000.0,
      );

      final schedule = ShiftScheduleModel.resolveLocal(
        activeShift: activeShift,
        openingTime: '08:00',
        closingTime: '22:00',
        graceMinutes: 30,
        enforcementEnabled: true,
        now: now,
      );

      expect(schedule.operationalState, ShiftOperationalState.closingSoon);
      expect(schedule.hasActiveShift, isTrue);
      expect(schedule.statusMessage, contains('Mendekati batas jam tutup'));
    });

    test('State 5: closingOverdue when active shift passes closing time + grace period', () {
      final now = DateTime(2026, 10, 27, 22, 35); // 22:35 WIB (Closing is 22:00, Grace is 30m -> 22:30 threshold)
      final activeShift = CashDrawerShiftModel(
        id: 1,
        shiftNumber: 'SHF-GNT-20261027-001',
        branchId: 4,
        branchName: 'Genteng Pusat',
        openedByName: 'Budi Santoso',
        openedAt: DateTime(2026, 10, 27, 8, 5),
        status: ShiftStatus.open,
        openingCashFloat: 200000.0,
      );

      final schedule = ShiftScheduleModel.resolveLocal(
        activeShift: activeShift,
        openingTime: '08:00',
        closingTime: '22:00',
        graceMinutes: 30,
        enforcementEnabled: true,
        now: now,
      );

      expect(schedule.operationalState, ShiftOperationalState.closingOverdue);
      expect(schedule.hasActiveShift, isTrue);
      expect(schedule.statusMessage, contains('melewati batas jam tutup'));
    });

    test('State 6: closed when operating hours have ended and no active shift exists', () {
      final now = DateTime(2026, 10, 27, 23, 10); // 23:10 WIB
      final schedule = ShiftScheduleModel.resolveLocal(
        activeShift: null,
        openingTime: '08:00',
        closingTime: '22:00',
        graceMinutes: 30,
        enforcementEnabled: true,
        now: now,
      );

      expect(schedule.operationalState, ShiftOperationalState.closed);
      expect(schedule.hasActiveShift, isFalse);
    });

    test('Overnight shift calculation: handles 20:00 to 04:00 cross-midnight schedule', () {
      // 1. Sebelum jam buka (19:00) -> notOpened
      var schedule = ShiftScheduleModel.resolveLocal(
        activeShift: null,
        openingTime: '20:00',
        closingTime: '04:00',
        graceMinutes: 30,
        now: DateTime(2026, 10, 27, 19, 0),
      );
      expect(schedule.isOvernight, isTrue);
      expect(schedule.operationalState, ShiftOperationalState.notOpened);

      // 2. Selama jam buka malam (22:00) tanpa shift -> openingRequired
      schedule = ShiftScheduleModel.resolveLocal(
        activeShift: null,
        openingTime: '20:00',
        closingTime: '04:00',
        graceMinutes: 30,
        now: DateTime(2026, 10, 27, 22, 0),
      );
      expect(schedule.operationalState, ShiftOperationalState.openingRequired);

      // 3. Menjelang fajar (03:15) dengan shift aktif -> closingSoon
      final nightShift = CashDrawerShiftModel(
        id: 2,
        shiftNumber: 'SHF-GNT-20261027-002',
        branchId: 4,
        branchName: 'Genteng Pusat',
        openedByName: 'Budi Santoso',
        openedAt: DateTime(2026, 10, 27, 20, 0),
        status: ShiftStatus.open,
        openingCashFloat: 150000.0,
      );
      schedule = ShiftScheduleModel.resolveLocal(
        activeShift: nightShift,
        openingTime: '20:00',
        closingTime: '04:00',
        graceMinutes: 30,
        now: DateTime(2026, 10, 28, 3, 15),
      );
      expect(schedule.operationalState, ShiftOperationalState.closingSoon);

      // 4. Melewati fajar (04:45) dengan shift aktif -> closingOverdue
      schedule = ShiftScheduleModel.resolveLocal(
        activeShift: nightShift,
        openingTime: '20:00',
        closingTime: '04:00',
        graceMinutes: 30,
        now: DateTime(2026, 10, 28, 4, 45),
      );
      expect(schedule.operationalState, ShiftOperationalState.closingOverdue);
    });

    test('ShiftScheduleModel JSON deserialization and fallback handling', () {
      final json = {
        'shift_enforcement_enabled': true,
        'shift_opening_time': '09:00',
        'shift_closing_time': '21:00',
        'shift_grace_period_minutes': 45,
        'timezone': 'Asia/Jakarta',
        'is_overnight': false,
        'operational_state': 'closing_soon',
        'status_message': 'Mendekati jam tutup',
        'has_active_shift': true,
        'active_shift_id': 10,
        'scheduled_open_at': '2026-10-27T09:00:00.000Z',
        'scheduled_close_at': '2026-10-27T21:00:00.000Z',
        'overdue_threshold_at': '2026-10-27T21:45:00.000Z',
      };

      final model = ShiftScheduleModel.fromJson(json);

      expect(model.shiftEnforcementEnabled, isTrue);
      expect(model.shiftOpeningTime, '09:00');
      expect(model.shiftClosingTime, '21:00');
      expect(model.shiftGracePeriodMinutes, 45);
      expect(model.operationalState, ShiftOperationalState.closingSoon);
      expect(model.hasActiveShift, isTrue);
      expect(model.activeShiftId, 10);
      expect(model.scheduledOpenAt, isNotNull);
      expect(model.scheduledCloseAt, isNotNull);
      expect(model.overdueThresholdAt, isNotNull);

      final exportedJson = model.toJson();
      expect(exportedJson['shift_opening_time'], '09:00');
      expect(exportedJson['shift_closing_time'], '21:00');
      expect(exportedJson['operational_state'], 'closing_soon');
    });
  });

  group('Add-on Device Model & Classification Tests', () {
    test('IphoneModel differentiates iPhone from Add-on device via isAddon', () {
      // 1. Primary iPhone unit
      final iphoneUnit = IphoneModel(
        id: 101,
        name: 'iPhone 15 Pro',
        storage: '256GB',
        color: 'Natural Titanium',
        serialNumber: 'IP15P-001',
        assetCode: 'IPHONE-001',
        status: 'ready',
        isAddon: false,
      );
      expect(iphoneUnit.isAddon, isFalse);

      // 2. Add-on accessory unit
      final addonUnit = IphoneModel(
        id: 202,
        name: 'MagSafe Battery Pack',
        storage: 'Standard',
        color: 'White',
        serialNumber: 'ACC-MAGSAFE-01',
        assetCode: 'ADDON-0001',
        status: 'ready',
        isAddon: true,
      );
      expect(addonUnit.isAddon, isTrue);

      // 3. copyWith preserves isAddon
      final updatedAddon = addonUnit.copyWith(name: 'MagSafe Battery Pack White');
      expect(updatedAddon.isAddon, isTrue);
      expect(updatedAddon.name, 'MagSafe Battery Pack White');

      // 4. JSON roundtrip preserves isAddon
      final addonJson = addonUnit.toJson();
      expect(addonJson['is_addon'], isTrue);
      final fromJsonUnit = IphoneModel.fromJson(addonJson);
      expect(fromJsonUnit.isAddon, isTrue);
    });
  });

  group('Repository Shift Schedule & Booking Restriction Integration Tests', () {
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
      MockBookingData.shiftEnforcementEnabled = true;
      repository = BookingRepository();
    });

    test('Repository retrieves shift schedule and reflects active shift presence', () async {
      // Awalnya belum ada shift aktif
      var schedule = await repository.getShiftSchedule(branchId: 4);
      expect(schedule.hasActiveShift, isFalse);
      expect(schedule.shiftEnforcementEnabled, isTrue);

      // Buka shift kasir
      final openedShift = await repository.openShift(
        openingCashFloat: 250000.0,
        branchId: 4,
      );
      expect(openedShift.isOpen, isTrue);

      // Schedule sekarang mendeteksi bahwa ada active shift
      schedule = await repository.getShiftSchedule(branchId: 4);
      expect(schedule.hasActiveShift, isTrue);
      expect(schedule.activeShiftId, openedShift.id);
    });

    test('Repository updateShiftSchedule updates schedule parameters successfully', () async {
      final updated = await repository.updateShiftSchedule(
        enforcementEnabled: true,
        openingTime: '07:30',
        closingTime: '23:00',
        graceMinutes: 45,
        branchId: 4,
      );

      expect(updated.shiftOpeningTime, '07:30');
      expect(updated.shiftClosingTime, '23:00');
      expect(updated.shiftGracePeriodMinutes, 45);

      // Verifikasi pembacaan berikutnya menghasilkan nilai yang baru
      final current = await repository.getShiftSchedule(branchId: 4);
      expect(current.shiftOpeningTime, '07:30');
      expect(current.shiftClosingTime, '23:00');
    });

    test('Shift restriction blocks new bookings when shift is required but not opened', () async {
      // Pastikan tidak ada shift aktif
      final currentShift = await repository.getCurrentShift(branchId: 4, forceRefresh: true);
      expect(currentShift, isNull);

      final schedule = await repository.getShiftSchedule(branchId: 4);
      expect(schedule.shiftEnforcementEnabled, isTrue);

      // Logika verifikasi pembatasan booking:
      // Jika enforcement aktif dan shift belum dibuka, booking tidak boleh dilakukan
      final isBookingAllowed = !schedule.shiftEnforcementEnabled || schedule.hasActiveShift;
      expect(isBookingAllowed, isFalse);

      // Setelah shift dibuka:
      await repository.openShift(openingCashFloat: 100000.0, branchId: 4);
      final refreshedSchedule = await repository.getShiftSchedule(branchId: 4);
      final isBookingAllowedNow = !refreshedSchedule.shiftEnforcementEnabled || refreshedSchedule.hasActiveShift;
      expect(isBookingAllowedNow, isTrue);
    });
  });
}
