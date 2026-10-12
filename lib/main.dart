import 'dart:async';
import 'package:flutter/material.dart';
import 'data/booking_repository.dart';
import 'routes/app_routes.dart';

import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService().restoreSession();
  final bookingRepository = BookingRepository();
  await ThemeService().init();
  runApp(SkyRentalAdminApp(bookingRepository: bookingRepository));

  // Inisialisasi FCM di latar belakang agar tidak memblokir pemuatan frame awal
  unawaited(FcmService().init());
}

class SkyRentalAdminApp extends StatelessWidget {
  final BookingRepository bookingRepository;

  const SkyRentalAdminApp({
    super.key,
    required this.bookingRepository,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          title: 'SkyRental',
          debugShowCheckedModeBanner: false,
          theme: ThemeService().lightTheme,
          darkTheme: ThemeService().darkTheme,
          themeMode: ThemeService().themeMode,
          initialRoute: AuthService().isAuthenticated ? AppRoutes.mainNavigation : AppRoutes.login,
          onGenerateInitialRoutes: (initialRoute) => [
            AppRoutes.onGenerateRoute(
              RouteSettings(name: initialRoute),
              bookingRepository,
            ),
          ],
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(settings, bookingRepository),
        );
      },
    );
  }
}
