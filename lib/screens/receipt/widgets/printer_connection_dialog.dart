import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class PrinterConnectionDialog {
  /// Scenario A: No printer is configured
  static Future<void> showNoPrinter(
    BuildContext context, {
    required VoidCallback onConnectPrinter,
    required VoidCallback onPrintLater,
    VoidCallback? onContinueWithoutPrinting,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.print_disabled_rounded,
                color: Color(0xFFD97706),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Printer Not Connected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No receipt printer has been connected. Connect a printer to print the booking receipt.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          if (onContinueWithoutPrinting != null)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                onContinueWithoutPrinting();
              },
              child: const Text('Continue without printing'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onPrintLater();
            },
            child: const Text('Print Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onConnectPrinter();
            },
            icon: const Icon(Icons.bluetooth_searching_rounded, size: 16),
            label: const Text('Connect Printer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Scenario B: A printer connection attempt fails or timed out
  static Future<void> showConnectionFailed(
    BuildContext context, {
    String? failureMessage,
    required VoidCallback onTryAgain,
    required VoidCallback onChooseAnotherPrinter,
    required VoidCallback onPrintLater,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_off_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Unable to Connect to Printer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The printer could not be connected. Check that the printer is powered on, nearby, and available, then try again.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            if (failureMessage != null &&
                failureMessage.isNotEmpty &&
                failureMessage != 'The printer could not be connected. Check that the printer is powered on, nearby, and available, then try again.') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        failureMessage,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onPrintLater();
            },
            child: const Text('Print Later'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onChooseAnotherPrinter();
            },
            child: const Text('Choose Another Printer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onTryAgain();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Scenario D: Printer disconnects or printing fails during transmission
  static Future<void> showPrintingFailed(
    BuildContext context, {
    required String failureMessage,
    required VoidCallback onTryAgain,
    required VoidCallback onReconnect,
    required VoidCallback onPrintLater,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Printing Failed',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failureMessage.isNotEmpty ? failureMessage : 'Gagal mencetak resi transaksi.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onPrintLater();
            },
            child: const Text('Print Later'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onReconnect();
            },
            child: const Text('Reconnect'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              onTryAgain();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Loading dialog during printer connection or transmission
  static Future<void> showLoading(
    BuildContext context, {
    String message = 'Menghubungkan ke printer...',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
