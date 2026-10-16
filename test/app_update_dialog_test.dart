import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skyrental_admin/models/app_update_model.dart';
import 'package:skyrental_admin/services/api_service.dart';
import 'package:skyrental_admin/widgets/app_update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUpdateInfo = AppUpdateInfo(
    updateAvailable: true,
    isMandatory: false,
    currentBuild: 1,
    latestBuild: 2,
    latestVersion: '1.1.0',
    minSupportedBuild: 1,
    title: 'Update Tersedia',
    releaseNotes: 'Fitur baru dan perbaikan stabilitas',
    fileSize: 10485760,
    formattedSize: '10.00 MB',
    sha256Checksum: 'dummy_hash',
    downloadUrl: 'https://skyrental.id/api/v1/app/download/2',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService().baseUrl = 'https://skyrental.id/api/v1';
  });

  testWidgets('AppUpdateDialog renders release info and controls correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUpdateDialog(updateInfo: testUpdateInfo),
        ),
      ),
    );

    expect(find.text('Update Aplikasi Tersedia'), findsOneWidget);
    expect(find.text('VERSI SAAT INI'), findsOneWidget);
    expect(find.text('VERSI TERBARU'), findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('Build 2 • 10.00 MB'), findsOneWidget);
    expect(find.text('YANG BARU'), findsOneWidget);
    expect(find.text('Fitur baru dan perbaikan stabilitas'), findsOneWidget);
    expect(find.text('Perbarui Sekarang'), findsOneWidget);
    expect(find.text('Nanti'), findsOneWidget);
  });

  testWidgets('AppUpdateDialog.show manages _isShowing mutex and prevents duplicate dialogs', (tester) async {
    expect(AppUpdateDialog.isShowing, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppUpdateDialog.show(context, testUpdateInfo);
                // Trigger duplicate immediately
                AppUpdateDialog.show(context, testUpdateInfo);
              },
              child: const Text('Open Update Dialog'),
            ),
          ),
        ),
      ),
    );

    // Tap button to open dialog
    await tester.tap(find.text('Open Update Dialog'));
    await tester.pumpAndSettle();

    // Dialog is visible and mutex is active
    expect(AppUpdateDialog.isShowing, isTrue);
    expect(find.byType(AppUpdateDialog), findsOneWidget);

    // Dismiss dialog via "Nanti"
    await tester.tap(find.text('Nanti'));
    await tester.pumpAndSettle();

    // Dialog is closed and mutex is released
    expect(AppUpdateDialog.isShowing, isFalse);
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  testWidgets('AppUpdateDialog lifecycle on resumed: handles cancelled install and successful install', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.example.skyrental_admin/app_installer');

    int simulatedInstalledBuild = 1;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getInstalledVersionInfo') {
        return {'version': '1.1.0', 'buildNumber': simulatedInstalledBuild};
      }
      if (call.method == 'canRequestPackageInstalls') {
        return true;
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppUpdateDialog.show(context, testUpdateInfo),
              child: const Text('Launch Update'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch Update'));
    await tester.pumpAndSettle();

    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(AppUpdateDialog.isShowing, isTrue);

    // Get dialog state
    final dynamic dialogState = tester.state(find.byType(AppUpdateDialog));

    // SCENARIO 1: Installer was launched, but user returns WITHOUT finishing install (build remains 1)
    dialogState.launchedInstaller = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Dialog must stay open, and status message indicates incomplete installation
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(AppUpdateDialog.isShowing, isTrue);
    expect(find.textContaining('Instalasi belum selesai'), findsOneWidget);
    expect(dialogState.launchedInstaller, isFalse);

    // SCENARIO 2: Installer was launched, and user returns AFTER successful installation (build is now 2)
    simulatedInstalledBuild = 2;
    dialogState.launchedInstaller = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Dialog must be automatically dismissed, mutex released, and success SnackBar shown!
    expect(find.byType(AppUpdateDialog), findsNothing);
    expect(AppUpdateDialog.isShowing, isFalse);
    expect(find.textContaining('SkyMobile berhasil diperbarui ke v1.1.0 (Build 2)'), findsOneWidget);

    // Pump past the 3-second background timeout and SnackBar animation
    await tester.pump(const Duration(seconds: 5));

    // Clean up
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('AppUpdateDialog mandatory update mode hides "Nanti" and displays warning banner', (tester) async {
    const mandatoryUpdateInfo = AppUpdateInfo(
      updateAvailable: true,
      isMandatory: true,
      currentBuild: 1,
      latestBuild: 3,
      latestVersion: '1.2.0',
      minSupportedBuild: 2,
      title: 'Update Aplikasi Wajib',
      releaseNotes: 'Security patch penting',
      fileSize: 5242880,
      formattedSize: '5.00 MB',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUpdateDialog(
            updateInfo: mandatoryUpdateInfo,
            currentVersion: '1.0.5',
          ),
        ),
      ),
    );

    expect(find.text('Update Aplikasi Tersedia'), findsOneWidget);
    expect(find.text('Versi ini wajib dipasang untuk terus menggunakan SKYRental.'), findsOneWidget);
    expect(find.text('v1.0.5'), findsOneWidget);
    expect(find.text('v1.2.0'), findsOneWidget);
    expect(find.text('Perbarui Sekarang'), findsOneWidget);
    expect(find.text('Nanti'), findsNothing);
  });

  testWidgets('AppUpdateDialog parses various release note bullet formats cleanly', (tester) async {
    const customUpdateInfo = AppUpdateInfo(
      updateAvailable: true,
      isMandatory: false,
      currentBuild: 2,
      latestBuild: 4,
      latestVersion: '2.0.0',
      releaseNotes: '- Integrasi printer thermal Bluetooth baru\n* Peningkatan kecepatan loading booking\n1. Perbaikan bug filter unit status\n• Optimasi sinkronisasi data kasir',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUpdateDialog(
            updateInfo: customUpdateInfo,
            currentVersion: '1.9.0',
          ),
        ),
      ),
    );

    expect(find.text('YANG BARU'), findsOneWidget);
    expect(find.text('Integrasi printer thermal Bluetooth baru'), findsOneWidget);
    expect(find.text('Peningkatan kecepatan loading booking'), findsOneWidget);
    expect(find.text('Perbaikan bug filter unit status'), findsOneWidget);
    expect(find.text('Optimasi sinkronisasi data kasir'), findsOneWidget);
  });

  testWidgets('AppUpdateDialog handles empty release notes gracefully without breaking layout', (tester) async {
    const noNotesUpdateInfo = AppUpdateInfo(
      updateAvailable: true,
      isMandatory: false,
      currentBuild: 1,
      latestBuild: 2,
      latestVersion: '1.0.1',
      releaseNotes: '',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUpdateDialog(
            updateInfo: noNotesUpdateInfo,
            currentVersion: '1.0.0',
          ),
        ),
      ),
    );

    expect(find.text('Update Aplikasi Tersedia'), findsOneWidget);
    expect(find.text('YANG BARU'), findsNothing);
    expect(find.text('Perbarui Sekarang'), findsOneWidget);
    expect(find.text('Nanti'), findsOneWidget);
  });

  testWidgets('AppUpdateDialog renders responsively without overflow on small screen (360x640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const longNotesInfo = AppUpdateInfo(
      updateAvailable: true,
      isMandatory: false,
      currentBuild: 1,
      latestBuild: 5,
      latestVersion: '1.5.0',
      releaseNotes: '1. Fitur A\n2. Fitur B\n3. Fitur C\n4. Fitur D\n5. Fitur E\n6. Fitur F',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppUpdateDialog(
            updateInfo: longNotesInfo,
            currentVersion: '1.0.0',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Update Aplikasi Tersedia'), findsOneWidget);
    expect(find.text('Perbarui Sekarang'), findsOneWidget);
  });

  testWidgets('AppUpdateDialog renders in dark theme mode without contrast issues', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: AppUpdateDialog(
            updateInfo: testUpdateInfo,
            currentVersion: '1.0.0',
          ),
        ),
      ),
    );

    expect(find.text('Update Aplikasi Tersedia'), findsOneWidget);
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.text('v1.1.0'), findsOneWidget);
    expect(find.text('Perbarui Sekarang'), findsOneWidget);
  });
}
