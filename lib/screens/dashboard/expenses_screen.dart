import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/booking_repository.dart';
import '../../models/affiliate_model.dart';
import '../../models/expense_model.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_header.dart';
import 'widgets/report_date_range_picker.dart';

class ExpensesScreen extends StatefulWidget {
  final BookingRepository repository;
  final int? initialAffiliateId;

  const ExpensesScreen({
    super.key,
    required this.repository,
    this.initialAffiliateId,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedPeriod = 'Hari Ini';
  DateTimeRange? _customDateRange;
  int? _selectedAffiliateId;
  String _selectedCategory = 'all';

  List<ExpenseModel> _expenses = [];
  ExpenseSummaryModel _summary = const ExpenseSummaryModel(
    totalExpenses: 0.0,
    totalExpensesFormatted: 'Rp 0',
    count: 0,
    categories: {},
  );
  List<AffiliateModel> _affiliates = [];

  final List<String> _periodOptions = [
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
    'Semua',
  ];

  static const Map<String, String> _categoryOptions = {
    'all': 'Semua Kategori',
    'operasional': 'Operasional Toko',
    'listrik_internet': 'Listrik & Internet',
    'transport': 'Transport & BBM',
    'maintenance': 'Perawatan & Servis',
    'konsumsi': 'Konsumsi Staff',
    'lainnya': 'Lain-lain',
  };

  bool get _canSelectBranch {
    final auth = AuthService();
    return auth.isSuperAdmin || (auth.isAdmin && (auth.affiliateId == null || auth.affiliateId == 4));
  }

  String get _selectedBranchName {
    if (_selectedAffiliateId == null) {
      return 'Semua Cabang (Gabungan)';
    }
    final match = _affiliates.where((a) => a.id == _selectedAffiliateId).firstOrNull;
    if (match != null) {
      return match.name;
    }
    if (_selectedAffiliateId == 4) {
      return 'Genteng Pusat';
    }
    return 'Cabang #$_selectedAffiliateId';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAffiliateId != null) {
      _selectedAffiliateId = widget.initialAffiliateId;
    } else if (_canSelectBranch) {
      _selectedAffiliateId = 4; // Default to Genteng Pusat
    } else if (AuthService().affiliateId != null) {
      _selectedAffiliateId = AuthService().affiliateId;
    }
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    if (_customDateRange != null) {
      start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
      end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999);
    } else {
      switch (_selectedPeriod.toLowerCase()) {
        case 'hari ini':
          start = DateTime(now.year, now.month, now.day, 0, 0, 0);
          end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          break;
        case 'minggu ini':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          end = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59, 999);
          break;
        case 'bulan ini':
          start = DateTime(now.year, now.month, 1, 0, 0, 0);
          final lastDay = DateTime(now.year, now.month + 1, 0).day;
          end = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
          break;
        case 'semua':
        default:
          start = null;
          end = null;
          break;
      }
    }

    try {
      final res = await widget.repository.getExpensesData(
        period: _selectedPeriod,
        startDate: start,
        endDate: end,
        affiliateId: _selectedAffiliateId,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );

      List<AffiliateModel> affiliateList = _affiliates;
      if (_canSelectBranch && affiliateList.isEmpty) {
        try {
          affiliateList = await widget.repository.getAffiliates(forceRefresh: false);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _expenses = res.data;
          _summary = res.summary;
          _affiliates = affiliateList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat catatan biaya operasional: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final result = await ReportDateRangePickerBottomSheet.show(
      context,
      initialStart: _customDateRange?.start ?? DateTime(now.year, now.month, 1),
      initialEnd: _customDateRange?.end ?? now,
      initialLabel: _selectedPeriod,
    );

    if (result != null) {
      setState(() {
        _customDateRange = DateTimeRange(
          start: result.startDate,
          end: result.endDate,
        );
        _selectedPeriod = result.label;
      });
      _loadExpenses();
    }
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Yakin ingin menghapus pengeluaran sebesar ${Formatters.currency(expense.amount)} (${expense.categoryLabel})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await widget.repository.deleteExpenseData(expense.id);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Catatan pengeluaran berhasil dihapus.'),
              backgroundColor: AppTheme.success,
            ),
          );
          _loadExpenses();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _openAddExpenseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddExpenseBottomSheet(
        repository: widget.repository,
        canSelectBranch: _canSelectBranch,
        affiliates: _affiliates,
        defaultAffiliateId: _selectedAffiliateId,
        onSuccess: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengeluaran cabang berhasil dicatat.'),
              backgroundColor: AppTheme.success,
            ),
          );
          _loadExpenses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppHeader(
        title: 'Biaya Operasional',
        subtitle: _selectedBranchName,
        showBackButton: true,
        actions: [
          IconButton(
            tooltip: 'Tambah Biaya',
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.error),
            onPressed: _openAddExpenseModal,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.error,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Catat Biaya', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _openAddExpenseModal,
      ),
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBranchSelector(),
              const SizedBox(height: 12),
              _buildPeriodSelector(),
              const SizedBox(height: 12),
              _buildCategorySelector(),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildExpenseListSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchSelector() {
    if (!_canSelectBranch) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront, size: 20, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(
              'Cabang: $_selectedBranchName',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Semua Cabang (Gabungan)', style: TextStyle(fontSize: 13)),
      ),
      ..._affiliates.map((aff) {
        return DropdownMenuItem<int?>(
          value: aff.id,
          child: Text(aff.name, style: const TextStyle(fontSize: 13)),
        );
      }),
    ];

    if (_selectedAffiliateId != null && !_affiliates.any((a) => a.id == _selectedAffiliateId)) {
      items.add(
        DropdownMenuItem<int?>(
          value: _selectedAffiliateId,
          child: Text(_selectedBranchName, style: const TextStyle(fontSize: 13)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.storefront, size: 20, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _selectedAffiliateId,
                isExpanded: true,
                hint: const Text('Pilih Cabang'),
                items: items,
                onChanged: (val) {
                  setState(() {
                    _selectedAffiliateId = val;
                  });
                  _loadExpenses();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._periodOptions.map((period) {
            final isSelected = _selectedPeriod.toLowerCase() == period.toLowerCase() && _customDateRange == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(period, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                selected: isSelected,
                selectedColor: AppTheme.accent.withValues(alpha: 0.15),
                backgroundColor: AppTheme.surface,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppTheme.accent : AppTheme.cardBorder,
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPeriod = period;
                      _customDateRange = null;
                    });
                    _loadExpenses();
                  }
                },
              ),
            );
          }),
          ActionChip(
            avatar: Icon(Icons.calendar_month, size: 16, color: _customDateRange != null ? AppTheme.accent : AppTheme.textSecondary),
            label: Text(
              _customDateRange != null ? _selectedPeriod : 'Kustom',
              style: TextStyle(
                fontSize: 12,
                fontWeight: _customDateRange != null ? FontWeight.bold : FontWeight.normal,
                color: _customDateRange != null ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
            backgroundColor: _customDateRange != null ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _customDateRange != null ? AppTheme.accent : AppTheme.cardBorder,
              ),
            ),
            onPressed: _pickCustomDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categoryOptions.entries.map((entry) {
          final isSelected = _selectedCategory == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(entry.value, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              selectedColor: AppTheme.error.withValues(alpha: 0.15),
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.error : AppTheme.textSecondary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppTheme.error : AppTheme.cardBorder,
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = entry.key;
                });
                _loadExpenses();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFEF2F2),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long, color: AppTheme.error, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Pengeluaran Cabang',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onErrorContainer,
                        ),
                      ),
                      Text(
                        _selectedPeriod,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.errorBorder),
                ),
                child: Text(
                  '${_summary.count} Biaya',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            Formatters.currency(_summary.totalExpenses),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.error,
              letterSpacing: -0.5,
            ),
          ),
          if (_summary.categories.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.errorBorder),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _summary.categories.entries.map((cat) {
                final label = _categoryOptions[cat.key] ?? cat.key.replaceAll('_', ' ');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Text(
                    '$label: ${Formatters.currency(cat.value)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseListSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 36),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.onErrorContainer, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadExpenses,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.savings_outlined, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Belum ada catatan pengeluaran',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada biaya operasional tercatat pada periode ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Catat Pengeluaran Baru'),
              onPressed: _openAddExpenseModal,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rincian Biaya Operasional',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              '${_expenses.length} Transaksi',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _expenses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = _expenses[index];
            return _buildExpenseCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildExpenseCard(ExpenseModel item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_upward, color: AppTheme.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.categoryLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '-${Formatters.currency(item.amount)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
                if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.storefront, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      item.affiliateName,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.person_outline, size: 13, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      item.userName,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const Spacer(),
                    Text(
                      item.spentAtFormatted.isNotEmpty ? item.spentAtFormatted : (item.spentAt?.toString() ?? ''),
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.textMuted),
            tooltip: 'Hapus Biaya',
            onPressed: () => _deleteExpense(item),
          ),
        ],
      ),
    );
  }
}

class _AddExpenseBottomSheet extends StatefulWidget {
  final BookingRepository repository;
  final bool canSelectBranch;
  final List<AffiliateModel> affiliates;
  final int? defaultAffiliateId;
  final VoidCallback onSuccess;

  const _AddExpenseBottomSheet({
    required this.repository,
    required this.canSelectBranch,
    required this.affiliates,
    this.defaultAffiliateId,
    required this.onSuccess,
  });

  @override
  State<_AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<_AddExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'operasional';
  int? _selectedAffiliateId;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  String? _submitError;

  static const Map<String, String> _categories = {
    'operasional': 'Operasional Toko',
    'listrik_internet': 'Listrik & Internet',
    'transport': 'Transport & BBM',
    'maintenance': 'Perawatan & Servis',
    'konsumsi': 'Konsumsi Staff',
    'lainnya': 'Lain-lain',
  };

  @override
  void initState() {
    super.initState();
    _selectedAffiliateId = widget.defaultAffiliateId ?? 4;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final rawAmountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(rawAmountText) ?? 0.0;
    if (amount <= 0) {
      setState(() {
        _submitError = 'Nominal pengeluaran harus lebih besar dari Rp 0.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      await widget.repository.createExpenseData(
        amount: amount,
        category: _selectedCategory,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        spentAt: _selectedDate,
        affiliateId: widget.canSelectBranch ? _selectedAffiliateId : null,
      );

      if (mounted) {
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitError = 'Gagal mencatat pengeluaran: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Catat Biaya Operasional',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              if (_submitError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorBorder),
                  ),
                  child: Text(
                    _submitError!,
                    style: const TextStyle(color: AppTheme.onErrorContainer, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Branch Selector (if admin)
              if (widget.canSelectBranch && widget.affiliates.isNotEmpty) ...[
                const Text('Cabang:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int?>(
                  value: widget.affiliates.any((a) => a.id == _selectedAffiliateId)
                      ? _selectedAffiliateId
                      : (widget.affiliates.isNotEmpty ? widget.affiliates.first.id : null),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: widget.affiliates.map((aff) {
                    return DropdownMenuItem<int?>(
                      value: aff.id,
                      child: Text(aff.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedAffiliateId = val;
                    });
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Category Selector
              const Text('Kategori Biaya:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _categories.entries.map((e) {
                  return DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Amount
              const Text('Nominal Pengeluaran (Rp):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '50.000',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nominal wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Notes
              const Text('Keterangan / Keperluan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Contoh: Beli token listrik toko, bensin kurir, snack tamu...',
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Simpan Pengeluaran',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
