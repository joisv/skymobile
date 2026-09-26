import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/affiliate_model.dart';
import '../../theme/app_theme.dart';

class AffiliateFormScreen extends StatefulWidget {
  final AffiliateModel? affiliate;
  final BookingRepository repository;

  const AffiliateFormScreen({
    super.key,
    this.affiliate,
    required this.repository,
  });

  @override
  State<AffiliateFormScreen> createState() => _AffiliateFormScreenState();
}

class _AffiliateFormScreenState extends State<AffiliateFormScreen> {
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

  bool get _isEdit => widget.affiliate != null;

  @override
  void initState() {
    super.initState();
    final a = widget.affiliate;
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
    if (!_formKey.currentState!.validate()) return;

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

      if (_isEdit) {
        final existing = widget.affiliate!;
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
        await widget.repository.updateAffiliate(updated);
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
        await widget.repository.createAffiliate(newAffiliate);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Mitra berhasil diperbarui' : 'Mitra cabang baru berhasil ditambahkan'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Mitra Cabang' : 'Tambah Mitra Cabang',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.cardBorder, height: 1),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : _submitForm,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _isSaving ? 'Menyimpan...' : (_isEdit ? 'Simpan Perubahan' : 'Buat Mitra Cabang'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('INFORMASI UTAMA CABANG'),
              _buildCardContainer([
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Kode Cabang *',
                    hintText: 'Misal: JOG-01, BALI-02',
                    prefixIcon: Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Mitra / Cabang *',
                    hintText: 'Misal: Cabang Malioboro SKYRental',
                    prefixIcon: Icon(Icons.storefront_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nama mitra / cabang wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon / WhatsApp *',
                    hintText: 'Misal: 08123456789',
                    prefixIcon: Icon(Icons.phone_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nomor telepon wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Cabang (Opsional)',
                    hintText: 'Misal: malioboro@skyrental.id',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              _buildSectionHeader('ALAMAT & LOKASI'),
              _buildCardContainer([
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Lengkap',
                    hintText: 'Jl. Malioboro No. 12, Sosromenduran...',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'Kota / Kab.',
                          hintText: 'Yogyakarta',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _provinceController,
                        decoration: const InputDecoration(
                          labelText: 'Provinsi',
                          hintText: 'DI Yogyakarta',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _postalCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kode Pos',
                    hintText: '55271',
                    border: OutlineInputBorder(),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              _buildSectionHeader('PENGATURAN STATUS & CATATAN'),
              _buildCardContainer([
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Status Mitra Aktif',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Mitra aktif dapat menerima unit transfer dan membukukan rental.'
                        : 'Mitra nonaktif disembunyikan dari pemilihan booking & transfer baru.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  value: _isActive,
                  activeThumbColor: AppTheme.accent,
                  onChanged: (val) => setState(() => _isActive = val),
                ),
                const Divider(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan / Keterangan',
                    hintText: 'Keterangan tambahan operasional cabang...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
