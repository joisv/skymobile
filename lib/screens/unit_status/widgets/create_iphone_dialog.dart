import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/booking_repository.dart';
import '../../../models/affiliate_model.dart';
import '../../../models/iphone_model.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/formatters.dart';

class CreateIphoneDialog extends StatefulWidget {
  final BookingRepository repository;
  final ValueChanged<IphoneModel>? onCreated;
  final IphoneModel? initialUnit;

  const CreateIphoneDialog({
    super.key,
    required this.repository,
    this.onCreated,
    this.initialUnit,
  });

  const CreateIphoneDialog.edit({
    super.key,
    required this.repository,
    required IphoneModel unit,
    ValueChanged<IphoneModel>? onSaved,
  })  : initialUnit = unit,
        onCreated = onSaved;

  @override
  State<CreateIphoneDialog> createState() => _CreateIphoneDialogState();
}

class _DurationEntry {
  final TextEditingController hoursController;
  final TextEditingController priceController;

  _DurationEntry({required int hours, required int price})
      : hoursController = TextEditingController(text: hours.toString()),
        priceController = TextEditingController(text: _formatPrice(price));

  static String _formatPrice(int p) {
    return p.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void dispose() {
    hoursController.dispose();
    priceController.dispose();
  }
}

class _ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    final raw = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (raw.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final formatted = raw.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CreateIphoneDialogState extends State<CreateIphoneDialog> {
  final _formKey = GlobalKey<FormState>();

  bool get isEditMode => widget.initialUnit != null;

  // Text Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _snController = TextEditingController();
  final TextEditingController _assetCodeController = TextEditingController();

  // Form State
  DateTime _registrationDate = DateTime.now();
  bool _isAddon = false;
  bool _showManualSlug = false;

  // Poster & Gallery State
  int? _selectedGalleryId;
  String? _selectedPosterUrl;
  Uint8List? _localImageBytes;
  String? _localImageName;
  bool _isUploadingImage = false;
  List<Map<String, dynamic>> _galleries = [];
  bool _isLoadingGalleries = false;

  // Affiliate State
  int? _selectedAffiliateId;
  List<AffiliateModel> _affiliates = [];

  // Slugs & Auto-generation
  bool _isSlugManuallyEdited = false;

  // Durations dynamic repeater (matching Livewire/Iphones/Create.php:25-31)
  final List<_DurationEntry> _durationEntries = [];

  // UI state
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      final unit = widget.initialUnit!;
      _isAddon = unit.isAddon;
      _nameController.text = unit.name;
      _slugController.text = unit.slug ?? _slugify(unit.name);
      _isSlugManuallyEdited = true;
      _showManualSlug = (unit.slug != null && unit.slug != _slugify(unit.name));
      _descriptionController.text = unit.description ?? '';
      _snController.text = unit.serialNumber;
      _assetCodeController.text = unit.assetCode;
      _registrationDate = unit.createdDate ?? DateTime.now();
      _selectedGalleryId = unit.galleryId;
      _selectedPosterUrl = unit.photoUrl;
      _selectedAffiliateId = unit.affiliateId;

      if (unit.durations.isNotEmpty) {
        for (final d in unit.durations) {
          _durationEntries.add(_DurationEntry(hours: d.hours, price: d.price.round()));
        }
      } else {
        _durationEntries.add(_DurationEntry(hours: 24, price: 100000));
      }
    } else {
      // Default duration repeater: 24 Jam - Rp 100.000 (matching Create.php:25-31)
      _durationEntries.add(_DurationEntry(hours: 24, price: 100000));

      // Auto-generate initial asset code & serial number
      _generateAssetCode();
      _generateSerialNumber();
    }

    // Auto-slug listener on name
    _nameController.addListener(_onNameChanged);

    // Fetch live galleries and affiliates from backend
    _fetchGalleries();
    _fetchAffiliates();
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
      if (_slugController.text != slug) {
        setState(() {
          _slugController.text = slug;
        });
      }
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
      _assetCodeController.text = _isAddon ? 'ADDON$randomNum' : 'IPHSKY$randomNum';
    });
  }

  void _generateSerialNumber() {
    final hex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    setState(() {
      _snController.text = _isAddon ? 'ACC${hex.padLeft(8, '0')}' : 'DX${hex.padLeft(8, '0')}';
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

  Future<void> _fetchAffiliates() async {
    try {
      final affs = await widget.repository.getAffiliates();
      if (mounted) {
        setState(() {
          _affiliates = affs;
        });
      }
    } catch (_) {}
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
                                          cacheWidth: 300,
                                          cacheHeight: 300,
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
    setState(() {
      _hasAttemptedSubmit = true;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Harap periksa kembali isian formulir. Terdapat data yang belum valid.';
      });
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

    // Check duplicate duration hours
    final seenHours = <int>{};
    for (int i = 0; i < _durationEntries.length; i++) {
      final entry = _durationEntries[i];
      final h = int.tryParse(entry.hoursController.text.trim());
      if (h != null) {
        if (seenHours.contains(h)) {
          setState(() {
            _errorMessage = 'Terdapat paket durasi ganda ($h Jam). Setiap baris durasi harus memiliki jumlah jam yang berbeda.';
          });
          return;
        }
        seenHours.add(h);
      }
    }

    if (_durationEntries.isEmpty) {
      setState(() {
        _errorMessage = 'Minimal harus memiliki 1 paket durasi sewa.';
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

      if (hours > 0 && price > 0) {
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
      setState(() {
        _errorMessage = 'Paket durasi sewa dan tarif tidak boleh kosong.';
      });
      return;
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

      final selectedAff = _affiliates.where((a) => a.id == _selectedAffiliateId).firstOrNull;
      final branchName = selectedAff?.name ?? (isEditMode ? widget.initialUnit!.branchName : null);

      if (isEditMode) {
        final updatedUnit = widget.initialUnit!.copyWith(
          name: name,
          slug: _slugController.text.trim().isNotEmpty ? _slugController.text.trim() : _slugify(name),
          description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
          serialNumber: serialNumber,
          assetCode: assetCode,
          affiliateId: _selectedAffiliateId,
          branchName: branchName,
          photoUrl: _selectedPosterUrl,
          galleryId: _selectedGalleryId ?? widget.initialUnit!.galleryId ?? 1,
          createdDate: _registrationDate,
          durations: parsedDurations,
          isAddon: _isAddon,
        );

        final saved = await widget.repository.updateInventoryUnit(updatedUnit);

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
                  child: Text('Unit ${saved.fullName} (${saved.assetCode}) berhasil diperbarui!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!isEditMode && !AuthService().canCreateIphone) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = _isAddon
              ? 'Akses ditolak: Hanya Super Admin dan Admin yang memiliki izin untuk menambah unit add-on baru.'
              : 'Akses ditolak: Hanya Super Admin dan Admin yang memiliki izin untuk menambah unit iPhone baru.';
        });
        return;
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
        affiliateId: _selectedAffiliateId,
        branchName: branchName,
        photoUrl: _selectedPosterUrl,
        galleryId: _selectedGalleryId ?? 1,
        createdDate: _registrationDate,
        durations: parsedDurations,
        isAddon: _isAddon,
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
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: screenHeight * 0.85,
        ),
        child: Container(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: Form(
            key: _formKey,
            autovalidateMode: _hasAttemptedSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header with dynamic title and right-aligned close button
                _buildHeader(context, isDark),
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                // Error Banner if present
                if (_errorMessage != null)
                  _buildErrorBanner(isDark),

                // 2. Scrollable Middle Body (Single Unified Form)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Minimal Toggle Switch for Add-on / Aksesoris
                        _buildAddonToggle(isDark),
                        const SizedBox(height: 18),

                        // Model Unit / Nama Add-on Field
                        _buildModelNameSection(isDark),
                        const SizedBox(height: 18),

                        // Description Field
                        _buildDescriptionSection(isDark),
                        const SizedBox(height: 18),

                        // Poster / Photo Section
                        _buildPosterSection(isDark),
                        const SizedBox(height: 18),

                        // Registration Date, Serial Number & Asset Code Row
                        _buildSerialAndAssetSection(isDark),
                        const SizedBox(height: 14),

                        // Automated Permalink / Slug with collapsed accordion
                        _buildSlugSection(isDark),
                        const SizedBox(height: 18),

                        // Branch / Affiliate Section
                        _buildAffiliateSection(isDark),
                        const SizedBox(height: 18),

                        // Duration & Rate Management
                        _buildDurationRepeaterSection(isDark),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // 3. Fixed Footer with Batal and Simpan action buttons
                const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                _buildBottomBar(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final title = isEditMode
        ? (_isAddon ? 'Edit Add-on' : 'Edit Unit iPhone')
        : (_isAddon ? 'Tambah Add-on Baru' : 'Tambah Unit Baru');

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 14, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            tooltip: 'Tutup Dialog',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gagal Menyimpan Data Unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB91C1C),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonToggle(bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: SwitchListTile.adaptive(
        key: const Key('create_iphone_addon_toggle'),
        value: _isAddon,
        onChanged: (val) {
          setState(() {
            _isAddon = val;
            if (!isEditMode &&
                (_assetCodeController.text.startsWith('IPHSKY') ||
                    _assetCodeController.text.startsWith('ADDON') ||
                    _assetCodeController.text.isEmpty)) {
              _generateAssetCode();
              _generateSerialNumber();
            }
          });
        },
        title: Text(
          'Item ini merupakan Aksesoris / Add-on',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        subtitle: const Text(
          'Aktifkan jika perangkat berupa tripod, lensa, atau kelengkapan tambahan',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        contentPadding: EdgeInsets.zero,
        activeTrackColor: const Color(0xFF8B5CF6),
      ),
    ),
  );
}

  Widget _buildModelNameSection(bool isDark) {
    final label = _isAddon ? 'NAMA AKSESORIS / ADD-ON *' : 'MODEL UNIT IPHONE *';
    final hint = _isAddon ? 'MagSafe Battery Pack / Tripod' : 'iPhone 16 pro MAX';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Wajib diisi',
              style: TextStyle(fontSize: 10.5, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key('create_iphone_name_field'),
          controller: _nameController,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.withAlpha(140),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          ),
          validator: (val) {
            final trimmed = val?.trim() ?? '';
            if (trimmed.isEmpty) {
              return _isAddon ? 'Nama add-on wajib diisi.' : 'Nama model iPhone wajib diisi.';
            }
            if (trimmed.length < 3) {
              return _isAddon ? 'Nama add-on minimal 3 karakter.' : 'Nama model iPhone minimal 3 karakter.';
            }
            return null;
          },
        ),
        if (!_isAddon) ...[
          const SizedBox(height: 8),
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
                    onTap: () => _nameController.text = m,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESKRIPSI & CATATAN UNIT',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Deskripsi unit, kelengkapan (kabel data, charger, case), dan catatan fisik unit...',
            hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.withAlpha(140)),
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPosterSection(bool isDark) {
    final bool hasImage = _localImageBytes != null || (_selectedPosterUrl != null && _selectedPosterUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Poster / Foto Unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
            if (hasImage)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  _localImageBytes != null ? 'Memori Perangkat' : 'Galeri Server',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasImage) ...[
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: _localImageBytes != null
                            ? Image.memory(_localImageBytes!, fit: BoxFit.contain)
                            : Image.network(
                                _resolveImageUrl(_selectedPosterUrl!),
                                cacheWidth: 320,
                                cacheHeight: 320,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                              ),
                      ),
                      if (_isUploadingImage)
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: InkWell(
                  onTap: _removePoster,
                  child: Container(
                    padding: const EdgeInsets.all(4),
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
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ElevatedButton(
              onPressed: _pickImageFromStorage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text(
                hasImage ? 'Ganti Foto' : 'Upload dari HP',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton(
              onPressed: _openGalleryPickerModal,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: Text(
                'Galeri Server',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
            TextButton(
              onPressed: _showCustomUrlDialog,
              child: const Text('URL Kustom', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSerialAndAssetSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Identitas & Kode Aset *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                _generateAssetCode();
                _generateSerialNumber();
              },
              child: const Text(
                'Generate Ulang',
                style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Serial Number
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nomor Seri (SN)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextFormField(
                    key: const Key('create_iphone_sn_field'),
                    controller: _snController,
                    style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'DX92SL093XJ',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    validator: (val) {
                      final trimmed = val?.trim() ?? '';
                      if (trimmed.isEmpty) return 'Nomor seri (SN) wajib diisi.';
                      if (trimmed.length < 4) return 'Minimal 4 karakter.';
                      final isDuplicate = widget.repository.inventory.any(
                        (u) =>
                            (!isEditMode ||
                                ((u.id > 0 && u.id != widget.initialUnit!.id) &&
                                    u.assetCode.trim().toLowerCase() != widget.initialUnit!.assetCode.trim().toLowerCase())) &&
                            u.serialNumber.trim().toLowerCase() == trimmed.toLowerCase(),
                      );
                      if (isDuplicate) return 'Nomor seri sudah terdaftar.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Asset Code
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kode Aset', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextFormField(
                    key: const Key('create_iphone_asset_code_field'),
                    controller: _assetCodeController,
                    style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'IPHSKY0001',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    validator: (val) {
                      final trimmed = val?.trim() ?? '';
                      if (trimmed.isEmpty) return 'Kode aset unit wajib diisi.';
                      if (trimmed.length < 3) return 'Minimal 3 karakter.';
                      final isDuplicate = widget.repository.inventory.any(
                        (u) =>
                            (!isEditMode ||
                                ((u.id > 0 && u.id != widget.initialUnit!.id) &&
                                    u.assetCode.trim().toLowerCase() != widget.initialUnit!.assetCode.trim().toLowerCase())) &&
                            u.assetCode.trim().toLowerCase() == trimmed.toLowerCase(),
                      );
                      if (isDuplicate) return 'Kode aset sudah digunakan.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Registration Date
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tgl Registrasi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _selectRegistrationDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        Formatters.date(_registrationDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlugSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('toggle_slug_accordion'),
          onTap: () => setState(() => _showManualSlug = !_showManualSlug),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _showManualSlug ? 'Sembunyikan Permalink Web' : 'Kustomisasi Permalink Web (Slug)',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showManualSlug ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
                if (!_showManualSlug) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(
                      '/${_slugController.text}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_showManualSlug) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('create_iphone_slug_field'),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  validator: (val) {
                    final trimmed = val?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Slug permalink wajib diisi.';
                    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(trimmed)) {
                      return 'Format slug tidak valid (hanya huruf kecil, angka, dan tanda hubung -)';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    _isSlugManuallyEdited = true;
                  },
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSlugManuallyEdited = false;
                    _slugController.text = _slugify(_nameController.text);
                  });
                },
                child: const Text('Reset Auto', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAffiliateSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cabang Affiliate',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int?>(
          key: const Key('create_iphone_affiliate_dropdown'),
          isExpanded: true,
          initialValue: _selectedAffiliateId,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Pilih Affiliate / Cabang',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Pusat / Tanpa Cabang (-)', style: TextStyle(fontSize: 12.5)),
            ),
            ..._affiliates.map((a) {
              return DropdownMenuItem<int?>(
                value: a.id,
                child: Text('${a.name} (${a.code})', style: const TextStyle(fontSize: 12.5)),
              );
            }),
          ],
          onChanged: (val) {
            setState(() => _selectedAffiliateId = val);
          },
        ),
      ],
    );
  }

  Widget _buildDurationRepeaterSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paket Durasi & Tarif *',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 105,
                child: Text('Durasi Sewa', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Tarif Sewa (Rp)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ),
              SizedBox(width: 36),
            ],
          ),
        ),
        const SizedBox(height: 4),
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
                // Duration: [ 24 ] Jam (numeric input, centered text)
                SizedBox(
                  width: 105,
                  child: TextFormField(
                    key: Key('create_iphone_duration_hours_$index'),
                    controller: entry.hoursController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '24',
                      suffixText: 'Jam',
                      suffixStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    validator: (val) {
                      final trimmed = val?.trim() ?? '';
                      if (trimmed.isEmpty) return 'Wajib diisi';
                      final hours = int.tryParse(trimmed);
                      if (hours == null || hours <= 0) return '> 0 jam';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Rate: Rp [ 100.000 ] (numeric input with thousand separator)
                Expanded(
                  child: TextFormField(
                    key: Key('create_iphone_duration_price_$index'),
                    controller: entry.priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ThousandSeparatorInputFormatter(),
                    ],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: 'Rp ',
                      prefixStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                      hintText: '100.000',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    validator: (val) {
                      final raw = (val ?? '').replaceAll(RegExp(r'[^\d]'), '');
                      if (raw.isEmpty) return 'Tarif wajib diisi';
                      final price = double.tryParse(raw);
                      if (price == null || price <= 0) return 'Harus > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Remove Action: Subtle trash icon button on the right edge (only visible if count > 1)
                SizedBox(
                  width: 32,
                  height: 36,
                  child: canDelete
                      ? IconButton(
                          key: Key('create_iphone_duration_delete_$index'),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Hapus baris',
                          padding: EdgeInsets.zero,
                          onPressed: () => _deleteDuration(index),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),

        // Clean '+ Tambah Paket Durasi' text action button underneath
        TextButton.icon(
          key: const Key('create_iphone_add_duration_btn'),
          onPressed: () => _addDuration(hours: 12, price: 65000),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('+ Tambah Paket Durasi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final submitText = isEditMode
        ? 'Simpan Perubahan'
        : (_isAddon ? 'Simpan Add-on' : 'Simpan Unit iPhone');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                key: const Key('create_iphone_submit_btn'),
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        submitText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
