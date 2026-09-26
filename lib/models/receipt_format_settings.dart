/// Model pengaturan format resi thermal untuk kustomisasi tampilan struk cetak.
///
/// Memungkinkan pengguna mengubah header, footer, visibilitas field,
/// gaya font nama usaha, dan mode kerapatan struk (eco/compact mode).
class ReceiptFormatSettings {
  // --- Header Toko & Tipografi ---
  final String businessName;
  final String businessTagline;
  final String branchName;
  final bool showHeader;
  final bool showTagline;
  final bool showBranch;

  /// Ukuran font Nama Usaha: 'small' (12pt), 'medium' (14pt), 'large' (18pt / double height), 'extraLarge' (22pt / double height & width)
  final String businessNameFontSize;

  /// Ketebalan font Nama Usaha: 'normal', 'bold', 'extraBold'
  final String businessNameFontWeight;

  /// Perataan Nama Usaha: 'center', 'left'
  final String businessNameAlignment;

  // --- Mode Kerapatan & Penghematan Kertas ---
  /// Mode kerapatan: 'standard' (format lengkap) atau 'compact' (format hemat kertas)
  final String densityMode;

  /// Menghapus baris spasi ekstra antar bagian untuk menghemat kertas
  final bool compactSpacing;

  /// Jumlah baris penggulung kertas sebelum potong (1-4 baris)
  final int feedLines;

  // --- Footer & Kontak ---
  final String footerLine1;
  final String footerLine2;
  final String footerLine3;
  final String contactInfo;
  final bool showFooter;
  final bool showTerms;
  final bool showContactInfo;

  // --- Visibilitas Field Transaksi ---
  final bool showReceiptNumber;
  final bool showAdminName;
  final bool showDateTime;
  final bool showTransactionType;

  // --- Visibilitas Field Pelanggan & Unit ---
  final bool showCustomerName;
  final bool showCustomerPhone;
  final bool showBookingCodeText;
  final bool showUnitName;
  final bool showSerialNumber;
  final bool showAssetCode;
  final bool showRentalDuration;
  final bool showRentalDates;

  // --- Visibilitas Biaya & Pembayaran ---
  final bool showRentFee;
  final bool showDeposit;
  final bool showDiscount;
  final bool showPaymentMethod;
  final bool showPaymentStatus;
  final bool showCashDetails;
  final bool showNotes;

  // --- Barcode & QR Code ---
  final bool showBarcode;
  final String barcodeType; // 'code128', 'qrcode', 'both'
  final bool showBarcodeHri;

  /// Ukuran barcode: 'small' (tinggi 40px), 'medium' (tinggi 64px), 'large' (tinggi 80px)
  final String barcodeSize;

  // --- Gaya Garis Pemisah ---
  final String separatorChar;
  final String subSeparatorChar;

  const ReceiptFormatSettings({
    this.businessName = 'SKYRENTAL',
    this.businessTagline = 'Sewa iPhone Terpercaya',
    this.branchName = 'SKYRENTAL YOGYAKARTA',
    this.showHeader = true,
    this.showTagline = true,
    this.showBranch = true,
    this.businessNameFontSize = 'large',
    this.businessNameFontWeight = 'bold',
    this.businessNameAlignment = 'center',
    this.densityMode = 'standard',
    this.compactSpacing = false,
    this.feedLines = 2,
    this.footerLine1 = 'Syarat & Ketentuan Berlaku',
    this.footerLine2 = 'Harap simpan struk ini sebagai',
    this.footerLine3 = 'bukti transaksi yang sah.',
    this.contactInfo = 'CS: 0812-3456-7890 (WA)',
    this.showFooter = true,
    this.showTerms = true,
    this.showContactInfo = true,
    this.showReceiptNumber = true,
    this.showAdminName = true,
    this.showDateTime = true,
    this.showTransactionType = true,
    this.showCustomerName = true,
    this.showCustomerPhone = true,
    this.showBookingCodeText = true,
    this.showUnitName = true,
    this.showSerialNumber = true,
    this.showAssetCode = true,
    this.showRentalDuration = true,
    this.showRentalDates = true,
    this.showRentFee = true,
    this.showDeposit = true,
    this.showDiscount = true,
    this.showPaymentMethod = true,
    this.showPaymentStatus = true,
    this.showCashDetails = true,
    this.showNotes = true,
    this.showBarcode = true,
    this.barcodeType = 'code128',
    this.showBarcodeHri = true,
    this.barcodeSize = 'medium',
    this.separatorChar = '=',
    this.subSeparatorChar = '-',
  });

  /// Pengaturan standar bawaan pabrik (Full / Standard Mode)
  factory ReceiptFormatSettings.defaultSettings() =>
      const ReceiptFormatSettings();

  /// Preset Mode Hemat Kertas (Compact / Eco Mode)
  /// Menghemat hingga ~50% panjang kertas thermal dengan memadatkan baris & mematikan field non-kritis.
  factory ReceiptFormatSettings.compactSettings() => const ReceiptFormatSettings(
        densityMode: 'compact',
        compactSpacing: true,
        businessNameFontSize: 'medium',
        businessNameFontWeight: 'bold',
        businessNameAlignment: 'center',
        showTagline: false,
        showBranch: true,
        showTerms: false,
        showContactInfo: true,
        showReceiptNumber: true,
        showAdminName: false,
        showDateTime: true,
        showTransactionType: false,
        showCustomerName: true,
        showCustomerPhone: true,
        showBookingCodeText: true,
        showUnitName: true,
        showSerialNumber: false,
        showAssetCode: false,
        showRentalDuration: true,
        showRentalDates: false,
        showRentFee: true,
        showDeposit: true,
        showDiscount: true,
        showPaymentMethod: true,
        showPaymentStatus: true,
        showCashDetails: false,
        showNotes: false,
        showBarcode: true,
        barcodeType: 'qrcode', // QR Code jauh lebih hemat kertas vertikal daripada 1D barcode
        showBarcodeHri: false,
        barcodeSize: 'small',
        feedLines: 1,
      );

  ReceiptFormatSettings copyWith({
    String? businessName,
    String? businessTagline,
    String? branchName,
    bool? showHeader,
    bool? showTagline,
    bool? showBranch,
    String? businessNameFontSize,
    String? businessNameFontWeight,
    String? businessNameAlignment,
    String? densityMode,
    bool? compactSpacing,
    int? feedLines,
    String? footerLine1,
    String? footerLine2,
    String? footerLine3,
    String? contactInfo,
    bool? showFooter,
    bool? showTerms,
    bool? showContactInfo,
    bool? showReceiptNumber,
    bool? showAdminName,
    bool? showDateTime,
    bool? showTransactionType,
    bool? showCustomerName,
    bool? showCustomerPhone,
    bool? showBookingCodeText,
    bool? showUnitName,
    bool? showSerialNumber,
    bool? showAssetCode,
    bool? showRentalDuration,
    bool? showRentalDates,
    bool? showRentFee,
    bool? showDeposit,
    bool? showDiscount,
    bool? showPaymentMethod,
    bool? showPaymentStatus,
    bool? showCashDetails,
    bool? showNotes,
    bool? showBarcode,
    String? barcodeType,
    bool? showBarcodeHri,
    String? barcodeSize,
    String? separatorChar,
    String? subSeparatorChar,
  }) {
    return ReceiptFormatSettings(
      businessName: businessName ?? this.businessName,
      businessTagline: businessTagline ?? this.businessTagline,
      branchName: branchName ?? this.branchName,
      showHeader: showHeader ?? this.showHeader,
      showTagline: showTagline ?? this.showTagline,
      showBranch: showBranch ?? this.showBranch,
      businessNameFontSize: businessNameFontSize ?? this.businessNameFontSize,
      businessNameFontWeight:
          businessNameFontWeight ?? this.businessNameFontWeight,
      businessNameAlignment:
          businessNameAlignment ?? this.businessNameAlignment,
      densityMode: densityMode ?? this.densityMode,
      compactSpacing: compactSpacing ?? this.compactSpacing,
      feedLines: feedLines ?? this.feedLines,
      footerLine1: footerLine1 ?? this.footerLine1,
      footerLine2: footerLine2 ?? this.footerLine2,
      footerLine3: footerLine3 ?? this.footerLine3,
      contactInfo: contactInfo ?? this.contactInfo,
      showFooter: showFooter ?? this.showFooter,
      showTerms: showTerms ?? this.showTerms,
      showContactInfo: showContactInfo ?? this.showContactInfo,
      showReceiptNumber: showReceiptNumber ?? this.showReceiptNumber,
      showAdminName: showAdminName ?? this.showAdminName,
      showDateTime: showDateTime ?? this.showDateTime,
      showTransactionType: showTransactionType ?? this.showTransactionType,
      showCustomerName: showCustomerName ?? this.showCustomerName,
      showCustomerPhone: showCustomerPhone ?? this.showCustomerPhone,
      showBookingCodeText: showBookingCodeText ?? this.showBookingCodeText,
      showUnitName: showUnitName ?? this.showUnitName,
      showSerialNumber: showSerialNumber ?? this.showSerialNumber,
      showAssetCode: showAssetCode ?? this.showAssetCode,
      showRentalDuration: showRentalDuration ?? this.showRentalDuration,
      showRentalDates: showRentalDates ?? this.showRentalDates,
      showRentFee: showRentFee ?? this.showRentFee,
      showDeposit: showDeposit ?? this.showDeposit,
      showDiscount: showDiscount ?? this.showDiscount,
      showPaymentMethod: showPaymentMethod ?? this.showPaymentMethod,
      showPaymentStatus: showPaymentStatus ?? this.showPaymentStatus,
      showCashDetails: showCashDetails ?? this.showCashDetails,
      showNotes: showNotes ?? this.showNotes,
      showBarcode: showBarcode ?? this.showBarcode,
      barcodeType: barcodeType ?? this.barcodeType,
      showBarcodeHri: showBarcodeHri ?? this.showBarcodeHri,
      barcodeSize: barcodeSize ?? this.barcodeSize,
      separatorChar: separatorChar ?? this.separatorChar,
      subSeparatorChar: subSeparatorChar ?? this.subSeparatorChar,
    );
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'businessTagline': businessTagline,
        'branchName': branchName,
        'showHeader': showHeader,
        'showTagline': showTagline,
        'showBranch': showBranch,
        'businessNameFontSize': businessNameFontSize,
        'businessNameFontWeight': businessNameFontWeight,
        'businessNameAlignment': businessNameAlignment,
        'densityMode': densityMode,
        'compactSpacing': compactSpacing,
        'feedLines': feedLines,
        'footerLine1': footerLine1,
        'footerLine2': footerLine2,
        'footerLine3': footerLine3,
        'contactInfo': contactInfo,
        'showFooter': showFooter,
        'showTerms': showTerms,
        'showContactInfo': showContactInfo,
        'showReceiptNumber': showReceiptNumber,
        'showAdminName': showAdminName,
        'showDateTime': showDateTime,
        'showTransactionType': showTransactionType,
        'showCustomerName': showCustomerName,
        'showCustomerPhone': showCustomerPhone,
        'showBookingCodeText': showBookingCodeText,
        'showUnitName': showUnitName,
        'showSerialNumber': showSerialNumber,
        'showAssetCode': showAssetCode,
        'showRentalDuration': showRentalDuration,
        'showRentalDates': showRentalDates,
        'showRentFee': showRentFee,
        'showDeposit': showDeposit,
        'showDiscount': showDiscount,
        'showPaymentMethod': showPaymentMethod,
        'showPaymentStatus': showPaymentStatus,
        'showCashDetails': showCashDetails,
        'showNotes': showNotes,
        'showBarcode': showBarcode,
        'barcodeType': barcodeType,
        'showBarcodeHri': showBarcodeHri,
        'barcodeSize': barcodeSize,
        'separatorChar': separatorChar,
        'subSeparatorChar': subSeparatorChar,
      };

  factory ReceiptFormatSettings.fromJson(Map<String, dynamic> json) =>
      ReceiptFormatSettings(
        businessName: json['businessName'] as String? ?? 'SKYRENTAL',
        businessTagline:
            json['businessTagline'] as String? ?? 'Sewa iPhone Terpercaya',
        branchName:
            json['branchName'] as String? ?? 'SKYRENTAL YOGYAKARTA',
        showHeader: json['showHeader'] as bool? ?? true,
        showTagline: json['showTagline'] as bool? ?? true,
        showBranch: json['showBranch'] as bool? ?? true,
        businessNameFontSize:
            json['businessNameFontSize'] as String? ?? 'large',
        businessNameFontWeight:
            json['businessNameFontWeight'] as String? ?? 'bold',
        businessNameAlignment:
            json['businessNameAlignment'] as String? ?? 'center',
        densityMode: json['densityMode'] as String? ?? 'standard',
        compactSpacing: json['compactSpacing'] as bool? ?? false,
        feedLines: json['feedLines'] as int? ?? 2,
        footerLine1:
            json['footerLine1'] as String? ?? 'Syarat & Ketentuan Berlaku',
        footerLine2: json['footerLine2'] as String? ??
            'Harap simpan struk ini sebagai',
        footerLine3:
            json['footerLine3'] as String? ?? 'bukti transaksi yang sah.',
        contactInfo:
            json['contactInfo'] as String? ?? 'CS: 0812-3456-7890 (WA)',
        showFooter: json['showFooter'] as bool? ?? true,
        showTerms: json['showTerms'] as bool? ?? true,
        showContactInfo: json['showContactInfo'] as bool? ?? true,
        showReceiptNumber: json['showReceiptNumber'] as bool? ?? true,
        showAdminName: json['showAdminName'] as bool? ?? true,
        showDateTime: json['showDateTime'] as bool? ?? true,
        showTransactionType: json['showTransactionType'] as bool? ?? true,
        showCustomerName: json['showCustomerName'] as bool? ?? true,
        showCustomerPhone: json['showCustomerPhone'] as bool? ?? true,
        showBookingCodeText: json['showBookingCodeText'] as bool? ?? true,
        showUnitName: json['showUnitName'] as bool? ?? true,
        showSerialNumber: json['showSerialNumber'] as bool? ?? true,
        showAssetCode: json['showAssetCode'] as bool? ?? true,
        showRentalDuration: json['showRentalDuration'] as bool? ?? true,
        showRentalDates: json['showRentalDates'] as bool? ?? true,
        showRentFee: json['showRentFee'] as bool? ?? true,
        showDeposit: json['showDeposit'] as bool? ?? true,
        showDiscount: json['showDiscount'] as bool? ?? true,
        showPaymentMethod: json['showPaymentMethod'] as bool? ?? true,
        showPaymentStatus: json['showPaymentStatus'] as bool? ?? true,
        showCashDetails: json['showCashDetails'] as bool? ?? true,
        showNotes: json['showNotes'] as bool? ?? true,
        showBarcode: json['showBarcode'] as bool? ?? true,
        barcodeType: json['barcodeType'] as String? ?? 'code128',
        showBarcodeHri: json['showBarcodeHri'] as bool? ?? true,
        barcodeSize: json['barcodeSize'] as String? ?? 'medium',
        separatorChar: json['separatorChar'] as String? ?? '=',
        subSeparatorChar: json['subSeparatorChar'] as String? ?? '-',
      );
}
