import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/booking_repository.dart';
import '../../models/booking_model.dart';
import '../../models/iphone_model.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_header.dart';

/// Formatter otomatis nomor WhatsApp (8123-4567-8901)
class _PhoneHyphenFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final chunks = <String>[];
    for (int i = 0; i < digits.length; i += 4) {
      final end = (i + 4 < digits.length) ? i + 4 : digits.length;
      chunks.add(digits.substring(i, end));
    }
    final formatted = chunks.join('-');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CreateBookingScreen extends StatefulWidget {
  final BookingRepository repository;

  const CreateBookingScreen({super.key, required this.repository});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  static const double _contentMaxWidth = 1120;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers (Step 1)
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isValidatingPhone = false;
  String? _phoneErrorText;
  String _searchQuery = '';

  // Options & Selections
  String _countryCode = '+62';
  final List<Map<String, String>> _countryCodes = const [
    {'code': '+62', 'flag': '🇮🇩', 'name': 'Indonesia (+62)'},
    {'code': '+60', 'flag': '🇲🇾', 'name': 'Malaysia (+60)'},
    {'code': '+65', 'flag': '🇸🇬', 'name': 'Singapura (+65)'},
    {'code': '+66', 'flag': '🇹🇭', 'name': 'Thailand (+66)'},
    {'code': '+63', 'flag': '🇵🇭', 'name': 'Filipina (+63)'},
    {'code': '+84', 'flag': '🇻🇳', 'name': 'Vietnam (+84)'},
  ];

  String _jaminanType = 'KTP';
  final List<Map<String, String>> _jaminanOptions = const [
    {'value': 'KTP', 'label': 'KTP Asli Fisik', 'desc': 'KTP Elektronik WNI'},
    {'value': 'SIM', 'label': 'SIM A/C Aktif', 'desc': 'SIM Masih Berlaku'},
    {'value': 'Kartu Pelajar', 'label': 'Kartu Pelajar', 'desc': 'Siswa SMP / SMA'},
    {'value': 'Kartu Identitas Mahasiswa', 'label': 'KTM Mahasiswa', 'desc': 'KTM Perguruan Tinggi'},
    {'value': 'KK', 'label': 'KK (Keluarga)', 'desc': 'Kartu Keluarga Asli/Legalisir'},
    {'value': 'Kartu Identitas Anak', 'label': 'KIA (Anak)', 'desc': 'Kartu Identitas Anak'},
  ];

  int _currentStep = 1; // 1: Data Tamu, 2: Unit & Durasi, 3: Konfirmasi
  List<IphoneModel> _availableUnits = [];
  IphoneModel? _selectedUnit;
  IphoneDurationOption? _selectedDurationOption;
  bool _isLoadingUnits = true;
  String _selectedAvailabilityFilter = 'tersedia'; // 'tersedia' (default), 'semua', 'disewa'
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalUnits = 0;
  bool _isLoadingMoreUnits = false;

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();

  bool _isCustomDurationMode = false;
  int _customJumlah = 1;
  String _customUnit = 'Hari'; // 'Hari', 'Minggu', 'Bulan'

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _startTime = TimeOfDay.now();
    _fetchAvailableUnits();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isUnitAvailableForBooking(IphoneModel unit) {
    final s = unit.status.toLowerCase().trim();
    if (!['ready', 'tersedia'].contains(s)) return false;
    return widget.repository.isUnitAvailableForPeriod(unit, _startDateTime, _endDateTime);
  }

  void _applyPaginatedUnits(PaginatedIphonesResult result, {required bool append}) {
    var incomingUnits = result.units;

    // Enforce affiliate scoping for Section 2:
    // 1. Affiliate / Affiliate Admin: only show iPhones where iphone.affiliate_id matches user's affiliate_id
    // 2. Super Admin: show ONLY iPhones where affiliate_id IS NULL (unassigned/global iPhones)
    if (AuthService().isSuperAdmin) {
      incomingUnits = incomingUnits.where((u) => u.affiliateId == null).toList();
    } else if (AuthService().isAffiliateScoped && AuthService().affiliateId != null) {
      incomingUnits = incomingUnits.where((u) {
        if (u.affiliateId == null) return false;
        return u.affiliateId == AuthService().affiliateId;
      }).toList();
    }

    final List<IphoneModel> updatedList;
    if (append) {
      final existingIds = _availableUnits.map((u) => u.id).toSet();
      updatedList = List.from(_availableUnits)
        ..addAll(incomingUnits.where((u) => !existingIds.contains(u.id)));
    } else {
      updatedList = incomingUnits;
    }

    final currentSelected = _selectedUnit;
    IphoneModel? matchedUnit;

    if (currentSelected != null) {
      final found = updatedList.where((u) => u.id == currentSelected.id).firstOrNull;
      if (found != null) {
        matchedUnit = _isUnitAvailableForBooking(found) ? found : null;
      } else {
        matchedUnit = _isUnitAvailableForBooking(currentSelected) ? currentSelected : null;
      }
    }

    setState(() {
      _availableUnits = updatedList;
      _currentPage = result.currentPage;
      _lastPage = result.lastPage;
      _totalUnits = result.total;
      _selectedUnit = matchedUnit;
      if (_selectedDurationOption != null && matchedUnit != null) {
        _selectedDurationOption = matchedUnit.availableDurations
            .where((d) => d.hours == _selectedDurationOption!.hours)
            .firstOrNull ?? matchedUnit.availableDurations.firstOrNull;
      } else {
        _selectedDurationOption = matchedUnit?.availableDurations.firstOrNull;
      }
      _isLoadingUnits = false;
      _isLoadingMoreUnits = false;
    });
  }

  Future<void> _fetchAvailableUnits({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoadingUnits = true;
        _currentPage = 1;
      });
    }

    try {
      final isScoped = AuthService().isAffiliateScoped;
      final userAffiliateId = AuthService().affiliateId;
      final effectiveAffId = isScoped ? userAffiliateId : null;

      final startH = _startTime.hour.toString().padLeft(2, '0');
      final startM = _startTime.minute.toString().padLeft(2, '0');
      final endH = _endDateTime.hour.toString().padLeft(2, '0');
      final endM = _endDateTime.minute.toString().padLeft(2, '0');

      final result = await widget.repository.getInventoryUnitsPaginated(
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        statusFilter: _selectedAvailabilityFilter,
        affiliateId: effectiveAffId,
        startDate: _startDate,
        endDate: _endDateTime,
        startTime: '$startH:$startM',
        endTime: '$endH:$endM',
        duration: _durationHoursToSubmit,
        forBooking: true,
        page: _currentPage,
        perPage: 10,
      );
      if (mounted) _applyPaginatedUnits(result, append: !reset);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingUnits = false;
          _isLoadingMoreUnits = false;
        });
      }
    }
  }

  Future<void> _loadMoreUnits() async {
    if (_isLoadingMoreUnits || _currentPage >= _lastPage) return;
    setState(() {
      _isLoadingMoreUnits = true;
      _currentPage++;
    });
    await _fetchAvailableUnits(reset: false);
  }

  void _resetForm() {
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _addressController.clear();
    _notesController.clear();
    _searchController.clear();
    setState(() {
      _currentStep = 1;
      _searchQuery = '';
      _selectedAvailabilityFilter = 'tersedia';
      _currentPage = 1;
      _lastPage = 1;
      _totalUnits = 0;
      _isCustomDurationMode = false;
      _customJumlah = 1;
      _customUnit = 'Hari';
      _startDate = DateTime.now();
      _startTime = TimeOfDay.now();
      _phoneErrorText = null;
    });
    _fetchAvailableUnits(reset: true);
  }

  // Calculations & Getters
  DateTime get _startDateTime => DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  int get _customHours {
    switch (_customUnit) {
      case 'Hari':
        return 24 * _customJumlah;
      case 'Minggu':
        return 24 * 7 * _customJumlah;
      case 'Bulan':
        return 24 * 30 * _customJumlah;
      default:
        return 24 * _customJumlah;
    }
  }

  int get _durationHoursToSubmit {
    if (!_isCustomDurationMode && _selectedDurationOption != null) {
      return _selectedDurationOption!.hours;
    }
    return _customHours;
  }

  DateTime get _endDateTime => _startDateTime.add(Duration(hours: _durationHoursToSubmit));

  double get _dailyRate {
    if (_selectedUnit != null && _selectedUnit!.availableDurations.isNotEmpty) {
      final d24 = _selectedUnit!.availableDurations.where((d) => d.hours == 24).firstOrNull;
      return d24 != null ? d24.price : _selectedUnit!.availableDurations.first.price;
    }
    return 150000.0;
  }

  double get _customPrice {
    final base = _dailyRate;
    switch (_customUnit) {
      case 'Hari':
        return base * _customJumlah;
      case 'Minggu':
        return base * 7 * _customJumlah;
      case 'Bulan':
        return base * 30 * _customJumlah;
      default:
        return base * _customJumlah;
    }
  }

  double get _rentTotal {
    if (_selectedUnit == null) return 0.0;
    if (!_isCustomDurationMode && _selectedDurationOption != null) {
      return _selectedDurationOption!.price;
    }
    return _customPrice;
  }

  double get _depositTotal => 0.0;
  double get _grandTotal => _rentTotal;

  String _formatPhoneNumber(String phone) {
    var clean = phone.replaceAll(RegExp(r'\D'), '');
    final countryDigits = _countryCode.replaceAll(RegExp(r'\D'), '');
    if (countryDigits.isNotEmpty && clean.startsWith(countryDigits)) {
      clean = clean.substring(countryDigits.length);
    }
    if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    if (clean.isEmpty) return _countryCode;
    final chunks = <String>[];
    for (int i = 0; i < clean.length; i += 4) {
      final end = (i + 4 < clean.length) ? i + 4 : clean.length;
      chunks.add(clean.substring(i, end));
    }
    return '$_countryCode-${chunks.join('-')}';
  }

  String _getJaminanLabel(String val) {
    for (final opt in _jaminanOptions) {
      if (opt['value'] == val) return opt['label']!;
    }
    return val;
  }

  String _getCustomerInitials() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'RH';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'RH';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // Validations & Dialogs
  bool _validateSection1() {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 3) {
      _showSnackbar('Nama customer tidak boleh kosong (minimal 3 karakter).', isError: true);
      return false;
    }

    final phone = _phoneController.text.trim();
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    final isAllSame = RegExp(r'^(\d)\1+$').hasMatch(digitsOnly);
    final countryDigits = _countryCode.replaceAll(RegExp(r'\D'), '');

    var localDigits = digitsOnly;
    if (countryDigits.isNotEmpty && localDigits.startsWith(countryDigits)) {
      localDigits = localDigits.substring(countryDigits.length);
    }
    if (localDigits.startsWith('0')) {
      localDigits = localDigits.substring(1);
    }

    final isIndo = _countryCode == '+62';
    final isValidIndo = !isIndo ||
        RegExp(r'^(?:08|628|8)[0-9]{7,12}$').hasMatch(digitsOnly) ||
        RegExp(r'^[0-9]{8,12}$').hasMatch(localDigits);

    if (phone.isEmpty || digitsOnly.length < 8 || isAllSame || !isValidIndo) {
      setState(() {
        _phoneErrorText = 'Nomor WhatsApp tidak valid. Format harus diawali 08/628 dan 10-13 digit.';
      });
      _showSnackbar(_phoneErrorText!, isError: true);
      return false;
    }
    setState(() => _phoneErrorText = null);

    final address = _addressController.text.trim();
    if (address.isEmpty || address.length < 5) {
      _showSnackbar('Alamat customer tidak boleh kosong (minimal 5 karakter).', isError: true);
      return false;
    }

    if (_jaminanType.isEmpty) {
      _showSnackbar('Silakan pilih tipe jaminan identitas resmi Skyrent.', isError: true);
      return false;
    }

    if (_currentStep == 1) {
      return _formKey.currentState?.validate() ?? true;
    }
    return true;
  }

  bool _validateSection2() {
    if (_selectedUnit == null) {
      _showSnackbar('Silakan pilih salah satu unit iPhone yang tersedia.', isError: true);
      return false;
    }

    final unitStatus = _selectedUnit!.status.toLowerCase().trim();
    if (['rented', 'disewa'].contains(unitStatus) || widget.repository.isUnitCurrentlyRented(_selectedUnit!.assetCode)) {
      _showRentedUnitWarningDialog(_selectedUnit!);
      return false;
    }
    if (['maintenance', 'perawatan'].contains(unitStatus)) {
      _showMaintenanceUnitWarningDialog(_selectedUnit!);
      return false;
    }
    if (!_isUnitAvailableForBooking(_selectedUnit!)) {
      _showScheduleConflictWarningDialog(_selectedUnit!);
      return false;
    }
    if (!_isCustomDurationMode && _selectedDurationOption == null) {
      _showSnackbar('Silakan pilih durasi sewa yang tersedia.', isError: true);
      return false;
    }
    if (_isCustomDurationMode && _customJumlah < 1) {
      _showSnackbar('Jumlah durasi custom minimal 1.', isError: true);
      return false;
    }
    return true;
  }

  bool _validateSection3() {
    if (!_validateSection1()) {
      setState(() => _currentStep = 1);
      return false;
    }
    if (!_validateSection2()) {
      setState(() => _currentStep = 2);
      return false;
    }
    return true;
  }

  void _showUnitWarningDialog(IphoneModel unit, {required bool isRented}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isRented ? AppTheme.warning : AppTheme.error).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRented ? Icons.lock_clock_rounded : Icons.build_rounded,
                color: isRented ? AppTheme.warning : AppTheme.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isRented ? 'Unit Sedang Disewa' : 'Unit Dalam Perawatan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRented
                  ? 'Unit ${unit.modelName} (${unit.color}, SN: ${unit.serialNumber}) saat ini sedang dalam masa sewa aktif oleh pelanggan lain dan tidak dapat disewa ulang.'
                  : 'Unit ${unit.modelName} (${unit.color}, SN: ${unit.serialNumber}) sedang dalam status perbaikan/maintenance teknis.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRented
                          ? 'Unit baru dapat disewa kembali setelah proses inspeksi pengembalian unit selesai.'
                          : 'Pilih unit iPhone lain yang bertanda Tersedia untuk melanjutkan.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showRentedUnitWarningDialog(IphoneModel unit) => _showUnitWarningDialog(unit, isRented: true);
  void _showMaintenanceUnitWarningDialog(IphoneModel unit) => _showUnitWarningDialog(unit, isRented: false);

  void _showScheduleConflictWarningDialog(IphoneModel unit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppTheme.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Jadwal Sudah Dibooking',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unit ${unit.modelName} (${unit.color}, SN: ${unit.serialNumber}) telah dibooking oleh pelanggan lain untuk jadwal sewa yang Anda pilih.',
              style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Silakan pilih unit iPhone lain yang masih tersedia atau sesuaikan tanggal dan durasi sewa.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Step Navigation Handlers
  Future<void> _handleNextFromStep1() async {
    if (!_validateSection1()) return;

    final fullPhone = _formatPhoneNumber(_phoneController.text.trim());
    setState(() {
      _isValidatingPhone = true;
      _phoneErrorText = null;
    });

    try {
      final result = await widget.repository.validateWhatsApp(fullPhone);
      if (result['registered'] == false) {
        final errorMsg = result['message']?.toString() ?? 'Nomor WhatsApp yang Anda masukkan tidak terdaftar di WhatsApp.';
        setState(() => _phoneErrorText = errorMsg);
        if (mounted) _showSnackbar(errorMsg, isError: true);
        return;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isValidatingPhone = false);
    }

    if (mounted) setState(() => _currentStep = 2);
  }

  void _nextStep() {
    if (_currentStep == 1) {
      _handleNextFromStep1();
    } else if (_currentStep == 2) {
      if (_validateSection2()) setState(() => _currentStep = 3);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) setState(() => _currentStep--);
  }

  void _goToStep(int targetStep) {
    if (targetStep == _currentStep) return;
    if (targetStep < _currentStep) {
      setState(() => _currentStep = targetStep);
    } else if (targetStep == 2) {
      if (_validateSection1()) setState(() => _currentStep = 2);
    } else if (targetStep == 3) {
      if (_validateSection1() && _validateSection2()) setState(() => _currentStep = 3);
    }
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_selectedUnit != null && !_isUnitAvailableForBooking(_selectedUnit!)) {
          _selectedUnit = null;
          _selectedDurationOption = null;
        }
      });
      _fetchAvailableUnits();
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      setState(() {
        _startTime = picked;
        if (_selectedUnit != null && !_isUnitAvailableForBooking(_selectedUnit!)) {
          _selectedUnit = null;
          _selectedDurationOption = null;
        }
      });
      _fetchAvailableUnits();
    }
  }

  Future<void> _submitBooking() async {
    if (!_validateSection3()) return;
    if (_selectedUnit == null) {
      _showSnackbar('Silakan pilih salah satu unit iPhone yang tersedia.', isError: true);
      return;
    }

    final unitStatus = _selectedUnit!.status.toLowerCase().trim();
    if (['rented', 'disewa'].contains(unitStatus) ||
        widget.repository.isUnitCurrentlyRented(_selectedUnit!.assetCode)) {
      _showRentedUnitWarningDialog(_selectedUnit!);
      return;
    }
    if (['maintenance', 'perawatan'].contains(unitStatus)) {
      _showMaintenanceUnitWarningDialog(_selectedUnit!);
      return;
    }
    if (!_isUnitAvailableForBooking(_selectedUnit!)) {
      _showScheduleConflictWarningDialog(_selectedUnit!);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim().isEmpty
          ? '${_nameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}@customer.local'
          : _emailController.text.trim();
      final fullPhone = _formatPhoneNumber(_phoneController.text.trim());

      final newBooking = await widget.repository.createBooking(
        customerName: _nameController.text.trim(),
        customerPhone: fullPhone,
        customerEmail: email,
        address: _addressController.text.trim(),
        iphone: _selectedUnit!,
        startDate: _startDateTime,
        endDate: _endDateTime,
        durationDays: _durationHoursToSubmit,
        price: _rentTotal,
        deposit: _depositTotal,
        jaminanType: _jaminanType,
        pickupType: 'pickup',
        paymentStatus: PaymentStatus.unpaid,
        amountPaid: 0,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pushReplacementNamed(context, AppRoutes.paymentDeposit, arguments: newBooking);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _showSnackbar('Gagal membuat booking: $cleanMsg', isError: true);
      }
    }
  }

  MediaQueryData _isolatedMediaQuery(BuildContext context) {
    return MediaQueryData(
      size: MediaQuery.sizeOf(context),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      textScaler: MediaQuery.textScalerOf(context),
      platformBrightness: MediaQuery.platformBrightnessOf(context),
      padding: MediaQuery.paddingOf(context),
      viewPadding: MediaQuery.viewPaddingOf(context),
      viewInsets: EdgeInsets.zero,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      accessibleNavigation: MediaQuery.accessibleNavigationOf(context),
      invertColors: MediaQuery.invertColorsOf(context),
      highContrast: MediaQuery.highContrastOf(context),
      disableAnimations: MediaQuery.disableAnimationsOf(context),
      boldText: MediaQuery.boldTextOf(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: _isolatedMediaQuery(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final isTabletLandscape = constraints.maxWidth >= 900 && isLandscape;
          
          return isTabletLandscape ? _buildTabletLayout(context) : _buildMobileLayout(context);
        },
      ),
    );
  }

  // ===========================================================================
  // TABLET LANDSCAPE POS LAYOUT (66:34)
  // ===========================================================================
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      appBar: const AppHeader(isTablet: true, title: 'Buat Booking Baru'),
      body: Column(
        children: [
          _buildTabletSubHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 66,
                    child: RepaintBoundary(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 340),
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Form(key: _formKey, child: _buildTabletLeftColumn(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 34,
                    child: RepaintBoundary(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTabletTopRightNavButtons(context),
                            const SizedBox(height: 16),
                            _buildTabletLivePreviewCard(context),
                          ],
                        ),
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

  Widget _buildTabletSubHeader(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 14, color: Color(0xFF475569)),
                            SizedBox(width: 4),
                            Text('Antrean Booking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          ],
                        ),
                      ),
                      const Text('  /  Formulir Booking Baru', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Buat Booking Baru',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('DRAFT #BK-8821', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildTabletStepperPills(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletStepperPills() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTabletStepPill(step: 1, title: 'Data Tamu', isCompleted: _currentStep > 1, isActive: _currentStep == 1, onTap: () => _goToStep(1)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8))),
        _buildTabletStepPill(step: 2, title: 'Unit & Durasi', isCompleted: _currentStep > 2, isActive: _currentStep == 2, onTap: () => _goToStep(2)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8))),
        _buildTabletStepPill(step: 3, title: 'Konfirmasi', isCompleted: false, isActive: _currentStep == 3, onTap: () => _goToStep(3)),
      ],
    );
  }

  Widget _buildTabletStepPill({
    required int step,
    required String title,
    required bool isCompleted,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: (isActive || isCompleted) ? const Color(0xFF0F172A) : Colors.white,
          border: Border.all(color: (isActive || isCompleted) ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF10B981) : (isActive ? Colors.white : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : Text('$step', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
            ),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: (isActive || isCompleted) ? Colors.white : const Color(0xFF64748B))),
            if (isCompleted) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabletSectionCard({required Widget child}) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildTabletTopRightNavButtons(BuildContext context) {
    final String nextLabel = _currentStep < 3 ? 'Lanjut' : 'Konfirmasi';
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_currentStep > 1) ...[
              OutlinedButton(
                key: _currentStep == 2
                    ? const Key('btn_prev_to_step_1')
                    : const Key('btn_prev_to_step_2'),
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 15, color: Color(0xFF334155)),
                    SizedBox(width: 4),
                    Text('Kembali', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton(
                  key: _currentStep == 1
                      ? const Key('btn_next_to_step_2')
                      : (_currentStep == 2
                          ? const Key('btn_next_to_step_3')
                          : const Key('btn_confirm_booking')),
                  onPressed: _isSubmitting || _isValidatingPhone
                      ? null
                      : (_currentStep == 1
                          ? _handleNextFromStep1
                          : (_currentStep == 2 ? _nextStep : _submitBooking)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == 3 ? const Color(0xFF047857) : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: (_isSubmitting || _isValidatingPhone)
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                nextLabel,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _currentStep == 3 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                              size: 15,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLeftColumn(BuildContext context) {
    switch (_currentStep) {
      case 1:
        return _buildTabletSection1(context);
      case 2:
        return _buildTabletSection2(context);
      case 3:
      default:
        return _buildTabletSection3(context);
    }
  }

  Widget _buildTabletSection1(BuildContext context) {
    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. Data & Jaminan Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _buildNameField(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: _buildPhoneField(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildEmailField(),
          const SizedBox(height: 14),
          _buildAddressField(),
          const SizedBox(height: 18),
          _buildJaminanSelector(),
        ],
      ),
    );
  }

  Widget _buildTabletSection2(BuildContext context) {
    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('2. Unit iPhone & Durasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Pilih Unit iPhone Tersedia', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          _buildUnitSearchAndFilterBar(),
          const SizedBox(height: 16),
          _buildUnitListWrap(isTablet: true),
          const SizedBox(height: 20),
          _buildDurationSelectionSection(),
          const SizedBox(height: 20),
          _buildSchedulePickerSection(),
        ],
      ),
    );
  }

  Widget _buildTabletSection3(BuildContext context) {
    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('3. Estimasi Biaya & Konfirmasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: const Text('ID: #BK-8821', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildBillingRow('Sewa ${_selectedUnit?.modelName ?? 'iPhone'}', Formatters.formatCurrency(_rentTotal)),
          _buildBillingRow('Deposit Fisik & Jaminan', 'Rp 0 (Jaminan ${_getJaminanLabel(_jaminanType)})'),
          const Divider(color: Color(0xFFE2E8F0)),
          _buildBillingRow('TOTAL TAGIHAN BAYAR DI KASIR', Formatters.formatCurrency(_grandTotal), isAccent: true),
          const SizedBox(height: 18),
          const Text('Catatan Tagihan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Tambahkan catatan jika ada kebutuhan khusus...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLivePreviewCard(BuildContext context) {
    return _buildTabletSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pratinjau Data Booking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                    SizedBox(height: 2),
                    Text('Ringkasan instan input kasir & kontrak', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Customer Preview
          AnimatedBuilder(
            animation: Listenable.merge([_nameController, _phoneController, _emailController, _addressController]),
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DATA CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(_getJaminanLabel(_jaminanType), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nameController.text.trim().isEmpty ? 'Nama belum diisi' : _nameController.text.trim(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _nameController.text.trim().isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                      fontStyle: _nameController.text.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  Text(
                    _phoneController.text.trim().isEmpty ? 'No. WhatsApp belum diisi' : _formatPhoneNumber(_phoneController.text.trim()),
                    style: TextStyle(
                      fontSize: 11,
                      color: _phoneController.text.trim().isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontStyle: _phoneController.text.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  Text(
                    _addressController.text.trim().isEmpty ? 'Alamat belum diisi' : _addressController.text.trim(),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _addressController.text.trim().isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      fontStyle: _addressController.text.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Unit Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('UNIT & DURASI SEWA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    Text(
                      _selectedUnit == null
                          ? '-'
                          : (!_isCustomDurationMode && _selectedDurationOption != null ? _selectedDurationOption!.displayName : '$_customJumlah $_customUnit'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _selectedUnit == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedUnit?.modelName ?? '-',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _selectedUnit == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    fontStyle: _selectedUnit == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                Text(
                  _selectedUnit != null
                      ? '${_selectedUnit!.color} • SN: ${_selectedUnit!.serialNumber}'
                      : 'Pilih unit iPhone di formulir',
                  style: TextStyle(
                    fontSize: 11,
                    color: _selectedUnit == null ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontStyle: _selectedUnit == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 6),
                if (_selectedUnit != null) ...[
                  Text('Mulai: ${Formatters.date(_startDate)}, ${Formatters.time(_startDateTime)} WIB', style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155))),
                  Text('Selesai: ${Formatters.date(_endDateTime)}, ${Formatters.time(_endDateTime)} WIB', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                ] else ...[
                  const Text('Durasi sewa: -', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Calculation Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL BIAYA SEWA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                Text(Formatters.formatCurrency(_grandTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF166534))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE PORTRAIT LAYOUT
  // ===========================================================================
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: false,
      appBar: AppHeader(
        title: 'Buat Booking Baru',
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textSecondary),
            tooltip: 'Reset Form',
            onPressed: _resetForm,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Text('Draft #BK-8821', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStepperHeader(),
            Expanded(
              child: RepaintBoundary(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 320),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                      child: _buildCurrentStepContent(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildStickyBottomDock(),
    );
  }

  Widget _buildStepperHeader() {
    final double progress = _currentStep == 1 ? 0.33 : (_currentStep == 2 ? 0.66 : 1.0);
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStepItem(step: '1', label: '1. Data Tamu', isCompleted: _currentStep > 1, isActive: _currentStep == 1, onTap: () => _goToStep(1))),
                  Expanded(child: _buildStepItem(step: '2', label: '2. Unit & Durasi', isCompleted: _currentStep > 2, isActive: _currentStep == 2, onTap: () => _goToStep(2))),
                  Expanded(child: _buildStepItem(step: '3', label: '3. Konfirmasi', isCompleted: false, isActive: _currentStep == 3, onTap: () => _goToStep(3))),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppTheme.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required String step,
    required String label,
    required bool isCompleted,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = (isCompleted || isActive) ? AppTheme.secondary : AppTheme.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? AppTheme.secondary : (isActive ? AppTheme.primary : AppTheme.surfaceContainerLow),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(step, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (isActive || isCompleted) ? Colors.white : AppTheme.textMuted)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildCustomerSection();
      case 2:
        return Column(
          children: [
            _buildCustomerSummaryCard(),
            const SizedBox(height: 14),
            _buildUnitSection(),
          ],
        );
      case 3:
      default:
        return Column(
          children: [
            _buildBookingSummaryOverviewCard(),
            const SizedBox(height: 14),
            _buildReviewSummarySection(),
          ],
        );
    }
  }

  Widget _buildCustomerSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.cardBorder)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Text(_getCustomerInitials(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nameController.text.trim().isEmpty ? 'Customer' : _nameController.text.trim(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${_formatPhoneNumber(_phoneController.text.trim())} • Jaminan: ${_getJaminanLabel(_jaminanType)}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary), onPressed: () => _goToStep(1)),
        ],
      ),
    );
  }

  Widget _buildBookingSummaryOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedUnit?.modelName ?? 'iPhone',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                !_isCustomDurationMode && _selectedDurationOption != null ? _selectedDurationOption!.displayName : '$_customJumlah $_customUnit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Jadwal: ${Formatters.date(_startDate)} - ${Formatters.date(_endDateTime)}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Data & Jaminan Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildNameField(),
            const SizedBox(height: 12),
            _buildPhoneField(),
            const SizedBox(height: 12),
            _buildEmailField(),
            const SizedBox(height: 12),
            _buildAddressField(),
            const SizedBox(height: 16),
            _buildJaminanSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildJaminanSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipe Jaminan Fisik Diserahkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _jaminanOptions.map((opt) {
            final val = opt['value']!;
            final label = opt['label']!;
            final isSelected = _jaminanType == val;
            return InkWell(
              onTap: () => setState(() => _jaminanType = val),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF334155)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nama Lengkap Customer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: null,
          scrollPadding: const EdgeInsets.only(bottom: 40),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.badge_outlined, size: 18, color: AppTheme.textSecondary),
            hintText: 'Nama lengkap customer',
          ),
          validator: (v) => (v == null || v.trim().length < 3) ? 'Nama customer tidak boleh kosong' : null,
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nomor Customer (WhatsApp Aktif)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _countryCode,
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  items: _countryCodes.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['code'],
                      child: Text('${item['flag']} ${item['code']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _countryCode = val);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: null,
                scrollPadding: const EdgeInsets.only(bottom: 40),
                inputFormatters: [_PhoneHyphenFormatter()],
                decoration: InputDecoration(
                  hintText: '8123-4567-8901',
                  errorText: _phoneErrorText,
                ),
                validator: (v) {
                  final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  return clean.length < 8 ? 'Nomor customer tidak boleh kosong (min 8 digit)' : null;
                },
                onChanged: (_) {
                  if (_phoneErrorText != null) setState(() => _phoneErrorText = null);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alamat Email Customer (Opsional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: null,
          scrollPadding: const EdgeInsets.only(bottom: 40),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.mail_outline, size: 18, color: AppTheme.textSecondary),
            hintText: 'nama@domain.com',
          ),
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alamat Customer (Sesuai Identitas)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _addressController,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: null,
          scrollPadding: const EdgeInsets.only(bottom: 40),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: AppTheme.textSecondary),
            hintText: 'Alamat domisili tempat tinggal',
          ),
          validator: (v) => (v == null || v.trim().length < 5) ? 'Alamat customer tidak boleh kosong' : null,
        ),
      ],
    );
  }

  Widget _buildUnitSearchAndFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _fetchAvailableUnits(reset: true);
                    },
                  )
                : null,
            hintText: 'Cari Tipe iPhone',
            helperText: 'Gunakan serial number atau nama iphone',
            filled: true,
            fillColor: AppTheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.cardBorder),
            ),
          ),
          onChanged: (val) {
            setState(() => _searchQuery = val);
            _fetchAvailableUnits(reset: true);
          },
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildAvailabilityFilterChip(
                key: const Key('filter_chip_tersedia'),
                label: 'Tersedia (Default)',
                value: 'tersedia',
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 8),
              _buildAvailabilityFilterChip(
                key: const Key('filter_chip_semua'),
                label: 'Semua',
                value: 'semua',
                icon: Icons.grid_view_rounded,
              ),
              const SizedBox(width: 8),
              _buildAvailabilityFilterChip(
                key: const Key('filter_chip_disewa'),
                label: 'Sedang Disewa',
                value: 'disewa',
                icon: Icons.lock_clock_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityFilterChip({
    Key? key,
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedAvailabilityFilter == value;
    return InkWell(
      key: key,
      onTap: () {
        if (_selectedAvailabilityFilter != value) {
          setState(() {
            _selectedAvailabilityFilter = value;
          });
          _fetchAvailableUnits(reset: true);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('2. Unit iPhone & Durasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildUnitSearchAndFilterBar(),
          const SizedBox(height: 12),
          _buildUnitListWrap(isTablet: false),
          const SizedBox(height: 16),
          _buildDurationSelectionSection(),
          const SizedBox(height: 16),
          _buildSchedulePickerSection(),
        ],
      ),
    );
  }

  Widget _buildUnitListWrap({required bool isTablet}) {
    if (_isLoadingUnits) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_availableUnits.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.phone_iphone_outlined, size: 36, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text('iPhone tidak ditemukan', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Tidak ada unit yang sesuai dengan pencarian atau filter.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            if (_selectedAvailabilityFilter != 'semua' || _searchQuery.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Tampilkan Semua Unit', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedAvailabilityFilter = 'semua';
                  });
                  _fetchAvailableUnits(reset: true);
                },
              ),
            ],
          ],
        ),
      );
    }

    final sortedUnits = List<IphoneModel>.from(_availableUnits)
      ..sort((a, b) {
        final aAvail = _isUnitAvailableForBooking(a) ? 0 : 1;
        final bAvail = _isUnitAvailableForBooking(b) ? 0 : 1;
        return aAvail.compareTo(bAvail);
      });

    final wrapWidget = LayoutBuilder(
          builder: (context, constraints) {
            final columns = isTablet ? (constraints.maxWidth >= 500 ? 2 : 1) : 1;
            final itemWidth = columns == 2 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;

            return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sortedUnits.map((unit) {
            final isSelected = _selectedUnit?.id == unit.id;
            final unitStatus = unit.status.toLowerCase().trim();
            final isRented = ['rented', 'disewa'].contains(unitStatus) ||
                widget.repository.isUnitCurrentlyRented(unit.assetCode);
            final isMaintenance = ['maintenance', 'perawatan'].contains(unitStatus);
            final isPeriodAvailable = _isUnitAvailableForBooking(unit);
            final isScheduleConflict = !isRented && !isMaintenance && !isPeriodAvailable;
            final isUnavailable = isRented || isMaintenance || isScheduleConflict;

            final badgeLabel = isSelected
                ? 'Terpilih'
                : (isRented
                    ? 'Sedang Disewa'
                    : (isMaintenance
                        ? 'Perawatan'
                        : (isScheduleConflict ? 'Sudah Dibooking' : 'Tersedia')));

            final badgeColor = isSelected
                ? AppTheme.secondary
                : (isRented
                    ? const Color(0xFFB45309)
                    : (isMaintenance
                        ? const Color(0xFFDC2626)
                        : (isScheduleConflict ? const Color(0xFFD97706) : const Color(0xFF047857))));

            final card = SizedBox(
              width: itemWidth,
              child: InkWell(
                onTap: () {
                  if (isRented) {
                    _showRentedUnitWarningDialog(unit);
                    return;
                  }
                  if (isMaintenance) {
                    _showMaintenanceUnitWarningDialog(unit);
                    return;
                  }
                  if (isScheduleConflict) {
                    _showScheduleConflictWarningDialog(unit);
                    return;
                  }
                  setState(() {
                    _selectedUnit = unit;
                    _selectedDurationOption = unit.availableDurations.firstOrNull;
                    _isCustomDurationMode = false;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.surfaceContainerLow : (isUnavailable ? const Color(0xFFFFFBEB) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.secondary : (isUnavailable ? const Color(0xFFFDE68A) : AppTheme.cardBorder),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isRented
                              ? const Color(0xFFFEF3C7)
                              : (isScheduleConflict ? const Color(0xFFFEF3C7) : AppTheme.surfaceContainer),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isRented
                              ? Icons.lock_clock_rounded
                              : (isMaintenance
                                  ? Icons.build_rounded
                                  : (isScheduleConflict ? Icons.calendar_month_rounded : Icons.phone_iphone_rounded)),
                          color: isRented
                              ? const Color(0xFFB45309)
                              : (isMaintenance
                                  ? const Color(0xFFDC2626)
                                  : (isScheduleConflict ? const Color(0xFFD97706) : AppTheme.primary)),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(unit.modelName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.secondary.withValues(alpha: 0.12)
                                        : (isRented
                                            ? const Color(0xFFFEF3C7)
                                            : (isMaintenance
                                                ? const Color(0xFFFEE2E2)
                                                : (isScheduleConflict ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)))),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.secondary.withValues(alpha: 0.3)
                                          : (isRented
                                              ? const Color(0xFFFDE68A)
                                              : (isMaintenance
                                                  ? const Color(0xFFFECACA)
                                                  : (isScheduleConflict ? const Color(0xFFFDE68A) : const Color(0xFF86EFAC)))),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Builder(
                              builder: (context) {
                                final branchTag = unit.branchName?.trim().isNotEmpty == true
                                    ? unit.branchName!.trim()
                                    : (unit.affiliateName?.trim().isNotEmpty == true ? unit.affiliateName!.trim() : '');
                                final tagPrefix = branchTag.isNotEmpty ? '$branchTag • ' : '';
                                return Text(
                                  '$tagPrefix${unit.color} • Bat. ${unit.batteryHealth}% • SN: ${unit.serialNumber}',
                                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                            const SizedBox(height: 2),
                            Text('${Formatters.formatCurrency(unit.dailyRate)} /hari', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            return isUnavailable ? Opacity(opacity: 0.65, child: card) : card;
          }).toList(),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        wrapWidget,
        if (_currentPage < _lastPage) ...[
          const SizedBox(height: 12),
          InkWell(
            key: const Key('btn_load_more_units'),
            onTap: _isLoadingMoreUnits ? null : _loadMoreUnits,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Center(
                child: _isLoadingMoreUnits
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.expand_more_rounded, size: 20, color: AppTheme.secondary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Muat Lebih Banyak (${_availableUnits.length} dari $_totalUnits unit)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ] else if (_totalUnits > 0) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Menampilkan seluruh $_totalUnits unit iPhone',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDurationSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pilih Durasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_selectedUnit == null || _selectedUnit!.availableDurations.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            child: Text('Silakan pilih unit iPhone terlebih dahulu.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 600 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.2,
                ),
                itemCount: _selectedUnit!.availableDurations.length,
                itemBuilder: (context, index) {
                  final item = _selectedUnit!.availableDurations[index];
                  final isSelected = !_isCustomDurationMode && _selectedDurationOption?.hours == item.hours;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _isCustomDurationMode = false;
                        _selectedDurationOption = item;
                        if (_selectedUnit != null && !_isUnitAvailableForBooking(_selectedUnit!)) {
                          _selectedUnit = null;
                        }
                      });
                      _fetchAvailableUnits();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.cardBorder, width: isSelected ? 1.5 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${item.hours} jam', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                          Text(Formatters.formatCurrency(item.price), style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: 10),
        // Durasi Custom Toggle
        InkWell(
          onTap: () {
            setState(() {
              _isCustomDurationMode = !_isCustomDurationMode;
              if (_selectedUnit != null && !_isUnitAvailableForBooking(_selectedUnit!)) {
                _selectedUnit = null;
              }
            });
            _fetchAvailableUnits();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isCustomDurationMode ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isCustomDurationMode ? AppTheme.primary : AppTheme.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 16, color: _isCustomDurationMode ? Colors.white : AppTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text('Durasi Custom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isCustomDurationMode ? Colors.white : AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isCustomDurationMode ? '$_customJumlah $_customUnit Aktif' : 'Atur durasi bebas',
                    style: TextStyle(fontSize: 11, color: _isCustomDurationMode ? Colors.white70 : AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isCustomDurationMode) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Masukkan Durasi Sendiri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _customJumlah > 1
                          ? () {
                              setState(() {
                                _customJumlah--;
                                if (_selectedUnit != null && !_isUnitAvailableForBooking(_selectedUnit!)) {
                                  _selectedUnit = null;
                                }
                              });
                              _fetchAvailableUnits();
                            }
                          : null,
                    ),
                    Text('$_customJumlah', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setState(() {
                          _customJumlah++;
                          if (_selectedUnit != null && !_isUnitAvailableForBooking(_selectedUnit!)) {
                            _selectedUnit = null;
                          }
                        });
                        _fetchAvailableUnits();
                      },
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _customUnit,
                      items: const [
                        DropdownMenuItem(value: 'Hari', child: Text('Hari')),
                        DropdownMenuItem(value: 'Minggu', child: Text('Minggu')),
                        DropdownMenuItem(value: 'Bulan', child: Text('Bulan')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _customUnit = v;
                            if (_selectedUnit != null && !_isUnitAvailableForBooking(_selectedUnit!)) {
                              _selectedUnit = null;
                            }
                          });
                          _fetchAvailableUnits();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSchedulePickerSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Jadwal Mulai Sewa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(Formatters.date(_startDate), style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickStartTime,
                  icon: const Icon(Icons.access_time, size: 14),
                  label: Text(Formatters.time(_startDateTime), style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSummarySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('3. Estimasi Biaya & Konfirmasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildBillingRow('Unit iPhone', _selectedUnit?.modelName ?? '-'),
          _buildBillingRow('Durasi', !_isCustomDurationMode && _selectedDurationOption != null ? _selectedDurationOption!.displayName : '$_customJumlah $_customUnit'),
          _buildBillingRow('Sewa', Formatters.formatCurrency(_rentTotal)),
          const Divider(),
          _buildBillingRow('Total', Formatters.formatCurrency(_grandTotal), isAccent: true),
        ],
      ),
    );
  }

  Widget _buildBillingRow(String label, String value, {bool isAccent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, color: isAccent ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: isAccent ? FontWeight.bold : FontWeight.normal)),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: isAccent ? 14 : 12, fontWeight: FontWeight.bold, color: isAccent ? AppTheme.secondary : AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildStickyBottomDock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -3)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Row(
              children: [
                if (_currentStep > 1) ...[
                  OutlinedButton(
                    onPressed: _prevStep,
                    child: const Text('Kembali'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: _currentStep == 1
                          ? const Key('btn_next_to_step_2')
                          : (_currentStep == 2 ? const Key('btn_next_to_step_3') : const Key('btn_confirm_booking')),
                      onPressed: _isSubmitting || _isValidatingPhone
                          ? null
                          : (_currentStep == 1 ? _handleNextFromStep1 : (_currentStep == 2 ? _nextStep : _submitBooking)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentStep == 3 ? const Color(0xFF047857) : AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: (_isSubmitting || _isValidatingPhone)
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _currentStep == 1
                                  ? 'Lanjut ke Unit & Durasi'
                                  : (_currentStep == 2 ? 'Lanjut ke Review' : 'Konfirmasi & Buat Booking'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
