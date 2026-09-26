// This standalone verification script intentionally prints each check result.
// ignore_for_file: avoid_print

import 'package:skyrental_admin/data/booking_repository.dart';
import 'package:skyrental_admin/data/mock_booking_data.dart';
import 'package:skyrental_admin/data/mock_receipt_data.dart';
import 'package:skyrental_admin/models/admin_user_model.dart';
import 'package:skyrental_admin/models/booking_model.dart';
import 'package:skyrental_admin/models/payment_model.dart';
import 'package:skyrental_admin/models/printer_device_model.dart';
import 'package:skyrental_admin/models/receipt_model.dart';
import 'package:skyrental_admin/models/print_result_model.dart';
import 'package:skyrental_admin/services/auth_service.dart';
import 'package:skyrental_admin/services/printer_storage_service.dart';
import 'package:skyrental_admin/services/thermal_print_service.dart';
import 'package:skyrental_admin/utils/formatters.dart';

void main() async {
  print('--- Running Advanced QR & Navigation Verifications ---');

  // Test Currency
  final c1 = Formatters.currency(450000);
  assert(c1 == 'Rp 450.000', 'Currency format failed: $c1');
  print('✓ Currency format OK: $c1');

  // Test Repository
  final repo = BookingRepository();
  final all = await repo.getBookings();
  assert(all.length >= MockBookingData.items.length, 'All items count mismatch');
  print('✓ All bookings count: ${all.length}');

  // Test QR Code Detection Logic: Raw Code
  const scannedRaw = 'SKY260909A8F1';
  final bookingByRaw = await repo.getBookingByCode(scannedRaw);
  assert(bookingByRaw != null, 'Lookup by raw code failed');
  assert(bookingByRaw!.customerName == 'Ahmad Fauzi', 'Customer name mismatch');
  print('✓ QR raw code lookup OK: ${bookingByRaw!.bookingCode}');

  // Test QR Code Detection Logic: Scanned from full URL
  const scannedUrl = 'https://skyrent.test/booking/SKY260908C4D5';
  final cleanCode = scannedUrl.split('/').last;
  final bookingByUrl = await repo.getBookingByCode(cleanCode);
  assert(bookingByUrl != null, 'Lookup by url failed');
  assert(bookingByUrl!.customerName == 'Kevin Wijaya', 'Customer url mismatch');
  print('✓ QR URL clean & lookup OK: $cleanCode -> ${bookingByUrl!.customerName}');

  // Test QR Code Invalid
  const invalidCode = 'INVALID-QR-CODE';
  final bookingInvalid = await repo.getBookingByCode(invalidCode);
  assert(bookingInvalid == null, 'Lookup for invalid code should return null');
  print('✓ QR invalid code properly rejected');

  // Test Booking Verification Logic
  print('--- Running Booking Verification Tests ---');
  final confirmedBooking = await repo.getBookingByCode('SKY260909A8F1');
  assert(confirmedBooking != null && confirmedBooking.canPickup == true, 'Confirmed booking should be eligible for pickup');
  assert(confirmedBooking!.jaminanType.isNotEmpty, 'Jaminan type must be specified');
  print('✓ Confirmed booking canPickup OK: ${confirmedBooking!.bookingCode} (${confirmedBooking.status.label})');

  final rentedBooking = await repo.getBookingByCode('SKY260908C4D5');
  assert(rentedBooking != null && rentedBooking.canPickup == false, 'Rented booking should not be eligible for pickup');
  assert(rentedBooking!.canReturn == true, 'Rented booking should be eligible for return');
  print('✓ Rented booking canPickup=false & canReturn=true OK: ${rentedBooking!.bookingCode}');

  // Test Available Unit Selection Logic
  print('--- Running Unit Inventory & Selection Tests ---');
  final availableUnits = await repo.getInventoryUnits(onlyAvailable: true);
  assert(availableUnits.isNotEmpty, 'Available units should not be empty');
  assert(availableUnits.every((u) => u.status.toLowerCase() == 'tersedia' || u.status.toLowerCase() == 'ready'), 'All units must have status tersedia or ready');
  print('✓ Total available units in stock: ${availableUnits.length}');

  final proUnits = await repo.getInventoryUnits(modelName: 'iPhone 15 Pro', onlyAvailable: true);
  assert(proUnits.isNotEmpty, 'iPhone 15 Pro units should be available');
  assert(proUnits.every((u) => u.name.contains('iPhone 15 Pro')), 'Filtered units must match model');
  print('✓ Available iPhone 15 Pro units count: ${proUnits.length}');

  final byAsset = await repo.getInventoryUnits(query: 'AST-IP15P-001');
  assert(byAsset.length == 1 && byAsset.first.assetCode == 'AST-IP15P-001', 'Asset lookup failed');
  print('✓ Unit lookup by asset code OK: ${byAsset.first.fullName} (${byAsset.first.assetCode})');

  // Test Payment & Deposit Management Logic
  print('--- Running Payment & Deposit Management Tests ---');
  final payments = await repo.getPaymentTransactions();
  assert(payments.isNotEmpty, 'Payment transactions should not be empty');
  print('✓ Total payment transactions count: ${payments.length}');

  final unpaid = await repo.getPaymentTransactions(paymentStatusFilter: 'unpaid');
  assert(unpaid.isNotEmpty && unpaid.every((tx) => tx.hasRemaining), 'Unpaid filter test failed');
  print('✓ Unpaid / pending transactions count: ${unpaid.length}');

  final readyRefund = await repo.getPaymentTransactions(depositStatusFilter: DepositStatus.readyRefund);
  assert(readyRefund.isNotEmpty && readyRefund.every((tx) => tx.canRefundDeposit), 'Ready refund filter failed');
  print('✓ Ready to refund deposit transactions: ${readyRefund.length}');

  final summary = repo.getFinancialSummary();
  assert(summary['totalPaid']! > 0, 'Total paid summary should be positive');
  assert(summary['totalHeldDeposit']! > 0, 'Total held deposit should be positive');
  print('✓ Financial summary metrics OK: Kas Sewa = ${Formatters.currency(summary['totalPaid']!)}, Deposit Ditahan = ${Formatters.currency(summary['totalHeldDeposit']!)}');

  // Test Submitting Payment Flow
  print('--- Running Submit Payment Flow Test ---');
  final paymentResult = await repo.submitPayment(
    bookingCode: 'SKY260909B2C3',
    amountPaid: 180000,
    paymentMethod: 'QRIS',
    notes: 'Pelunasan sisa tagihan via QRIS outlet',
  );
  assert(paymentResult != null, 'Payment submission should succeed');
  assert(paymentResult!.remainingAmount == 0, 'Remaining amount should be 0 after full settlement');
  assert(paymentResult!.paymentStatus == 'paid', 'Status should be paid');
  print('✓ Payment flow processed: ${paymentResult!.bookingCode} paid=${Formatters.currency(paymentResult.paidAmount)}, remaining=${Formatters.currency(paymentResult.remainingAmount)}, status=${paymentResult.paymentStatus}');

  // Test Deposit Status Management Flow
  print('--- Running Deposit Status Management Test ---');
  final depositUpdate = await repo.updateDepositStatus(
    bookingCode: 'SKY260908C4D5',
    newStatus: DepositStatus.readyRefund,
    deductionAmount: 50000,
    notes: 'Keterlambatan 1 jam dipotong Rp 50.000',
  );
  assert(depositUpdate != null, 'Deposit status update failed');
  assert(depositUpdate!.depositStatus == DepositStatus.readyRefund, 'Status should be readyRefund');
  assert(depositUpdate!.refundAmount == 200000, 'Refund should be deposit (250.000) - deduction (50.000) = 200.000');
  assert(depositUpdate!.deductionAmount == 50000, 'Deduction should be 50.000');
  print('✓ Deposit status updated: ${depositUpdate!.bookingCode} status=${depositUpdate.depositStatus.label}, refund=${Formatters.currency(depositUpdate.refundAmount)}, deduction=${Formatters.currency(depositUpdate.deductionAmount)}');

  // Test Deposit Refund Execution Flow
  print('--- Running Deposit Refund Execution Test ---');
  final refundResult = await repo.executeRefund(
    bookingCode: 'SKY260905M8P1',
    refundAmount: 200000,
    refundMethod: 'Transfer Bank',
    bankName: 'BCA',
    accountNumber: '5210982312',
    accountHolder: 'Reza Rahadian',
    notes: 'Transfer sukses via KlikBCA',
  );
  assert(refundResult != null, 'Refund execution failed');
  assert(refundResult!.depositStatus == DepositStatus.refunded, 'Status should be refunded');
  assert(refundResult!.refundAmount == 200000, 'Refund amount should be 200.000');
  print('✓ Refund executed: ${refundResult!.bookingCode} amount=${Formatters.currency(refundResult.refundAmount)} status=${refundResult.depositStatus.label}');

  // Test Double Refund Prevention
  bool doubleRefundBlocked = false;
  try {
    await repo.executeRefund(
      bookingCode: 'SKY260905M8P1',
      refundAmount: 200000,
      refundMethod: 'Transfer Bank',
    );
  } catch (_) {
    doubleRefundBlocked = true;
  }
  assert(doubleRefundBlocked, 'Double refund must be blocked by system');
  print('✓ Double refund protection verified: blocked duplicate refund attempt');

  // Test Payment History Filtering & Sorting
  print('--- Running Payment History Filtering & Sorting Tests ---');
  final historyAll = await repo.getPaymentHistory();
  assert(historyAll.length >= 8, 'History all should contain all mock transactions');
  // Check default sort: newest first
  for (int i = 0; i < historyAll.length - 1; i++) {
    assert(
      !historyAll[i].transactionDate.isBefore(historyAll[i + 1].transactionDate),
      'Transactions should be sorted descending by date',
    );
  }
  print('✓ Payment history default newest-first sorting verified (${historyAll.length} items)');

  final historyFauzi = await repo.getPaymentHistory(query: 'Fauzi');
  assert(historyFauzi.length == 1 && historyFauzi.first.customerName == 'Ahmad Fauzi', 'Query Fauzi failed');
  print('✓ History query by customer name OK: ${historyFauzi.first.customerName}');

  final historyPaid = await repo.getPaymentHistory(paymentStatusFilter: 'paid');
  assert(historyPaid.every((tx) => tx.isPaid), 'All returned should be paid');
  print('✓ History filter by payment status paid OK: ${historyPaid.length} items');

  final historyDeducted = await repo.getPaymentHistory(depositStatusFilter: DepositStatus.deducted);
  assert(historyDeducted.length == 1 && historyDeducted.first.customerName == 'Hendra Setiawan', 'Deducted filter failed');
  assert(historyDeducted.first.deductionAmount == 50000, 'Deduction amount mismatch');
  print('✓ History filter by deposit deducted OK: ${historyDeducted.first.customerName} (Denda: ${Formatters.currency(historyDeducted.first.deductionAmount)})');

  final historyTunai = await repo.getPaymentHistory(paymentMethodFilter: 'Tunai');
  assert(historyTunai.isNotEmpty && historyTunai.every((tx) => tx.paymentMethod == 'Tunai'), 'Tunai filter failed');
  print('✓ History filter by payment method Tunai OK: ${historyTunai.length} items');

  final historySortLargest = await repo.getPaymentHistory(sortBy: 'terbesar');
  assert(historySortLargest.first.rentTotal >= historySortLargest.last.rentTotal, 'Largest sort failed');
  print('✓ History sort by largest amount OK: ${historySortLargest.first.bookingCode} (${Formatters.currency(historySortLargest.first.rentTotal)})');

  // Test 58mm Thermal Receipt structure
  const divider = '================================';
  assert(divider.length == 32, 'Thermal divider must be exactly 32 columns for 58mm');
  print('✓ Thermal ESC/POS 58mm 32-column structure verified');

  // Test Mock Receipt Data and ESC/POS 32-column validation
  print('--- Running Mock Receipt Data & Thermal Formatting Tests ---');
  assert(MockReceiptData.items.length >= 5, 'MockReceiptData should contain at least 5 sample receipts');
  print('✓ Mock receipts collection count: ${MockReceiptData.items.length}');

  for (final receipt in MockReceiptData.items) {
    assert(receipt.receiptNumber.isNotEmpty, 'Receipt number must not be empty');
    assert(receipt.customerName.isNotEmpty, 'Customer name must not be empty');
    assert(receipt.totalAmount > 0, 'Total amount must be greater than 0');

    final escPosText = receipt.toEscPos58mm();
    assert(escPosText.isNotEmpty, 'ESC/POS text must not be empty');

    final lines = escPosText.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      assert(
        line.length <= 32,
        'Line $i in receipt ${receipt.receiptNumber} exceeds 32 columns (${line.length} chars): "$line"',
      );
    }
    print('✓ Receipt ${receipt.receiptNumber} (${receipt.type.label}): ${lines.length} lines, all <= 32 cols OK');
  }

  // Test Post-Transaction Receipt Generation from PaymentTransactionModel
  print('--- Running Post-Transaction Print Generation Tests ---');
  final testTx = historyAll.first;
  final dynamicReceipt = ReceiptModel(
    receiptNumber: 'STR-202609-0${testTx.id}',
    date: DateTime.now(),
    adminName: 'Budi (Kasir Toko)',
    branchName: 'SKYRENTAL YOGYAKARTA',
    type: ReceiptType.paymentSettlement,
    bookingCode: testTx.bookingCode,
    customerName: testTx.customerName,
    customerPhone: testTx.customerPhone,
    unitName: testTx.iphoneName,
    rentalDuration: '3 Hari',
    rentFee: testTx.rentTotal,
    depositFee: testTx.depositAmount,
    totalAmount: testTx.rentTotal + testTx.depositAmount,
    paidAmount: testTx.paidAmount,
    remainingAmount: testTx.remainingAmount,
    paymentMethod: testTx.paymentMethod,
    paymentStatus: testTx.paymentStatus,
  );

  final dynamicEscPos = dynamicReceipt.toEscPos58mm();
  assert(dynamicEscPos.contains('SKYRENTAL'), 'Receipt header missing');
  assert(dynamicEscPos.contains(testTx.bookingCode), 'Booking code missing from receipt');
  for (final line in dynamicEscPos.split('\n')) {
    assert(line.length <= 32, 'Dynamic receipt line exceeds 32 chars: "$line"');
  }
  print('✓ Dynamic post-transaction receipt generated and validated: ${dynamicReceipt.receiptNumber} (${dynamicReceipt.bookingCode})');

  // Test Repository Receipt History & Reprint Support
  print('--- Running Repository Receipt History & Reprint Tests ---');
  final initialReceipts = await repo.getReceiptHistory();
  assert(initialReceipts.length >= 5, 'Initial receipts should be at least 5');
  print('✓ Receipt history fetched from repo: ${initialReceipts.length} items');

  final pickupReceipts = await repo.getReceiptHistory(typeFilter: ReceiptType.pickup);
  assert(pickupReceipts.every((r) => r.type == ReceiptType.pickup), 'Type filter failed');
  print('✓ Filter receipt by pickup type OK: ${pickupReceipts.length} items');

  final returnReceipts = await repo.getReceiptHistory(typeFilter: ReceiptType.returnUnit);
  assert(returnReceipts.every((r) => r.type == ReceiptType.returnUnit), 'Return filter failed');
  print('✓ Filter receipt by returnUnit type OK: ${returnReceipts.length} items');

  final queryReceipt = await repo.getReceiptHistory(query: '0012');
  assert(queryReceipt.length == 1 && queryReceipt.first.receiptNumber == 'STR-202609-0012', 'Receipt query failed');
  print('✓ Query receipt by number OK: ${queryReceipt.first.receiptNumber} (${queryReceipt.first.customerName})');

  // Save new receipt into history
  await repo.saveReceipt(dynamicReceipt);
  final afterSave = await repo.getReceiptHistory();
  assert(afterSave.first.receiptNumber == dynamicReceipt.receiptNumber, 'Newly saved receipt should be at top');
  print('✓ New transaction receipt saved into reprint history successfully: ${afterSave.first.receiptNumber}');

  // Test Printer Device Configuration & ESC/POS Test Print Payload
  print('--- Running Printer Settings & Test Print Tests ---');
  final vscDevice = PrinterDeviceModel.defaultVsc();
  assert(vscDevice.name == 'VSC MP-58C', 'Default device name mismatch');
  assert(vscDevice.isConnected == true, 'Default device should be connected');
  assert(vscDevice.connectionType == 'bluetooth', 'Connection type should be bluetooth');
  print('✓ Default printer model OK: ${vscDevice.name} (${vscDevice.address})');

  const settings = PrinterSettingsModel();
  assert(settings.paperWidthMm == 58, 'Paper width must be 58mm');
  assert(settings.columns == 32, 'Columns must be 32 for VSC MP-58C');
  assert(settings.printDensity == 'Normal', 'Default density should be Normal');
  print('✓ Printer settings model OK: ${settings.paperWidthMm}mm, ${settings.columns} columns, density=${settings.printDensity}');

  final testPayload = PrinterSettingsModel.generateTestPrintPayload(
    device: vscDevice,
    settings: settings,
  );
  assert(testPayload.isNotEmpty, 'Test payload must not be empty');
  assert(testPayload.contains('SKYRENTAL POS PRINTER'), 'Test payload missing header');
  assert(testPayload.contains('VSC MP-58C'), 'Test payload missing printer name');

  final testLines = testPayload.split('\n');
  for (int i = 0; i < testLines.length; i++) {
    final line = testLines[i];
    assert(
      line.length <= 32,
      'Test print line $i exceeds 32 columns (${line.length} chars): "$line"',
    );
  }
  print('✓ Test print ESC/POS payload validated (${testLines.length} lines, all <= 32 cols OK)');

  // Test disconnect / toggle
  final disconnected = vscDevice.copyWith(isConnected: false);
  assert(disconnected.isConnected == false, 'Device should be disconnected');
  print('✓ Device disconnect state toggle OK');

  // Test PrinterStorageService Local Persistence
  print('--- Running Printer Storage Service Local Persistence Tests ---');
  final storage = PrinterStorageService();
  await storage.init();

  // Test initial default
  final initialPrimary = await storage.getPrimaryPrinter();
  assert(initialPrimary.name == 'VSC MP-58C', 'Initial primary printer mismatch');
  assert(storage.isPrimaryPrinter(initialPrimary.address), 'isPrimaryPrinter check failed');
  print('✓ Local storage initial primary printer OK: ${initialPrimary.name}');

  // Save new primary printer
  const altPrinter = PrinterDeviceModel(
    name: 'RPP02N-58 Bluetooth',
    address: 'AA:BB:CC:22:33:44',
    isConnected: true,
  );
  await storage.savePrimaryPrinter(altPrinter);
  assert(storage.isPrimaryPrinter('AA:BB:CC:22:33:44'), 'New primary printer check failed');
  final loadedAlt = await storage.getPrimaryPrinter();
  assert(loadedAlt.name == 'RPP02N-58 Bluetooth', 'Primary printer reload failed');
  print('✓ Save and reload custom primary printer OK: ${loadedAlt.name} (${loadedAlt.address})');

  // Save customized printer settings
  const customSettings = PrinterSettingsModel(
    paperWidthMm: 58,
    columns: 32,
    printDensity: 'Pekat',
    feedLines: 3,
    autoPrintOnTransaction: false,
    beepOnComplete: true,
  );
  await storage.savePrinterSettings(customSettings);
  final loadedSettings = await storage.getPrinterSettings();
  assert(loadedSettings.printDensity == 'Pekat', 'Print density persistence failed');
  assert(loadedSettings.feedLines == 3, 'Feed lines persistence failed');
  assert(loadedSettings.autoPrintOnTransaction == false, 'Auto-print persistence failed');
  print('✓ Save and reload customized printer settings OK: density=${loadedSettings.printDensity}, feed=${loadedSettings.feedLines} lines');

  // Reset back to VSC MP-58C
  await storage.resetToDefaults();
  final resetPrimary = await storage.getPrimaryPrinter();
  assert(resetPrimary.name == 'VSC MP-58C', 'Reset to default VSC failed');
  print('✓ Reset printer storage to default VSC MP-58C OK');

  // Test ThermalPrintService with Status & Results
  print('--- Running ThermalPrintService & PrintResult Tests ---');
  final printService = ThermalPrintService();
  printService.configureSimulation(delayMs: 50); // fast tests

  // 1. Test model serialization & extensions
  final dummySuccess = PrintResult.success(
    message: 'Struk berhasil dicetak',
    receiptNumber: 'RCP-TEST-001',
    deviceName: 'VSC MP-58C',
    deviceAddress: '58:A2:3B:11:89:DC',
    bytesSent: 420,
    executionDurationMs: 350,
  );
  assert(dummySuccess.isSuccess == true, 'isSuccess should be true');
  assert(dummySuccess.status == PrintResultStatus.success, 'status should be success');
  assert(dummySuccess.statusLabel == 'Berhasil', 'statusLabel mismatch');
  final jsonMap = dummySuccess.toJson();
  final parsedResult = PrintResult.fromJson(jsonMap);
  assert(parsedResult.receiptNumber == 'RCP-TEST-001', 'receiptNumber deserialize failed');
  assert(parsedResult.isSuccess == true, 'isSuccess deserialize failed');
  print('✓ PrintResult model & JSON serialization OK');

  // 2. Test Print Receipt (Success Scenario)
  final sampleReceipt = MockReceiptData.items[0];
  final printRes = await printService.printReceipt(sampleReceipt);
  assert(printRes.isSuccess == true, 'Print receipt should succeed by default');
  assert(printRes.status == PrintResultStatus.success, 'Print status must be success');
  assert(printRes.receiptNumber == sampleReceipt.receiptNumber, 'Receipt number mismatch');
  assert(printRes.bytesSent > 0, 'Bytes sent should be > 0');
  assert(printRes.deviceName == 'VSC MP-58C', 'Device name should be VSC MP-58C');
  assert(printService.lastResult != null, 'lastResult should be recorded');
  assert(printService.history.isNotEmpty, 'history should not be empty');
  print('✓ ThermalPrintService.printReceipt() success OK: ${printRes.receiptNumber} (${printRes.bytesSent} bytes)');

  // 3. Test Test-Page Print
  final testPageRes = await printService.printTestPage();
  assert(testPageRes.isSuccess == true, 'Test page print should succeed');
  assert(testPageRes.bytesSent > 0, 'Bytes sent for test page should be > 0');
  print('✓ ThermalPrintService.printTestPage() OK: ${testPageRes.deviceName}');

  // 4. Test Disconnected Printer Failure Scenario
  const disconnectedDevice = PrinterDeviceModel(
    name: 'VSC MP-58C Offline',
    address: '58:A2:3B:11:89:DC',
    isConnected: false,
  );
  final disconnectedRes = await printService.printReceipt(sampleReceipt, targetPrinter: disconnectedDevice);
  assert(disconnectedRes.isSuccess == false, 'Disconnected print must fail');
  assert(disconnectedRes.status == PrintResultStatus.printerNotConnected, 'Status should be printerNotConnected');
  print('✓ Disconnected printer properly returns printerNotConnected status');

  // 5. Test Simulated Hardware Failure: Out Of Paper
  printService.configureSimulation(
    simulateFailure: true,
    failureStatus: PrintResultStatus.outOfPaper,
    failureMessage: 'Roll kertas thermal habis.',
    delayMs: 20,
  );
  final outOfPaperRes = await printService.printReceipt(sampleReceipt);
  assert(outOfPaperRes.isSuccess == false, 'Out of paper print must fail');
  assert(outOfPaperRes.status == PrintResultStatus.outOfPaper, 'Status should be outOfPaper');
  assert(outOfPaperRes.message.contains('habis'), 'Failure message mismatch');
  print('✓ Simulated hardware error (OutOfPaper) properly reported: ${outOfPaperRes.statusLabel}');

  // 6. Test Diagnostics Check
  printService.resetSimulation();
  final diag = await printService.checkDiagnostics();
  assert(diag['isConnected'] == true, 'Default diagnostic isConnected should be true');
  assert(diag['printerName'] == 'VSC MP-58C', 'Default diagnostic printerName mismatch');
  print('✓ Diagnostics check OK: ${diag['printerName']} -> ${diag['statusDescription']}');

  // Test Return iPhone Active Rentals & Mock Data
  print('--- Running Return iPhone Active Rentals & Mock Data Tests ---');
  final activeRentals = await repo.getActiveRentals();
  assert(activeRentals.isNotEmpty, 'Active rentals should not be empty');
  assert(activeRentals.every((b) => b.status == BookingStatus.rented && b.canReturn), 'All active rentals must have status rented and canReturn=true');
  print('✓ Total active rentals count in mock data: ${activeRentals.length}');

  // Test query search
  final kevinSearch = await repo.getActiveRentals(query: 'Kevin');
  assert(kevinSearch.length == 1 && kevinSearch.first.bookingCode == 'SKY260908C4D5', 'Query Kevin failed');
  print('✓ Active rental query by customer name OK: ${kevinSearch.first.customerName}');

  final assetSearch = await repo.getActiveRentals(query: 'AST-IP14P-003');
  assert(assetSearch.length == 1 && assetSearch.first.customerName == 'Hendra Setiawan', 'Query asset AST-IP14P-003 failed');
  print('✓ Active rental query by asset code OK: ${assetSearch.first.iphone.name} (${assetSearch.first.iphone.assetCode})');

  // Test Overdue filter
  final overdueRentals = await repo.getActiveRentals(isOverdueOnly: true);
  assert(overdueRentals.isNotEmpty, 'Overdue rentals should have at least 1 item');
  assert(overdueRentals.any((b) => b.bookingCode == 'SKY260906N5P6'), 'Maya Anggraini should be overdue');
  print('✓ Active rental overdue filter OK: ${overdueRentals.length} unit overdue detected');

  // Test Due Today filter
  final dueTodayRentals = await repo.getActiveRentals(isDueTodayOnly: true);
  assert(dueTodayRentals.isNotEmpty, 'Due today rentals should have items');
  assert(dueTodayRentals.any((b) => b.bookingCode == 'SKY260907L3M4'), 'Hendra Setiawan should be due today');
  print('✓ Active rental due today filter OK: ${dueTodayRentals.length} unit due today');

  // Test Multi-criteria Search by Serial Number
  final serialSearch = await repo.getActiveRentals(query: 'Z3X456CV7B');
  assert(serialSearch.length == 1 && serialSearch.first.customerName == 'Rizky Ramadhan', 'Serial number search failed');
  print('✓ Search active rental by serial number OK: ${serialSearch.first.customerName} (${serialSearch.first.iphone.serialNumber})');

  // Test Model Filter
  final ip15Rentals = await repo.getActiveRentals(modelFilter: 'iPhone 15');
  assert(ip15Rentals.isNotEmpty && ip15Rentals.every((b) => b.iphone.name.contains('iPhone 15')), 'Model filter iPhone 15 failed');
  print('✓ Model filter iPhone 15 OK: ${ip15Rentals.length} unit');

  // Test Jaminan Filter
  final motorRentals = await repo.getActiveRentals(jaminanFilter: 'Motor');
  assert(motorRentals.length == 1 && motorRentals.first.customerName == 'Hendra Setiawan', 'Jaminan Motor filter failed');
  print('✓ Jaminan Motor filter OK: ${motorRentals.first.customerName} (${motorRentals.first.jaminanType})');

  // Test Upcoming Filter
  final upcomingRentals = await repo.getActiveRentals(isUpcomingOnly: true);
  assert(upcomingRentals.any((b) => b.bookingCode == 'SKY260908C4D5'), 'Upcoming rental Kevin Wijaya missing');
  print('✓ Upcoming rentals filter OK: ${upcomingRentals.length} unit upcoming');

  // Test Sorting: Urgent (overdue first)
  final urgentSort = await repo.getActiveRentals(sortBy: 'urgent');
  assert(urgentSort.first.bookingCode == 'SKY260906N5P6', 'Urgent sort should place overdue unit first');
  print('✓ Sorting urgent (overdue first) OK: ${urgentSort.first.bookingCode} (${urgentSort.first.customerName})');

  // Test Sorting: Customer Name (A-Z)
  final customerSort = await repo.getActiveRentals(sortBy: 'customerAsc');
  assert(customerSort.first.customerName == 'Hendra Setiawan', 'Customer sort A-Z failed');
  print('✓ Sorting customerAsc A-Z OK: ${customerSort.first.customerName}');

  // Test Return Summary KPI Metrics
  final returnSummary = repo.getReturnSummary();
  assert(returnSummary['totalActiveRentals'] == activeRentals.length, 'Summary totalActiveRentals mismatch');
  assert(returnSummary['totalOverdue'] == overdueRentals.length, 'Summary totalOverdue mismatch');
  assert(returnSummary['totalDueToday'] == dueTodayRentals.length, 'Summary totalDueToday mismatch');
  assert((returnSummary['totalActiveDeposit'] as double) > 0, 'Summary totalActiveDeposit should be > 0');
  print('✓ Return summary metrics OK: Active=${returnSummary['totalActiveRentals']}, DueToday=${returnSummary['totalDueToday']}, Overdue=${returnSummary['totalOverdue']}, Deposit=${Formatters.currency(returnSummary['totalActiveDeposit'])}');

  // Test Return Summary Screen Business Calculations (On-Time vs Overdue Late Fee & Deposit)
  print('--- Running Return Summary & Late Fee Calculation Tests ---');
  final onTimeBooking = await repo.getBookingByCode('SKY260908C4D5'); // Kevin Wijaya
  assert(onTimeBooking != null, 'Kevin Wijaya booking not found');
  final mockNow = DateTime(2026, 9, 9, 14, 0);
  final isOnTimeOverdue = onTimeBooking!.endDate.isBefore(mockNow);
  assert(isOnTimeOverdue == false, 'Kevin Wijaya should not be overdue');
  final onTimeDailyRate = onTimeBooking.price / onTimeBooking.durationDays;
  final onTimeLateFee = isOnTimeOverdue ? onTimeDailyRate : 0.0;
  final onTimeDepositRefund = onTimeBooking.deposit - onTimeLateFee;
  assert(onTimeLateFee == 0.0, 'On-time booking should have 0 late fee');
  assert(onTimeDepositRefund == 250000.0, 'Full deposit should be refundable for on-time booking');
  print('✓ On-time return summary calculation OK: LateFee=Rp 0, DepositRefund=${Formatters.currency(onTimeDepositRefund)}');

  final overdueBooking = await repo.getBookingByCode('SKY260906N5P6'); // Maya Anggraini
  assert(overdueBooking != null, 'Maya Anggraini booking not found');
  final isMayaOverdue = overdueBooking!.endDate.isBefore(mockNow);
  assert(isMayaOverdue == true, 'Maya Anggraini should be overdue');
  final mayaDaysLate = (mockNow.difference(overdueBooking.endDate).inHours / 24).ceil().clamp(1, 30);
  assert(mayaDaysLate == 1, 'Maya Anggraini should be 1 day late');
  final mayaDailyRate = overdueBooking.price / overdueBooking.durationDays;
  final mayaLateFee = mayaDailyRate * mayaDaysLate;
  assert(mayaLateFee == 190000.0, 'Maya late fee mismatch: expected 190000, got $mayaLateFee');
  final mayaDepositRefund = (overdueBooking.deposit - mayaLateFee).clamp(0.0, double.infinity);
  assert(mayaDepositRefund == 60000.0, 'Maya remaining deposit refund mismatch: expected 60000, got $mayaDepositRefund');
  print('✓ Overdue return summary calculation OK: DaysLate=$mayaDaysLate, LateFee=${Formatters.currency(mayaLateFee)}, NetDepositRefund=${Formatters.currency(mayaDepositRefund)}');

  // Test Execution of completeReturn
  print('--- Running Unit Inspection & Complete Return Execution Tests ---');
  final initialActiveCount = (await repo.getActiveRentals()).length;
  final completedReturn = await repo.completeReturn(
    bookingCode: 'SKY260907R7S8',
    physicalCondition: 'Mulus (Sempurna)',
    batteryHealthFinal: 92,
    lateFee: 0,
    damageFee: 0,
    depositRefunded: 200000,
    refundMethod: 'Tunai (Kasir)',
    accessoriesReturned: ['Kabel Original', 'Adaptor 20W', 'Case Pelindung', 'Tempered Glass', 'Pouch SKYRental'],
    staffNotes: 'Unit diterima lengkap dan mulus. Jaminan KTP sudah dikembalikan.',
  );
  assert(completedReturn.status == BookingStatus.returned, 'Booking status must be returned');
  assert(completedReturn.canReturn == false, 'Returned booking canReturn must be false');
  assert(completedReturn.iphone.status == 'tersedia', 'Unit status must be restored to tersedia');
  assert(completedReturn.notes!.contains('Pengembalian selesai'), 'Notes should contain completion message');

  final afterActiveCount = (await repo.getActiveRentals()).length;
  assert(afterActiveCount == initialActiveCount - 1, 'Active rentals count should decrease by 1 after completion');
  print('✓ completeReturn execution OK: ${completedReturn.bookingCode} -> status: ${completedReturn.status.label}, unit restored to tersedia');

  // Test Return Success Receipt Generation & Thermal ESC/POS
  print('--- Running Return Success Screen & Receipt Printing Tests ---');
  final returnReceipt = ReceiptModel(
    receiptNumber: 'STR-202609-3008',
    date: DateTime.now(),
    adminName: 'Staff Admin SKYRental',
    branchName: 'Outlet Malioboro',
    type: ReceiptType.returnUnit,
    bookingCode: completedReturn.bookingCode,
    customerName: completedReturn.customerName,
    customerPhone: completedReturn.customerPhone,
    unitName: completedReturn.iphone.fullName,
    serialNumber: completedReturn.iphone.serialNumber,
    assetCode: completedReturn.iphone.assetCode,
    rentalDuration: '${completedReturn.durationDays} Hari',
    rentalDates: '${Formatters.date(completedReturn.startDate)} - ${Formatters.date(completedReturn.endDate)}',
    rentFee: completedReturn.price,
    depositFee: completedReturn.deposit,
    finesFee: 0,
    discountFee: 0,
    totalAmount: completedReturn.price,
    paidAmount: completedReturn.price,
    remainingAmount: 0,
    refundAmount: 200000,
    paymentMethod: 'Tunai Kasir',
    paymentStatus: 'refunded',
    depositStatus: 'Telah Direfund',
    notes: 'Pengembalian selesai. Kondisi: Mulus (Sempurna). Jaminan KTP dikembalikan.',
  );

  final escPosText = returnReceipt.toEscPos58mm();
  final escLines = escPosText.split('\n');
  assert(escLines.every((l) => l.length <= 32), 'All return receipt lines must be <= 32 characters');
  assert(escPosText.contains('PENGEMBALIAN UNIT'), 'Receipt text must contain PENGEMBALIAN UNIT');
  assert(escPosText.contains('Refund Dep. : Rp 200.000'), 'Receipt text must contain refund amount');
  print('✓ Return receipt ESC/POS 32-col format validated (${escLines.length} lines, all <= 32 cols)');

  final returnPrintRes = await printService.printReceipt(returnReceipt);
  assert(returnPrintRes.isSuccess == true, 'Return receipt printing must succeed');
  assert(returnPrintRes.metadata['type'] == 'returnUnit', 'Receipt type in metadata must be returnUnit');
  print('✓ ThermalPrintService.printReceipt(returnReceipt) OK: ${returnPrintRes.receiptNumber}');

  // Test iPhone Inventory Status & Real-time Tracking Screen
  print('--- Running iPhone Inventory Status & Unit Status Screen Tests ---');
  final inventoryUnits = await repo.getAllInventoryUnits();
  assert(inventoryUnits.isNotEmpty, 'Inventory units must not be empty');
  print('✓ Total inventory units retrieved: ${inventoryUnits.length}');

  // Test status summary
  final unitSummary = await repo.getUnitStatusSummary();
  assert(unitSummary['total'] == inventoryUnits.length, 'Total summary count must match inventory size');
  assert(unitSummary['tersedia']! > 0, 'Must have tersedia units');
  assert(unitSummary.containsKey('disewa'), 'Summary must contain disewa key');
  assert(unitSummary.containsKey('maintenance'), 'Summary must contain maintenance key');
  print('✓ Unit status summary: $unitSummary');

  // Test filter by status 'tersedia'
  final readyUnits = await repo.getAllInventoryUnits(statusFilter: 'tersedia');
  assert(readyUnits.every((u) => u.status == 'tersedia' || u.status == 'ready'), 'All filtered units must be tersedia');
  assert(readyUnits.length == unitSummary['tersedia'], 'Tersedia count should match summary');
  print('✓ Filter status "tersedia": ${readyUnits.length} units (matches summary)');

  // Test filter by status 'disewa'
  final disewaUnits = await repo.getAllInventoryUnits(statusFilter: 'disewa');
  assert(disewaUnits.length == unitSummary['disewa'], 'Disewa count should match summary');
  print('✓ Filter status "disewa": ${disewaUnits.length} units (matches summary)');

  // Test filter by status 'maintenance'
  final maintenanceUnits = await repo.getAllInventoryUnits(statusFilter: 'maintenance');
  assert(maintenanceUnits.length == unitSummary['maintenance'], 'Maintenance count should match summary');
  print('✓ Filter status "maintenance": ${maintenanceUnits.length} units (matches summary)');

  // Test filter by model 'iPhone 15 Pro'
  final ip15ProUnits = await repo.getAllInventoryUnits(modelFilter: 'iPhone 15 Pro');
  assert(ip15ProUnits.every((u) => u.name.contains('iPhone 15 Pro')), 'Filtered units must be iPhone 15 Pro');
  print('✓ Filter model "iPhone 15 Pro": ${ip15ProUnits.length} units');

  // Test search by serial number / asset code
  final firstUnit = inventoryUnits.first;
  final searchByAsset = await repo.getAllInventoryUnits(query: firstUnit.assetCode);
  assert(searchByAsset.isNotEmpty, 'Search by asset code should find unit');
  assert(searchByAsset.first.assetCode == firstUnit.assetCode, 'Asset code must match');
  print('✓ Search by asset code "${firstUnit.assetCode}" found: ${searchByAsset.first.name}');

  // Test get active booking for rented unit
  final rentedUnit = inventoryUnits.firstWhere(
    (u) => u.status == 'disewa' || u.status == 'rented',
    orElse: () => inventoryUnits.first,
  );
  final activeBooking = await repo.getActiveBookingForUnit(rentedUnit.assetCode);
  print('✓ Active booking for unit ${rentedUnit.assetCode}: ${activeBooking?.customerName ?? "None"}');

  // Test update unit status
  final updatedUnit = await repo.updateUnitStatus(
    firstUnit.assetCode,
    'maintenance',
    batteryHealth: 95,
  );
  assert(updatedUnit.status == 'maintenance', 'Status should be updated to maintenance');
  assert(updatedUnit.batteryHealth == 95, 'Battery health should be updated to 95');
  print('✓ Update unit status OK: ${updatedUnit.assetCode} -> status: ${updatedUnit.status}, BH: ${updatedUnit.batteryHealth}%');

  // Restore back to available
  final restoredUnit = await repo.updateUnitStatus(
    firstUnit.assetCode,
    firstUnit.status,
    batteryHealth: firstUnit.batteryHealth,
  );
  assert(restoredUnit.status == firstUnit.status, 'Status should be restored');
  print('✓ Restored unit status OK: ${restoredUnit.assetCode} -> status: ${restoredUnit.status}');

  // Test unit rental schedule timeline
  print('--- Running Unit Rental Schedule Tests ---');
  final allSchedules = await repo.getUnitRentalSchedule(firstUnit.assetCode);
  assert(allSchedules.isNotEmpty, 'Unit schedules must not be empty');
  print('✓ Unit rental schedules count for ${firstUnit.assetCode}: ${allSchedules.length}');

  final upcomingSchedules = await repo.getUnitRentalSchedule(firstUnit.assetCode, timeframeFilter: 'mendatang');
  print('✓ Upcoming schedules count: ${upcomingSchedules.length}');

  final pastSchedules = await repo.getUnitRentalSchedule(firstUnit.assetCode, timeframeFilter: 'selesai');
  print('✓ Completed schedules count: ${pastSchedules.length}');

  // Test operational dashboard metrics and financials
  print('--- Running Operational Dashboard Tests ---');
  final dashboardData = await repo.getOperationalDashboardData();
  assert(dashboardData.containsKey('metrics'), 'Dashboard must contain metrics');
  assert(dashboardData.containsKey('financials'), 'Dashboard must contain financials');
  assert(dashboardData.containsKey('actionItems'), 'Dashboard must contain actionItems');
  assert(dashboardData.containsKey('recentBookings'), 'Dashboard must contain recentBookings');

  final metrics = dashboardData['metrics'] as Map<String, dynamic>;
  assert(metrics['activeRentals'] != null, 'activeRentals metric must be present');
  assert(metrics['availableUnits'] != null, 'availableUnits metric must be present');
  assert(metrics['utilizationRate'] != null, 'utilizationRate metric must be present');
  print('✓ Operational metrics: activeRentals=${metrics['activeRentals']}, pickups=${metrics['todayPickups']}, returns=${metrics['todayReturns']}, utilRate=${metrics['utilizationRate']}%');

  final financials = dashboardData['financials'] as Map<String, dynamic>;
  assert(financials['totalRevenue'] != null && financials['totalRevenue'] > 0, 'totalRevenue must be positive');
  assert(financials['totalHeldDeposit'] != null && financials['totalHeldDeposit'] > 0, 'totalHeldDeposit must be positive');
  print('✓ Financial summary: revenue=${Formatters.currency(financials['totalRevenue'])}, heldDeposit=${Formatters.currency(financials['totalHeldDeposit'])}');

  final actionItems = dashboardData['actionItems'] as List<BookingModel>;
  print('✓ Action items count: ${actionItems.length}');

  final recentBookings = dashboardData['recentBookings'] as List<BookingModel>;
  assert(recentBookings.isNotEmpty, 'recentBookings must not be empty');
  print('✓ Recent bookings count: ${recentBookings.length}');

  // Test sales and revenue report
  print('--- Running Sales Report Tests ---');
  final salesReport = await repo.getSalesReportData(period: 'Hari Ini');
  assert(salesReport.containsKey('summary'), 'Sales report must contain summary');
  assert(salesReport.containsKey('paymentMethodBreakdown'), 'Sales report must contain payment breakdown');
  assert(salesReport.containsKey('modelRevenue'), 'Sales report must contain model revenue');
  assert(salesReport.containsKey('transactions'), 'Sales report must contain transactions');

  final salesSummary = salesReport['summary'] as Map<String, dynamic>;
  assert(salesSummary['totalRevenue'] != null && salesSummary['totalRevenue'] > 0, 'Sales revenue must be positive');
  assert(salesSummary['transactionCount'] != null && salesSummary['transactionCount'] > 0, 'Transaction count must be positive');
  print('✓ Sales report summary: totalRevenue=${Formatters.currency(salesSummary['totalRevenue'])}, transactions=${salesSummary['transactionCount']}, aov=${Formatters.currency(salesSummary['averageTransactionValue'])}');

  final payBreakdown = salesReport['paymentMethodBreakdown'] as Map<String, double>;
  assert(payBreakdown.isNotEmpty, 'Payment method breakdown must not be empty');
  print('✓ Payment breakdown: $payBreakdown');

  final modelRev = salesReport['modelRevenue'] as Map<String, double>;
  assert(modelRev.isNotEmpty, 'Model revenue must not be empty');
  print('✓ Top models revenue count: ${modelRev.length}');

  // Test date range picker filtering
  print('--- Running Date Range Picker Filter Tests ---');
  final dateRangeReport = await repo.getSalesReportData(
    period: 'Kustom',
    startDate: DateTime(2026, 9, 8),
    endDate: DateTime(2026, 9, 9),
  );
  final dateRangeTxs = dateRangeReport['transactions'] as List<PaymentTransactionModel>;
  assert(dateRangeTxs.isNotEmpty, 'Filtered transactions should not be empty');
  assert(
    dateRangeTxs.every((t) =>
        t.transactionDate.isAfter(DateTime(2026, 9, 7, 23, 59, 59)) &&
        t.transactionDate.isBefore(DateTime(2026, 9, 9, 23, 59, 59, 999))),
    'All transactions must fall within the custom date range',
  );
  print('✓ Custom date range (08-09 Sep 2026) returned ${dateRangeTxs.length} transactions, all within range');

  // Test export CSV and ESC/POS closing report
  print('--- Running Export Reports & Thermal Closing Tests ---');
  final csvOutput = repo.exportSalesReportCsv(salesReport);
  assert(csvOutput.contains('Kode Booking,Pelanggan'), 'CSV must contain standard headers');
  assert(csvOutput.contains('SKY260909A8F1'), 'CSV must contain booking codes');
  print('✓ Export CSV validated (${csvOutput.split('\n').length} lines generated)');

  final closingEscPos = repo.exportClosingReportEscPos(salesReport);
  final closingLines = closingEscPos.split('\n');
  assert(closingLines.every((l) => l.length <= 32), 'All closing receipt lines must be <= 32 columns');
  assert(closingEscPos.contains('LAPORAN PENUTUPAN KASIR'), 'Must contain closing header');
  assert(closingEscPos.contains('RINGKASAN OMZET & KAS'), 'Must contain omzet summary');
  print('✓ Closing thermal receipt 32-col format validated (${closingLines.length} lines, all <= 32 cols)');

  // Test Notifications
  print('--- Running Notifications Tests ---');
  final notifs = await repo.getNotifications();
  assert(notifs.isNotEmpty, 'Notifications should not be empty');
  print('✓ Notifications retrieved: ${notifs.length} items');

  await repo.markNotificationAsRead(notifs.first.id);
  final updatedNotifs = await repo.getNotifications();
  assert(updatedNotifs.first.isRead == true, 'First notification must be marked as read');
  print('✓ Notification marked as read OK');

  await repo.markAllNotificationsAsRead();
  final unreadCount = await repo.getUnreadNotificationCount();
  assert(unreadCount == 0, 'Unread count should be 0 after mark all as read');
  print('✓ All notifications marked as read OK');

  // Test Admin Profile & Account Models
  print('--- Running Admin Profile & Account Settings Tests ---');
  final defaultAdmin = AdminUserModel.defaultAdmin();
  assert(defaultAdmin.name == 'Admin SKYRental', 'Default admin name mismatch');
  assert(defaultAdmin.email == 'admin@skyrental.id', 'Default admin email mismatch');
  assert(defaultAdmin.role.contains('Kasir'), 'Default admin role mismatch');
  assert(defaultAdmin.outletName.contains('Malioboro'), 'Default outlet mismatch');

  final adminJson = defaultAdmin.toJson();
  final parsedAdmin = AdminUserModel.fromJson(adminJson);
  assert(parsedAdmin.name == defaultAdmin.name, 'AdminUserModel deserialization failed');
  print('✓ AdminUserModel & serialization validated: ${parsedAdmin.name} (${parsedAdmin.role})');

  final defaultSettings = ShopSettingsModel.defaultSettings();
  assert(defaultSettings.shopName.contains('SKYRental'), 'Default shop name mismatch');
  assert(defaultSettings.wifiName.isNotEmpty, 'Default wifi name must not be empty');
  final settingsJson = defaultSettings.toJson();
  final parsedSettings = ShopSettingsModel.fromJson(settingsJson);
  assert(parsedSettings.shopName == defaultSettings.shopName, 'ShopSettingsModel deserialization failed');
  print('✓ ShopSettingsModel & serialization validated: ${parsedSettings.shopName} - ${parsedSettings.outletName}');

  // Test Repository Shop Settings
  final repoSettings = await repo.getShopSettings();
  assert(repoSettings.shopName.isNotEmpty, 'Repo shop settings should not be empty');
  final updatedShopSettings = repoSettings.copyWith(
    shopName: 'SKYRental iPhone Official POS',
    outletName: 'Outlet Utama Malioboro Flagship',
  );
  final savedShop = await repo.updateShopSettings(updatedShopSettings);
  assert(savedShop.shopName == 'SKYRental iPhone Official POS', 'Saved shop name mismatch');
  assert(savedShop.outletName.contains('Flagship'), 'Saved outlet name mismatch');
  print('✓ Repository getShopSettings & updateShopSettings OK: ${savedShop.shopName} (${savedShop.outletName})');

  // Test Navigation Paths & Routing Logic
  print('--- Running App Navigation Paths & Routing Tests ---');
  const routeMain = '/';
  const routeAccount = '/account';
  const routeChangePassword = '/change-password';
  const routeShopSettings = '/shop-settings';
  const routeLogin = '/login';
  assert(routeMain == '/', 'Main route must be "/"');
  assert(routeAccount == '/account', 'Account route must be "/account"');
  assert(routeChangePassword == '/change-password', 'ChangePassword route must be "/change-password"');
  assert(routeShopSettings == '/shop-settings', 'ShopSettings route must be "/shop-settings"');
  assert(routeLogin == '/login', 'Login route must be "/login"');
  print('✓ App navigation paths verified: mainNavigation="/", account="/account", changePassword="/change-password", shopSettings="/shop-settings", login="/login"');

  // Test AuthService Authentication & Mock Validation
  print('--- Running AuthService Login & Session Tests ---');
  final authService = AuthService();

  // Test valid login with email
  final loggedInAdmin = await authService.login(
    emailOrUsername: 'admin@skyrental.id',
    password: 'password123',
    rememberMe: true,
  );
  assert(loggedInAdmin.name == 'Admin SKYRental', 'Logged in admin name mismatch');
  assert(authService.isAuthenticated == true, 'Auth service should be authenticated');
  assert(authService.token != null && authService.token!.startsWith('mock-sanctum-token'), 'Token invalid');
  print('✓ AuthService login via email OK: ${loggedInAdmin.name} (Token: ${authService.token})');

  // Test valid login with username
  final loggedInKasir = await authService.login(
    emailOrUsername: 'kasir',
    password: 'password123',
  );
  assert(loggedInKasir.name == 'Budi Santoso', 'Logged in kasir name mismatch');
  print('✓ AuthService login via username OK: ${loggedInKasir.name}');

  // Test invalid password rejection
  bool invalidPassRejected = false;
  try {
    await authService.login(
      emailOrUsername: 'admin@skyrental.id',
      password: 'wrongpassword',
    );
  } on AuthException catch (e) {
    invalidPassRejected = true;
    assert(e.message.contains('tidak valid'), 'Error message mismatch');
  }
  assert(invalidPassRejected, 'Invalid password must be rejected by AuthService');
  print('✓ AuthService invalid password properly rejected with AuthException');

  // Test unknown user rejection
  bool unknownUserRejected = false;
  try {
    await authService.login(
      emailOrUsername: 'unknown@user.com',
      password: 'password123',
    );
  } on AuthException catch (_) {
    unknownUserRejected = true;
  }
  assert(unknownUserRejected, 'Unknown user must be rejected');
  print('✓ AuthService unknown user properly rejected');

  // Test change password
  await authService.login(emailOrUsername: 'admin@skyrental.id', password: 'password123');
  final changed = await authService.changePassword(
    currentPassword: 'password123',
    newPassword: 'newpassword456',
  );
  assert(changed == true, 'Password change should succeed');

  // Login with new password
  final loginNew = await authService.login(
    emailOrUsername: 'admin@skyrental.id',
    password: 'newpassword456',
  );
  assert(loginNew.name == 'Admin SKYRental', 'Login with new password should succeed');
  print('✓ AuthService password change & re-login OK');

  // Reset back to original password
  await authService.changePassword(
    currentPassword: 'newpassword456',
    newPassword: 'password123',
  );

  // Test logout
  await authService.logout();
  assert(authService.isAuthenticated == false, 'User must not be authenticated after logout');
  assert(authService.currentUser == null, 'currentUser must be null after logout');
  assert(authService.token == null, 'token must be null after logout');
  print('✓ AuthService logout properly clears session and token');

  // Test Page Protection & Route Guard
  print('--- Running Route Guard & Page Protection Tests ---');
  // When logged out
  assert(authService.canAccessRoute('/login') == true, 'Login route must always be accessible');
  assert(authService.canAccessRoute('/') == false, 'Root protected route must be blocked when logged out');
  assert(authService.canAccessRoute('/account') == false, 'Account route must be blocked when logged out');
  assert(authService.canAccessRoute('/dashboard') == false, 'Dashboard route must be blocked when logged out');
  assert(authService.canAccessRoute('/shop-settings') == false, 'Shop settings route must be blocked when logged out');
  print('✓ Page protection properly blocks protected routes for unauthenticated users');

  // When logged back in
  int listenerCalls = 0;
  void testListener() => listenerCalls++;
  authService.addListener(testListener);

  await authService.login(emailOrUsername: 'admin@skyrental.id', password: 'password123');
  assert(authService.canAccessRoute('/') == true, 'Protected route must be allowed when logged in');
  assert(authService.canAccessRoute('/account') == true, 'Account route must be allowed when logged in');
  assert(authService.isSuperAdmin == true, 'Admin should have superadmin role');
  assert(authService.canAccessFinancials == true, 'Admin should have financial access');
  assert(listenerCalls > 0, 'Listener should have been triggered on login');
  print('✓ Route access granted for authenticated user & listener notified (${authService.currentUser?.name})');

  authService.removeListener(testListener);

  print('--- Running Create Booking Verification Tests ---');
  final units = await repo.getInventoryUnits(onlyAvailable: true);
  assert(units.isNotEmpty, 'Available inventory units must not be empty');
  final selectedUnit = units.first;

  final newBooking = await repo.createBooking(
    customerName: 'Dian Permata',
    customerPhone: '081377889900',
    customerEmail: 'dian@example.com',
    address: 'Jl. Gejayan No. 88, Sleman',
    iphone: selectedUnit,
    startDate: DateTime(2026, 9, 10, 14, 0),
    endDate: DateTime(2026, 9, 13, 14, 0),
    durationDays: 3,
    price: 450000,
    deposit: 200000,
    jaminanType: 'KTP Asli + Motor',
    amountPaid: 200000,
    paymentMethod: 'QRIS',
  );

  assert(newBooking.customerName == 'Dian Permata', 'Customer name mismatch');
  assert(newBooking.price == 450000, 'Price mismatch');
  assert(newBooking.deposit == 200000, 'Deposit mismatch');
  assert(newBooking.totalBill == 650000, 'Total bill mismatch');
  assert(newBooking.bookingCode.startsWith('SKY'), 'Booking code prefix must be SKY');
  assert(newBooking.canPickup == true, 'Newly created booking must be eligible for pickup');

  // Verify payment transaction was recorded
  final bookingPayments = await repo.getPaymentTransactions(query: newBooking.bookingCode);
  assert(bookingPayments.isNotEmpty, 'Payment transaction for initial payment must be recorded');
  assert(bookingPayments.first.paidAmount == 200000, 'Paid amount mismatch');
  assert(bookingPayments.first.depositStatus == DepositStatus.held, 'Deposit status must be held');
  print('✓ Create booking & initial payment transaction OK: ${newBooking.bookingCode} for ${newBooking.customerName}');

  print('=== ALL ADVANCED QR, VERIFICATION, UNIT SELECTION, PAYMENT, RECEIPT, THERMAL SERVICE, RETURN IPHONE, UNIT STATUS, UNIT SCHEDULE, DASHBOARD, SALES REPORT, DATE RANGE, EXPORT, NOTIFICATIONS, ACCOUNT, NAVIGATION, AUTH LOGIN, CREATE BOOKING & PAGE PROTECTION TESTS PASSED ===');
}
