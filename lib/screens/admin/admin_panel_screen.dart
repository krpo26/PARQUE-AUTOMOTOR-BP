import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/complex.dart';
import '../../services/backup_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/drive_backup_card.dart';
import 'access_log_screen.dart';
import 'audit_log_screen.dart';
import '../notification_settings_screen.dart';
import 'complex_appearance_screen.dart';
import 'logo_settings_screen.dart';
import 'feature_flags_screen.dart';

/// Panel de administración avanzada. Solo llega acá el usuario god
/// (el botón que la abre está oculto para usuarios comunes).
///
/// Desde acá se configura:
/// - El sonido (MP3) y la frecuencia de cada tipo de aviso (service,
///   carnet y combustible), en la pantalla de Notificaciones.
/// - La apariencia propia de cada complejo (logo, tema, color, letra).
/// - El respaldo de la base de datos: ver cuándo fue el último
///   (automático, cada 3 horas, corre solo en segundo plano), forzar
///   uno manual ahora mismo, y restaurar desde un archivo guardado.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  DateTime? _lastBackupAt;
  bool _loading = true;
  bool _exporting = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lastBackup = await BackupService.instance.getLastBackupAt();
    if (!mounted) return;
    setState(() {
      _lastBackupAt = lastBackup;
      _loading = false;
    });
  }

  Future<void> _exportNow() async {
    setState(() => _exporting = true);
    try {
      await BackupService.instance.exportAndShare();
      final lastBackup = await BackupService.instance.getLastBackupAt();
      if (!mounted) return;
      setState(() => _lastBackupAt = lastBackup);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveCopy() async {
    setState(() => _exporting = true);
    try {
      final ok = await BackupService.instance.saveCopyToChosenLocation();
      final lastBackup = await BackupService.instance.getLastBackupAt();
      if (!mounted) return;
      setState(() => _lastBackupAt = lastBackup);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo guardado.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el respaldo: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restoreFromFile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: const Text(
          'Se van a cargar los datos del archivo elegido. No borra nada '
          'de lo que ya está cargado: si un vehículo, chofer o carga ya '
          'existe (mismo ID), se actualiza con lo del archivo; si no '
          'existe, se agrega. ¿Continuar?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoring = true);
    try {
      final jsonStr = await BackupService.instance.pickBackupJson();
      if (jsonStr == null) return;
      await BackupService.instance.restoreFromJsonString(jsonStr);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respaldo restaurado correctamente')),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo restaurar: $e')),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final cloudEnabled = SyncService.instance.isCloudEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de administración')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Notificaciones',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Elegí el sonido (MP3) y cada cuánto se repite cada tipo '
                  'de aviso: service, carnet y combustible por separado.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Sonido y frecuencia de avisos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen()),
                  ),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Logos de la app'),
                  subtitle: const Text('Logo de inicio y logo de la interfaz'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LogoSettingsScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Apariencia de cada complejo',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Logo, tema, color y letra propios de cada complejo. Se '
                  'aplican al entrar a ese complejo y llegan a los demás '
                  'celulares al sincronizar.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                for (final c in kComplexes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(c.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ComplexAppearanceScreen(complex: c)),
                    ),
                  ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Respaldo de la base de datos',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  cloudEnabled
                      ? 'Se hace un respaldo automático cada 3 horas en '
                        'segundo plano (se sube también a la nube). '
                        'También podés forzar uno manual ahora mismo.'
                      : 'Se hace un respaldo automático cada 3 horas, '
                        'guardado en este celular (la nube todavía no '
                        'está conectada, ver diagnóstico en el dashboard). '
                        'También podés forzar uno manual ahora mismo.',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastBackupAt == null
                      ? 'Todavía no se hizo ningún respaldo.'
                      : 'Último respaldo: ${dateFmt.format(_lastBackupAt!)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportNow,
                  icon: _exporting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_outlined),
                  label: const Text('Exportar respaldo ahora'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _exporting ? null : _saveCopy,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Guardar copia (Drive, Descargas…)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _restoring ? null : _restoreFromFile,
                  icon: _restoring
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined),
                  label: const Text('Restaurar desde un archivo'),
                ),
                const SizedBox(height: 8),
                Text(
                  'El respaldo incluye vehículos, choferes, usuarios comunes, '
                  'mantenimiento, combustible y fichas técnicas. No incluye '
                  'las fotos en sí (quedan solo en el celular donde se '
                  'tomaron, salvo que la nube esté conectada). El usuario '
                  'god nunca se incluye en el respaldo, por seguridad.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const DriveBackupCard(),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Auditoría',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Quién creó, editó, archivó o eliminó definitivamente '
                  'cada vehículo, chofer o usuario, y cuándo.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('Ver historial de movimientos'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccessLogScreen()),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('Últimos ingresos de usuarios'),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Pestañas visibles',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Elegí qué secciones puede ver un usuario común (vos '
                  'siempre las ves todas).',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FeatureFlagsScreen()),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Configurar pestañas'),
                ),
              ],
            ),
    );
  }
}
