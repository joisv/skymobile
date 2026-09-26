import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/booking_repository.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  final BookingRepository repository;
  final MobileScannerController? controller;

  const QrScannerScreen({
    super.key,
    required this.repository,
    this.controller,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late final MobileScannerController _scannerController;
  bool _isFlashOn = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _scannerController = widget.controller ??
        MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          facing: CameraFacing.back,
          torchEnabled: false,
        );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (widget.controller == null) {
      _scannerController.dispose();
    }
    super.dispose();
  }

  void _toggleFlash() async {
    try {
      await _scannerController.toggleTorch();
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (_) {
      setState(() => _isFlashOn = !_isFlashOn);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFlashOn ? 'Lampu kilat aktif' : 'Lampu kilat nonaktif'),
          duration: const Duration(milliseconds: 700),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _switchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (_) {}
  }

  void _onCodeDetected(String rawCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Normalize code (handle URLs like https://skyrental.id/booking/SKY260909A8F1)
    String cleanCode = rawCode.trim();
    if (cleanCode.contains('/')) {
      cleanCode = cleanCode.split('/').last;
    }

    HapticFeedback.mediumImpact();

    final booking = await widget.repository.getBookingByCode(cleanCode);

    if (!mounted) return;

    if (booking != null) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.bookingDetail,
        arguments: booking,
      );
    } else {
      setState(() => _isProcessing = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Booking Tidak Ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Kode "$cleanCode" tidak terdaftar di sistem SKYRental. Pastikan barcode/QR struk valid atau masukkan kode secara manual.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Pindai Ulang'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showManualInputDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Input Manual'),
            ),
          ],
        ),
      );
    }
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan Kode Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Contoh: SKY260909A8F1',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = textController.text.trim();
              Navigator.pop(ctx);
              if (code.isNotEmpty) {
                _onCodeDetected(code);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cari'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pindai Barcode / QR Booking'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: 'Lampu Kilat',
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            tooltip: 'Ganti Kamera',
            onPressed: _switchCamera,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_rounded),
            tooltip: 'Input Manual',
            onPressed: _showManualInputDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Live Camera Barcode / QR Scanner
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (BarcodeCapture capture) {
                if (_isProcessing) return;
                for (final barcode in capture.barcodes) {
                  final code = barcode.rawValue ?? barcode.displayValue;
                  if (code != null && code.trim().isNotEmpty) {
                    _onCodeDetected(code);
                    break;
                  }
                }
              },
              errorBuilder: (context, error) {
                return Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white38),
                      const SizedBox(height: 12),
                      Text(
                        'Kamera tidak aktif (${error.errorCode.name}).\nSilakan gunakan simulasi scan atau input manual di bawah.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 2. Viewfinder Overlay
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Arahkan kamera ke Barcode / QR Struk Pelanggan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Viewfinder Box (Dimensions tailored to both 1D Barcode & 2D QR)
                SizedBox(
                  width: 280,
                  height: 220,
                  child: Stack(
                    children: [
                      // Outer Border Brackets
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.8),
                            width: 2,
                          ),
                        ),
                      ),

                      // Animated Laser Scan Line
                      AnimatedBuilder(
                        animation: _scanLineAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: _scanLineAnimation.value * 200 + 10,
                            left: 12,
                            right: 12,
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Center QR / Barcode Watermark Icon
                      Center(
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 76,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Mendukung Barcode 1D (Code 128) & QR Code',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),

                const SizedBox(height: 20),
                if (_isProcessing)
                  Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.accent),
                      const SizedBox(height: 12),
                      const Text(
                        'Memverifikasi kode booking...',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: Icon(Icons.edit_note_rounded, color: AppTheme.accent),
                    label: Text(
                      'Tidak bisa scan? Input kode manual',
                      style: TextStyle(color: AppTheme.accent, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Sheet Simulation Bar (Allows 1-tap testing in Dev/Mock Mode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(color: Colors.white12),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                        Icon(Icons.touch_app_rounded, size: 15, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        const Text(
                          'Simulasi Scan Cepat (Data Mock):',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMockScanChip('SKY260909A8F1', 'Ahmad (Confirmed/Pickup)'),
                          const SizedBox(width: 8),
                          _buildMockScanChip('SKY260908C4D5', 'Kevin (Rented/Return)'),
                          const SizedBox(width: 8),
                          _buildMockScanChip('SKY260909B2C3', 'Siti (DP 50%)'),
                          const SizedBox(width: 8),
                          _buildMockScanChip('INVALID-CODE', 'Kode Salah (Test Error)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockScanChip(String code, String label) {
    return InkWell(
      onTap: () => _onCodeDetected(code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
