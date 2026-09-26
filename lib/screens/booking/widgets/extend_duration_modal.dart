import 'package:flutter/material.dart';
import '../../../data/booking_repository.dart';
import '../../../models/booking_model.dart';
import '../../../models/iphone_model.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../payment/payment_deposit_screen.dart';

/// Modal Bottom Sheet Tambah Jam / Tambah Durasi Sewa
/// Mengacu pada x-modal name="tambah-durasi" di detail-booking.blade.php
class ExtendDurationModal extends StatefulWidget {
  final BookingModel booking;
  final BookingRepository repository;
  final VoidCallback? onExtended;

  const ExtendDurationModal({
    super.key,
    required this.booking,
    required this.repository,
    this.onExtended,
  });

  static Future<bool?> show(
    BuildContext context, {
    required BookingModel booking,
    required BookingRepository repository,
    VoidCallback? onExtended,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExtendDurationModal(
        booking: booking,
        repository: repository,
        onExtended: onExtended,
      ),
    );
  }

  @override
  State<ExtendDurationModal> createState() => _ExtendDurationModalState();
}

class _ExtendDurationModalState extends State<ExtendDurationModal> {
  late List<IphoneDurationOption> _durations;
  IphoneDurationOption? _selectedDuration;
  int _multiplier = 1;
  bool _isCheckingAvailability = false;
  bool _isAvailable = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initDurations();
    _checkAvailability();
  }

  void _initDurations() {
    final available = widget.booking.iphone.availableDurations;
    if (available.isNotEmpty) {
      _durations = List.from(available)..sort((a, b) => a.hours.compareTo(b.hours));
    } else {
      _durations = [
        const IphoneDurationOption(id: 1, name: '6 Jam', hours: 6, price: 45000),
        const IphoneDurationOption(id: 2, name: '12 Jam', hours: 12, price: 75000),
        const IphoneDurationOption(id: 3, name: '24 Jam', hours: 24, price: 120000),
      ];
    }
    _selectedDuration = _durations.firstOrNull;
  }

  int get _totalHours => (_selectedDuration?.hours ?? 0) * _multiplier;
  double get _totalPrice => (_selectedDuration?.price ?? 0.0) * _multiplier;
  DateTime get _newEndDate => widget.booking.endDate.add(Duration(hours: _totalHours));

  Future<void> _checkAvailability() async {
    if (_totalHours <= 0) return;

    setState(() {
      _isCheckingAvailability = true;
    });

    try {
      final available = await widget.repository.canExtendBooking(
        widget.booking.bookingCode,
        _totalHours,
      );

      if (mounted) {
        setState(() {
          _isAvailable = available;
          _isCheckingAvailability = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAvailable = true;
          _isCheckingAvailability = false;
        });
      }
    }
  }

  void _onDurationSelected(IphoneDurationOption option) {
    setState(() {
      _selectedDuration = option;
    });
    _checkAvailability();
  }

  void _changeMultiplier(int delta) {
    final next = _multiplier + delta;
    if (next < 1) return;
    setState(() {
      _multiplier = next;
    });
    _checkAvailability();
  }

  Future<void> _proceedToPayment() async {
    if (!_isAvailable || _totalHours <= 0) return;

    Navigator.pop(context, true);

    Navigator.pushNamed(
      context,
      AppRoutes.paymentDeposit,
      arguments: {
        'booking': widget.booking,
        'initialPaymentType': PaymentTypeOption.extend,
        'initialAmount': _totalPrice,
        'extendHours': _totalHours,
      },
    ).then((result) {
      if (result == true) {
        widget.onExtended?.call();
      }
    });
  }

  Future<void> _extendDirectly() async {
    if (!_isAvailable || _totalHours <= 0 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.repository.extendBooking(
        bookingCode: widget.booking.bookingCode,
        hours: _totalHours,
        durationId: _selectedDuration?.id,
        multiplier: _multiplier,
        price: _totalPrice,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Durasi sewa berhasil ditambahkan $_totalHours jam! Selesai baru: ${Formatters.dateTime(_newEndDate)}',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );

        widget.onExtended?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambah durasi: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: const Icon(
                    Icons.more_time_rounded,
                    color: Color(0xFFEA580C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tambah Durasi Sewa',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.booking.bookingCode} • ${widget.booking.iphone.fullName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppTheme.cardBorder),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Batas selesai sekarang
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        const Text(
                          'Batas Selesai Saat Ini:',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const Spacer(),
                        Text(
                          Formatters.dateTime(widget.booking.endDate),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 1. Pilih Durasi
                  const Text(
                    'Pilih Durasi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Duration Options Grid (mirrors web grid-cols-3)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 16) / 3;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _durations.map((duration) {
                          final isSelected = _selectedDuration?.id == duration.id;
                          return SizedBox(
                            width: itemWidth,
                            child: InkWell(
                              onTap: () => _onDurationSelected(duration),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0F172A)
                                        : AppTheme.cardBorder,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${duration.hours} Jam',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.currency(duration.price),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white.withValues(alpha: 0.85)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // 2. Jumlah (Multiplier)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jumlah',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Kelipatan durasi paket',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_rounded, size: 20),
                              color: _multiplier <= 1
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF0F172A),
                              onPressed: _multiplier <= 1 ? null : () => _changeMultiplier(-1),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 36),
                              alignment: Alignment.center,
                              child: Text(
                                '$_multiplier',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 20),
                              color: const Color(0xFFEA580C),
                              onPressed: () => _changeMultiplier(1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Preview Box (sesuai detail-booking.blade.php)
                  if (_totalHours > 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isAvailable ? const Color(0xFFF8FAFC) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isAvailable ? AppTheme.cardBorder : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Tambah Waktu',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              Text(
                                '+$_totalHours Jam',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Waktu Selesai Baru',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              Text(
                                Formatters.dateTime(_newEndDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(height: 1, color: AppTheme.cardBorder),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Biaya Tambahan',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                Formatters.currency(_totalPrice),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          if (_isCheckingAvailability) ...[
                            const Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Memeriksa ketersediaan jadwal unit...',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ] else if (!_isAvailable) ...[
                            const Row(
                              children: [
                                Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '❌ Tidak tersedia (Bertabrakan dengan jadwal booking lain)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                SizedBox(width: 6),
                                Text(
                                  '✅ Unit tersedia untuk diperpanjang',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: const Color(0xFFFED7AA),
                        disabledForegroundColor: const Color(0xFF9A3412),
                      ),
                      onPressed: (!_isAvailable || _totalHours <= 0 || _isCheckingAvailability || _isSubmitting)
                          ? null
                          : _proceedToPayment,
                      icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                      label: Text(
                        'Bayar di Kasir (${Formatters.currency(_totalPrice)})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (!_isAvailable || _totalHours <= 0 || _isCheckingAvailability || _isSubmitting)
                          ? null
                          : _extendDirectly,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Simpan Tambah Jam (Bayar Nanti)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
