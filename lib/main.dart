import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/feature_flags_provider.dart';
import 'providers/procedure_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/vehicle_provider.dart';
import 'screens/auth_gate.dart';
import 'services/background_service.dart';
import 'services/drive_backup_service.dart';
import 'services/notification_service.dart';
import 'services/screenshot_protection_service.dart';
import 'services/sync_service.dart';

/// Nombre institucional del sistema: PARQUE AUTOMOTOR BENJAMIN PAZ
const String kAppTitle = 'PARQUE AUTOMOTOR BENJAMIN PAZ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bloquea capturas/grabación de pantalla para todos los usuarios,
  // desde el primer instante que se abre la app.
  await ScreenshotProtectionService.enable();
  await NotificationService.instance.init();
  // Si Firebase no está configurado (ver README), esto falla en
  // silencio y la app sigue funcionando 100% offline con SQLite.
  await SyncService.instance.init();
  // Registra la tarea en segundo plano (respaldo automático cada 3
  // horas + alertas sonoras según el intervalo que configure el
  // admin). Si falla el registro (plataforma no soportada, etc.), la
  // app sigue funcionando normal — solo se pierde la automatización.
  await BackgroundService.instance.initializeAndRegister();
  runApp(const FleetApp());
}

class FleetApp extends StatelessWidget {
  const FleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VehicleProvider()..load()),
        ChangeNotifierProvider(create: (_) => DriverProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProcedureProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => FeatureFlagsProvider()..load()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          TextTheme? textTheme;
          switch (settings.font) {
            case AppFont.roboto:
              textTheme = GoogleFonts.robotoTextTheme();
              break;
            case AppFont.poppins:
              textTheme = GoogleFonts.poppinsTextTheme();
              break;
            case AppFont.montserrat:
              textTheme = GoogleFonts.montserratTextTheme();
              break;
            case AppFont.system:
              textTheme = null;
              break;
          }

          ThemeData buildTheme(Brightness brightness) {
            var theme = ThemeData(
              colorSchemeSeed: settings.seedColor,
              brightness: brightness,
              useMaterial3: true,
              appBarTheme:
                  const AppBarTheme(centerTitle: true, elevation: 0),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            );
            if (textTheme != null) {
              theme = theme.copyWith(
                textTheme: textTheme.apply(
                  bodyColor: theme.colorScheme.onSurface,
                  displayColor: theme.colorScheme.onSurface,
                ),
              );
            }
            return theme;
          }

          return MaterialApp(
            title: kAppTitle,
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            home: const AppStartup(),
          );
        },
      ),
    );
  }
}

/// Arranca la sincronización online/offline una vez que los
/// providers ya existen en el árbol, y solo entonces muestra el
/// flujo normal de autenticación.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SyncProvider>().start(onSynced: () {
        if (!mounted) return;
        context.read<VehicleProvider>().load();
        context.read<DriverProvider>().load();
        context.read<FeatureFlagsProvider>().load();
        context.read<ProcedureProvider>().load();
      });
      _checkAlertsOnOpen();
      _driveAutoSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando el usuario vuelve a la app (por ejemplo, cambió a otra
    // app y regresó, sin llegar a cerrar esta del todo) se sincroniza
    // sola, para traer al toque cualquier cambio que haya hecho el
    // admin desde otro dispositivo mientras tanto.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<SyncProvider>().syncNow();
      _driveAutoSync();
    }
  }

  /// Respaldo en Google Drive: solo actúa en el celular del admin
  /// (sube un respaldo nuevo si pasaron 15 min desde el último).
  Future<void> _driveAutoSync() => DriveBackupService.instance.autoSync();

  Future<void> _checkAlertsOnOpen() async {
    if (!mounted) return;
    await NotificationService.instance.checkForCurrentUser();
  }

  @override
  Widget build(BuildContext context) => const AuthGate();
}
