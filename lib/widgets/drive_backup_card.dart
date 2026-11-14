import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/driver_provider.dart';
import '../providers/vehicle_provider.dart';
import '../services/backup_service.dart';
import '../services/drive_backup_service.dart';

/// Tarjeta del respaldo en Google Drive.
///
/// Solo se muestra en el Panel de administración (únicamente el admin):
/// elegir la cuenta de Google/Drive, subir el respaldo y bajarlo.
class DriveBackupCard extends StatefulWidget {
  const DriveBackupCard({super.key});

  @override
  State<DriveBackupCard> createState() => _DriveBackupCardState();
}

class _DriveBackupCardState extends State<DriveBackupCard> {
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');
  String? _email;
  DateTime? _lastUpload;
  DateTime? _lastPull;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = DriveBackupService.instance;
    final email = await svc.adminEmail();
    final up = await svc.lastUploadAt();
    final pull = await svc.lastPullAt();
    if (!mounted) return;
    setState(() {
      _email = email;
      _lastUpload = up;
      _lastPull = pull;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyError(Object e) {
    final t = e.toString();
    if (t.contains('ApiException: 10') || t.contains('DEVELOPER_ERROR')) {
      return 'Google rechazó el inicio de sesión: falta registrar la huella '
          'SHA-1 de la app en Firebase (ver README, sección "Respaldo en '
          'Google Drive").';
    }
    if (t.contains('403') || t.contains('accessNotConfigured')) {
      return 'La API de Google Drive no está habilitada en el proyecto de '
          'Google Cloud (ver README).';
    }
    if (t.contains('network') || t.contains('SocketException')) {
      return 'No hay conexión a internet.';
    }
    return 'No se pudo completar: $e';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _chooseAccount() => _run(() async {
        final email = await DriveBackupService.instance.chooseAccount();
        if (email == null) return;
        final ok = await BackupService.instance.backupToDrive();
        _toast(ok
            ? 'Listo: el respaldo se guarda en el Drive de $email'
            : 'Cuenta elegida, pero no se pudo subir el primer respaldo. '
                'Probá con "Respaldar ahora".');
      });

  Future<void> _backupNow() => _run(() async {
        final ok = await BackupService.instance.backupToDrive();
        _toast(ok
            ? 'Respaldo subido a Google Drive'
            : 'No se pudo subir (¿sin sesión de Google o sin internet?)');
      });

  Future<void> _pullNow() => _run(() async {
        final result = await DriveBackupService.instance.pullLatest();
        switch (result) {
          case DrivePullResult.updated:
            if (mounted) {
              context.read<VehicleProvider>().load();
              context.read<DriverProvider>().load();
            }
            _toast('Datos actualizados desde Google Drive');
            break;
          case DrivePullResult.notFound:
            _toast('No hay ningún respaldo en este Drive todavía.');
            break;
          case DrivePullResult.notConfigured:
            _toast('Primero elegí la cuenta de Google Drive.');
            break;
          case DrivePullResult.failed:
            _toast('No se pudo bajar el respaldo de Drive.');
            break;
        }
      });

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Desconectar Google Drive'),
        content: const Text(
            'Este dispositivo deja de subir respaldos. No se borra nada de '
            'Drive y los demás usuarios siguen pudiendo bajar el último '
            'respaldo publicado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Desconectar')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => DriveBackupService.instance.disconnect());
  }

  @override
  Widget build(BuildContext context) {
    const spinner = SizedBox(
        height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Respaldo en Google Drive',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'La cuenta de Google que elijas acá es la que maneja los '
          'respaldos de la app. Solo el administrador puede subir y bajar '
          'respaldos. Se sube solo al abrir la app (cada 15 minutos como '
          'máximo) y en el respaldo automático de 3 horas. El archivo es '
          'privado: no se comparte con nadie.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _email == null
              ? 'Todavía no elegiste ninguna cuenta de Drive.'
              : 'Cuenta de Drive: $_email',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        if (_lastUpload != null)
          Text('Último respaldo subido: ${_fmt.format(_lastUpload!)}'),
        if (_lastPull != null)
          Text('Última bajada desde Drive: ${_fmt.format(_lastPull!)}'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _chooseAccount,
          icon: _busy ? spinner : const Icon(Icons.account_circle_outlined),
          label: Text(_email == null
              ? 'Elegir cuenta de Google Drive'
              : 'Cambiar cuenta de Drive'),
        ),
        if (_email != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _backupNow,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Subir respaldo ahora'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pullNow,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Bajar respaldo desde Drive'),
          ),
          TextButton(
            onPressed: _busy ? null : _disconnect,
            child: const Text('Desconectar Drive de este dispositivo'),
          ),
        ],
      ],
    );
  }
}
