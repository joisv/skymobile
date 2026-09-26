import 'package:flutter/material.dart';
import '../../models/app_theme_model.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';

/// Layar pengaturan kustomisasi tema dan warna aplikasi
class ThemeSettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const ThemeSettingsScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  final ThemeService _themeService = ThemeService();

  // State untuk kustomisasi manual
  late Color _tempPrimary;
  late Color _tempAccent;

  // Opsi palet warna primer kustom (Deep & Solid)
  final List<Color> _customPrimaryOptions = const [
    Color(0xFF0F172A), // Slate 900
    Color(0xFF1E1B4B), // Indigo 950
    Color(0xFF064E3B), // Emerald 900
    Color(0xFF78350F), // Amber 900
    Color(0xFF881337), // Rose 900
    Color(0xFF581C87), // Purple 900
    Color(0xFF134E4A), // Teal 900
    Color(0xFF18181B), // Zinc 900
    Color(0xFF1E3A8A), // Blue 900
    Color(0xFF3B0764), // Deep Purple
  ];

  // Opsi palet warna aksen kustom (Vibrant & Highlight)
  final List<Color> _customAccentOptions = const [
    Color(0xFF0EA5E9), // Sky Blue 500
    Color(0xFF4F46E5), // Indigo 600
    Color(0xFF10B981), // Emerald 500
    Color(0xFFF59E0B), // Amber 500
    Color(0xFFE11D48), // Rose 600
    Color(0xFF8B5CF6), // Purple 500
    Color(0xFF14B8A6), // Teal 500
    Color(0xFFF97316), // Orange 500
    Color(0xFF06B6D4), // Cyan 500
    Color(0xFF64748B), // Slate 500
  ];

  @override
  void initState() {
    super.initState();
    _tempPrimary = _themeService.primaryColor;
    _tempAccent = _themeService.accentColor;
  }

  void _onSelectPreset(AppThemePreset preset) async {
    await _themeService.setPreset(preset.id);
    setState(() {
      _tempPrimary = preset.primary;
      _tempAccent = preset.accent;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Tema diubah ke ${preset.name}'),
            ],
          ),
          backgroundColor: preset.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _applyCustomColors() async {
    await _themeService.setCustomColors(
      primary: _tempPrimary,
      accent: _tempAccent,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.palette_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Warna kustom berhasil diterapkan!'),
            ],
          ),
          backgroundColor: _tempPrimary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _resetToDefault() async {
    await _themeService.resetToDefault();
    final defaultPreset = AppThemePreset.getById('sky_blue');
    setState(() {
      _tempPrimary = defaultPreset.primary;
      _tempAccent = defaultPreset.accent;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.restore_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Tema berhasil dikembalikan ke standar Biru Langit'),
            ],
          ),
          backgroundColor: defaultPreset.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _onChangeThemeMode(ThemeMode mode) async {
    await _themeService.setThemeMode(mode);

    String label = 'Mode Terang diaktifkan';
    if (mode == ThemeMode.dark) label = 'Mode Gelap diaktifkan';
    if (mode == ThemeMode.system) label = 'Mode Tampilan mengikuti pengaturan perangkat';

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                mode == ThemeMode.dark
                    ? Icons.dark_mode_rounded
                    : (mode == ThemeMode.light ? Icons.light_mode_rounded : Icons.settings_brightness_rounded),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(label),
            ],
          ),
          backgroundColor: _themeService.primaryColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeService,
      builder: (context, _) {
        final activePreset = _themeService.currentPreset;
        final currentPrimary = _themeService.primaryColor;
        final currentAccent = _themeService.accentColor;
        final currentAccentLight = _themeService.accentLightColor;
        final isCustom = _themeService.isCustom;

        if (widget.isEmbedded) {
          return _buildEmbeddedLayout(
            context,
            activePreset: activePreset,
            currentPrimary: currentPrimary,
            currentAccent: currentAccent,
            currentAccentLight: currentAccentLight,
            isCustom: isCustom,
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(
              'Tema & Warna Aplikasi',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
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
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // 1. Section: Mode Tampilan (Terang / Gelap / Sistem)
              _buildSectionTitle(
                title: 'MODE TAMPILAN',
                subtitle: 'Sesuaikan tema tampilan dengan preferensi kenyamanan mata Anda:',
              ),
              const SizedBox(height: 12),
              _buildThemeModeSelector(),
              const SizedBox(height: 24),

              // 2. Live Preview Card
              _buildLivePreviewCard(
                primary: currentPrimary,
                accent: currentAccent,
                accentLight: currentAccentLight,
                presetName: isCustom ? 'Warna Kustom' : activePreset.name,
              ),
              const SizedBox(height: 24),

              // 3. Section: Preset Tema Resmi
              _buildSectionTitle(
                title: 'PILIHAN TEMA PRESET',
                subtitle: 'Pilih palet warna yang dirancang serasi dan profesional:',
              ),
              const SizedBox(height: 12),
              ...AppThemePreset.defaultPresets.map((preset) {
                final isSelected = !isCustom && _themeService.activePresetId == preset.id;
                return _buildPresetItem(preset, isSelected);
              }),
              const SizedBox(height: 24),

              // 4. Section: Kustomisasi Mandiri
              _buildSectionTitle(
                title: 'KUSTOMISASI WARNA MANDIRI',
                subtitle: 'Padukan warna primer dan aksen sesuai preferensi identitas toko Anda:',
              ),
              const SizedBox(height: 12),
              _buildCustomColorPicker(),
              const SizedBox(height: 24),

              // 5. Section: Reset ke Default
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: AppTheme.surface,
                  ),
                  onPressed: _resetToDefault,
                  icon: const Icon(Icons.restore_rounded, size: 20),
                  label: const Text(
                    'Kembalikan ke Tema Standar (Biru Langit)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmbeddedLayout(
    BuildContext context, {
    required AppThemePreset activePreset,
    required Color currentPrimary,
    required Color currentAccent,
    required Color currentAccentLight,
    required bool isCustom,
  }) {
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
                      'Tema & Warna Aplikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sesuaikan mode tampilan gelap/terang, pilih palet warna resmi, atau kustomisasi warna primer dan aksen toko.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _resetToDefault,
                icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFFDC2626)),
                label: const Text(
                  'Reset Standar',
                  style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Section: Mode Tampilan (Terang / Gelap / Sistem)
        _buildSectionTitle(
          title: 'MODE TAMPILAN',
          subtitle: 'Sesuaikan tema tampilan dengan preferensi kenyamanan mata Anda:',
        ),
        const SizedBox(height: 12),
        _buildThemeModeSelector(),
        const SizedBox(height: 24),

        // 2. Live Preview Card
        _buildLivePreviewCard(
          primary: currentPrimary,
          accent: currentAccent,
          accentLight: currentAccentLight,
          presetName: isCustom ? 'Warna Kustom' : activePreset.name,
        ),
        const SizedBox(height: 24),

        // 3. Section: Preset Tema Resmi
        _buildSectionTitle(
          title: 'PILIHAN TEMA PRESET',
          subtitle: 'Pilih palet warna yang dirancang serasi dan profesional:',
        ),
        const SizedBox(height: 12),
        ...AppThemePreset.defaultPresets.map((preset) {
          final isSelected = !isCustom && _themeService.activePresetId == preset.id;
          return _buildPresetItem(preset, isSelected);
        }),
        const SizedBox(height: 24),

        // 4. Section: Kustomisasi Mandiri
        _buildSectionTitle(
          title: 'KUSTOMISASI WARNA MANDIRI',
          subtitle: 'Padukan warna primer dan aksen sesuai preferensi identitas toko Anda:',
        ),
        const SizedBox(height: 12),
        _buildCustomColorPicker(),
        const SizedBox(height: 24),

        // 5. Section: Reset ke Default
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              side: BorderSide(color: AppTheme.cardBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: AppTheme.surface,
            ),
            onPressed: _resetToDefault,
            icon: const Icon(Icons.restore_rounded, size: 20),
            label: const Text(
              'Kembalikan ke Tema Standar (Biru Langit)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildThemeModeSelector() {
    final currentMode = _themeService.themeMode;

    final modes = [
      (ThemeMode.light, Icons.light_mode_rounded, 'Terang', 'Cerah & Bersih'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Gelap', 'Redup & Fokus'),
      (ThemeMode.system, Icons.settings_brightness_rounded, 'Sistem', 'Otomatis HP'),
    ];

    return Row(
      children: modes.map((item) {
        final mode = item.$1;
        final icon = item.$2;
        final title = item.$3;
        final desc = item.$4;
        final isSelected = currentMode == mode;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => _onChangeThemeMode(mode),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _themeService.accentColor.withValues(alpha: 0.12)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _themeService.accentColor : AppTheme.cardBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isSelected ? _themeService.accentColor : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? _themeService.accentColor : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  /// Kotak Pratinjau Interaktif (Live Preview)
  Widget _buildLivePreviewCard({
    required Color primary,
    required Color accent,
    required Color accentLight,
    required String presetName,
  }) {
    final isDark = _themeService.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.2 : 0.06),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar Preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pratinjau Langsung Tema',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    presetName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Konten Simulasi Tampilan
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Kartu Unit Sewa Mockup
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.phone_iphone_rounded, color: accent, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'iPhone 15 Pro Max 256GB',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rp 350.000 / 24 Jam',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Siap Sewa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mockup Form Input dengan Fokus Aksen
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Cari nomor seri unit atau nama pelanggan...',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Mockup Tombol Utama & Sekunder
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {},
                        child: const Text('Tombol Utama', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(color: accent, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {},
                        child: const Text('Tombol Aksen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Item Kartu Preset Tema
  Widget _buildPresetItem(AppThemePreset preset, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? preset.accent : AppTheme.cardBorder,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: preset.accent.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onSelectPreset(preset),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Color Swatches Circle
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: preset.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(-8, 0),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: preset.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // Nama & Deskripsi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Centang Terpilih
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: preset.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                  )
                else
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.outline, width: 1.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Komponen Pemilih Warna Kustom Mandiri
  Widget _buildCustomColorPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pilihan Warna Primer
          Text(
            '1. Pilih Warna Primer (Tombol Utama & Bar)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _customPrimaryOptions.map((color) {
              final isPicked = _tempPrimary.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _tempPrimary = color),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPicked ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: isPicked ? 0.5 : 0.2),
                        blurRadius: isPicked ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isPicked
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Pilihan Warna Aksen
          Text(
            '2. Pilih Warna Aksen (Highlight, FAB & Border)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _customAccentOptions.map((color) {
              final isPicked = _tempAccent.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _tempAccent = color),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPicked ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: isPicked ? 0.5 : 0.2),
                        blurRadius: isPicked ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isPicked
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Tombol Terapkan Kustom
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _tempPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _applyCustomColors,
              icon: const Icon(Icons.colorize_rounded, size: 18),
              label: const Text(
                'Terapkan Warna Kustom',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
