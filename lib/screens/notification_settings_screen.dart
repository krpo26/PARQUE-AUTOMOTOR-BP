import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../services/notification_sound_service.dart';

/// Sonido (MP3 propio), vista previa de la notificación y frecuencia
/// individual de cada tipo de aviso.
///
/// - El sonido es de ESTE celular y lo puede elegir cualquier usuario.
/// - Encender/apagar cada aviso y cambiar cada cuánto se repite lo
///   cambia solo el administrador (como antes con el intervalo único).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _soundName;
  bool _notifEnabled = true;
  final Map<AlertType, AlertTypeConfig> _cfg = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await NotificationService.instance.getCustomSoundName();
    for (final t in AlertType.values) {
      _cfg[t] = await NotificationService.instance.getConfig(t);
    }
    final enabled = await NotificationService.instance.areNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _soundName = name;
      _notifEnabled = enabled;
      _loading = false;
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _label(int minutes) {
    if (minutes == 0) return 'Solo una vez';
    if (minutes < 60) return 'Cada $minutes min';
    if (minutes < 1440) {
      final h = minutes ~/ 60;
      return h == 1 ? 'Cada 1 hora' : 'Cada $h horas';
    }
    final d = minutes ~/ 1440;
    return d == 1 ? 'Cada 1 día' : 'Cada $d días';
  }

  Future<void> _pickSound() async {
    setState(() => _busy = true);
    try {
      final name = await NotificationSoundService.instance.pickAndApply();
      if (name != null) {
        _soundName = name;
        _toast('Sonido guardado: $name. Va a sonar una prueba.');
        await NotificationService.instance.showTest();
      }
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetSound() async {
    setState(() => _busy = true);
    try {
      await NotificationSoundService.instance.reset();
      _soundName = null;
      _toast('Se usa el sonido predeterminado del celular');
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final problem = await NotificationService.instance.showTest();
    final enabled = await NotificationService.instance.areNotificationsEnabled();
    if (mounted) setState(() => _notifEnabled = enabled);
    if (problem != null) _toast(problem);
  }

  Future<void> _allowNotifications() async {
    final ok = await NotificationService.instance.requestPermission();
    if (mounted) setState(() => _notifEnabled = ok);
    if (!ok) {
      _toast('Activalas en Ajustes del celular → Aplicaciones → esta app → '
          'Notificaciones.');
    }
  }

  Future<void> _setEnabled(AlertType type, bool value) async {
    await NotificationService.instance.setConfig(type, enabled: value);
    _cfg[type] = await NotificationService.instance.getConfig(type);
    if (mounted) setState(() {});
  }

  Future<void> _setInterval(AlertType type, int minutes) async {
    await NotificationService.instance.setConfig(type, intervalMinutes: minutes);
    _cfg[type] = await NotificationService.instance.getConfig(type);
    if (mounted) setState(() {});
  }

  Widget _typeCard(AlertType type, bool canEdit) {
    final cfg = _cfg[type]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(type.label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(type.description),
              value: cfg.enabled,
              onChanged: canEdit ? (v) => _setEnabled(type, v) : null,
            ),
            if (cfg.enabled) ...[
              const SizedBox(height: 4),
              Text(
                type.allowsOnce
                    ? 'Avisa apenas se cruza el límite. Si elegís una '
                        'frecuencia, además lo repite mientras siga así:'
                    : 'Repetir el aviso mientras siga pendiente:',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: NotificationService.optionsFor(type)
                    .map((m) => ChoiceChip(
                          label: Text(_label(m)),
                          selected: cfg.intervalMinutes == m,
                          onSelected: canEdit ? (_) => _setInterval(type, m) : null,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthProvider>().isGod;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_notifEnabled)
                  Card(
                    color: Colors.orange.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Las notificaciones de esta app están bloqueadas '
                            'en el celular, por eso no aparecen en la barra '
                            'de arriba ni suenan.',
                            style: TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _allowNotifications,
                            child: const Text('Permitir notificaciones'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!_notifEnabled) const SizedBox(height: 16),
                const Text('Sonido',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Los avisos aparecen en la barra de arriba del celular, '
                  'con un ícono de auto, y suenan con el sonido que elijas '
                  '(audio de hasta 5 MB: MP3, M4A, OGG, WAV…). Vale solo para este '
                  'celular.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.music_note_outlined),
                    title: Text(_soundName ?? 'Sonido predeterminado del celular'),
                    subtitle: Text(_soundName == null
                        ? 'Podés elegir un MP3 propio'
                        : 'MP3 elegido por vos'),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _pickSound,
                      icon: const Icon(Icons.audio_file_outlined),
                      label: const Text('Elegir audio'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || _soundName == null ? null : _resetSound,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Usar el predeterminado'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _test,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Probar notificación'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Frecuencia de cada aviso',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  canEdit
                      ? 'Cada tipo de aviso se enciende y se repite por '
                          'separado.'
                      : 'Solo el administrador puede cambiar estos valores.',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                for (final t in AlertType.values) _typeCard(t, canEdit),
              ],
            ),
    );
  }
}
