import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../../data/mock_receipt_data.dart';
import '../../../models/receipt_format_settings.dart';
import '../../../models/receipt_model.dart';
import '../../../theme/app_theme.dart';

/// Reusable simulated thermal receipt paper widget.
/// Renders standard ESC/POS 58mm receipt (32 characters per line) matching the
/// thermal printer settings and ReceiptFormatSettingsScreen layout.
class ThermalReceiptPaperPreview extends StatelessWidget {
  final ReceiptFormatSettings? formatSettings;
  final String? shopName;
  final String? outletName;
  final String? address;
  final String? phoneNumber;
  final String? footerNote;
  final ReceiptModel? receipt;
  final double width;
  final double? maxHeight;
  final bool showHeaderBadge;

  const ThermalReceiptPaperPreview({
    super.key,
    this.formatSettings,
    this.shopName,
    this.outletName,
    this.address,
    this.phoneNumber,
    this.footerNote,
    this.receipt,
    this.width = 320,
    this.maxHeight,
    this.showHeaderBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseFormat = formatSettings ?? const ReceiptFormatSettings();

    final footerLines = (footerNote != null && footerNote!.trim().isNotEmpty)
        ? _wrapText(footerNote!.trim(), 32)
        : <String>[];

    // Dynamically override store identity and footer with live inputs
    final effectiveFormat = baseFormat.copyWith(
      businessName: (shopName != null && shopName!.trim().isNotEmpty)
          ? shopName!.trim()
          : baseFormat.businessName,
      branchName: (outletName != null && outletName!.trim().isNotEmpty)
          ? outletName!.trim()
          : baseFormat.branchName,
      businessTagline: (address != null && address!.trim().isNotEmpty)
          ? address!.trim()
          : baseFormat.businessTagline,
      contactInfo: (phoneNumber != null && phoneNumber!.trim().isNotEmpty)
          ? 'CS: ${phoneNumber!.trim()} (WA)'
          : baseFormat.contactInfo,
      footerLine1: footerLines.isNotEmpty ? footerLines[0] : baseFormat.footerLine1,
      footerLine2: footerLines.length > 1
          ? footerLines[1]
          : (footerLines.isNotEmpty ? '' : baseFormat.footerLine2),
      footerLine3: footerLines.length > 2
          ? footerLines[2]
          : (footerLines.isNotEmpty ? '' : baseFormat.footerLine3),
    );

    final currentReceipt =
        receipt ?? (MockReceiptData.items.isNotEmpty ? MockReceiptData.items[0] : null);

    if (currentReceipt == null) {
      return const SizedBox.shrink();
    }

    final receiptText = currentReceipt.toEscPos58mm(formatSettings: effectiveFormat);
    final estCm = ReceiptModel.estimatePaperLengthCm(receiptText, effectiveFormat);
    final hasBarcodeTag = receiptText.contains(RegExp(r'\[BARCODE:.*?\]'));

    const monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 9.5,
      height: 1.35,
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
      final storeNameText = match.group(4) ?? '';
      final after = text.substring(match.end);

      double titleFontSize = 13.5;
      if (size == 'small') titleFontSize = 10.5;
      if (size == 'medium') titleFontSize = 12;
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
              storeNameText,
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

    Widget buildBarcodePreview(String code) {
      final type = effectiveFormat.barcodeType;
      final size = effectiveFormat.barcodeSize;
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
                drawText: effectiveFormat.showBarcodeHri,
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

    Widget previewBody;
    if (hasBarcodeTag && effectiveFormat.showBarcode) {
      final parts = receiptText.split(RegExp(r'\[BARCODE:.*?\]\n?'));
      final bookingCode = currentReceipt.bookingCode;
      previewBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPreviewSegment(parts[0]),
          buildBarcodePreview(bookingCode),
          if (parts.length > 1) buildPreviewSegment(parts[1]),
        ],
      );
    } else {
      final cleanText =
          receiptText.replaceAll(RegExp(r'\[BARCODE:.*?\]\n?'), '');
      previewBody = buildPreviewSegment(cleanText);
    }

    final paperWidget = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          previewBody,
          const SizedBox(height: 12),
          Text(
            '— Lebar Kertas Standar VSC MP-58C (32 Karakter Monospace) —',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );

    final scrollablePaper = maxHeight != null
        ? Container(
            constraints: BoxConstraints(maxHeight: maxHeight!),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(child: paperWidget),
            ),
          )
        : Center(child: paperWidget);

    if (!showHeaderBadge) {
      return scrollablePaper;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'PRATINJAU KERTAS THERMAL 58MM (LIVE RECEIPT PREVIEW)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '58mm Thermal Print Mode • ~$estCm cm',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        scrollablePaper,
      ],
    );
  }

  static List<String> _wrapText(String text, int maxWidth) {
    if (text.isEmpty) return [];
    final lines = <String>[];
    for (final rawLine in text.split('\n')) {
      if (rawLine.length <= maxWidth) {
        lines.add(rawLine);
      } else {
        final words = rawLine.split(' ');
        var current = '';
        for (final word in words) {
          if (word.length > maxWidth) {
            if (current.isNotEmpty) {
              lines.add(current);
              current = '';
            }
            var rem = word;
            while (rem.length > maxWidth) {
              lines.add(rem.substring(0, maxWidth));
              rem = rem.substring(maxWidth);
            }
            current = rem;
          } else if (current.isEmpty) {
            current = word;
          } else if (current.length + 1 + word.length <= maxWidth) {
            current = '$current $word';
          } else {
            lines.add(current);
            current = word;
          }
        }
        if (current.isNotEmpty) {
          lines.add(current);
        }
      }
    }
    return lines;
  }
}
