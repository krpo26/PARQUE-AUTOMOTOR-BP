import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/appearance_provider.dart';
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
import 'theme/app_theme.dart';
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

ThemeMode? _modeFromKey(String? key) {
  switch (key) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return null;
  }
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
        ChangeNotifierProvider(create: (_) => AppearanceProvider()..load()),
      ],
      child: Consumer2<SettingsProvider, AppearanceProvider>(
        builder: (context, settings, appearance, _) {
          // Dentro de un complejo se aplica la apariencia que le definió
          // el administrador; los campos vacíos usan lo general de la app.
          final a = appearance.active;
          final mode = _modeFromKey(a?.themeMode) ?? settings.themeMode;
          final idx = a?.colorIndex;
          final seed = (idx != null && idx >= 0 && idx < kColorOptions.length)
              ? kColorOptions[idx].color
              : settings.seedColor;
          final font = fontFromKey(a?.fontKey) ?? settings.font;
          return MaterialApp(
            title: kAppTitle,
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: buildAppTheme(
              brightness: Brightness.light,
              seed: seed,
              font: font,
              style: settings.themeStyle,
            ),
            darkTheme: buildAppTheme(
              brightness: Brightness.dark,
              seed: seed,
              font: font,
              style: settings.themeStyle,
            ),
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
        context.read<AppearanceProvider>().load();
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
