import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../data/mock_receipt_data.dart';
import '../../models/receipt_format_settings.dart';
import '../../models/receipt_model.dart';
import '../../services/printer_storage_service.dart';
import '../../theme/app_theme.dart';

/// Halaman pengaturan format resi thermal.
/// Memungkinkan pengguna mengkustomisasi header, footer, visibilitas field,
/// dan gaya separator pada struk cetak.
class ReceiptFormatSettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const ReceiptFormatSettingsScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<ReceiptFormatSettingsScreen> createState() =>
      _ReceiptFormatSettingsScreenState();
}

class _ReceiptFormatSettingsScreenState
    extends State<ReceiptFormatSettingsScreen> {
  final PrinterStorageService _storage = PrinterStorageService();

  ReceiptFormatSettings _settings = const ReceiptFormatSettings();
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _showPreview = false;

  // Controllers untuk TextField
  late TextEditingController _businessNameCtrl;
  late TextEditingController _businessTaglineCtrl;
  late TextEditingController _branchNameCtrl;
  late TextEditingController _footerLine1Ctrl;
  late TextEditingController _footerLine2Ctrl;
  late TextEditingController _footerLine3Ctrl;
  late TextEditingController _contactInfoCtrl;

  @override
  void initState() {
    super.initState();
    _businessNameCtrl = TextEditingController(text: _settings.businessName);
    _businessTaglineCtrl = TextEditingController(text: _settings.businessTagline);
    _branchNameCtrl = TextEditingController(text: _settings.branchName);
    _footerLine1Ctrl = TextEditingController(text: _settings.footerLine1);
    _footerLine2Ctrl = TextEditingController(text: _settings.footerLine2);
    _footerLine3Ctrl = TextEditingController(text: _settings.footerLine3);
    _contactInfoCtrl = TextEditingController(text: _settings.contactInfo);
    _loadSettings();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _businessTaglineCtrl.dispose();
    _branchNameCtrl.dispose();
    _footerLine1Ctrl.dispose();
    _footerLine2Ctrl.dispose();
    _footerLine3Ctrl.dispose();
    _contactInfoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final format = await _storage.getReceiptFormatSettings();
      if (mounted && !_hasChanges) {
        setState(() {
          _settings = format;
          _businessNameCtrl.text = format.businessName;
          _businessTaglineCtrl.text = format.businessTagline;
          _branchNameCtrl.text = format.branchName;
          _footerLine1Ctrl.text = format.footerLine1;
          _footerLine2Ctrl.text = format.footerLine2;
          _footerLine3Ctrl.text = format.footerLine3;
          _contactInfoCtrl.text = format.contactInfo;
        });
      }
    } catch (_) {}
  }

  void _updateSetting(ReceiptFormatSettings newSettings) {
    setState(() {
      _settings = newSettings;
      _hasChanges = true;
    });
  }

  void _applyPreset(ReceiptFormatSettings preset) {
    setState(() {
      _settings = preset;
      _businessNameCtrl.text = preset.businessName;
      _businessTaglineCtrl.text = preset.businessTagline;
      _branchNameCtrl.text = preset.branchName;
      _footerLine1Ctrl.text = preset.footerLine1;
      _footerLine2Ctrl.text = preset.footerLine2;
      _footerLine3Ctrl.text = preset.footerLine3;
      _contactInfoCtrl.text = preset.contactInfo;
      _hasChanges = true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _storage.saveReceiptFormatSettings(_settings);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Pengaturan format resi berhasil disimpan!'),
              ],
            ),
            backgroundColor: Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restore, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Reset ke Default?', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'Semua pengaturan format resi akan dikembalikan ke nilai bawaan. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final defaultSettings = ReceiptFormatSettings.defaultSettings();
      await _storage.saveReceiptFormatSettings(defaultSettings);
      if (mounted) {
        setState(() {
          _settings = defaultSettings;
          _businessNameCtrl.text = defaultSettings.businessName;
          _businessTaglineCtrl.text = defaultSettings.businessTagline;
          _branchNameCtrl.text = defaultSettings.branchName;
          _footerLine1Ctrl.text = defaultSettings.footerLine1;
          _footerLine2Ctrl.text = defaultSettings.footerLine2;
          _footerLine3Ctrl.text = defaultSettings.footerLine3;
          _contactInfoCtrl.text = defaultSettings.contactInfo;
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan format resi direset ke default.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildEmbeddedLayout(context);
    }
    return Scaffold(
      backgroundColor: AppTheme.cardBorder,
      appBar: AppBar(
        title: Text(
          'Pengaturan Format Resi',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_hasChanges) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Perubahan Belum Disimpan',
                      style: TextStyle(fontSize: 16)),
                  content: const Text(
                      'Ada perubahan yang belum disimpan. Simpan sebelum keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Buang'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _saveSettings();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Simpan & Keluar'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Reset ke Default',
            icon: const Icon(Icons.restore_rounded),
            onPressed: _resetToDefault,
          ),
          IconButton(
            tooltip: _showPreview
                ? 'Sembunyikan Pratinjau'
                : 'Tampilkan Pratinjau',
            icon: Icon(_showPreview
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded),
            onPressed: () => setState(() => _showPreview = !_showPreview),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Preview (collapsible)
          if (_showPreview) _buildLivePreview(),

          // Settings Form
          Expanded(
            child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Preset 1-Klik & Meteran Panjang Kertas
                      _buildPresetAndMeterSection(),

                      _buildSectionHeader(
                        'Header Toko & Tipografi',
                        Icons.store_rounded,
                        'Nama usaha, gaya font (ukuran/ketebalan), dan cabang',
                      ),
                      _buildHeaderSection(),
                      const SizedBox(height: 16),

                      _buildSectionHeader(
                        'Tampilkan / Sembunyikan Field',
                        Icons.toggle_on_rounded,
                        'Pilih field apa saja yang muncul di struk',
                      ),
                      _buildVisibilitySection(),
                      const SizedBox(height: 16),

                      _buildSectionHeader(
                        'Barcode / QR Code Booking',
                        Icons.qr_code_scanner_rounded,
                        'Cetak barcode atau QR untuk pemindaian saat unit kembali',
                      ),
                      _buildBarcodeSection(),
                      const SizedBox(height: 16),

                      _buildSectionHeader(
                        'Footer & Kontak',
                        Icons.article_rounded,
                        'Teks yang tampil di bagian bawah struk',
                      ),
                      _buildFooterSection(),
                      const SizedBox(height: 16),

                      _buildSectionHeader(
                        'Format Kertas & Pemisah',
                        Icons.horizontal_rule_rounded,
                        'Kerapatan spasi, baris potong kertas, dan gaya pemisah',
                      ),
                      _buildPaperAndSeparatorSection(),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
      // Sticky Save Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.cardBorder)),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showPreview = !_showPreview),
                      icon: Icon(
                        _showPreview
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _showPreview ? 'Tutup Pratinjau' : 'Pratinjau',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isSaving || !_hasChanges) ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        _isSaving
                            ? 'Menyimpan...'
                            : _hasChanges
                                ? 'Simpan Perubahan'
                                : 'Tersimpan',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmbeddedLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header matching tablet design
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Format & Kustomisasi Resi 58mm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Kustomisasi header, footer, ukuran teks, eco mode hemat kertas, dan visibilitas barcode resi.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Reset', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _showPreview = !_showPreview),
                    icon: Icon(_showPreview ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
                    label: Text(_showPreview ? 'Tutup Preview' : 'Pratinjau', style: const TextStyle(fontSize: 12)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Format',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live Preview (collapsible)
        if (_showPreview) ...[
          _buildLivePreview(),
          const SizedBox(height: 16),
        ],

        // Preset 1-Klik & Meteran Panjang Kertas
        _buildPresetAndMeterSection(),
        const SizedBox(height: 16),

        _buildSectionHeader(
          'Header Toko & Tipografi',
          Icons.store_rounded,
          'Nama usaha, gaya font (ukuran/ketebalan), dan cabang',
        ),
        _buildHeaderSection(),
        const SizedBox(height: 16),

        _buildSectionHeader(
          'Tampilkan / Sembunyikan Field',
          Icons.toggle_on_rounded,
          'Pilih field apa saja yang muncul di struk',
        ),
        _buildVisibilitySection(),
        const SizedBox(height: 16),

        _buildSectionHeader(
          'Barcode / QR Code Booking',
          Icons.qr_code_scanner_rounded,
          'Cetak barcode atau QR untuk pemindaian saat unit kembali',
        ),
        _buildBarcodeSection(),
        const SizedBox(height: 16),

        _buildSectionHeader(
          'Footer & Kontak',
          Icons.article_rounded,
          'Teks yang tampil di bagian bawah struk',
        ),
        _buildFooterSection(),
        const SizedBox(height: 16),

        _buildSectionHeader(
          'Format Kertas & Pemisah',
          Icons.horizontal_rule_rounded,
          'Kerapatan spasi, baris potong kertas, dan gaya pemisah',
        ),
        _buildPaperAndSeparatorSection(),
      ],
    );
  }

  // --- Preset & Paper Meter Section ---
  Widget _buildPresetAndMeterSection() {
    final mockReceipt =
        MockReceiptData.items.isNotEmpty ? MockReceiptData.items[0] : null;
    final receiptText =
        mockReceipt?.toEscPos58mm(formatSettings: _settings) ?? '';
    final estLength =
        ReceiptModel.estimatePaperLengthCm(receiptText, _settings);
    final isEco = _settings.densityMode == 'compact';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEco ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEco ? const Color(0xFFA7F3D0) : AppTheme.cardBorder,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEco ? const Color(0xFF047857) : AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEco ? Icons.eco_rounded : Icons.straighten_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEco
                          ? 'Mode Hemat Kertas Aktif (ECO)'
                          : 'Estimasi Panjang Kertas Thermal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isEco
                            ? const Color(0xFF065F46)
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEco
                          ? 'Panjang struk ~$estLength cm (Menghemat ~48% kertas roll)'
                          : 'Panjang struk ~$estLength cm per transaksi (Format Lengkap)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isEco
                            ? const Color(0xFF047857)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isEco ? const Color(0xFFD1FAE5) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '~$estLength cm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isEco
                        ? const Color(0xFF047857)
                        : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Preset Format 1-Klik:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _applyPreset(ReceiptFormatSettings.defaultSettings()),
                  icon: const Icon(Icons.article_outlined, size: 16),
                  label: const Text('Mode Standar',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: !isEco
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    side: BorderSide(
                      color: !isEco ? AppTheme.primary : AppTheme.cardBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _applyPreset(ReceiptFormatSettings.compactSettings()),
                  icon: const Icon(Icons.eco_rounded, size: 16),
                  label: const Text('Mode Hemat (Eco)',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor:
                        isEco ? const Color(0xFF047857) : AppTheme.surface,
                    foregroundColor:
                        isEco ? Colors.white : AppTheme.textPrimary,
                    side: BorderSide(
                      color: isEco
                          ? const Color(0xFF047857)
                          : AppTheme.cardBorder,
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Live Preview Widget ---
  Widget _buildLivePreview() {
    final mockReceipt =
        MockReceiptData.items.isNotEmpty ? MockReceiptData.items[0] : null;

    if (mockReceipt == null) {
      return const SizedBox.shrink();
    }

    final receiptText = mockReceipt.toEscPos58mm(formatSettings: _settings);
    final estCm = ReceiptModel.estimatePaperLengthCm(receiptText, _settings);
    final isEco = _settings.densityMode == 'compact';
    final hasBarcodeTag = receiptText.contains(RegExp(r'\[BARCODE:.*?\]'));

    const monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 9,
      height: 1.3,
      letterSpacing: 0.3,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0F172A),
    );

    Widget buildPreviewSegment(String text) {
      if (!text.contains('[STORE_NAME:')) {
        return SelectableText(text, style: monoStyle);
      }

      final storeRegex = RegExp(r'\[STORE_NAME:(.*?):(.*?):(.*?):(.*?)\]');
      final match = storeRegex.firstMatch(text);
      if (match == null) {
        return SelectableText(text, style: monoStyle);
      }

      final before = text.substring(0, match.start);
      final size = match.group(1) ?? 'large';
      final weight = match.group(2) ?? 'bold';
      final align = match.group(3) ?? 'center';
      final storeName = match.group(4) ?? '';
      final after = text.substring(match.end);

      double titleFontSize = 13;
      if (size == 'small') titleFontSize = 10;
      if (size == 'medium') titleFontSize = 11.5;
      if (size == 'large') titleFontSize = 14;
      if (size == 'extraLarge') titleFontSize = 16.5;

      FontWeight titleFontWeight = FontWeight.bold;
      if (weight == 'normal') titleFontWeight = FontWeight.normal;
      if (weight == 'bold') titleFontWeight = FontWeight.bold;
      if (weight == 'extraBold') titleFontWeight = FontWeight.w900;

      TextAlign titleAlign =
          align == 'left' ? TextAlign.left : TextAlign.center;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (before.isNotEmpty)
            SelectableText(before.trimRight(), style: monoStyle),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              storeName,
              textAlign: titleAlign,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: titleFontSize,
                fontWeight: titleFontWeight,
                letterSpacing: 0.5,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          if (after.isNotEmpty)
            SelectableText(after.trimLeft(), style: monoStyle),
        ],
      );
    }

    Widget previewBody;
    if (hasBarcodeTag && _settings.showBarcode) {
      final parts = receiptText.split(RegExp(r'\[BARCODE:.*?\]\n?'));
      final bookingCode = mockReceipt.bookingCode;
      previewBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPreviewSegment(parts[0]),
          _buildBarcodePreview(bookingCode),
          if (parts.length > 1) buildPreviewSegment(parts[1]),
        ],
      );
    } else {
      final cleanText =
          receiptText.replaceAll(RegExp(r'\[BARCODE:.*?\]\n?'), '');
      previewBody = buildPreviewSegment(cleanText);
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Column(
        children: [
          // Preview header with live meter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(
                  isEco
                      ? 'PRATINJAU LIVE (~$estCm cm • HEMAT ~48%)'
                      : 'PRATINJAU STRUK LIVE (~$estCm cm)',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showPreview = false),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
          // Receipt text
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFDFB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: previewBody,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Section Header ---
  Widget _buildSectionHeader(
      String title, IconData icon, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Header & Typography Section ---
  Widget _buildHeaderSection() {
    return Card(
      color: AppTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tampilkan Header Toko',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Sembunyikan header jika tidak diperlukan',
                      style: TextStyle(fontSize: 11)),
              value: _settings.showHeader,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) =>
                  _updateSetting(_settings.copyWith(showHeader: val)),
            ),
            if (_settings.showHeader) ...[
              const Divider(height: 16),
              _buildTextField(
                label: 'Nama Usaha',
                controller: _businessNameCtrl,
                hint: 'Contoh: SKYRENTAL',
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(businessName: val)),
              ),
              const SizedBox(height: 14),

              // Format Font Nama Usaha
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields_rounded,
                            size: 16, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Format Font Nama Usaha',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ukuran Font
                    Text('Ukuran Font:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildChoiceChip(
                            'Kecil (12pt)',
                            'small',
                            _settings.businessNameFontSize,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameFontSize: v))),
                        _buildChoiceChip(
                            'Sedang (14pt)',
                            'medium',
                            _settings.businessNameFontSize,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameFontSize: v))),
                        _buildChoiceChip(
                            'Besar (18pt)',
                            'large',
                            _settings.businessNameFontSize,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameFontSize: v))),
                        _buildChoiceChip(
                            'Ekstra Besar (22pt)',
                            'extraLarge',
                            _settings.businessNameFontSize,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameFontSize: v))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Ketebalan Font
                    Text('Ketebalan Font:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildChoiceChip(
                            'Reguler',
                            'normal',
                            _settings.businessNameFontWeight,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameFontWeight: v))),
                        _buildChoiceChip(
                            'Tebal (Bold)',
                            'bold',
                            _settings.businessNameFontWeight,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameFontWeight: v))),
                        _buildChoiceChip(
                            'Ekstra Tebal',
                            'extraBold',
                            _settings.businessNameFontWeight,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameFontWeight: v))),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Perataan
                    Text('Perataan Teks:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildChoiceChip(
                            'Rata Tengah',
                            'center',
                            _settings.businessNameAlignment,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameAlignment: v))),
                        _buildChoiceChip(
                            'Rata Kiri',
                            'left',
                            _settings.businessNameAlignment,
                            (v) => _updateSetting(
                                _settings.copyWith(businessNameAlignment: v))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampilkan Tagline / Slogan',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: const Text('Teks slogan di bawah nama usaha',
                    style: TextStyle(fontSize: 11)),
                value: _settings.showTagline,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showTagline: val)),
              ),
              if (_settings.showTagline) ...[
                const SizedBox(height: 6),
                _buildTextField(
                  label: 'Tagline / Slogan',
                  controller: _businessTaglineCtrl,
                  hint: 'Contoh: Sewa iPhone Terpercaya',
                  onChanged: (val) => _updateSetting(
                      _settings.copyWith(businessTagline: val)),
                ),
              ],
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampilkan Nama Cabang',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: const Text('Alamat / nama outlet cabang rental',
                    style: TextStyle(fontSize: 11)),
                value: _settings.showBranch,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showBranch: val)),
              ),
              if (_settings.showBranch) ...[
                const SizedBox(height: 6),
                _buildTextField(
                  label: 'Nama Cabang',
                  controller: _branchNameCtrl,
                  hint: 'Contoh: SKYRENTAL YOGYAKARTA',
                  onChanged: (val) =>
                      _updateSetting(_settings.copyWith(branchName: val)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // --- Visibility Section (Granular Field Toggles) ---
  Widget _buildVisibilitySection() {
    return Column(
      children: [
        // Sub-Kategori 1: Info Transaksi
        Card(
          color: AppTheme.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Info Transaksi',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
              ),
              _buildToggleTile(
                title: 'Nomor Struk',
                subtitle: 'No. bukti transaksi (e.g. REC-202609-001)',
                icon: Icons.receipt_rounded,
                value: _settings.showReceiptNumber,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showReceiptNumber: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Tanggal & Waktu',
                subtitle: 'Waktu transaksi dicetak',
                icon: Icons.access_time_rounded,
                value: _settings.showDateTime,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showDateTime: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Nama Kasir / Admin',
                subtitle: 'Nama staf yang melayani transaksi',
                icon: Icons.person_outline_rounded,
                value: _settings.showAdminName,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showAdminName: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Tipe Resi',
                subtitle: 'Label tipe struk (e.g. Sewa Baru, Pelunasan)',
                icon: Icons.label_outline_rounded,
                value: _settings.showTransactionType,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showTransactionType: val)),
              ),
            ],
          ),
        ),

        // Sub-Kategori 2: Data Pelanggan & Unit
        Card(
          color: AppTheme.surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Pelanggan & Unit iPhone',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
              ),
              _buildToggleTile(
                title: 'Nama Pelanggan',
                subtitle: 'Nama penyewa unit',
                icon: Icons.badge_outlined,
                value: _settings.showCustomerName,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showCustomerName: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Kontak / No HP Pelanggan',
                subtitle: 'Nomor WhatsApp pelanggan',
                icon: Icons.phone_outlined,
                value: _settings.showCustomerPhone,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showCustomerPhone: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Kode Booking',
                subtitle: 'Teks kode booking pada rincian data',
                icon: Icons.qr_code_rounded,
                value: _settings.showBookingCodeText,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showBookingCodeText: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Nama Unit iPhone',
                subtitle: 'Model & kapasitas unit yang disewa',
                icon: Icons.phone_iphone_rounded,
                value: _settings.showUnitName,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showUnitName: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Durasi Sewa',
                subtitle: 'Lama waktu sewa (e.g. 3 Hari)',
                icon: Icons.timelapse_rounded,
                value: _settings.showRentalDuration,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showRentalDuration: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Periode Tanggal Sewa',
                subtitle: 'Rentang tanggal mulai s/d selesai',
                icon: Icons.date_range_rounded,
                value: _settings.showRentalDates,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showRentalDates: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Serial Number Unit',
                subtitle: 'Nomor seri fisik perangkat iPhone',
                icon: Icons.tag_rounded,
                value: _settings.showSerialNumber,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showSerialNumber: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Kode Aset Internal',
                subtitle: 'Kode inventaris internal unit',
                icon: Icons.inventory_2_outlined,
                value: _settings.showAssetCode,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showAssetCode: val)),
              ),
            ],
          ),
        ),

        // Sub-Kategori 3: Biaya & Pembayaran
        Card(
          color: AppTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Rincian Biaya & Pembayaran',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
              ),
              _buildToggleTile(
                title: 'Biaya Sewa Pokok',
                subtitle: 'Nominal sewa unit sebelum deposit & diskon',
                icon: Icons.monetization_on_outlined,
                value: _settings.showRentFee,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showRentFee: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Deposit Jaminan',
                subtitle: 'Informasi uang jaminan rental',
                icon: Icons.account_balance_wallet_rounded,
                value: _settings.showDeposit,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showDeposit: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Potongan / Diskon',
                subtitle: 'Potongan harga atau voucher promo',
                icon: Icons.discount_rounded,
                value: _settings.showDiscount,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showDiscount: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Metode Pembayaran',
                subtitle: 'Tunai, Transfer Bank, atau QRIS',
                icon: Icons.payment_rounded,
                value: _settings.showPaymentMethod,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showPaymentMethod: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Status Bayar',
                subtitle: 'Status Lunas / Belum Lunas',
                icon: Icons.check_circle_outline_rounded,
                value: _settings.showPaymentStatus,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showPaymentStatus: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Detail Tunai (Uang Diterima & Kembalian)',
                subtitle: 'Khusus transaksi pembayaran tunai',
                icon: Icons.payments_rounded,
                value: _settings.showCashDetails,
                onChanged: (val) => _updateSetting(
                    _settings.copyWith(showCashDetails: val)),
              ),
              const Divider(height: 0, indent: 16, endIndent: 16),
              _buildToggleTile(
                title: 'Catatan Transaksi',
                subtitle: 'Catatan tambahan yang diinput kasir',
                icon: Icons.note_alt_rounded,
                value: _settings.showNotes,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showNotes: val)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Barcode Section ---
  Widget _buildBarcodeSection() {
    return Card(
      color: AppTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Cetak Barcode / QR di Struk',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Cetak barcode/QR kode booking di struk fisik agar mudah di-scan saat unit dikembalikan',
                style: TextStyle(fontSize: 11),
              ),
              value: _settings.showBarcode,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) =>
                  _updateSetting(_settings.copyWith(showBarcode: val)),
            ),
            if (_settings.showBarcode) ...[
              const Divider(height: 16),
              Text(
                'Tipe Format Kode',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Barcode 1D (Code 128)',
                        style: TextStyle(fontSize: 12)),
                    selected: _settings.barcodeType == 'code128',
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: _settings.barcodeType == 'code128'
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontWeight: _settings.barcodeType == 'code128'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        _updateSetting(
                            _settings.copyWith(barcodeType: 'code128'));
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('QR Code (2D)',
                        style: TextStyle(fontSize: 12)),
                    selected: _settings.barcodeType == 'qrcode',
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: _settings.barcodeType == 'qrcode'
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontWeight: _settings.barcodeType == 'qrcode'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        _updateSetting(
                            _settings.copyWith(barcodeType: 'qrcode'));
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Keduanya (1D & QR)',
                        style: TextStyle(fontSize: 12)),
                    selected: _settings.barcodeType == 'both',
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: _settings.barcodeType == 'both'
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontWeight: _settings.barcodeType == 'both'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        _updateSetting(_settings.copyWith(barcodeType: 'both'));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Pilihan Ukuran Barcode
              Text(
                'Ukuran Barcode / QR Code',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildChoiceChip(
                    'Kecil / Hemat (40px)',
                    'small',
                    _settings.barcodeSize,
                    (v) =>
                        _updateSetting(_settings.copyWith(barcodeSize: v)),
                  ),
                  _buildChoiceChip(
                    'Sedang / Standar (64px)',
                    'medium',
                    _settings.barcodeSize,
                    (v) =>
                        _updateSetting(_settings.copyWith(barcodeSize: v)),
                  ),
                  _buildChoiceChip(
                    'Besar (80px)',
                    'large',
                    _settings.barcodeSize,
                    (v) =>
                        _updateSetting(_settings.copyWith(barcodeSize: v)),
                  ),
                ],
              ),

              if (_settings.barcodeType == 'code128' ||
                  _settings.barcodeType == 'both') ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tampilkan Teks Kode di Bawah Barcode',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Mencetak teks booking code (HRI) di bawah garis barcode 1D',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _settings.showBarcodeHri,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (val) =>
                      _updateSetting(_settings.copyWith(showBarcodeHri: val)),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saat pelanggan mengembalikan iPhone, staf cukup scan barcode di struk dengan pemindai kamera untuk membuka detail booking dan form inspeksi secara instan.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1E40AF),
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodePreview(String code) {
    final type = _settings.barcodeType;
    final size = _settings.barcodeSize;
    final double barcodeH = size == 'small' ? 30 : (size == 'large' ? 50 : 40);
    final double qrDim = size == 'small' ? 55 : (size == 'large' ? 80 : 65);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(6),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (type == 'code128' || type == 'both') ...[
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: code,
              width: 180,
              height: barcodeH,
              drawText: _settings.showBarcodeHri,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            if (type == 'both') const SizedBox(height: 6),
          ],
          if (type == 'qrcode' || type == 'both') ...[
            BarcodeWidget(
              barcode: Barcode.qrCode(
                  errorCorrectLevel: BarcodeQRCorrectionLevel.medium),
              data: code,
              width: qrDim,
              height: qrDim,
            ),
            const SizedBox(height: 2),
            Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Footer Section ---
  Widget _buildFooterSection() {
    return Card(
      color: AppTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tampilkan Footer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Sembunyikan footer jika tidak diperlukan',
                  style: TextStyle(fontSize: 11)),
              value: _settings.showFooter,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) =>
                  _updateSetting(_settings.copyWith(showFooter: val)),
            ),
            if (_settings.showFooter) ...[
              const Divider(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampilkan Syarat & Ketentuan',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: const Text('Teks S&K di bagian bawah struk',
                    style: TextStyle(fontSize: 11)),
                value: _settings.showTerms,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showTerms: val)),
              ),
              if (_settings.showTerms) ...[
                const SizedBox(height: 8),
                _buildTextField(
                  label: 'Footer Baris 1',
                  controller: _footerLine1Ctrl,
                  hint: 'Contoh: Syarat & Ketentuan Berlaku',
                  onChanged: (val) =>
                      _updateSetting(_settings.copyWith(footerLine1: val)),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Footer Baris 2',
                  controller: _footerLine2Ctrl,
                  hint: 'Contoh: Harap simpan struk ini',
                  onChanged: (val) =>
                      _updateSetting(_settings.copyWith(footerLine2: val)),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Footer Baris 3',
                  controller: _footerLine3Ctrl,
                  hint: 'Contoh: bukti transaksi yang sah.',
                  onChanged: (val) =>
                      _updateSetting(_settings.copyWith(footerLine3: val)),
                ),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampilkan Kontak CS',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: const Text('Nomor bantuan atau WhatsApp toko',
                    style: TextStyle(fontSize: 11)),
                value: _settings.showContactInfo,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) =>
                    _updateSetting(_settings.copyWith(showContactInfo: val)),
              ),
              if (_settings.showContactInfo) ...[
                const SizedBox(height: 8),
                _buildTextField(
                  label: 'Kontak CS / WhatsApp',
                  controller: _contactInfoCtrl,
                  hint: 'Contoh: CS: 0812-3456-7890 (WA)',
                  onChanged: (val) =>
                      _updateSetting(_settings.copyWith(contactInfo: val)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // --- Paper & Separator Section ---
  Widget _buildPaperAndSeparatorSection() {
    const separatorOptions = ['=', '-', '*', '#', '~'];
    const subSeparatorOptions = ['-', '.', '·', '~', '_'];

    return Card(
      color: AppTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Spasi Padat (Eco Spacing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mode Spasi Padat (Compact Spacing)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Menghapus baris pemisah ganda dan spasi berlebih untuk menghemat kertas roll thermal',
                style: TextStyle(fontSize: 11),
              ),
              value: _settings.compactSpacing,
              activeThumbColor: AppTheme.primary,
              onChanged: (val) =>
                  _updateSetting(_settings.copyWith(compactSpacing: val)),
            ),
            const Divider(height: 20),

            // Feed Lines
            Text('Baris Penggulung Kertas (Feed Lines)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Jumlah baris kosong yang didorong printer sebelum memotong struk:',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 4].map((lines) {
                final isSelected = _settings.feedLines == lines;
                return ChoiceChip(
                  label: Text('$lines Baris ${lines == 1 ? '(Hemat)' : ''}',
                      style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) {
                      _updateSetting(_settings.copyWith(feedLines: lines));
                    }
                  },
                );
              }).toList(),
            ),
            const Divider(height: 24),

            // Pemisah Utama
            Text('Pemisah Utama',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Pratinjau: ${_settings.separatorChar * 32}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: separatorOptions.map((char) {
                final isSelected = _settings.separatorChar == char;
                return ChoiceChip(
                  label: Text(' $char ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      )),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  onSelected: (val) {
                    if (val) {
                      _updateSetting(
                          _settings.copyWith(separatorChar: char));
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Pemisah Sub-Bagian
            Text('Pemisah Sub-Bagian',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Pratinjau: ${_settings.subSeparatorChar * 32}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: subSeparatorOptions.map((char) {
                final isSelected = _settings.subSeparatorChar == char;
                return ChoiceChip(
                  label: Text(' $char ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      )),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  onSelected: (val) {
                    if (val) {
                      _updateSetting(
                          _settings.copyWith(subSeparatorChar: char));
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) onSelected(value);
      },
    );
  }

  // --- Reusable Widgets ---

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(fontSize: 12, color: AppTheme.textMuted),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.cardBorder,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 16,
            color: value ? AppTheme.primary : AppTheme.textMuted),
      ),
      title: Text(title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: value ? AppTheme.textPrimary : AppTheme.textSecondary,
          )),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      value: value,
      activeThumbColor: AppTheme.primary,
      onChanged: (val) => onChanged(val),
    );
  }
}
