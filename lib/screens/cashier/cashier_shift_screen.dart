import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/booking_repository.dart';
import '../../models/cash_drawer_shift_model.dart';
import '../../services/auth_service.dart';
import '../../services/thermal_print_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_header.dart';

/// Auto-formats numeric input into Indonesian Rupiah format with thousands separators (e.g. 200.000)
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final number = int.tryParse(digits) ?? 0;
    final formatted = Formatters.number(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CashierShiftScreen extends StatefulWidget {
  final BookingRepository repository;
  final int? branchId;

  const CashierShiftScreen({
    super.key,
    required this.repository,
    this.branchId,
  });

  @override
  State<CashierShiftScreen> createState() => _CashierShiftScreenState();
}

class _CashierShiftScreenState extends State<CashierShiftScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  CashDrawerShiftModel? _activeShift;
  List<CashBookEntryModel> _cashBookEntries = [];
  List<CashDrawerShiftModel> _shiftHistory = [];
  ShiftScheduleModel? _shiftSchedule;

  // Form Controller untuk Buka Shift
  final _openFloatController = TextEditingController(text: '200.000');
  double _nonCashTotal = 0.0;
  final _openNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadShiftData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _openFloatController.dispose();
    _openNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadShiftData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final active = await widget.repository.getCurrentShift(
        branchId: widget.branchId,
        forceRefresh: forceRefresh,
      );

      List<CashBookEntryModel> entries = [];
      if (active != null) {
        entries = await widget.repository.getCashBookEntries(shift: active);
      }

      final history = await widget.repository.getShiftHistory(branchId: widget.branchId);

      double nonCash = 0.0;
      try {
        final txs = await widget.repository.getPaymentTransactions();
        final start = active?.openedAt;
        final end = active?.closedAt;
        if (start != null) {
          for (final tx in txs) {
            if (tx.transactionDate.isBefore(start) || (end != null && tx.transactionDate.isAfter(end))) continue;
            if (tx.paymentStatus.toLowerCase() == 'void') continue;
            final method = tx.paymentMethod.toLowerCase();
            final isCash = method.contains('tunai') || method.contains('cash');
            if (!isCash) {
              nonCash += tx.paidAmount;
            }
          }
        }
      } catch (_) {}

      ShiftScheduleModel? schedule;
      try {
        schedule = await widget.repository.getShiftSchedule(branchId: widget.branchId, forceRefresh: forceRefresh);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _activeShift = active;
          _cashBookEntries = entries;
          _shiftHistory = history;
          _nonCashTotal = nonCash;
          if (schedule != null) _shiftSchedule = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data shift kasir: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // SHIFT ACTIONS: OPEN & CLOSE
  // ===========================================================================

  Future<void> _handleOpenShift() async {
    final floatText = _openFloatController.text.replaceAll(RegExp(r'\D'), '');
    final double openFloat = double.tryParse(floatText) ?? 0.0;

    setState(() => _isLoading = true);

    try {
      final newShift = await widget.repository.openShift(
        openingCashFloat: openFloat,
        notes: _openNotesController.text.trim().isNotEmpty ? _openNotesController.text.trim() : null,
        branchId: widget.branchId,
      );

      final entries = await widget.repository.getCashBookEntries(shift: newShift);

      if (mounted) {
        setState(() {
          _activeShift = newShift;
          _cashBookEntries = entries;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shift kasir berhasil dibuka: ${newShift.shiftNumber}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Gagal Membuka Shift', e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _showCloseShiftDialog() async {
    // Always refresh active shift metrics first to ensure expected cash includes recent cash transactions
    try {
      final freshShift = await widget.repository.getCurrentShift(forceRefresh: true);
      if (mounted && freshShift != null) {
        setState(() {
          _activeShift = freshShift;
        });
      }
    } catch (_) {}

    if (!mounted || _activeShift == null) return;

    final shift = _activeShift!;
    final expectedCash = shift.effectiveExpectedCash;

    // Physical cash input must default to 0; denomination calculator opens automatically
    final actualCashController = TextEditingController(text: '0');
    final actualCashFocusNode = FocusNode();
    final reasonController = TextEditingController();
    final closingNotesController = TextEditingController();

    actualCashFocusNode.addListener(() {
      if (actualCashFocusNode.hasFocus) {
        if (actualCashController.text == '0') {
          actualCashController.clear();
        }
      } else {
        if (actualCashController.text.trim().isEmpty) {
          actualCashController.text = '0';
        }
      }
    });

    final counter = DenominationCounter();
    bool showCounter = true;
    bool hasEnteredCash = false;

    final c100k = TextEditingController(text: '0');
    final c50k = TextEditingController(text: '0');
    final c20k = TextEditingController(text: '0');
    final c10k = TextEditingController(text: '0');
    final c5k = TextEditingController(text: '0');
    final c2k = TextEditingController(text: '0');
    final c1k = TextEditingController(text: '0');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 960),
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final screenWidth = MediaQuery.sizeOf(ctx).width;
        final screenHeight = MediaQuery.sizeOf(ctx).height;
        final isTablet = screenWidth >= 800;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cleanActual = actualCashController.text.replaceAll(RegExp(r'\D'), '');
            final double actualCounted = double.tryParse(cleanActual) ?? 0.0;
            final bool hasCounted = hasEnteredCash || actualCounted > 0 || counter.total > 0;
            final double difference = actualCounted - expectedCash;
            final bool hasDiscrepancy = hasCounted && difference.abs() > 0.01;
            final bool requiresReason = hasCounted && difference.abs() > 5000;

            Future<void> submitCloseShift() async {
              if (!hasCounted) {
                setModalState(() {
                  hasEnteredCash = true;
                });
                if (expectedCash > 5000 && reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alasan selisih kas fisik wajib diisi sebelum shift dapat ditutup.'),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                  return;
                }
              }

              if (requiresReason && reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alasan selisih kas fisik wajib diisi sebelum shift dapat ditutup.'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              await _executeCloseShift(
                actualCash: actualCounted,
                reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                notes: closingNotesController.text.trim().isNotEmpty ? closingNotesController.text.trim() : null,
              );
            }

            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text('Kas Fisik Dihitung (Aktual) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          showCounter = !showCounter;
                        });
                      },
                      icon: Icon(showCounter ? Icons.keyboard_arrow_up : Icons.calculate_outlined, size: 16),
                      label: Text(showCounter ? 'Tutup Kalkulator' : 'Kalkulator Pecahan'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: actualCashController,
                  focusNode: actualCashFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) {
                    setModalState(() {
                      hasEnteredCash = true;
                    });
                  },
                ),
                if (showCounter) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Hitung Per Pecahan Uang Rupiah',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total: ${Formatters.currency(counter.total)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _DenomInputRow(
                          label: 'Rp 100.000',
                          unitValue: 100000,
                          controller: c100k,
                          onChanged: (v) {
                            setModalState(() {
                              hasEnteredCash = true;
                              counter.n100k = v;
                              actualCashController.text = counter.total.toInt().toString();
                            });
                          },
                        ),
                        _DenomInputRow(
                          label: 'Rp 50.000',
                          unitValue: 50000,
                          controller: c50k,
                          onChanged: (v) {
                            setModalState(() {
                              hasEnteredCash = true;
                              counter.n50k = v;
                              actualCashController.text = counter.total.toInt().toString();
                            });
                          },
                        ),
                        _DenomInputRow(
                          label: 'Rp 20.000',
                          unitValue: 20000,
                          controller: c20k,
                          onChanged: (v) {
                            setModalState(() {
                              hasEnteredCash = true;
                              counter.n20k = v;
                              actualCashController.text = counter.total.toInt().toString();
                            });
                          },
                        ),
                        _DenomInputRow(
                          label: 'Rp 10.000',
                          unitValue: 10000,
                          controller: c10k,
                          onChanged: (v) {
                            setModalState(() {
                              hasEnteredCash = true;
                              counter.n10k = v;
                              actualCashController.text = counter.total.toInt().toString();
                            });
                          },
                        ),
                        _DenomInputRow(
                          label: 'Rp 5.000',
                          unitValue: 5000,
                          controller: c5k,
                          onChanged: (v) {
                            setModalState(() {
                              hasEnteredCash = true;
                              counter.n5k = v;
                              actualCashController.text = counter.total.toInt().toString();
                            });
                          },
                        ),
                        _DenomInputRow(
                          label: 'Rp 2.000',
                          unitValue: 2000,
                          controller: c2k,
                          onChanged: (v) {
                            setModalState(() {
                              hasEnteredCash = true;
                              counter.n2k = v;
                              actualCashController.text = counter.total.toInt().toString();
                            });
                          },
                        ),
                        _DenomInputRow(
                          label: 'Rp 1.000',
                          unitValue: 1000,
                          controller: c1k,
                          onChanged: (v) {
                            setModalState(() {
                              hasEnteredCash = true;
                              counter.n1k = v;
                              actualCashController.text = counter.total.toInt().toString();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );

            final rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Estimasi Kas Laci & Aktual Summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ESTIMASI KAS SISTEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                SizedBox(height: 2),
                                Text('Berdasarkan modal awal, transaksi, & biaya', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.currency(expectedCash),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Kas Fisik Dihitung (Aktual)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.currency(actualCounted),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Status Selisih Kas
                _buildDiscrepancyStatusCard(
                  hasCounted: hasCounted,
                  difference: difference,
                  hasDiscrepancy: hasDiscrepancy,
                ),

                if (requiresReason) ...[
                  const SizedBox(height: 12),
                  const Text('Alasan Selisih Kas (Wajib diisi jika > Rp 5.000) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Selisih uang kembalian receh parkir / pembulatan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Text('Catatan Penutupan Shift (Opsional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: closingNotesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Catatan serah terima kasir ke shift berikutnya...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('btn_confirm_close_shift'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: submitCloseShift,
                    icon: const Icon(Icons.lock_clock_rounded, size: 18),
                    label: const Text('Konfirmasi & Tutup Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );

            return AnimatedPadding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 960 : double.infinity,
                    maxHeight: screenHeight * (isTablet ? 0.90 : 0.92),
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: isTablet
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Tutup Shift Kasir (Close Shift)',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Shift: ${shift.shiftNumber} • Kasir: ${shift.openedByName}',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: leftColumn),
                                    const SizedBox(width: 20),
                                    Expanded(flex: 5, child: rightColumn),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Mobile Fixed Top Bar
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Tutup Shift Kasir (Close Shift)',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Shift: ${shift.shiftNumber} • Kasir: ${shift.openedByName}',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                            // 2. Mobile Scrollable Middle Body
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Estimasi Kas Sistem
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('ESTIMASI KAS SISTEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                                SizedBox(height: 2),
                                                Text('Berdasarkan modal awal, transaksi, & biaya', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            Formatters.currency(expectedCash),
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    leftColumn,
                                    if (requiresReason) ...[
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Alasan Selisih Kas (Wajib diisi jika > Rp 5.000) *',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                      ),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: reasonController,
                                        maxLines: 2,
                                        decoration: InputDecoration(
                                          hintText: 'Contoh: Selisih uang kembalian receh parkir / pembulatan',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    const Text('Catatan Penutupan Shift (Opsional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    TextField(
                                      controller: closingNotesController,
                                      maxLines: 2,
                                      decoration: InputDecoration(
                                        hintText: 'Catatan serah terima kasir ke shift berikutnya...',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),

                            // 3. Mobile Sticky Bottom Footer
                            Container(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: const Border(
                                  top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    offset: const Offset(0, -2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Summary Card: Total Dihitung & Status Selisih
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Total Kas Dihitung',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              Formatters.currency(actualCounted),
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _buildDiscrepancyStatusCard(
                                          hasCounted: hasCounted,
                                          difference: difference,
                                          hasDiscrepancy: hasDiscrepancy,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      key: const Key('btn_confirm_close_shift'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F172A),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      onPressed: submitCloseShift,
                                      icon: const Icon(Icons.lock_clock_rounded, size: 18),
                                      label: const Text('Konfirmasi & Tutup Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDiscrepancyStatusCard({
    required bool hasCounted,
    required double difference,
    required bool hasDiscrepancy,
  }) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    Color iconColor;
    IconData icon;
    String label;
    String diffText;

    if (!hasCounted) {
      bgColor = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF64748B);
      iconColor = const Color(0xFF64748B);
      icon = Icons.hourglass_empty_rounded;
      label = 'Belum Dihitung';
      diffText = '-';
    } else if (!hasDiscrepancy) {
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFFBBF7D0);
      textColor = const Color(0xFF15803D);
      iconColor = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
      label = 'Kas Seimbang';
      diffText = 'Rp 0';
    } else if (difference > 0) {
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFFBFDBFE);
      textColor = const Color(0xFF1D4ED8);
      iconColor = const Color(0xFF2563EB);
      icon = Icons.info_rounded;
      label = 'Surplus (Lebih Kas)';
      diffText = '+${Formatters.currency(difference)}';
    } else {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      textColor = const Color(0xFFB91C1C);
      iconColor = const Color(0xFFDC2626);
      icon = Icons.warning_amber_rounded;
      label = 'Shortage (Selisih Kurang)';
      diffText = '-${Formatters.currency(difference.abs())}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            diffText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecordExpenseDialog() async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = 'Operasional';
    bool isSubmitting = false;

    final categories = [
      'Operasional',
      'Konsumsi',
      'Transport / Bensin',
      'Perlengkapan / ATK',
      'Lain-lain',
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.money_off_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Catat Kas Keluar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Pengeluaran operasional dari kas laci kasir', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nominal Pengeluaran (Rp) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          hintText: '0',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [10000, 20000, 50000, 100000].map((nominal) {
                          return ActionChip(
                            label: Text(
                              'Rp ${Formatters.number(nominal)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () {
                              setDialogState(() {
                                amountController.text = nominal.toString();
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text('Kategori Pengeluaran *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Keterangan / Keperluan *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Beli air galon & lakban packing...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final clean = amountController.text.replaceAll(RegExp(r'\D'), '');
                          final amount = double.tryParse(clean) ?? 0.0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nominal pengeluaran harus lebih besar dari Rp 0'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }
                          final note = notesController.text.trim();
                          if (note.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Keterangan pengeluaran wajib diisi'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await widget.repository.createExpenseData(
                              amount: amount,
                              category: selectedCategory,
                              notes: note,
                              spentAt: DateTime.now(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Kas keluar sebesar ${Formatters.currency(amount)} berhasil dicatat'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                              _loadShiftData(forceRefresh: true);
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() => isSubmitting = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal mencatat pengeluaran: $e'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan Kas Keluar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _executeCloseShift({
    required double actualCash,
    String? reason,
    String? notes,
  }) async {
    setState(() => _isLoading = true);

    try {
      final closedShift = await widget.repository.closeShift(
        actualCashCounted: actualCash,
        differenceReason: reason,
        closingNotes: notes,
      );

      final history = await widget.repository.getShiftHistory(branchId: widget.branchId);

      if (mounted) {
        setState(() {
          _activeShift = null;
          _cashBookEntries = [];
          _shiftHistory = history;
          _isLoading = false;
        });

        _showClosingSuccessDialog(closedShift);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Gagal Menutup Shift', e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @visibleForTesting
  void showClosingSuccessDialogForTest(CashDrawerShiftModel shift) => _showClosingSuccessDialog(shift);

  void _showClosingSuccessDialog(CashDrawerShiftModel closedShift) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final double selisih = closedShift.cashDifference ?? 0.0;
        final bool hasDiscrepancy = selisih.abs() > 0.01;
        final Color selisihColor = hasDiscrepancy
            ? (selisih < 0 ? const Color(0xFFDC2626) : const Color(0xFF059669))
            : const Color(0xFF0F172A);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header with Checkmark Icon and Title (Wrapped in Expanded to eliminate subpixel overflow)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Shift Berhasil Ditutup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shift #${closedShift.shiftNumber} telah resmi ditutup dan dicatat ke sistem.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  // 2. Clean Detailed Metrics Card (Monospace numeric values, compact typography)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildClosingMetricRow('Modal Awal', Formatters.currency(closedShift.openingCashFloat)),
                        const SizedBox(height: 4),
                        _buildClosingMetricRow('Kas Masuk', Formatters.currency(closedShift.currentCashInflow), valueColor: const Color(0xFF059669)),
                        const SizedBox(height: 4),
                        _buildClosingMetricRow('Pengeluaran', '-${Formatters.currency(closedShift.currentCashExpenses)}', valueColor: const Color(0xFFDC2626)),
                        const Divider(height: 12, thickness: 1, color: Color(0xFFE2E8F0)),
                        _buildClosingMetricRow('Estimasi Kas', Formatters.currency(closedShift.effectiveExpectedCash)),
                        const SizedBox(height: 4),
                        _buildClosingMetricRow('Kas Fisik Dihitung', Formatters.currency(closedShift.actualCashCounted ?? 0), isBold: true),
                        const SizedBox(height: 4),
                        _buildClosingMetricRow('Selisih Kas', Formatters.currency(selisih), valueColor: selisihColor, isBold: hasDiscrepancy),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Vertical Button Stacking (Preserve Both Actions)
                  // Primary Top Button: "Cetak Struk 58mm" in filled high-contrast primary theme color
                  ElevatedButton.icon(
                    key: const Key('closing_dialog_print_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _printClosingReceipt(closedShift);
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text(
                      'Cetak Struk 58mm',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Secondary Bottom Button: "Selesai" as outline button
                  OutlinedButton(
                    key: const Key('closing_dialog_done_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClosingMetricRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Future<void> _printClosingReceipt(CashDrawerShiftModel shift) async {
    final printService = ThermalPrintService();
    final res = await printService.printShiftClosingReport(shift);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final bool isShiftOpen = _activeShift != null && _activeShift!.isOpen;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppHeader(
        title: 'Manajemen Shift & Buku Kas',
        showBackButton: true,
        subtitle: isShiftOpen
            ? 'Shift Aktif • ${_activeShift!.shiftNumber}'
            : 'Shift Belum Dibuka • POS Station',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _loadShiftData(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.schedule_rounded),
            tooltip: 'Setelan Jadwal Shift',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _showScheduleSettingsDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Shift Aktif & Buku Kas'),
            Tab(text: 'Riwayat Shift'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveShiftTab(),
                    _buildShiftHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadShiftData(forceRefresh: true),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScheduleSettingsDialog() async {
    final schedule = _shiftSchedule ?? await widget.repository.getShiftSchedule(branchId: widget.branchId);
    bool enforce = schedule.shiftEnforcementEnabled;
    final openTimeController = TextEditingController(text: schedule.shiftOpeningTime);
    final closeTimeController = TextEditingController(text: schedule.shiftClosingTime);
    final graceController = TextEditingController(text: schedule.shiftGracePeriodMinutes.toString());

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Setelan Jadwal Shift', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Wajibkan Buka Shift', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Batasi booking baru jika shift belum dibuka', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      value: enforce,
                      onChanged: (val) => setDialogState(() => enforce = val),
                    ),
                    const Divider(height: 20),
                    const Text('Jam Buka Shift (HH:mm)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: openTimeController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '08:00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Jam Tutup Shift (HH:mm)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: closeTimeController,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '22:00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Toleransi Tutup (Menit)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: graceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '30',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final grace = int.tryParse(graceController.text.trim()) ?? 30;
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      final updated = await widget.repository.updateShiftSchedule(
                        enforcementEnabled: enforce,
                        openingTime: openTimeController.text.trim(),
                        closingTime: closeTimeController.text.trim(),
                        graceMinutes: grace,
                        branchId: widget.branchId,
                      );
                      if (mounted) {
                        setState(() {
                          _shiftSchedule = updated;
                          _isLoading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Setelan jadwal shift berhasil diperbarui.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        _showErrorDialog('Gagal Mengubah Jadwal', e.toString());
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShiftOperationalBanner() {
    if (_shiftSchedule == null) return const SizedBox.shrink();
    final schedule = _shiftSchedule!;
    final state = schedule.operationalState;

    if (state == ShiftOperationalState.open) return const SizedBox.shrink();

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String title;
    String desc;

    switch (state) {
      case ShiftOperationalState.closingSoon:
        bgColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFF59E0B);
        textColor = const Color(0xFF92400E);
        icon = Icons.access_time_rounded;
        title = 'Mendekati Batas Jam Tutup Operasional (${schedule.shiftClosingTime})';
        desc = 'Waktu operasional shift akan segera berakhir. Harap mulai menghitung uang fisik di laci kasir.';
        break;
      case ShiftOperationalState.closingOverdue:
        bgColor = const Color(0xFFFEE2E2);
        borderColor = const Color(0xFFEF4444);
        textColor = const Color(0xFF991B1B);
        icon = Icons.warning_rounded;
        title = 'Melewati Batas Tutup Shift (${schedule.shiftClosingTime})';
        desc = 'Jam operasional shift telah berakhir. Harap segera lakukan Tutup Shift Kasir untuk rekonsiliasi kas.';
        break;
      case ShiftOperationalState.closed:
        bgColor = const Color(0xFFF1F5F9);
        borderColor = const Color(0xFFCBD5E1);
        textColor = const Color(0xFF334155);
        icon = Icons.lock_clock_rounded;
        title = 'Shift Kasir Telah Ditutup';
        desc = 'Sesi shift untuk hari ini telah selesai ditutup.';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11.5, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenShiftOperationalBanner() {
    if (_shiftSchedule == null) return const SizedBox.shrink();
    final schedule = _shiftSchedule!;
    final state = schedule.operationalState;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String title;
    String desc;

    switch (state) {
      case ShiftOperationalState.openingRequired:
        bgColor = const Color(0xFFFFEDD5);
        borderColor = const Color(0xFFF97316);
        textColor = const Color(0xFF9A3412);
        icon = Icons.alarm_on_rounded;
        title = 'Wajib Buka Shift Kasir (Jam Buka: ${schedule.shiftOpeningTime})';
        desc = 'Jam operasional telah dimulai. Buka shift kasir terlebih dahulu untuk mulai melayani transaksi sewa.';
        break;
      case ShiftOperationalState.closed:
        bgColor = const Color(0xFFF1F5F9);
        borderColor = const Color(0xFFCBD5E1);
        textColor = const Color(0xFF334155);
        icon = Icons.lock_clock_rounded;
        title = 'Shift Kasir Hari Ini Telah Ditutup (${schedule.shiftClosingTime})';
        desc = 'Anda dapat membuka shift baru jika toko menyelenggarakan shift tambahan/malam.';
        break;
      case ShiftOperationalState.notOpened:
      default:
        bgColor = const Color(0xFFF0FDF4);
        borderColor = const Color(0xFF86EFAC);
        textColor = const Color(0xFF166534);
        icon = Icons.schedule_rounded;
        title = 'Jadwal Operasional: ${schedule.shiftOpeningTime} - ${schedule.shiftClosingTime} WIB';
        desc = 'Masukkan modal awal kas laci untuk memulai shift hari ini.';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11.5, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: ACTIVE SHIFT & CASH BOOK
  // ===========================================================================

  Widget _buildActiveShiftTab() {
    if (_activeShift == null || !_activeShift!.isOpen) {
      return _buildOpenShiftPrompt();
    }

    final shift = _activeShift!;
    final isTablet = MediaQuery.sizeOf(context).width >= 800;

    return RefreshIndicator(
      onRefresh: () => _loadShiftData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildShiftOperationalBanner(),

          // 1. Shift Header Badge Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift.shiftNumber,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${shift.branchName} • Dibuka oleh ${shift.openedByName}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, size: 10, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text('SHIFT AKTIF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Text(
                  'Waktu Buka: ${Formatters.date(shift.openedAt)}, ${Formatters.time(shift.openedAt)} WIB',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Financial Metrics Cards Grid (4 columns on tablet, 2x2 on mobile)
          if (isTablet)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Modal Awal Kas',
                    amount: shift.openingCashFloat,
                    color: const Color(0xFF3B82F6),
                    icon: Icons.savings_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Kas Masuk Tunai',
                    amount: shift.currentCashInflow,
                    color: const Color(0xFF10B981),
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Non-Tunai / QRIS',
                    amount: _nonCashTotal,
                    color: const Color(0xFF6366F1),
                    icon: Icons.qr_code_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Kas Keluar & Refund',
                    amount: shift.currentCashRefund + shift.currentCashExpenses,
                    color: const Color(0xFFEF4444),
                    icon: Icons.keyboard_return_rounded,
                    isNegative: true,
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Modal Awal Kas',
                    amount: shift.openingCashFloat,
                    color: const Color(0xFF3B82F6),
                    icon: Icons.savings_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Kas Masuk Tunai',
                    amount: shift.currentCashInflow,
                    color: const Color(0xFF10B981),
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Non-Tunai / QRIS',
                    amount: _nonCashTotal,
                    color: const Color(0xFF6366F1),
                    icon: Icons.qr_code_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Kas Keluar & Refund',
                    amount: shift.currentCashRefund + shift.currentCashExpenses,
                    color: const Color(0xFFEF4444),
                    icon: Icons.keyboard_return_rounded,
                    isNegative: true,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // 3. Saldo Kas di Laci Saat Ini (Hero Card)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESTIMASI KAS FISIK DI LACI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE2E8F0))),
                      SizedBox(height: 4),
                      Text('Saldo fisik yang harus ada di drawer saat ini', style: TextStyle(fontSize: 10.5, color: Color(0xFFCBD5E1))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.currency(shift.effectiveExpectedCash),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Non-Cash Disclaimer Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pembayaran non-tunai (QRIS/VA) masuk ke rekening bank dan tidak mempengaruhi kas fisik laci.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. Action Buttons (Tutup Shift & Rekonsiliasi, Cetak Struk, Catat Kas Keluar)
          if (!isTablet) ...[
            // Mobile 2-Tier Layout: Full-Width Primary Action on Top, 2 Equal Secondary Actions Below
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('btn_close_shift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _showCloseShiftDialog,
                icon: const Icon(Icons.lock_clock_rounded, size: 18),
                label: const Text(
                  'Tutup Shift Kasir',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _printClosingReceipt(shift),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF475569)),
                      label: const Text(
                        'Cetak Ringkasan',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      key: const Key('btn_record_expense'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: _showRecordExpenseDialog,
                      icon: const Icon(Icons.payments_outlined, size: 16, color: Color(0xFFDC2626)),
                      label: const Text(
                        '+ Catat Kas',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Tablet Layout: 3-Button Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => _printClosingReceipt(shift),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF475569)),
                      label: const Text('Cetak Ringkasan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      key: const Key('btn_record_expense'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: _showRecordExpenseDialog,
                      icon: const Icon(Icons.payments_outlined, size: 16, color: Color(0xFFDC2626)),
                      label: const Text(
                        '+ Catat Kas',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('btn_close_shift'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _showCloseShiftDialog,
                      icon: const Icon(Icons.lock_clock_rounded, size: 18),
                      label: const Text(
                        'Tutup Shift Kasir',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // 6. Chronological Shift Cash Book Ledger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Buku Kas Harian (Mutasi Kas Laci)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                child: Text('${_cashBookEntries.length} Mutasi', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_cashBookEntries.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: const Text('Belum ada transaksi tunai pada shift ini.', style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            ..._cashBookEntries.map((e) => _buildCashBookTile(e)),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    bool isNegative = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isNegative && amount > 0 ? '-${Formatters.currency(amount)}' : Formatters.currency(amount),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCashBookTile(CashBookEntryModel entry) {
    Color badgeColor;
    Color textColor;
    String sign;

    switch (entry.entryType) {
      case CashBookEntryType.openingFloat:
        badgeColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF2563EB);
        sign = '+';
        break;
      case CashBookEntryType.cashInflow:
        badgeColor = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        sign = '+';
        break;
      case CashBookEntryType.cashRefund:
        badgeColor = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFD97706);
        sign = '-';
        break;
      case CashBookEntryType.cashExpense:
        badgeColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        sign = '-';
        break;
    }

    final double delta = entry.isInflow ? entry.inflowAmount : entry.outflowAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(
              entry.isInflow ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: textColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.time(entry.timestamp)} WIB • Ref: ${entry.transactionRef}',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${Formatters.currency(delta)}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 2),
              Text(
                'Saldo: ${Formatters.currency(entry.runningBalance)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE: OPEN SHIFT PROMPT
  // ===========================================================================

  Widget _buildOpenShiftPrompt() {
    final now = DateTime.now();
    final cashierName = AuthService().currentUser?.name ?? 'Kasir SKYRental';
    final branchName = widget.branchId != null
        ? 'Cabang #${widget.branchId}'
        : (AuthService().currentUser?.outletName ?? 'Outlet Utama');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOpenShiftOperationalBanner(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Buka Shift Kasir Baru',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Wajib dibuka sebelum melayani transaksi sewa tunai.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Shift Belum Buka',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Compact Cashier Info Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$cashierName • $branchName',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${Formatters.date(now)}, ${Formatters.time(now)} WIB',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Opening Float Input with Currency Formatter
              const Text(
                'Modal Awal Kas Laci (Opening Cash Float) *',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: TextField(
                  controller: _openFloatController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    hintText: '200.000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Quick Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickChip('Rp 0', 0),
                    _buildQuickChip('Rp 100.000', 100000),
                    _buildQuickChip('Rp 200.000', 200000),
                    _buildQuickChip('Rp 500.000', 500000),
                    _buildQuickChip('Rp 1.000.000', 1000000),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Notes
              const Text(
                'Catatan Pembukaan (Opsional)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 42,
                child: TextField(
                  controller: _openNotesController,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintText: 'Contoh: Modal awal uang receh dari brankas...',
                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Submit Action Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: _handleOpenShift,
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text(
                    'Buka Shift Kasir Sekarang',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        onPressed: () {
          setState(() {
            _openFloatController.text = Formatters.number(amount);
          });
        },
      ),
    );
  }

  // ===========================================================================
  // TAB 2: SHIFT HISTORY
  // ===========================================================================

  Widget _buildShiftHistoryTab() {
    if (_shiftHistory.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadShiftData(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: const [
            SizedBox(height: 60),
            Center(
              child: Text(
                'Belum ada riwayat shift yang ditutup.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final isTablet = MediaQuery.sizeOf(context).width >= 800;

    return RefreshIndicator(
      onRefresh: () => _loadShiftData(forceRefresh: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: _shiftHistory.length + (isTablet ? 1 : 0),
        itemBuilder: (ctx, idx) {
          // Table Column Headers for Tablet
          if (isTablet && idx == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 4, child: Text('SHIFT ID & KASIR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5))),
                  SizedBox(width: 12),
                  Expanded(flex: 4, child: Text('WAKTU OPERASIONAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5))),
                  SizedBox(width: 12),
                  Expanded(flex: 2, child: Text('MODAL AWAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5))),
                  SizedBox(width: 12),
                  Expanded(flex: 3, child: Text('ESTIMASI VS FISIK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5))),
                  SizedBox(width: 12),
                  Expanded(flex: 4, child: Text('STATUS SELISIH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5))),
                  SizedBox(width: 44, child: Text('AKSI', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569), letterSpacing: 0.5))),
                ],
              ),
            );
          }

          final shift = _shiftHistory[isTablet ? idx - 1 : idx];
          return _buildShiftHistoryRow(shift, isTablet);
        },
      ),
    );
  }

  Widget _buildShiftHistoryRow(CashDrawerShiftModel shift, bool isTablet) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          title: isTablet
              ? Row(
                  children: [
                    // Col 1: Shift ID & Kasir (flex: 4)
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            shift.shiftNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kasir: ${shift.openedByName}${shift.closedByName != null && shift.closedByName!.isNotEmpty && shift.closedByName != shift.openedByName ? " • Tutup: ${shift.closedByName}" : ""}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Col 2: Timestamps (flex: 4)
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.login_rounded, size: 12, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Buka: ${Formatters.dateTime(shift.openedAt)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                shift.closedAt != null ? Icons.lock_clock_rounded : Icons.pending_actions_rounded,
                                size: 12,
                                color: shift.closedAt != null ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  shift.closedAt != null
                                      ? 'Tutup: ${Formatters.dateTime(shift.closedAt!)}'
                                      : 'Shift Masih Aktif (Belum Ditutup)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: shift.closedAt != null ? FontWeight.normal : FontWeight.bold,
                                    color: shift.closedAt != null ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Col 3: Modal Awal (flex: 2)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Modal Awal', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.currency(shift.openingCashFloat),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Col 4: Estimasi vs Fisik (flex: 3)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sistem: ${Formatters.currency(shift.effectiveExpectedCash)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fisik: ${shift.actualCashCounted != null ? Formatters.currency(shift.actualCashCounted!) : "-"}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: shift.actualCashCounted != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Col 5: Discrepancy Status Badge (flex: 4)
                    Expanded(
                      flex: 4,
                      child: _buildDiscrepancyBadge(shift),
                    ),
                    const SizedBox(width: 8),

                    // Col 6: Print Icon Button
                    SizedBox(
                      width: 44,
                      child: IconButton(
                        icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF64748B)),
                        tooltip: 'Cetak Ulang Struk',
                        onPressed: () => _printClosingReceipt(shift),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift.shiftNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.login_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Buka: ${Formatters.dateTime(shift.openedAt)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          shift.closedAt != null ? Icons.lock_clock_rounded : Icons.pending_actions_rounded,
                          size: 12,
                          color: shift.closedAt != null ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            shift.closedAt != null
                                ? 'Tutup: ${Formatters.dateTime(shift.closedAt!)}'
                                : 'Shift Masih Aktif (Belum Ditutup)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: shift.closedAt != null ? FontWeight.normal : FontWeight.bold,
                              color: shift.closedAt != null ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kasir Buka: ${shift.openedByName}${shift.closedByName != null && shift.closedByName!.isNotEmpty && shift.closedByName != shift.openedByName ? " • Tutup: ${shift.closedByName}" : ""}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _buildDiscrepancyBadge(shift),
                  ],
                ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildKeyValue('Waktu Buka Shift', Formatters.dateTime(shift.openedAt)),
                  _buildKeyValue(
                    'Waktu Tutup Shift',
                    shift.closedAt != null ? Formatters.dateTime(shift.closedAt!) : 'Shift Masih Aktif (Belum Ditutup)',
                  ),
                  if (shift.closedByName != null && shift.closedByName!.isNotEmpty)
                    _buildKeyValue('Kasir Penutup', shift.closedByName!),
                  const Divider(height: 12),
                  _buildKeyValue('Modal Awal', Formatters.currency(shift.openingCashFloat)),
                  _buildKeyValue('Kas Masuk', Formatters.currency(shift.currentCashInflow)),
                  _buildKeyValue('Pengeluaran', '-${Formatters.currency(shift.currentCashExpenses)}'),
                  _buildKeyValue('Estimasi Kas', Formatters.currency(shift.effectiveExpectedCash)),
                  _buildKeyValue('Fisik Dihitung', Formatters.currency(shift.actualCashCounted ?? 0)),
                  _buildKeyValue('Selisih Kas', Formatters.currency(shift.cashDifference ?? 0)),
                  if (shift.differenceReason != null && shift.differenceReason!.isNotEmpty)
                    _buildKeyValue('Alasan Selisih', shift.differenceReason!),
                  if (shift.closingNotes != null && shift.closingNotes!.isNotEmpty)
                    _buildKeyValue('Catatan', shift.closingNotes!),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _printClosingReceipt(shift),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Cetak Ulang Struk Tutup Kasir (58mm)'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscrepancyBadge(CashDrawerShiftModel shift) {
    if (shift.status == ShiftStatus.open || shift.closedAt == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF2563EB)),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Shift Masih Aktif',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final diff = shift.cashDifference ?? 0;
    if (shift.isBalanced) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF16A34A)),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Seimbang - Rp 0',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (shift.isShortage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_downward_rounded, size: 11, color: Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Kurang - ${Formatters.currency(diff.abs())}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Surplus
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.arrow_upward_rounded, size: 11, color: Color(0xFFD97706)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Lebih + ${Formatters.currency(diff)}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValue(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              key,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

/// Row input denominasi uang Rupiah tanpa tombol stepper.
/// Mendukung auto-clear angka '0' saat fokus dan subtotal monospace otomatis.
class _DenomInputRow extends StatefulWidget {
  final String label;
  final int unitValue;
  final TextEditingController controller;
  final ValueChanged<int> onChanged;

  const _DenomInputRow({
    required this.label,
    required this.unitValue,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_DenomInputRow> createState() => _DenomInputRowState();
}

class _DenomInputRowState extends State<_DenomInputRow> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleControllerChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      if (widget.controller.text == '0') {
        widget.controller.clear();
      }
    } else {
      if (widget.controller.text.trim().isEmpty) {
        widget.controller.text = '0';
        widget.onChanged(0);
      }
    }
  }

  void _handleControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse(widget.controller.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final subtotal = count * widget.unitValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Left: Currency label (e.g. Rp 100.000)
          SizedBox(
            width: 84,
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Center: Clean numeric text input field (auto-clears initial 0 on focus)
          SizedBox(
            width: 60,
            height: 36,
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                hintText: '0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) {
                final c = int.tryParse(val.replaceAll(RegExp(r'\D'), '')) ?? 0;
                widget.onChanged(c);
              },
            ),
          ),
          const SizedBox(width: 8),
          // Right: Auto-calculated total right-aligned in monospace styling
          Expanded(
            child: Text(
              Formatters.currency(subtotal.toDouble()),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
