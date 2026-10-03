import 'package:flutter/material.dart';
import '../../../data/booking_repository.dart';
import '../../../models/affiliate_model.dart';
import '../../../theme/app_theme.dart';

class CreateAffiliateDialog extends StatefulWidget {
  final BookingRepository repository;
  final AffiliateModel? initialAffiliate;
  final ValueChanged<AffiliateModel>? onSaved;

  const CreateAffiliateDialog({
    super.key,
    required this.repository,
    this.initialAffiliate,
    this.onSaved,
  });

  const CreateAffiliateDialog.edit({
    super.key,
    required this.repository,
    required AffiliateModel affiliate,
    this.onSaved,
  })  : initialAffiliate = affiliate;

  @override
  State<CreateAffiliateDialog> createState() => _CreateAffiliateDialogState();
}

class _CreateAffiliateDialogState extends State<CreateAffiliateDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _postalCodeController;
  late TextEditingController _descriptionController;

  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;

  bool get isEdit => widget.initialAffiliate != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAffiliate;
    _codeController = TextEditingController(text: a?.code ?? '');
    _nameController = TextEditingController(text: a?.name ?? '');
    _emailController = TextEditingController(text: a?.email ?? '');
    _phoneController = TextEditingController(text: a?.phone ?? '');
    _addressController = TextEditingController(text: a?.address ?? '');
    _cityController = TextEditingController(text: a?.city ?? '');
    _provinceController = TextEditingController(text: a?.province ?? '');
    _postalCodeController = TextEditingController(text: a?.postalCode ?? '');
    _descriptionController = TextEditingController(text: a?.description ?? '');
    _isActive = a?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final code = _codeController.text.trim().toUpperCase();
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
      final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
      final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
      final city = _cityController.text.trim().isEmpty ? null : _cityController.text.trim();
      final province = _provinceController.text.trim().isEmpty ? null : _provinceController.text.trim();
      final postalCode = _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim();
      final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();

      AffiliateModel savedAffiliate;

      if (isEdit) {
        final existing = widget.initialAffiliate!;
        final updated = existing.copyWith(
          code: code,
          name: name,
          email: email,
          phone: phone,
          address: address,
          city: city,
          province: province,
          postalCode: postalCode,
          description: description,
          isActive: _isActive,
        );
        savedAffiliate = await widget.repository.updateAffiliate(updated);
      } else {
        final newAffiliate = AffiliateModel(
          id: 0,
          code: code,
          name: name,
          slug: code.toLowerCase(),
          email: email,
          phone: phone,
          address: address,
          city: city,
          province: province,
          postalCode: postalCode,
          description: description,
          isActive: _isActive,
        );
        savedAffiliate = await widget.repository.createAffiliate(newAffiliate);
      }

      if (!mounted) return;

      widget.onSaved?.call(savedAffiliate);
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEdit
                      ? 'Mitra "${savedAffiliate.name}" berhasil diperbarui!'
                      : 'Mitra cabang "${savedAffiliate.name}" berhasil ditambahkan!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 640;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 16,
        vertical: isTablet ? 28 : 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 560 : 420,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(_errorMessage!),
                          const SizedBox(height: 14),
                        ],
                        _buildSectionHeader('INFORMASI UTAMA CABANG'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Kode Cabang *',
                            hintText: 'Misal: BWI, DPS, JOG-01',
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Kode cabang wajib diisi';
                            }
                            if (val.trim().length < 2) {
                              return 'Kode cabang minimal 2 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nama Mitra / Cabang *',
                            hintText: 'Misal: Affiliate Banyuwangi Kota',
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama mitra / cabang wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Nomor Telepon / WhatsApp *',
                            hintText: 'Misal: 08123456789',
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nomor telepon wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Cabang (Opsional)',
                            hintText: 'Misal: cabang@skyrent.id',
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegExp.hasMatch(val.trim())) {
                                return 'Format email tidak valid';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildSectionHeader('ALAMAT & WILAYAH'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Alamat Lengkap',
                            hintText: 'Jl. Ahmad Yani No. 88, Rogojampi...',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cityController,
                                decoration: InputDecoration(
                                  labelText: 'Kota / Kab.',
                                  hintText: 'Banyuwangi',
                                  filled: true,
                                  fillColor: AppTheme.surfaceContainerLow,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _provinceController,
                                decoration: InputDecoration(
                                  labelText: 'Provinsi',
                                  hintText: 'Jawa Timur',
                                  filled: true,
                                  fillColor: AppTheme.surfaceContainerLow,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _postalCodeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Kode Pos',
                            hintText: '68411',
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildSectionHeader('STATUS & KETERANGAN'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status Mitra Aktif',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isActive
                                          ? 'Mitra dapat menerima mutasi unit dan rental.'
                                          : 'Mitra dinonaktifkan sementara dari operasional.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _isActive,
                                activeThumbColor: AppTheme.accent,
                                onChanged: (val) => setState(() => _isActive = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Catatan / Keterangan Operasional',
                            hintText: 'Keterangan tambahan outlet cabang...',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: AppTheme.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_business_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Mitra Cabang' : 'Tambah Mitra Cabang Baru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit
                      ? 'Perbarui detail informasi outlet cabang mitra'
                      : 'Lengkapi data untuk mendaftarkan mitra cabang baru',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            splashRadius: 18,
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              elevation: 0,
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _isSaving
                  ? 'Menyimpan...'
                  : (isEdit ? 'Simpan Perubahan' : 'Simpan Mitra Cabang'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}
