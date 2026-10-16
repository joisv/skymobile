import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/app_update_model.dart';
import '../services/app_update_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final String? currentVersion;
  final VoidCallback? onDismissed;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    this.currentVersion,
    this.onDismissed,
  });

  static bool _isShowing = false;
  static bool get isShowing => _isShowing;

  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo, {
    String? currentVersion,
    VoidCallback? onDismissed,
  }) async {
    if (_isShowing) {
      debugPrint('AppUpdateDialog: Dialog already visible, skipping duplicate show.');
      return;
    }
    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !updateInfo.isMandatory,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (ctx) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: AppUpdateDialog(
            updateInfo: updateInfo,
            currentVersion: currentVersion,
            onDismissed: onDismissed,
          ),
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> with WidgetsBindingObserver {
  final AppUpdateService _updateService = AppUpdateService();

  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _statusMessage = '';
  String? _errorMessage;
  File? _downloadedFile;
  bool _needsPermission = false;
  bool _launchedInstaller = false;
  String _currentVersion = '';

  @visibleForTesting
  bool get launchedInstaller => _launchedInstaller;

  @visibleForTesting
  set launchedInstaller(bool value) => _launchedInstaller = value;

  @visibleForTesting
  String get statusMessage => _statusMessage;

  @visibleForTesting
  String? get errorMessage => _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _totalBytes = widget.updateInfo.fileSize;
    _currentVersion = widget.currentVersion ?? widget.updateInfo.currentVersion;
    if (_currentVersion.isEmpty) {
      _loadCurrentVersion();
    }
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final info = await _updateService.getCurrentVersionInfo();
      if (mounted && info.version.isNotEmpty) {
        setState(() {
          _currentVersion = info.version;
        });
      }
    } catch (e) {
      debugPrint('Notice: Error loading current version in dialog: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_launchedInstaller) {
        _verifyInstallationResult();
      } else if (_needsPermission && _downloadedFile != null && _downloadedFile!.existsSync()) {
        _checkPermissionOnResume();
      }
    }
  }

  Future<void> _checkPermissionOnResume() async {
    if (Platform.isAndroid) {
      final canInstall = await _updateService.canRequestPackageInstalls();
      if (canInstall && mounted) {
        setState(() {
          _needsPermission = false;
          _statusMessage = 'Izin telah diberikan. Membuka penginstal...';
        });
        await _launchInstaller(_downloadedFile!.path);
      }
    }
  }

  Future<void> _verifyInstallationResult() async {
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Memeriksa status versi terpasang...';
    });

    try {
      final currentInfo = await _updateService.getCurrentVersionInfo(forceRefresh: true);
      if (!mounted) return;

      if (currentInfo.buildNumber >= widget.updateInfo.latestBuild) {
        // 1. Immediately dismiss update dialog
        widget.onDismissed?.call();
        Navigator.of(context).pop();

        // 2. Show success SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SkyMobile berhasil diperbarui ke v${widget.updateInfo.latestVersion} (Build ${widget.updateInfo.latestBuild})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );

        // 3. Asynchronously clean up temp APKs and clear snooze in background
        _updateService.cleanupTempApks().catchError((e) {
          debugPrint('Notice: Error during temp APK cleanup: $e');
        });
        _updateService.clearSnooze().catchError((e) {
          debugPrint('Notice: Error clearing snooze: $e');
        });
      } else {
        // User returned before installation completed or cancelled
        setState(() {
          _launchedInstaller = false;
          _statusMessage = 'Instalasi belum selesai. Silakan pasang kembali berkas yang sudah diunduh.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _launchedInstaller = false;
        _errorMessage = 'Gagal memverifikasi versi terpasang: $e';
        _statusMessage = '';
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startUpdateFlow() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _needsPermission = false;
      _statusMessage = 'Menghubungi server unduhan...';
      _progress = 0.0;
      _receivedBytes = 0;
    });

    try {
      // 1. Download and verify APK
      final file = await _updateService.downloadAndVerifyApk(
        widget.updateInfo,
        onProgress: (received, total, progress) {
          if (mounted) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              _progress = progress;
              _statusMessage = 'Mengunduh paket instalasi (${(progress * 100).toStringAsFixed(0)}%)...';
            });
          }
        },
      );

      _downloadedFile = file;

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Memverifikasi integritas berkas (SHA-256)...';
      });

      // 2. Check Android Unknown App Sources permission (Android 8.0+)
      if (Platform.isAndroid) {
        final canInstall = await _updateService.canRequestPackageInstalls();
        if (!canInstall) {
          if (!mounted) return;
          setState(() {
            _isDownloading = false;
            _needsPermission = true;
            _statusMessage = 'Izin instalasi aplikasi pihak ketiga diperlukan.';
          });
          return;
        }
      }

      // 3. Launch native installer
      await _launchInstaller(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _statusMessage = '';
      });
    }
  }

  Future<void> _launchInstaller(String filePath) async {
    setState(() {
      _isDownloading = false;
      _statusMessage = 'Membuka penginstal paket Android...';
    });

    try {
      _launchedInstaller = true;
      await _updateService.installApk(filePath);
    } catch (e) {
      _launchedInstaller = false;
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal meluncurkan penginstal: $e';
        _statusMessage = '';
      });
    }
  }

  Future<void> _requestInstallPermission() async {
    await _updateService.openInstallPermissionSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Setelah mengaktifkan izin "Izinkan dari sumber ini", kembali ke aplikasi untuk melanjutkan instalasi.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _onDismiss() {
    if (!widget.updateInfo.isMandatory) {
      _updateService.snoozeUpdate(widget.updateInfo.latestBuild);
      widget.onDismissed?.call();
      Navigator.of(context).pop();
    }
  }

  String _formatVersionString(String version) {
    final trimmed = version.trim();
    if (trimmed.isEmpty) return 'v1.0.0';
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed;
    }
    return 'v$trimmed';
  }

  List<String> _parseReleaseNotes(String? rawNotes) {
    if (rawNotes == null || rawNotes.trim().isEmpty) {
      return [];
    }
    final lines = rawNotes
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final cleaned = <String>[];
    for (var line in lines) {
      line = line.replaceFirst(RegExp(r'^[-*•]\s*'), '');
      line = line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
      if (line.trim().isNotEmpty) {
        cleaned.add(line.trim());
      }
    }
    if (cleaned.isEmpty && rawNotes.trim().isNotEmpty) {
      cleaned.add(rawNotes.trim());
    }
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.updateInfo.isMandatory;
    final isDark = ThemeService().isDarkMode;
    final primaryAccent = isMandatory ? AppTheme.error : AppTheme.accent;
    final releaseNotes = _parseReleaseNotes(widget.updateInfo.releaseNotes);

    final String displayCurrentVersion = _formatVersionString(
      _currentVersion.isNotEmpty
          ? _currentVersion
          : (widget.updateInfo.currentBuild > 0 ? '1.0.0' : '-'),
    );
    final String displayLatestVersion = _formatVersionString(widget.updateInfo.latestVersion);

    return PopScope(
      canPop: !isMandatory && !_isDownloading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !widget.updateInfo.isMandatory) {
          _updateService.snoozeUpdate(widget.updateInfo.latestBuild);
          widget.onDismissed?.call();
        }
      },
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 390),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Icon inside Circular Outline with Soft Blue Accent
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isMandatory
                            ? AppTheme.errorContainer
                            : primaryAccent.withValues(alpha: 0.10),
                        border: Border.all(
                          color: isMandatory
                              ? AppTheme.errorBorder
                              : primaryAccent.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _downloadedFile != null &&
                                _downloadedFile!.existsSync() &&
                                _errorMessage == null
                            ? Icons.install_mobile_rounded
                            : (isMandatory
                                ? Icons.warning_amber_rounded
                                : Icons.download_rounded),
                        color: primaryAccent,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Title and Description
                  Text(
                    'Update Aplikasi Tersedia',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Versi terbaru SkyRental telah tersedia. Perbarui aplikasi untuk mendapatkan fitur terbaru, peningkatan performa, dan perbaikan bug.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Mandatory Alert Banner (if mandatory)
                  if (isMandatory) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.warningBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.onWarningContainer),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Versi ini wajib dipasang untuk terus menggunakan SKYRental.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onWarningContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 4. Version Comparison Panel
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Left: Current Version
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VERSI SAAT INI',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                displayCurrentVersion,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Center Arrow
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        // Right: Latest Version
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'VERSI TERBARU',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: primaryAccent,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: primaryAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: primaryAccent.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  displayLatestVersion,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.updateInfo.latestBuild > 0 ||
                                  widget.updateInfo.formattedSize.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Build ${widget.updateInfo.latestBuild}${widget.updateInfo.formattedSize.isNotEmpty ? " • ${widget.updateInfo.formattedSize}" : ""}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Release Notes Section
                  if (releaseNotes.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: primaryAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'YANG BARU',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: releaseNotes.map((note) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 13.5,
                                      color: primaryAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 6. Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.errorBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 15, color: AppTheme.error),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.onErrorContainer,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 7. Download Progress Indicator
                  if (_isDownloading) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _progress > 0 ? _progress : null,
                            minHeight: 7,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(primaryAccent),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ] else if (_statusMessage.isNotEmpty) ...[
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 8. Unknown Sources Permission Banner
                  if (_needsPermission) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.infoContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.infoBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Izin Sumber Tidak Dikenal Diperlukan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onInfoContainer,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Android memerlukan izin untuk mengizinkan aplikasi ini memasang berkas APK pembaruan.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.onInfoContainer.withValues(alpha: 0.9),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _requestInstallPermission,
                            icon: const Icon(Icons.settings_rounded, size: 15),
                            label: const Text('Buka Pengaturan Izin', style: TextStyle(fontSize: 11.5)),
                          ),
                          if (_downloadedFile != null) ...[
                            const SizedBox(height: 6),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _launchInstaller(_downloadedFile!.path),
                              child: const Text('Saya Sudah Memberi Izin, Lanjutkan', style: TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 9. Primary Action Button (Perbarui Sekarang / Pasang Sekarang)
                  if (!_isDownloading && !_needsPermission) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _downloadedFile != null &&
                                _downloadedFile!.existsSync() &&
                                _errorMessage == null
                            ? () => _launchInstaller(_downloadedFile!.path)
                            : _startUpdateFlow,
                        icon: Icon(
                          _downloadedFile != null &&
                                  _downloadedFile!.existsSync() &&
                                  _errorMessage == null
                              ? Icons.install_mobile_rounded
                              : Icons.download_rounded,
                          size: 19,
                        ),
                        label: Text(
                          _downloadedFile != null &&
                                  _downloadedFile!.existsSync() &&
                                  _errorMessage == null
                              ? 'Pasang Sekarang'
                              : 'Perbarui Sekarang',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],

                  // 10. Secondary Action Button (Nanti)
                  if (!isMandatory && !_isDownloading && !_needsPermission) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          minimumSize: const Size(80, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _onDismiss,
                        child: Text(
                          'Nanti',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
