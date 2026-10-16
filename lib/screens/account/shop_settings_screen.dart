import 'package:flutter/material.dart';
import '../../data/booking_repository.dart';
import '../../models/admin_user_model.dart';
import '../../models/receipt_format_settings.dart';
import '../../services/printer_storage_service.dart';
import '../../theme/app_theme.dart';
import '../receipt/widgets/thermal_receipt_paper_preview.dart';

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
  final PrinterStorageService _printerStorageService = PrinterStorageService();

  late final TextEditingController _shopNameController;
  late final TextEditingController _outletNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _footerController;

  ShopSettingsModel _settings = ShopSettingsModel.defaultSettings();
  ReceiptFormatSettings _formatSettings = const ReceiptFormatSettings();
  bool _isLoading = true;

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController();
    _outletNameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _footerController = TextEditingController();

    _shopNameController.addListener(_onFieldChanged);
    _outletNameController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _footerController.addListener(_onFieldChanged);

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final futures = await Future.wait([
        widget.repository.getShopSettings(),
        _printerStorageService.getReceiptFormatSettings(),
      ]);

      final settings = futures[0] as ShopSettingsModel;
      final format = futures[1] as ReceiptFormatSettings;

      if (mounted) {
        setState(() {
          _settings = settings;
          _formatSettings = format;
          _shopNameController.text = settings.shopName;
          _outletNameController.text = settings.outletName;
          _addressController.text = settings.address;
          _phoneController.text = settings.phoneNumber;
          _footerController.text = settings.footerNote;
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
    _shopNameController.removeListener(_onFieldChanged);
    _outletNameController.removeListener(_onFieldChanged);
    _addressController.removeListener(_onFieldChanged);
    _phoneController.removeListener(_onFieldChanged);
    _footerController.removeListener(_onFieldChanged);

    _shopNameController.dispose();
    _outletNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updated = _settings.copyWith(
        shopName: _shopNameController.text.trim(),
        outletName: _outletNameController.text.trim(),
        address: _addressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        footerNote: _footerController.text.trim(),
      );

      final saved = await widget.repository.updateShopSettings(updated);

      final currentFormat = await _printerStorageService.getReceiptFormatSettings();
      final updatedFormat = currentFormat.copyWith(
        businessName: _shopNameController.text.trim(),
        branchName: _outletNameController.text.trim(),
        businessTagline: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : currentFormat.businessTagline,
        contactInfo: _phoneController.text.trim().isNotEmpty
            ? 'CS: ${_phoneController.text.trim()} (WA)'
            : currentFormat.contactInfo,
        footerLine1: _footerController.text.trim().isNotEmpty
            ? _footerController.text.trim()
            : currentFormat.footerLine1,
      );
      await _printerStorageService.saveReceiptFormatSettings(updatedFormat);

      if (mounted) {
        setState(() {
          _settings = saved;
          _formatSettings = updatedFormat;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan toko dan outlet berhasil disimpan!'),
            backgroundColor: Color(0xFF047857),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengaturan toko: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Pengaturan Nama Toko & Outlet',
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
              // Realistic Simulated Thermal Receipt Paper Preview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: ThermalReceiptPaperPreview(
                  formatSettings: _formatSettings,
                  shopName: _shopNameController.text,
                  outletName: _outletNameController.text,
                  address: _addressController.text,
                  phoneNumber: _phoneController.text,
                  footerNote: _footerController.text,
                  maxHeight: 380,
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
                onChanged: (_) => setState(() {}),
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
