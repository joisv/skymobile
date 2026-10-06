import 'package:flutter/material.dart';
import '../data/booking_repository.dart';
import '../models/affiliate_model.dart';
import '../models/booking_model.dart';
import '../models/iphone_model.dart';
import '../models/payment_model.dart';
import '../models/receipt_model.dart';
import '../screens/account/account_screen.dart';
import '../screens/account/change_password_screen.dart';
import '../screens/account/roles_permissions_screen.dart';
import '../screens/account/shop_settings_screen.dart';
import '../screens/account/theme_settings_screen.dart';
import '../screens/affiliate/affiliate_detail_screen.dart';
import '../screens/affiliate/affiliate_form_screen.dart';
import '../screens/affiliate/affiliate_list_screen.dart';
import '../screens/affiliate/affiliate_revenue_screen.dart';
import '../screens/affiliate/iphone_transfer_list_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/booking/booking_detail_screen.dart';
import '../screens/booking/booking_list_screen.dart';
import '../screens/booking/create_booking_screen.dart';
import '../screens/dashboard/notification_list_screen.dart';
import '../screens/dashboard/sales_report_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/payment/deposit_refund_screen.dart';
import '../screens/payment/deposit_status_screen.dart';
import '../screens/payment/payment_deposit_screen.dart';
import '../screens/payment/payment_history_screen.dart';
import '../screens/payment/rental_payment_screen.dart';
import '../screens/pickup/booking_verification_screen.dart';
import '../screens/pickup/pickup_screen.dart';
import '../screens/pickup/pickup_success_screen.dart';
import '../screens/pickup/unit_selection_screen.dart';
import '../screens/receipt/printer_settings_screen.dart';
import '../screens/receipt/receipt_format_settings_screen.dart';
import '../screens/receipt/receipt_screen.dart';
import '../screens/receipt/reprint_receipt_list_screen.dart';
import '../screens/return/return_screen.dart';
import '../screens/return/return_success_screen.dart';
import '../screens/return/return_summary_screen.dart';
import '../screens/scanner/qr_scanner_screen.dart';
import '../screens/unit_status/unit_schedule_screen.dart';
import '../screens/unit_status/unit_status_list_screen.dart';
import '../services/auth_service.dart';

class AppRoutes {
  static const String mainNavigation = '/';
  static const String bookingList = '/booking-list';
  static const String createBooking = '/bookings/create';
  static const String bookingDetail = '/booking-detail';
  static const String qrScanner = '/qr-scanner';
  static const String pickup = '/pickup';
  static const String bookingVerification = '/booking-verification';
  static const String unitSelection = '/unit-selection';
  static const String pickupSuccess = '/pickup-success';
  static const String paymentDeposit = '/payment-deposit';
  static const String rentalPayment = '/rental-payment';
  static const String depositStatus = '/deposit-status';
  static const String depositRefund = '/deposit-refund';
  static const String paymentHistory = '/payment-history';
  static const String receiptPreview = '/receipt-preview';
  static const String reprintReceiptList = '/reprint-receipt-list';
  static const String printerSettings = '/printer-settings';
  static const String receiptFormatSettings = '/receipt-format-settings';
  static const String returnScreen = '/return';
  static const String returnSummary = '/return-summary';
  static const String returnInspection = '/return-inspection';
  static const String returnSuccess = '/return-success';
  static const String unitStatus = '/unit-status';
  static const String unitSchedule = '/unit-schedule';
  static const String dashboard = '/dashboard';
  static const String salesReport = '/sales-report';
  static const String notifications = '/notifications';
  static const String account = '/account';
  static const String changePassword = '/change-password';
  static const String shopSettings = '/shop-settings';
  static const String rolesPermissions = '/admin/roles-permissions';
  static const String login = '/login';
  static const String affiliateList = '/affiliates';
  static const String affiliateDetail = '/affiliates/detail';
  static const String affiliateForm = '/affiliates/form';
  static const String iphoneTransfer = '/affiliates/transfers';
  static const String affiliateTransferIphone = '/affiliate/transfer-iphone';
  static const String affiliateRevenue = '/affiliates/revenue';
  static const String themeSettings = '/theme-settings';

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
    BookingRepository repository, {
    AuthService? authService,
  }) {
    final auth = authService ?? AuthService();

    // Route Protection Guard:
    // If not authenticated and attempting to access a protected route, redirect to login
    if (settings.name != login) {
      if (!auth.isAuthenticated) {
        return MaterialPageRoute(
          builder: (_) => LoginScreen(repository: repository),
          settings: const RouteSettings(name: login),
        );
      }
      if (!auth.canAccessRoute(settings.name ?? '')) {
        return _errorRoute('Akses ditolak: Menu ini hanya dapat diakses oleh akun Super Admin.');
      }
    }

    switch (settings.name) {
      case mainNavigation:
        final initialIndex = settings.arguments is int ? settings.arguments as int : 0;
        return MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            repository: repository,
            initialIndex: initialIndex,
          ),
          settings: settings,
        );

      case bookingList:
      case '/bookings':
        return MaterialPageRoute(
          builder: (_) => BookingListScreen(repository: repository),
          settings: settings,
        );

      case createBooking:
      case '/create-booking':
        return MaterialPageRoute(
          builder: (_) => CreateBookingScreen(repository: repository),
          settings: settings,
        );

      case qrScanner:
        return MaterialPageRoute(
          builder: (_) => QrScannerScreen(repository: repository),
          settings: settings,
        );

      case pickup:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => PickupScreen(booking: booking),
            settings: settings,
          );
        } else if (settings.arguments is String) {
          final bookingCode = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => FutureBuilder<BookingModel?>(
              future: repository.getBookingByCode(bookingCode),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Alur Pickup')),
                    body: Center(
                      child: Text('Booking dengan kode $bookingCode tidak ditemukan'),
                    ),
                  );
                }
                return PickupScreen(booking: snapshot.data!);
              },
            ),
            settings: settings,
          );
        }
        return _errorRoute('Argumen booking untuk pickup tidak valid.');

      case bookingVerification:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => BookingVerificationScreen(
              initialBooking: booking,
              repository: repository,
            ),
            settings: settings,
          );
        } else if (settings.arguments is String) {
          final bookingCode = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => FutureBuilder<BookingModel?>(
              future: repository.getBookingByCode(bookingCode),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return BookingVerificationScreen(
                  initialBooking: snapshot.data,
                  repository: repository,
                );
              },
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => BookingVerificationScreen(repository: repository),
          settings: settings,
        );

      case unitSelection:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => UnitSelectionScreen(
              booking: booking,
              currentSelectedUnit: booking.iphone,
              repository: repository,
            ),
            settings: settings,
          );
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => UnitSelectionScreen(
              booking: args['booking'] as BookingModel?,
              currentSelectedUnit: args['currentSelectedUnit'] as IphoneModel?,
              repository: repository,
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => UnitSelectionScreen(repository: repository),
          settings: settings,
        );

      case pickupSuccess:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => PickupSuccessScreen(booking: booking),
            settings: settings,
          );
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => PickupSuccessScreen(
              booking: args['booking'] as BookingModel,
              assignedIphone: args['iphone'] as IphoneModel?,
              paymentMethod: args['paymentMethod'] as String? ?? 'QRIS',
              staffNotes: args['notes'] as String?,
            ),
            settings: settings,
          );
        }
        return _errorRoute('Data booking untuk layar sukses pickup tidak valid.');

      case paymentDeposit:
        BookingModel? booking;
        PaymentTypeOption? initialPaymentType;
        double? initialAmount;
        bool isReturnFlow = false;
        int? extendHours;

        if (settings.arguments is BookingModel) {
          booking = settings.arguments as BookingModel;
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          booking = args['booking'] as BookingModel?;
          initialPaymentType = args['initialPaymentType'] as PaymentTypeOption?;
          initialAmount = (args['initialAmount'] as num?)?.toDouble();
          isReturnFlow = args['isReturnFlow'] as bool? ?? false;
          extendHours = args['extendHours'] as int?;
        }

        return MaterialPageRoute(
          builder: (_) => PaymentDepositScreen(
            repository: repository,
            booking: booking,
            initialPaymentType: initialPaymentType,
            initialAmount: initialAmount,
            isReturnFlow: isReturnFlow,
            extendHours: extendHours,
          ),
          settings: settings,
        );

      case rentalPayment:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => RentalPaymentScreen(
              booking: booking,
              repository: repository,
            ),
            settings: settings,
          );
        } else if (settings.arguments is PaymentTransactionModel) {
          final tx = settings.arguments as PaymentTransactionModel;
          return MaterialPageRoute(
            builder: (_) => RentalPaymentScreen(
              transaction: tx,
              repository: repository,
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => RentalPaymentScreen(repository: repository),
          settings: settings,
        );

      case depositStatus:
        if (settings.arguments is PaymentTransactionModel) {
          final tx = settings.arguments as PaymentTransactionModel;
          return MaterialPageRoute(
            builder: (_) => DepositStatusScreen(
              transaction: tx,
              repository: repository,
            ),
            settings: settings,
          );
        } else if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => DepositStatusScreen(
              booking: booking,
              repository: repository,
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => DepositStatusScreen(repository: repository),
          settings: settings,
        );

      case depositRefund:
        if (settings.arguments is PaymentTransactionModel) {
          final tx = settings.arguments as PaymentTransactionModel;
          return MaterialPageRoute(
            builder: (_) => DepositRefundScreen(
              transaction: tx,
              repository: repository,
            ),
            settings: settings,
          );
        } else if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => DepositRefundScreen(
              booking: booking,
              repository: repository,
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => DepositRefundScreen(repository: repository),
          settings: settings,
        );

      case paymentHistory:
        return MaterialPageRoute(
          builder: (_) => PaymentHistoryScreen(repository: repository),
          settings: settings,
        );

      case receiptPreview:
        if (settings.arguments is ReceiptModel) {
          final receipt = settings.arguments as ReceiptModel;
          return MaterialPageRoute(
            builder: (_) => ReceiptScreen(initialReceipt: receipt),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => const ReceiptScreen(),
          settings: settings,
        );

      case reprintReceiptList:
        return MaterialPageRoute(
          builder: (_) => ReprintReceiptListScreen(repository: repository),
          settings: settings,
        );

      case printerSettings:
        return MaterialPageRoute(
          builder: (_) => const PrinterSettingsScreen(),
          settings: settings,
        );

      case receiptFormatSettings:
        return MaterialPageRoute(
          builder: (_) => const ReceiptFormatSettingsScreen(),
          settings: settings,
        );

      case returnScreen:
        return MaterialPageRoute(
          builder: (_) => ReturnScreen(repository: repository),
          settings: settings,
        );

      case returnSummary:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => ReturnSummaryScreen(booking: booking, repository: repository),
            settings: settings,
          );
        }
        return _errorRoute('Argumen booking untuk ringkasan pengembalian tidak valid.');

      case returnInspection:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          if (booking.isCurrentlyLate && booking.estimatedLateFee > 0) {
            return MaterialPageRoute(
              builder: (_) => PaymentDepositScreen(
                repository: repository,
                booking: booking,
                initialPaymentType: PaymentTypeOption.penalty,
                initialAmount: booking.estimatedLateFee,
                isReturnFlow: true,
              ),
              settings: settings,
            );
          }
          return MaterialPageRoute(
            builder: (_) => BookingDetailScreen(
              booking: booking,
              repository: repository,
            ),
            settings: settings,
          );
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          final booking = args['booking'] as BookingModel?;
          final lateFee = (args['lateFee'] as num?)?.toDouble() ?? booking?.estimatedLateFee ?? 0.0;
          return MaterialPageRoute(
            builder: (_) => PaymentDepositScreen(
              repository: repository,
              booking: booking,
              initialPaymentType: PaymentTypeOption.penalty,
              initialAmount: lateFee > 0 ? lateFee : null,
              isReturnFlow: true,
            ),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => PaymentDepositScreen(
            repository: repository,
            initialPaymentType: PaymentTypeOption.penalty,
            isReturnFlow: true,
          ),
          settings: settings,
        );

      case returnSuccess:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => ReturnSuccessScreen(booking: booking),
            settings: settings,
          );
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => ReturnSuccessScreen(
              booking: args['booking'] as BookingModel,
              receipt: args['receipt'] as ReceiptModel?,
              depositRefunded: (args['depositRefunded'] as num?)?.toDouble() ?? 0.0,
              lateFee: (args['lateFee'] as num?)?.toDouble() ?? 0.0,
              damageFee: (args['damageFee'] as num?)?.toDouble() ?? 0.0,
              condition: args['condition'] as String? ?? 'Baik / Normal',
            ),
            settings: settings,
          );
        }
        return _errorRoute('Argumen untuk layar selesai pengembalian tidak valid.');

      case bookingDetail:
        if (settings.arguments is BookingModel) {
          final booking = settings.arguments as BookingModel;
          return MaterialPageRoute(
            builder: (_) => BookingDetailScreen(
              booking: booking,
              repository: repository,
            ),
            settings: settings,
          );
        } else if (settings.arguments is String) {
          final bookingCode = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => FutureBuilder<BookingModel?>(
              future: repository.getBookingByCode(bookingCode),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Detail Booking')),
                    body: Center(
                      child: Text('Booking dengan kode $bookingCode tidak ditemukan'),
                    ),
                  );
                }
                return BookingDetailScreen(
                  booking: snapshot.data!,
                  repository: repository,
                );
              },
            ),
            settings: settings,
          );
        }
        return _errorRoute('Argumen booking tidak valid.');

      case unitStatus:
      case '/iphone-status':
        return MaterialPageRoute(
          builder: (_) => UnitStatusListScreen(repository: repository),
          settings: settings,
        );

      case unitSchedule:
        if (settings.arguments is IphoneModel) {
          final unit = settings.arguments as IphoneModel;
          return MaterialPageRoute(
            builder: (_) => UnitScheduleScreen(unit: unit, repository: repository),
            settings: settings,
          );
        }
        return _errorRoute('Argumen unit iPhone untuk jadwal tidak valid.');

      case dashboard:
        return MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            repository: repository,
            initialIndex: 0,
          ),
          settings: settings,
        );

      case salesReport:
        return MaterialPageRoute(
          builder: (_) => SalesReportScreen(repository: repository),
          settings: settings,
        );

      case notifications:
        return MaterialPageRoute(
          builder: (_) => NotificationListScreen(repository: repository),
          settings: settings,
        );

      case account:
        return MaterialPageRoute(
          builder: (_) => AccountScreen(repository: repository),
          settings: settings,
        );

      case changePassword:
        return MaterialPageRoute(
          builder: (_) => ChangePasswordScreen(repository: repository),
          settings: settings,
        );

      case shopSettings:
        return MaterialPageRoute(
          builder: (_) => ShopSettingsScreen(repository: repository),
          settings: settings,
        );

      case rolesPermissions:
      case '/admin/roles-permission':
      case 'admin/roles-permission':
      case 'admin/roles-permissions':
      case '/roles-permissions':
      case '/roles-permission':
      case 'roles-permissions':
      case 'roles-permission':
      case '/user-roles':
      case 'user-roles':
      case '/users':
      case 'users':
      case '/admin/users':
      case 'admin/users':
        return MaterialPageRoute(
          builder: (_) => RolesPermissionsScreen(repository: repository),
          settings: settings,
        );

      case themeSettings:
        return MaterialPageRoute(
          builder: (_) => const ThemeSettingsScreen(),
          settings: settings,
        );

      case login:
        return MaterialPageRoute(
          builder: (_) => LoginScreen(repository: repository),
          settings: settings,
        );

      case affiliateList:
        return MaterialPageRoute(
          builder: (_) => AffiliateListScreen(repository: repository),
          settings: settings,
        );

      case affiliateDetail:
        if (settings.arguments is AffiliateModel) {
          return MaterialPageRoute(
            builder: (_) => AffiliateDetailScreen(
              affiliate: settings.arguments as AffiliateModel,
              repository: repository,
            ),
            settings: settings,
          );
        }
        return _errorRoute('Argumen mitra affiliate tidak valid.');

      case affiliateForm:
        final affiliate = settings.arguments is AffiliateModel ? settings.arguments as AffiliateModel : null;
        return MaterialPageRoute(
          builder: (_) => AffiliateFormScreen(
            affiliate: affiliate,
            repository: repository,
          ),
          settings: settings,
        );

      case iphoneTransfer:
      case affiliateTransferIphone:
        final initialAffiliateId = settings.arguments is int ? settings.arguments as int : null;
        return MaterialPageRoute(
          builder: (_) => IphoneTransferListScreen(
            repository: repository,
            initialAffiliateId: initialAffiliateId,
          ),
          settings: settings,
        );

      case affiliateRevenue:
        if (settings.arguments is AffiliateModel) {
          return MaterialPageRoute(
            builder: (_) => AffiliateRevenueScreen(
              affiliate: settings.arguments as AffiliateModel,
              repository: repository,
            ),
            settings: settings,
          );
        }
        return _errorRoute('Argumen mitra affiliate untuk laporan omset tidak valid.');

      default:
        return _errorRoute('Rute tidak ditemukan: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error Navigasi')),
        body: Center(child: Text(message)),
      ),
    );
  }
}