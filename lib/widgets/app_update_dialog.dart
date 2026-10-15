import 'dart:io';
import 'package:flutter/material.dart';

import '../models/app_update_model.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback? onDismissed;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    this.onDismissed,
  });

  static bool _isShowing = false;
  static bool get isShowing => _isShowing;

  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo, {
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
        builder: (ctx) => AppUpdateDialog(
          updateInfo: updateInfo,
          onDismissed: onDismissed,
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

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.updateInfo.isMandatory;

    return PopScope(
      canPop: !isMandatory && !_isDownloading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !widget.updateInfo.isMandatory) {
          _updateService.snoozeUpdate(widget.updateInfo.latestBuild);
          widget.onDismissed?.call();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: AppTheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon and Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isMandatory
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isMandatory
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFBFDBFE),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      isMandatory
                          ? Icons.warning_amber_rounded
                          : Icons.system_update_rounded,
                      color: isMandatory
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2563EB),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isMandatory ? 'Pembaruan Wajib' : 'Pembaruan Tersedia',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isMandatory
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v${widget.updateInfo.latestVersion}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isMandatory
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Build ${widget.updateInfo.latestBuild} • ${widget.updateInfo.formattedSize}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Mandatory Alert Banner
              if (isMandatory) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Versi ini wajib dipasang untuk terus menggunakan SKYRental.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Release Notes Container
              if (widget.updateInfo.releaseNotes != null &&
                  widget.updateInfo.releaseNotes!.trim().isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catatan Rilis:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.updateInfo.releaseNotes!.trim(),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error Box
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF991B1B),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Download / Progress Section
              if (_isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMandatory ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else if (_statusMessage.isNotEmpty) ...[
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Permission Request Banner (if install unknown apps not enabled)
              if (_needsPermission) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Izin Sumber Tidak Dikenal Diperlukan',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Android memerlukan izin untuk mengizinkan aplikasi ini memasang berkas APK pembaruan.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF1E3A8A),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _requestInstallPermission,
                        icon: const Icon(Icons.settings_rounded, size: 16),
                        label: const Text('Buka Pengaturan Izin', style: TextStyle(fontSize: 12)),
                      ),
                      if (_downloadedFile != null) ...[
                        const SizedBox(height: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () => _launchInstaller(_downloadedFile!.path),
                          child: const Text('Saya Sudah Memberi Izin, Lanjutkan', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Dialog Action Buttons
              if (!_isDownloading && !_needsPermission)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isMandatory) ...[
                      TextButton(
                        onPressed: _onDismiss,
                        child: Text(
                          'Nanti Saja',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isMandatory)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
                            size: 18,
                          ),
                          label: Text(
                            _downloadedFile != null &&
                                    _downloadedFile!.existsSync() &&
                                    _errorMessage == null
                                ? 'Pasang Sekarang'
                                : 'Perbarui Sekarang',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
                            size: 18,
                          ),
                          label: Text(
                            _downloadedFile != null &&
                                    _downloadedFile!.existsSync() &&
                                    _errorMessage == null
                                ? 'Pasang Sekarang'
                                : 'Perbarui Sekarang',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
