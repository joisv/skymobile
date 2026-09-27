import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/booking_repository.dart';
import '../../../models/iphone_model.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';

class CreateIphoneDialog extends StatefulWidget {
  final BookingRepository repository;
  final ValueChanged<IphoneModel>? onCreated;

  const CreateIphoneDialog({
    super.key,
    required this.repository,
    this.onCreated,
  });

  @override
  State<CreateIphoneDialog> createState() => _CreateIphoneDialogState();
}

class _DurationEntry {
  final TextEditingController hoursController;
  final TextEditingController priceController;

  _DurationEntry({required int hours, required int price})
      : hoursController = TextEditingController(text: hours.toString()),
        priceController = TextEditingController(text: price.toString());

  void dispose() {
    hoursController.dispose();
    priceController.dispose();
  }
}

class _CreateIphoneDialogState extends State<CreateIphoneDialog> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _assetCodeController = TextEditingController();

  // Form State
  DateTime _registrationDate = DateTime.now();

  // Poster & Gallery State
  int? _selectedGalleryId;
  String? _selectedPosterUrl;
  Uint8List? _localImageBytes;
  String? _localImageName;
  bool _isUploadingImage = false;
  List<Map<String, dynamic>> _galleries = [];
  bool _isLoadingGalleries = false;

  // Slugs & Auto-generation
  bool _isSlugManuallyEdited = false;

  // Durations dynamic repeater (matching Livewire/Iphones/Create.php:25-31)
  final List<_DurationEntry> _durationEntries = [];

  // UI state
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default duration repeater: 24 Jam - Rp 100.000 (matching Create.php:25-31)
    _durationEntries.add(_DurationEntry(hours: 24, price: 100000));

    // Auto-generate initial asset code & serial number
    _generateAssetCode();
    _generateSerialNumber();

    // Auto-slug listener on name
    _nameController.addListener(_onNameChanged);

    // Fetch live galleries from backend
    _fetchGalleries();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _snController.dispose();
    _assetCodeController.dispose();
    for (final d in _durationEntries) {
      d.dispose();
    }
    super.dispose();
  }

  void _onNameChanged() {
    if (!_isSlugManuallyEdited) {
      final slug = _slugify(_nameController.text);
      _slugController.text = slug;
    }
  }

  String _slugify(String text) {
    var s = text.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    return s;
  }

  void _generateAssetCode() {
    final randomNum = (1000 + DateTime.now().millisecond).toString();
    setState(() {
      _assetCodeController.text = 'IPHSKY$randomNum';
    });
  }

  void _generateSerialNumber() {
    final hex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    setState(() {
      _snController.text = 'DX${hex.padLeft(8, '0')}';
    });
  }

  Future<void> _fetchGalleries() async {
    setState(() => _isLoadingGalleries = true);
    try {
      final res = await ApiService().getGalleriesApi();
      if (res != null && mounted) {
        setState(() {
          _galleries = res;
          if (_selectedPosterUrl == null && _galleries.isNotEmpty) {
            final first = _galleries.first;
            _selectedGalleryId = first['id'] is int ? first['id'] as int : int.tryParse(first['id']?.toString() ?? '');
            _selectedPosterUrl = first['image']?.toString();
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGalleries = false);
    }
  }

  void _addDuration({int hours = 12, int price = 65000}) {
    setState(() {
      _durationEntries.add(_DurationEntry(hours: hours, price: price));
    });
  }

  void _deleteDuration(int index) {
    if (_durationEntries.length <= 1) return;
    setState(() {
      final removed = _durationEntries.removeAt(index);
      removed.dispose();
    });
  }

  void _removePoster() {
    setState(() {
      _selectedPosterUrl = null;
      _selectedGalleryId = null;
      _localImageBytes = null;
      _localImageName = null;
    });
  }

  /// Memilih gambar dari galeri / penyimpanan internal perangkat (HP/Tablet/PC)
  Future<void> _pickImageFromStorage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final filename = image.name.isNotEmpty ? image.name : 'iphone_${DateTime.now().millisecondsSinceEpoch}.jpg';

      setState(() {
        _localImageBytes = bytes;
        _localImageName = filename;
        _selectedPosterUrl = image.path;
        _isUploadingImage = true;
      });

      final uploaded = await ApiService().uploadGalleryImageApi(
        bytes: bytes,
        filename: filename,
      );

      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          if (uploaded != null) {
            _selectedGalleryId = uploaded['id'] is int ? uploaded['id'] as int : int.tryParse(uploaded['id']?.toString() ?? '');
            final rawUrl = uploaded['url'] ?? uploaded['image'];
            if (rawUrl != null) {
              _selectedPosterUrl = rawUrl.toString();
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploaded != null
                ? 'Gambar berhasil diupload ke server galeri!'
                : 'Gambar berhasil dipilih dari memori internal.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _selectRegistrationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _registrationDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(ctx).colorScheme.surface,
              onSurface: Theme.of(ctx).textTheme.bodyMedium?.color ?? Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _registrationDate = picked);
    }
  }

  void _openGalleryPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (bottomCtx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            height: MediaQuery.sizeOf(context).height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Poster iPhone',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Katalog gambar resmi dari database galeri',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _galleries.isEmpty
                      ? Center(
                          child: _isLoadingGalleries
                              ? const CircularProgressIndicator()
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    const Text('Tidak ada gambar galeri tersedia di backend.'),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _showCustomUrlDialog();
                                      },
                                      child: const Text('Masukkan URL Gambar Manual'),
                                    ),
                                  ],
                                ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _galleries.length,
                          itemBuilder: (context, idx) {
                            final g = _galleries[idx];
                            final id = g['id'] is int ? g['id'] as int : int.tryParse(g['id']?.toString() ?? '') ?? (idx + 1);
                            final imgPath = g['image']?.toString() ?? '';
                            final isSelected = _selectedGalleryId == id;
                            final resolvedUrl = _resolveImageUrl(imgPath);

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedGalleryId = id;
                                  _selectedPosterUrl = imgPath;
                                });
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.accent : Colors.grey.withAlpha(60),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          resolvedUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (ctx, err, stack) => const Center(
                                            child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(160),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'ID #$id',
                                          style: const TextStyle(color: Colors.white, fontSize: 10),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCustomUrlDialog();
                    },
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Masukkan URL Gambar Kustom'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCustomUrlDialog() {
    final urlCtrl = TextEditingController(text: _selectedPosterUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('URL Gambar Poster'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            hintText: 'https://example.com/poster.jpg atau storage/galleries/...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _selectedPosterUrl = urlCtrl.text.trim();
                  _selectedGalleryId = _selectedGalleryId ?? 1;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Gunakan'),
          ),
        ],
      ),
    );
  }

  String _resolveImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final apiBase = ApiService().baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    final clean = path.startsWith('/') ? path.substring(1) : path;
    if (clean.startsWith('storage/')) {
      return '$apiBase/$clean';
    }
    return '$apiBase/storage/$clean';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final serialNumber = _snController.text.trim();
    final assetCode = _assetCodeController.text.trim();

    if (name.isEmpty || serialNumber.isEmpty || assetCode.isEmpty) {
      setState(() {
        _errorMessage = 'Nama Model, Nomor Seri, dan Kode Aset wajib diisi!';
      });
      return;
    }

    // Build duration list
    final List<IphoneDurationOption> parsedDurations = [];
    for (int i = 0; i < _durationEntries.length; i++) {
      final entry = _durationEntries[i];
      final hours = int.tryParse(entry.hoursController.text.trim()) ?? 24;
      final rawPriceText = entry.priceController.text.replaceAll(RegExp(r'[^\d]'), '');
      final price = double.tryParse(rawPriceText) ?? 100000.0;

      if (hours > 0) {
        parsedDurations.add(
          IphoneDurationOption(
            id: i + 1,
            name: '$hours Jam',
            hours: hours,
            price: price,
          ),
        );
      }
    }

    if (parsedDurations.isEmpty) {
      parsedDurations.add(
        const IphoneDurationOption(
          id: 1,
          name: '24 Jam',
          hours: 24,
          price: 100000.0,
        ),
      );
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_localImageBytes != null && _selectedGalleryId == null) {
        try {
          final uploaded = await ApiService().uploadGalleryImageApi(
            bytes: _localImageBytes!,
            filename: _localImageName ?? 'iphone.jpg',
          );
          if (uploaded != null) {
            _selectedGalleryId = uploaded['id'] is int ? uploaded['id'] as int : int.tryParse(uploaded['id']?.toString() ?? '');
            final rawUrl = uploaded['url'] ?? uploaded['image'];
            if (rawUrl != null) _selectedPosterUrl = rawUrl.toString();
          }
        } catch (_) {}
      }

      final newUnit = IphoneModel(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        name: name,
        slug: _slugController.text.trim().isNotEmpty ? _slugController.text.trim() : _slugify(name),
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        storage: '',
        color: '',
        serialNumber: serialNumber,
        assetCode: assetCode,
        status: 'ready',
        batteryHealth: 100,
        affiliateId: null,
        branchName: null,
        photoUrl: _selectedPosterUrl,
        galleryId: _selectedGalleryId ?? 1,
        createdDate: _registrationDate,
        durations: parsedDurations,
      );

      final saved = await widget.repository.addInventoryUnit(newUnit);

      if (!mounted) return;
      Navigator.of(context).pop();

      widget.onCreated?.call(saved);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Unit ${saved.fullName} (${saved.assetCode}) berhasil ditambahkan!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 850;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 36 : 16,
        vertical: isTablet ? 24 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 1040 : 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(context, isDark),
            body: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Error Banner if present
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _errorMessage = null),
                            child: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    ),

                  // Form Body: 2-column on tablet, 1-column scroll on mobile
                  Expanded(
                    child: isTablet ? _buildTabletBody(isDark) : _buildMobileBody(isDark),
                  ),

                  // Footer action bar
                  _buildBottomBar(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.phone_iphone_rounded, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tambah iPhone Baru',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(
                'Sistem Katalog & Sinkronisasi Web SKYRental',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Tutup Dialog',
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTabletBody(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (50%): Model Name, Description, Poster & Upload Foto
        Expanded(
          flex: 11,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModelNameSection(isDark),
                const SizedBox(height: 16),
                _buildDescriptionSection(isDark),
                const SizedBox(height: 16),
                _buildPosterSection(isDark),
              ],
            ),
          ),
        ),

        // Divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),

        // Right Column (50%): Setelan Series, Tanggal & Slug, Serial/Asset, Repeater Durasi
        Expanded(
          flex: 11,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSeriesSettingHeader(isDark),
                const SizedBox(height: 14),
                _buildDateAndSlugSection(isDark),
                const SizedBox(height: 14),
                _buildSerialAndAssetSection(isDark),
                const SizedBox(height: 14),
                _buildDurationRepeaterSection(isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelNameSection(isDark),
          const SizedBox(height: 14),
          _buildDescriptionSection(isDark),
          const SizedBox(height: 14),
          _buildPosterSection(isDark),
          const SizedBox(height: 16),
          _buildSeriesSettingHeader(isDark),
          const SizedBox(height: 12),
          _buildDateAndSlugSection(isDark),
          const SizedBox(height: 14),
          _buildSerialAndAssetSection(isDark),
          const SizedBox(height: 14),
          _buildDurationRepeaterSection(isDark),
        ],
      ),
    );
  }

  Widget _buildSeriesSettingHeader(bool isDark) {
    return Row(
      children: [
        Icon(Icons.tune_rounded, size: 18, color: AppTheme.accent),
        const SizedBox(width: 8),
        Text(
          'Setelan Series & Registrasi',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // 1. Model Name Headline (matches Livewire placeholder "iPhone 16 pro MAX")
  Widget _buildModelNameSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MODEL UNIT IPHONE *',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const Text(
                'Wajib diisi',
                style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'iPhone 16 pro MAX',
              hintStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.withAlpha(140),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Nama model iPhone wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          // Suggested Quick Models
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'iPhone 16 Pro Max',
                'iPhone 16 Pro',
                'iPhone 15 Pro Max',
                'iPhone 15 Pro',
                'iPhone 14 Pro',
                'iPhone 13',
                'iPhone 11',
              ].map((m) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      _nameController.text = m;
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(m, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Deskripsi Unit (matches summernote description in blade)
  Widget _buildDescriptionSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 16, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                'DESKRIPSI & CATATAN UNIT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Deskripsi unit, kelengkapan (kabel data, charger, case), dan catatan fisik unit...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.withAlpha(140)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Poster Section (Upload dari Memori HP / Galeri Server / Link URL)
  Widget _buildPosterSection(bool isDark) {
    final bool hasImage = _localImageBytes != null || (_selectedPosterUrl != null && _selectedPosterUrl!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_rounded, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  const Text('Poster / Foto Unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              if (hasImage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _localImageBytes != null ? Icons.phone_android_rounded : Icons.cloud_done_rounded,
                        size: 13,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _localImageBytes != null ? 'Memori HP' : 'Galeri Server',
                        style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Poster Preview Card (from local memory bytes or remote URL)
          if (hasImage) ...[
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Center(
                          child: _localImageBytes != null
                              ? Image.memory(
                                  _localImageBytes!,
                                  fit: BoxFit.contain,
                                )
                              : Image.network(
                                  _resolveImageUrl(_selectedPosterUrl!),
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, stack) => const Center(
                                    child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                                  ),
                                ),
                        ),
                        if (_isUploadingImage)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  SizedBox(height: 8),
                                  Text(
                                    'Mengunggah ke galeri server...',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Remove 'x' button
                Positioned(
                  top: -8,
                  right: -8,
                  child: InkWell(
                    onTap: _removePoster,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            // Empty placeholder dropzone / upload banner
            InkWell(
              onTap: _pickImageFromStorage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accent.withAlpha(90),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_photo_alternate_rounded, size: 28, color: AppTheme.accent),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pilih atau Upload Foto iPhone',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload dari penyimpanan internal HP atau pilih galeri server',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Buttons to change/select poster
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImageFromStorage,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(
                  hasImage ? 'Ganti dari HP' : 'Upload dari HP',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openGalleryPickerModal,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Galeri Server', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              IconButton(
                tooltip: 'Input URL Gambar Kustom',
                icon: const Icon(Icons.link_rounded, size: 18),
                onPressed: _showCustomUrlDialog,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. Date & Permalink / Slug (matches Livewire/Iphones/Create.php set-date & set-slug)
  Widget _buildDateAndSlugSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tanggal Registrasi (responsive row)
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Tanggal Registrasi',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _selectRegistrationDate,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Formatters.date(_registrationDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_calendar_rounded, size: 13, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),

          // Permalink / Slug
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded, size: 15, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  const Text('Permalink (Slug)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isSlugManuallyEdited = false;
                    _slugController.text = _slugify(_nameController.text);
                  });
                },
                child: Text('Reset Auto', style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _slugController,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'iphone-16-pro-max',
              prefixText: 'skyrent.id/iphone/',
              prefixStyle: TextStyle(
                fontSize: 11,
                color: Colors.grey.withAlpha(180),
                fontFamily: 'monospace',
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (val) {
              _isSlugManuallyEdited = true;
            },
          ),
        ],
      ),
    );
  }

  // 6. Serial Number & Asset Code (matches create.blade.php:154-182)
  Widget _buildSerialAndAssetSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 15, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Serial & Asset Code *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  _generateAssetCode();
                  _generateSerialNumber();
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 2),
                      Text('Auto Gen', style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Serial Number (SN):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _snController,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'DX92SL093XJ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Asset Code:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _assetCodeController,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'IPHSKY0001',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 7. Dynamic Duration Repeater (matches create.blade.php:184-247)
  Widget _buildDurationRepeaterSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'Paket Durasi & Tarif',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _addDuration(hours: 12, price: 65000),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Tambah Baris', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Repeater Rows (matches Alpine template x-for="(item, index) in durations")
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _durationEntries.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final entry = _durationEntries[index];
              final canDelete = _durationEntries.length > 1;

              return Row(
                children: [
                  // Hours input (e.g. 24 jam)
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: entry.hoursController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '24',
                        suffixText: 'Jam',
                        suffixStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Price input (e.g. Rp 100.000)
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: entry.priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                        hintText: '100000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Add button '+'
                  InkWell(
                    onTap: () => _addDuration(hours: 24, price: 100000),
                    child: Container(
                      height: 38,
                      width: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Delete button '-'
                  InkWell(
                    onTap: canDelete ? () => _deleteDuration(index) : null,
                    child: Container(
                      height: 38,
                      width: 32,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: canDelete ? const Color(0xFF0F172A) : Colors.grey.withAlpha(70),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 16,
                        color: canDelete ? (isDark ? Colors.white : const Color(0xFF0F172A)) : Colors.grey.withAlpha(90),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Quick Presets Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickPresetChip('12 Jam', 12, 65000),
                _buildQuickPresetChip('24 Jam', 24, 100000),
                _buildQuickPresetChip('48 Jam (2H)', 48, 180000),
                _buildQuickPresetChip('72 Jam (3H)', 72, 250000),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetChip(String label, int hours, int price) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        avatar: const Icon(Icons.add_rounded, size: 14),
        label: Text('$label (${Formatters.currency(price.toDouble())})', style: const TextStyle(fontSize: 10)),
        padding: EdgeInsets.zero,
        onPressed: () {
          final exists = _durationEntries.any((d) => d.hoursController.text.trim() == hours.toString());
          if (!exists) {
            _addDuration(hours: hours, price: price);
          } else {
            final item = _durationEntries.firstWhere((d) => d.hoursController.text.trim() == hours.toString());
            item.priceController.text = price.toString();
            setState(() {});
          }
        },
      ),
    );
  }

  // Bottom action bar
  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Simpan Unit iPhone', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
