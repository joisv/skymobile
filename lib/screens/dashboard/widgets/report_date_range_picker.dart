import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';

class ReportDateRangeResult {
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  const ReportDateRangeResult({
    required this.startDate,
    required this.endDate,
    required this.label,
  });

  int get durationDays {
    return endDate.difference(startDate).inDays + 1;
  }
}

class ReportDateRangePickerBottomSheet extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final String? initialLabel;
  final ValueChanged<ReportDateRangeResult> onApply;

  const ReportDateRangePickerBottomSheet({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    this.initialLabel,
    required this.onApply,
  });

  static Future<ReportDateRangeResult?> show(
    BuildContext context, {
    required DateTime initialStart,
    required DateTime initialEnd,
    String? initialLabel,
  }) {
    return showModalBottomSheet<ReportDateRangeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportDateRangePickerBottomSheet(
        initialStart: initialStart,
        initialEnd: initialEnd,
        initialLabel: initialLabel,
        onApply: (res) => Navigator.pop(ctx, res),
      ),
    );
  }

  @override
  State<ReportDateRangePickerBottomSheet> createState() =>
      _ReportDateRangePickerBottomSheetState();
}

class _ReportDateRangePickerBottomSheetState
    extends State<ReportDateRangePickerBottomSheet> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedPreset = 'Kustom';

  // Base date for simulated 2026 operational environment
  final DateTime _today = DateTime(2026, 9, 9);

  final List<String> _presets = [
    'Hari Ini',
    'Kemarin',
    '7 Hari Terakhir',
    '30 Hari Terakhir',
    'Bulan Ini',
    'Bulan Lalu',
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
    _selectedPreset = widget.initialLabel ?? 'Kustom';
  }

  void _applyPreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case 'Hari Ini':
          _startDate = DateTime(_today.year, _today.month, _today.day);
          _endDate = DateTime(_today.year, _today.month, _today.day, 23, 59, 59);
          break;
        case 'Kemarin':
          final y = _today.subtract(const Duration(days: 1));
          _startDate = DateTime(y.year, y.month, y.day);
          _endDate = DateTime(y.year, y.month, y.day, 23, 59, 59);
          break;
        case '7 Hari Terakhir':
          final start7 = _today.subtract(const Duration(days: 6));
          _startDate = DateTime(start7.year, start7.month, start7.day);
          _endDate = DateTime(_today.year, _today.month, _today.day, 23, 59, 59);
          break;
        case '30 Hari Terakhir':
          final start30 = _today.subtract(const Duration(days: 29));
          _startDate = DateTime(start30.year, start30.month, start30.day);
          _endDate = DateTime(_today.year, _today.month, _today.day, 23, 59, 59);
          break;
        case 'Bulan Ini':
          _startDate = DateTime(_today.year, _today.month, 1);
          _endDate = DateTime(_today.year, _today.month, 30, 23, 59, 59);
          break;
        case 'Bulan Lalu':
          final lastMonth = _today.month == 1 ? 12 : _today.month - 1;
          final year = _today.month == 1 ? _today.year - 1 : _today.year;
          _startDate = DateTime(year, lastMonth, 1);
          _endDate = DateTime(year, lastMonth, 31, 23, 59, 59);
          break;
      }
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _selectedPreset = 'Kustom';
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _selectedPreset = 'Kustom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationDays = _endDate.difference(_startDate).inDays + 1;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                  Icon(Icons.date_range_rounded, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Pilih Rentang Tanggal Laporan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Preset Chips
          Text(
            'Pilihan Cepat Periode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _presets.map((preset) {
              final isSelected = _selectedPreset == preset;
              return ChoiceChip(
                label: Text(
                  preset,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.cardBorder,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide.none,
                ),
                onSelected: (selected) {
                  if (selected) _applyPreset(preset);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Date Pickers Row (From -> To)
          Text('Rentang Tanggal Kustom',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mulai Tanggal',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.accent),
                            const SizedBox(width: 6),
                            Text(
                              Formatters.date(_startDate),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.textSecondary),
              ),
              Expanded(
                child: InkWell(
                  onTap: _selectEndDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sampai Tanggal',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Text(
                              Formatters.date(_endDate),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Duration Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.timelapse_rounded, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  'Total Durasi Laporan: $durationDays Hari',
                  style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    _applyPreset('Hari Ini');
                  },
                  child: const Text('Reset ke Hari Ini'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    final result = ReportDateRangeResult(
                      startDate: _startDate,
                      endDate: _endDate,
                      label: _selectedPreset,
                    );
                    widget.onApply(result);
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Terapkan Filter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
