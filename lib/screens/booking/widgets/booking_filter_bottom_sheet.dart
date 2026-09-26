import 'package:flutter/material.dart';
import '../../../data/booking_repository.dart';
import '../../../models/booking_model.dart';
import '../../../theme/app_theme.dart';

class BookingFilterBottomSheet extends StatefulWidget {
  final BookingFilterParams initialParams;
  final ValueChanged<BookingFilterParams> onApply;

  const BookingFilterBottomSheet({
    super.key,
    required this.initialParams,
    required this.onApply,
  });

  @override
  State<BookingFilterBottomSheet> createState() => _BookingFilterBottomSheetState();
}

class _BookingFilterBottomSheetState extends State<BookingFilterBottomSheet> {
  late BookingSortBy _sortBy;
  late PaymentStatus? _paymentStatus;
  late String? _pickupType;
  late bool _onlyToday;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initialParams.sortBy;
    _paymentStatus = widget.initialParams.paymentFilter;
    _pickupType = widget.initialParams.pickupTypeFilter;
    _onlyToday = widget.initialParams.onlyToday;
  }

  void _reset() {
    setState(() {
      _sortBy = BookingSortBy.scheduleAsc;
      _paymentStatus = null;
      _pickupType = null;
      _onlyToday = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter & Pengurutan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text('Reset', style: TextStyle(color: AppTheme.accent)),
                ),
              ],
            ),
            Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 14),

            // Section 1: Urutkan Berdasarkan
            Text(
              'Urutkan Hasil',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: BookingSortBy.values.map((sort) {
                final isSelected = _sortBy == sort;
                return ChoiceChip(
                  label: Text(sort.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _sortBy = sort);
                  },
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Section 2: Status Pembayaran
            Text(
              'Status Pembayaran',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _paymentStatus == null,
                  onSelected: (selected) {
                    if (selected) setState(() => _paymentStatus = null);
                  },
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: _paymentStatus == null ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: _paymentStatus == null ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                ...PaymentStatus.values.map((status) {
                  final isSelected = _paymentStatus == status;
                  return ChoiceChip(
                    label: Text(status.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _paymentStatus = selected ? status : null);
                    },
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),

            // Section 3: Tipe Penyerahan
            Text(
              'Metode Penyerahan Unit',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Semua', 'Outlet', 'Delivery'].map((type) {
                final isSelected = (_pickupType == null && type == 'Semua') || (_pickupType == type);
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _pickupType = type == 'Semua' ? null : type);
                  },
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Section 4: Hanya Hari Ini
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Jadwal Operasional Hari Ini',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              subtitle: Text('Hanya tampilkan booking yang pickup/return hari ini',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              value: _onlyToday,
              activeThumbColor: AppTheme.accent,
              onChanged: (val) => setState(() => _onlyToday = val),
            ),
            const SizedBox(height: 16),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final newParams = widget.initialParams.copyWith(
                    sortBy: _sortBy,
                    paymentFilter: () => _paymentStatus,
                    pickupTypeFilter: () => _pickupType,
                    onlyToday: _onlyToday,
                  );
                  widget.onApply(newParams);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Terapkan Filter', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
