import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/admin_user_model.dart';
import '../../theme/app_theme.dart';

class ShopSettingsScreen extends StatefulWidget {
  final BookingRepository repository;

  const ShopSettingsScreen({
    super.key,
    required this.repository,
  });

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _shopNameController;
  late final TextEditingController _outletNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _footerController;
  late final TextEditingController _wifiNameController;
  late final TextEditingController _wifiPasswordController;

  ShopSettingsModel _settings = ShopSettingsModel.defaultSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();
    _outletNameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _footerController = TextEditingController();
    _wifiNameController = TextEditingController();
    _wifiPasswordController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await widget.repository.getShopSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _shopNameController.text = settings.shopName;
          _outletNameController.text = settings.outletName;
          _addressController.text = settings.address;
          _phoneController.text = settings.phoneNumber;
          _footerController.text = settings.footerNote;
          _wifiNameController.text = settings.wifiName;
          _wifiPasswordController.text = settings.wifiPassword;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _outletNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    _wifiNameController.dispose();
    _wifiPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final updated = _settings.copyWith(
      shopName: _shopNameController.text.trim(),
      outletName: _outletNameController.text.trim(),
      address: _addressController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      footerNote: _footerController.text.trim(),
      wifiName: _wifiNameController.text.trim(),
      wifiPassword: _wifiPasswordController.text.trim(),
    );

    final saved = await widget.repository.updateShopSettings(updated);

    if (mounted) {
      setState(() {
        _settings = saved;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan toko dan outlet berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Pengaturan Nama Toko & Outlet',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.cardBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview Header Resi Thermal Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      'PREVIEW HEADER RESI CETAK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _shopNameController.text.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _outletNameController.text,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      _addressController.text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      'Telp/WA: ${_phoneController.text}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bagian Identitas Toko
              _buildSectionTitle('IDENTITAS RENTAL'),
              _buildTextField(
                controller: _shopNameController,
                label: 'Nama Bisnis / Toko',
                hint: 'Contoh: SKYRental iPhone POS',
                icon: Icons.storefront_rounded,
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama toko wajib diisi' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _outletNameController,
                label: 'Nama Cabang / Outlet',
                hint: 'Contoh: Outlet Utama Malioboro',
                icon: Icons.location_city_rounded,
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama outlet wajib diisi' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _phoneController,
                label: 'Nomor Telepon / WhatsApp CS',
                hint: 'Contoh: 0812-3456-7890',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty ? 'Nomor telepon wajib diisi' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _addressController,
                label: 'Alamat Lengkap Outlet',
                hint: 'Jl. Malioboro No. 45, Danurejan, Yogyakarta',
                icon: Icons.map_outlined,
                maxLines: 2,
                validator: (val) => val == null || val.trim().isEmpty ? 'Alamat outlet wajib diisi' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Bagian Konfigurasi Resi
              _buildSectionTitle('TEKS KAKI STRUK (FOOTER)'),
              _buildTextField(
                controller: _footerController,
                label: 'Pesan / Catatan Struk Thermal',
                hint: 'Terima kasih telah menyewa di SKYRental',
                icon: Icons.receipt_long_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Bagian WiFi Outlet (Fasilitas Pelanggan Saat Ambil Unit)
              _buildSectionTitle('WIFI OUTLET (FASILITAS PELANGGAN)'),
              _buildTextField(
                controller: _wifiNameController,
                label: 'Nama Jaringan WiFi (SSID)',
                hint: 'SKYRENTAL_GUEST',
                icon: Icons.wifi_rounded,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _wifiPasswordController,
                label: 'Kata Sandi WiFi',
                hint: 'rentaliphoneoke',
                icon: Icons.wifi_password_rounded,
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Pengaturan Toko',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
          ),
        ),
      ],
    );
  }
}
