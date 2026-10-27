import 'package:flutter/foundation.dart';

/// Status shift kasir
enum ShiftStatus {
  open,
  closed,
  reconciled;

  String get label {
    switch (this) {
      case ShiftStatus.open:
        return 'Aktif (Terbuka)';
      case ShiftStatus.closed:
        return 'Ditutup';
      case ShiftStatus.reconciled:
        return 'Terekonsiliasi';
    }
  }

  static ShiftStatus fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'closed':
      case 'ditutup':
        return ShiftStatus.closed;
      case 'reconciled':
      case 'terekonsiliasi':
        return ShiftStatus.reconciled;
      case 'open':
      case 'terbuka':
      default:
        return ShiftStatus.open;
    }
  }
}

/// Model data shift kasir (Cash Drawer Shift)
@immutable
class CashDrawerShiftModel {
  final int id;
  final String shiftNumber;
  final int branchId;
  final String branchName;
  final String openedByName;
  final String? closedByName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCashFloat; // Modal awal kas
  final double currentCashInflow; // Total penerimaan kas tunai
  final double currentCashRefund; // Total refund kas tunai
  final double currentCashExpenses; // Pengeluaran kasir (cash drawer)
  final double expectedCashNow; // Estimasi kas saat ini
  final double? expectedCashTotal; // Estimasi kas final saat tutup
  final double? actualCashCounted; // Kas fisik riil dihitung
  final double? cashDifference; // Selisih = Kas Fisik - Estimasi Kas
  final String? differenceReason; // Keterangan jika ada selisih
  final String? closingNotes; // Catatan penutupan shift
  final ShiftStatus status;

  const CashDrawerShiftModel({
    required this.id,
    required this.shiftNumber,
    required this.branchId,
    this.branchName = 'Cabang',
    this.openedByName = 'Kasir',
    this.closedByName,
    required this.openedAt,
    this.closedAt,
    required this.openingCashFloat,
    this.currentCashInflow = 0.0,
    this.currentCashRefund = 0.0,
    this.currentCashExpenses = 0.0,
    this.expectedCashNow = 0.0,
    this.expectedCashTotal,
    this.actualCashCounted,
    this.cashDifference,
    this.differenceReason,
    this.closingNotes,
    this.status = ShiftStatus.open,
  });

  bool get isOpen => status == ShiftStatus.open;
  bool get isClosed => status == ShiftStatus.closed || status == ShiftStatus.reconciled;

  /// Estimasi kas fisik yang dihitung secara dinamis
  double get effectiveExpectedCash {
    if (expectedCashTotal != null) return expectedCashTotal!;
    if (expectedCashNow > 0) return expectedCashNow;
    final calculated = openingCashFloat + currentCashInflow - currentCashRefund - currentCashExpenses;
    return calculated < 0 ? 0.0 : calculated;
  }

  /// Menentukan status selisih kas
  bool get hasDiscrepancy => cashDifference != null && cashDifference!.abs() > 0.01;
  bool get isSurplus => cashDifference != null && cashDifference! > 0.01;
  bool get isShortage => cashDifference != null && cashDifference! < -0.01;
  bool get isBalanced => cashDifference != null && cashDifference!.abs() <= 0.01;

  CashDrawerShiftModel copyWith({
    int? id,
    String? shiftNumber,
    int? branchId,
    String? branchName,
    String? openedByName,
    String? closedByName,
    DateTime? openedAt,
    DateTime? closedAt,
    double? openingCashFloat,
    double? currentCashInflow,
    double? currentCashRefund,
    double? currentCashExpenses,
    double? expectedCashNow,
    double? expectedCashTotal,
    double? actualCashCounted,
    double? cashDifference,
    String? differenceReason,
    String? closingNotes,
    ShiftStatus? status,
  }) {
    return CashDrawerShiftModel(
      id: id ?? this.id,
      shiftNumber: shiftNumber ?? this.shiftNumber,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      openedByName: openedByName ?? this.openedByName,
      closedByName: closedByName ?? this.closedByName,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openingCashFloat: openingCashFloat ?? this.openingCashFloat,
      currentCashInflow: currentCashInflow ?? this.currentCashInflow,
      currentCashRefund: currentCashRefund ?? this.currentCashRefund,
      currentCashExpenses: currentCashExpenses ?? this.currentCashExpenses,
      expectedCashNow: expectedCashNow ?? this.expectedCashNow,
      expectedCashTotal: expectedCashTotal ?? this.expectedCashTotal,
      actualCashCounted: actualCashCounted ?? this.actualCashCounted,
      cashDifference: cashDifference ?? this.cashDifference,
      differenceReason: differenceReason ?? this.differenceReason,
      closingNotes: closingNotes ?? this.closingNotes,
      status: status ?? this.status,
    );
  }

  factory CashDrawerShiftModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedOpenedAt;
    try {
      final val = json['opened_at'] ?? json['created_at'];
      if (val != null) {
        final parsed = DateTime.parse(val.toString());
        if (parsed.isUtc) {
          final wib = parsed.add(const Duration(hours: 7));
          parsedOpenedAt = DateTime(wib.year, wib.month, wib.day, wib.hour, wib.minute, wib.second);
        } else {
          parsedOpenedAt = parsed;
        }
      } else {
        parsedOpenedAt = DateTime.now();
      }
    } catch (_) {
      parsedOpenedAt = DateTime.now();
    }

    DateTime? parsedClosedAt;
    if (json['closed_at'] != null) {
      try {
        final parsed = DateTime.parse(json['closed_at'].toString());
        if (parsed.isUtc) {
          final wib = parsed.add(const Duration(hours: 7));
          parsedClosedAt = DateTime(wib.year, wib.month, wib.day, wib.hour, wib.minute, wib.second);
        } else {
          parsedClosedAt = parsed;
        }
      } catch (_) {}
    }

    final idVal = json['id'];
    final int parsedId = idVal is int ? idVal : int.tryParse(idVal?.toString() ?? '0') ?? 0;

    final branchIdVal = json['branch_id'];
    final int parsedBranchId = branchIdVal is int ? branchIdVal : int.tryParse(branchIdVal?.toString() ?? '0') ?? 0;

    final openFloat = (json['opening_cash_float'] as num?)?.toDouble() ?? 0.0;
    final inflow = (json['current_cash_inflow'] as num?)?.toDouble() ?? (json['cash_inflow'] as num?)?.toDouble() ?? 0.0;
    final refund = (json['current_cash_refund'] as num?)?.toDouble() ?? (json['cash_refund'] as num?)?.toDouble() ?? 0.0;
    final expenses = (json['current_cash_expenses'] as num?)?.toDouble() ?? (json['cash_expenses'] as num?)?.toDouble() ?? 0.0;

    final expectedNow = (json['expected_cash_now'] as num?)?.toDouble() ?? (openFloat + inflow - refund - expenses);
    final expectedTotal = (json['expected_cash_total'] as num?)?.toDouble();
    final actualCounted = (json['actual_cash_counted'] as num?)?.toDouble();
    final diff = (json['cash_difference'] as num?)?.toDouble();

    return CashDrawerShiftModel(
      id: parsedId,
      shiftNumber: json['shift_number']?.toString() ?? 'SHF-UNKNOWN',
      branchId: parsedBranchId,
      branchName: json['branch_name']?.toString() ?? json['branch']?['name']?.toString() ?? 'Cabang',
      openedByName: json['opened_by_name']?.toString() ?? json['opened_by']?['name']?.toString() ?? 'Kasir',
      closedByName: json['closed_by_name']?.toString() ?? json['closed_by']?['name']?.toString(),
      openedAt: parsedOpenedAt,
      closedAt: parsedClosedAt,
      openingCashFloat: openFloat,
      currentCashInflow: inflow,
      currentCashRefund: refund,
      currentCashExpenses: expenses,
      expectedCashNow: expectedNow < 0 ? 0.0 : expectedNow,
      expectedCashTotal: expectedTotal,
      actualCashCounted: actualCounted,
      cashDifference: diff,
      differenceReason: json['difference_reason']?.toString(),
      closingNotes: json['closing_notes']?.toString(),
      status: ShiftStatus.fromString(json['status']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shift_number': shiftNumber,
      'branch_id': branchId,
      'branch_name': branchName,
      'opened_by_name': openedByName,
      'closed_by_name': closedByName,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'opening_cash_float': openingCashFloat,
      'current_cash_inflow': currentCashInflow,
      'current_cash_refund': currentCashRefund,
      'current_cash_expenses': currentCashExpenses,
      'expected_cash_now': expectedCashNow,
      'expected_cash_total': expectedCashTotal,
      'actual_cash_counted': actualCashCounted,
      'cash_difference': cashDifference,
      'difference_reason': differenceReason,
      'closing_notes': closingNotes,
      'status': status.name,
    };
  }
}

/// Tipe mutasi buku kas fisik
enum CashBookEntryType {
  openingFloat,
  cashInflow,
  cashRefund,
  cashExpense;

  String get label {
    switch (this) {
      case CashBookEntryType.openingFloat:
        return 'Modal Awal Kas';
      case CashBookEntryType.cashInflow:
        return 'Penerimaan Tunai';
      case CashBookEntryType.cashRefund:
        return 'Refund Tunai';
      case CashBookEntryType.cashExpense:
        return 'Pengeluaran Kasir';
    }
  }
}

/// Model baris buku kas (Cash Book Entry) kronologis
@immutable
class CashBookEntryModel {
  final String id;
  final DateTime timestamp;
  final String transactionRef;
  final CashBookEntryType entryType;
  final String title;
  final String? notes;
  final double inflowAmount; // Uang Masuk (+)
  final double outflowAmount; // Uang Keluar (-)
  final double runningBalance; // Saldo Berjalan
  final String cashierName;
  final String paymentMethod;
  final int? relatedBookingId;
  final int? relatedExpenseId;

  const CashBookEntryModel({
    required this.id,
    required this.timestamp,
    required this.transactionRef,
    required this.entryType,
    required this.title,
    this.notes,
    this.inflowAmount = 0.0,
    this.outflowAmount = 0.0,
    required this.runningBalance,
    this.cashierName = 'Kasir',
    this.paymentMethod = 'Tunai (Cash)',
    this.relatedBookingId,
    this.relatedExpenseId,
  });

  bool get isInflow => inflowAmount > 0;
  bool get isOutflow => outflowAmount > 0;

  factory CashBookEntryModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      final val = json['timestamp'] ?? json['transacted_at'] ?? json['created_at'];
      parsedTime = val != null ? DateTime.parse(val.toString()) : DateTime.now();
    } catch (_) {
      parsedTime = DateTime.now();
    }

    final inAmt = (json['inflow_amount'] as num?)?.toDouble() ?? 0.0;
    final outAmt = (json['outflow_amount'] as num?)?.toDouble() ?? 0.0;
    final runBal = (json['running_balance'] as num?)?.toDouble() ?? 0.0;

    CashBookEntryType type = CashBookEntryType.cashInflow;
    final typeStr = json['entry_type']?.toString().toLowerCase() ?? '';
    if (typeStr.contains('opening') || typeStr.contains('modal')) {
      type = CashBookEntryType.openingFloat;
    } else if (typeStr.contains('refund')) {
      type = CashBookEntryType.cashRefund;
    } else if (typeStr.contains('expense') || typeStr.contains('biaya') || outAmt > 0) {
      type = CashBookEntryType.cashExpense;
    }

    return CashBookEntryModel(
      id: json['id']?.toString() ?? 'CB-${parsedTime.millisecondsSinceEpoch}',
      timestamp: parsedTime,
      transactionRef: json['transaction_ref']?.toString() ?? json['reference']?.toString() ?? '-',
      entryType: type,
      title: json['title']?.toString() ?? type.label,
      notes: json['notes']?.toString(),
      inflowAmount: inAmt,
      outflowAmount: outAmt,
      runningBalance: runBal,
      cashierName: json['cashier_name']?.toString() ?? 'Kasir',
      paymentMethod: json['payment_method']?.toString() ?? 'Tunai (Cash)',
      relatedBookingId: json['related_booking_id'] as int?,
      relatedExpenseId: json['related_expense_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'transaction_ref': transactionRef,
      'entry_type': entryType.name,
      'title': title,
      'notes': notes,
      'inflow_amount': inflowAmount,
      'outflow_amount': outflowAmount,
      'running_balance': runningBalance,
      'cashier_name': cashierName,
      'payment_method': paymentMethod,
      'related_booking_id': relatedBookingId,
      'related_expense_id': relatedExpenseId,
    };
  }
}

/// Helper untuk penghitungan fisik per pecahan uang Rupiah (Denomination Count)
class DenominationCounter {
  int n100k;
  int n50k;
  int n20k;
  int n10k;
  int n5k;
  int n2k;
  int n1k;
  double coins;

  DenominationCounter({
    this.n100k = 0,
    this.n50k = 0,
    this.n20k = 0,
    this.n10k = 0,
    this.n5k = 0,
    this.n2k = 0,
    this.n1k = 0,
    this.coins = 0.0,
  });

  double get total {
    return (n100k * 100000.0) +
        (n50k * 50000.0) +
        (n20k * 20000.0) +
        (n10k * 10000.0) +
        (n5k * 5000.0) +
        (n2k * 2000.0) +
        (n1k * 1000.0) +
        coins;
  }

  bool get isEmpty => total <= 0;

  void reset() {
    n100k = 0;
    n50k = 0;
    n20k = 0;
    n10k = 0;
    n5k = 0;
    n2k = 0;
    n1k = 0;
    coins = 0.0;
  }
}

/// 6 Status Operasional Shift Kasir
enum ShiftOperationalState {
  notOpened,      // Shift Belum Dibuka (sebelum jam buka)
  openingRequired,// Wajib Buka Shift (sudah masuk jam operasional tapi belum dibuka)
  open,           // Shift Sedang Aktif
  closingSoon,    // Mendekati Batas Jam Tutup (dalam 30-60 menit sebelum tutup)
  closingOverdue, // Melewati Batas Tutup Shift (lewat jam tutup + grace period)
  closed;         // Shift Hari Ini Telah Ditutup

  String get label {
    switch (this) {
      case ShiftOperationalState.notOpened:
        return 'Shift Belum Dibuka';
      case ShiftOperationalState.openingRequired:
        return 'Wajib Buka Shift';
      case ShiftOperationalState.open:
        return 'Shift Aktif';
      case ShiftOperationalState.closingSoon:
        return 'Mendekati Jam Tutup';
      case ShiftOperationalState.closingOverdue:
        return 'Melewati Jam Tutup';
      case ShiftOperationalState.closed:
        return 'Shift Ditutup';
    }
  }

  String get key {
    switch (this) {
      case ShiftOperationalState.notOpened:
        return 'not_opened';
      case ShiftOperationalState.openingRequired:
        return 'opening_required';
      case ShiftOperationalState.open:
        return 'open';
      case ShiftOperationalState.closingSoon:
        return 'closing_soon';
      case ShiftOperationalState.closingOverdue:
        return 'closing_overdue';
      case ShiftOperationalState.closed:
        return 'closed';
    }
  }

  static ShiftOperationalState fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'opening_required':
      case 'wajib_buka':
        return ShiftOperationalState.openingRequired;
      case 'open':
      case 'aktif':
        return ShiftOperationalState.open;
      case 'closing_soon':
      case 'mendekati_tutup':
        return ShiftOperationalState.closingSoon;
      case 'closing_overdue':
      case 'overdue':
      case 'melewati_tutup':
        return ShiftOperationalState.closingOverdue;
      case 'closed':
      case 'ditutup':
        return ShiftOperationalState.closed;
      case 'not_opened':
      case 'belum_dibuka':
      default:
        return ShiftOperationalState.notOpened;
    }
  }
}

/// Model Pengaturan Jadwal Shift & Status Operasional Real-time
@immutable
class ShiftScheduleModel {
  final bool shiftEnforcementEnabled;
  final String shiftOpeningTime; // e.g. "08:00"
  final String shiftClosingTime; // e.g. "22:00"
  final int shiftGracePeriodMinutes; // e.g. 30
  final String timezone; // e.g. "Asia/Jakarta"
  final bool isOvernight;
  final ShiftOperationalState operationalState;
  final String statusMessage;
  final bool hasActiveShift;
  final int? activeShiftId;
  final DateTime? scheduledOpenAt;
  final DateTime? scheduledCloseAt;
  final DateTime? overdueThresholdAt;

  const ShiftScheduleModel({
    this.shiftEnforcementEnabled = true,
    this.shiftOpeningTime = '08:00',
    this.shiftClosingTime = '22:00',
    this.shiftGracePeriodMinutes = 30,
    this.timezone = 'Asia/Jakarta',
    this.isOvernight = false,
    this.operationalState = ShiftOperationalState.notOpened,
    this.statusMessage = 'Shift belum dibuka.',
    this.hasActiveShift = false,
    this.activeShiftId,
    this.scheduledOpenAt,
    this.scheduledCloseAt,
    this.overdueThresholdAt,
  });

  bool get canCreateBooking => !shiftEnforcementEnabled || (hasActiveShift && operationalState != ShiftOperationalState.closed);

  factory ShiftScheduleModel.fromJson(Map<String, dynamic> json) {
    return ShiftScheduleModel(
      shiftEnforcementEnabled: json['shift_enforcement_enabled'] is bool
          ? json['shift_enforcement_enabled'] as bool
          : (json['shift_enforcement_enabled'] != 0 && json['shift_enforcement_enabled'] != '0'),
      shiftOpeningTime: json['shift_opening_time']?.toString() ?? '08:00',
      shiftClosingTime: json['shift_closing_time']?.toString() ?? '22:00',
      shiftGracePeriodMinutes: json['shift_grace_period_minutes'] is int
          ? json['shift_grace_period_minutes'] as int
          : int.tryParse(json['shift_grace_period_minutes']?.toString() ?? '') ?? 30,
      timezone: json['timezone']?.toString() ?? 'Asia/Jakarta',
      isOvernight: json['is_overnight'] == true || json['is_overnight'] == 1,
      operationalState: ShiftOperationalState.fromString(json['operational_state']?.toString()),
      statusMessage: json['status_message']?.toString() ?? 'Shift kasir.',
      hasActiveShift: json['has_active_shift'] == true || json['has_active_shift'] == 1,
      activeShiftId: json['active_shift_id'] is int ? json['active_shift_id'] as int : null,
      scheduledOpenAt: json['scheduled_open_at'] != null ? DateTime.tryParse(json['scheduled_open_at'].toString()) : null,
      scheduledCloseAt: json['scheduled_close_at'] != null ? DateTime.tryParse(json['scheduled_close_at'].toString()) : null,
      overdueThresholdAt: json['overdue_threshold_at'] != null ? DateTime.tryParse(json['overdue_threshold_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_enforcement_enabled': shiftEnforcementEnabled,
      'shift_opening_time': shiftOpeningTime,
      'shift_closing_time': shiftClosingTime,
      'shift_grace_period_minutes': shiftGracePeriodMinutes,
      'timezone': timezone,
      'is_overnight': isOvernight,
      'operational_state': operationalState.key,
      'status_message': statusMessage,
      'has_active_shift': hasActiveShift,
      'active_shift_id': activeShiftId,
      'scheduled_open_at': scheduledOpenAt?.toIso8601String(),
      'scheduled_close_at': scheduledCloseAt?.toIso8601String(),
      'overdue_threshold_at': overdueThresholdAt?.toIso8601String(),
    };
  }

  /// Evaluasi state operasional secara lokal ketika offline atau saat shift dibuka/ditutup
  static ShiftScheduleModel resolveLocal({
    required CashDrawerShiftModel? activeShift,
    String openingTime = '08:00',
    String closingTime = '22:00',
    int graceMinutes = 30,
    bool enforcementEnabled = true,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final isOvernight = closingTime.compareTo(openingTime) < 0;

    DateTime openDt;
    DateTime closeDt;

    final openParts = openingTime.split(':').map((e) => int.tryParse(e) ?? 0).toList();
    final closeParts = closingTime.split(':').map((e) => int.tryParse(e) ?? 0).toList();

    final openHour = openParts.isNotEmpty ? openParts[0] : 8;
    final openMinute = openParts.length > 1 ? openParts[1] : 0;
    final closeHour = closeParts.isNotEmpty ? closeParts[0] : 22;
    final closeMinute = closeParts.length > 1 ? closeParts[1] : 0;

    if (activeShift != null && activeShift.isOpen) {
      openDt = DateTime(activeShift.openedAt.year, activeShift.openedAt.month, activeShift.openedAt.day, openHour, openMinute);
      if (isOvernight) {
        closeDt = DateTime(activeShift.openedAt.year, activeShift.openedAt.month, activeShift.openedAt.day + 1, closeHour, closeMinute);
      } else {
        closeDt = DateTime(activeShift.openedAt.year, activeShift.openedAt.month, activeShift.openedAt.day, closeHour, closeMinute);
      }
    } else {
      if (isOvernight) {
        if (current.hour < closeHour || (current.hour == closeHour && current.minute < closeMinute)) {
          openDt = DateTime(current.year, current.month, current.day - 1, openHour, openMinute);
          closeDt = DateTime(current.year, current.month, current.day, closeHour, closeMinute);
        } else {
          openDt = DateTime(current.year, current.month, current.day, openHour, openMinute);
          closeDt = DateTime(current.year, current.month, current.day + 1, closeHour, closeMinute);
        }
      } else {
        openDt = DateTime(current.year, current.month, current.day, openHour, openMinute);
        closeDt = DateTime(current.year, current.month, current.day, closeHour, closeMinute);
      }
    }

    final overdueDt = closeDt.add(Duration(minutes: graceMinutes));
    final closingSoonDt = closeDt.subtract(const Duration(minutes: 60));

    ShiftOperationalState state;
    String message;

    if (activeShift != null && activeShift.isOpen) {
      if (current.isAfter(overdueDt)) {
        state = ShiftOperationalState.closingOverdue;
        message = 'Shift kasir telah melewati batas jam tutup ($closingTime). Segera tutup shift.';
      } else if (current.isAfter(closingSoonDt) || current.isAtSameMomentAs(closingSoonDt)) {
        state = ShiftOperationalState.closingSoon;
        message = 'Mendekati batas jam tutup operasional ($closingTime). Siapkan kas fisik.';
      } else {
        state = ShiftOperationalState.open;
        message = 'Shift kasir aktif melayani transaksi.';
      }
    } else {
      if (current.isAfter(closeDt)) {
        state = ShiftOperationalState.closed;
        message = 'Shift kasir untuk hari ini telah ditutup.';
      } else if (current.isAfter(openDt) || current.isAtSameMomentAs(openDt)) {
        state = ShiftOperationalState.openingRequired;
        message = 'Jam operasional telah dimulai ($openingTime). Wajib buka shift kasir.';
      } else {
        state = ShiftOperationalState.notOpened;
        message = 'Belum memasuki jam operasional shift ($openingTime - $closingTime).';
      }
    }

    return ShiftScheduleModel(
      shiftEnforcementEnabled: enforcementEnabled,
      shiftOpeningTime: openingTime,
      shiftClosingTime: closingTime,
      shiftGracePeriodMinutes: graceMinutes,
      isOvernight: isOvernight,
      operationalState: state,
      statusMessage: message,
      hasActiveShift: activeShift != null && activeShift.isOpen,
      activeShiftId: activeShift?.id,
      scheduledOpenAt: openDt,
      scheduledCloseAt: closeDt,
      overdueThresholdAt: overdueDt,
    );
  }
}
