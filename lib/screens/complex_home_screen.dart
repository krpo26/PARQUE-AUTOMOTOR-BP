import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/complex.dart';
import '../models/driver.dart';
import '../models/vehicle.dart';
import '../providers/auth_provider.dart';
import '../providers/appearance_provider.dart';
import '../providers/driver_provider.dart';
import '../providers/procedure_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import 'admin/admin_panel_screen.dart';
import 'auth/login_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'users/user_management_screen.dart';

/// Pantalla principal con la única sección del complejo (Benjamín Paz).
/// Abre el panel de trabajo (vehículos, choferes, trámites, alertas).
class ComplexHomeScreen extends StatefulWidget {
  const ComplexHomeScreen({super.key});

  @override
  State<ComplexHomeScreen> createState() => _ComplexHomeScreenState();
}

class _ComplexHomeScreenState extends State<ComplexHomeScreen> {
  // Cantidad de alertas críticas (service / carnet) de cada complejo.
  Map<String, int> _alertCounts = {};
  DateTime? _lastSeenSync;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    // Al entrar se revisan las alertas de los complejos habilitados
    // para este usuario y salen las notificaciones de cada uno.
    NotificationService.instance.checkForCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si terminó una sincronización con la nube, se refrescan los
    // contadores con lo que llegó.
    final synced = context.read<SyncProvider>().lastSyncedAt;
    if (synced != _lastSeenSync) {
      _lastSeenSync = synced;
      _loadCounts();
    }
  }

  Future<void> _loadCounts() async {
    final db = DatabaseHelper.instance;
    final vehicles = await db.getVehicles();
    final drivers = await db.getDrivers();
    final counts = <String, int>{};
    for (final v in vehicles) {
      if (v.maintenanceStatus != MaintenanceStatus.ok) {
        counts[v.complexId] = (counts[v.complexId] ?? 0) + 1;
      }
    }
    for (final d in drivers) {
      if (d.licenseStatus != LicenseStatus.ok) {
        counts[d.complexId] = (counts[d.complexId] ?? 0) + 1;
      }
    }
    if (!mounted) return;
    setState(() => _alertCounts = counts);
  }

  Future<void> _open(BuildContext context, Complex complex) async {
    final auth = context.read<AuthProvider>();
    if (!auth.canAccess(complex.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No tenés acceso a este complejo. Pedile al administrador que te habilite.'),
        ),
      );
      return;
    }
    final vehicles = context.read<VehicleProvider>();
    final drivers = context.read<DriverProvider>();
    final procedures = context.read<ProcedureProvider>();
    await Future.wait([
      vehicles.setComplex(complex.id),
      drivers.setComplex(complex.id),
      procedures.setComplex(complex.id),
    ]);
    if (mounted) context.read<AppearanceProvider>().setActive(complex.id);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(complex: complex)),
    );
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncProvider>();
    final isGod = auth.isGod;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PARQUE AUTOMOTOR',
            style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            tooltip: 'Apariencia',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (sync.isCloudEnabled)
            IconButton(
              tooltip: 'Sincronizar ahora',
              icon: sync.isSyncing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: sync.isSyncing ? null : () => sync.syncNow(),
            ),
          if (isGod)
            IconButton(
              tooltip: 'Administrar usuarios',
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const UserManagementScreen()),
              ),
            ),
          if (isGod)
            IconButton(
              tooltip: 'Panel de administración',
              icon: const Icon(Icons.settings_suggest_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
              ),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Image.asset('assets/images/logo.png',
                height: 90, width: 90, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Text(
            'Servicio Penitenciario de Tucumán',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).hintColor, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            isGod
                ? 'Elegí el complejo con el que querés trabajar'
                : 'Elegí tu complejo',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...kComplexes.map(
            (c) => _ComplexCard(
              complex: c,
              enabled: auth.canAccess(c.id),
              alerts: auth.canAccess(c.id) ? (_alertCounts[c.id] ?? 0) : 0,
              onTap: () => _open(context, c),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplexCard extends StatelessWidget {
  final Complex complex;
  final bool enabled;
  final int alerts;
  final VoidCallback onTap;

  const _ComplexCard({
    required this.complex,
    required this.enabled,
    required this.alerts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? complex.color : Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color,
                  child: Icon(complex.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    complex.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: enabled ? null : Colors.grey,
                    ),
                  ),
                ),
                if (alerts > 0) ...[
                  Badge(
                    label: Text('$alerts'),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.notifications_active_outlined,
                        color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(enabled ? Icons.chevron_right : Icons.lock_outline,
                    color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
