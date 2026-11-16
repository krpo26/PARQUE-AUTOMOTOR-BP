import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/appearance_provider.dart';
import '../../widgets/app_logo.dart';

/// Pantalla del administrador: elegir el logo de las pantallas de inicio
/// y el logo de la interfaz. Se guardan en la nube y llegan a todos los
/// celulares al sincronizar.
class AppLogosScreen extends StatefulWidget {
  const AppLogosScreen({super.key});

  @override
  State<AppLogosScreen> createState() => _AppLogosScreenState();
}

class _AppLogosScreenState extends State<AppLogosScreen> {
  String? _busyKey;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pick(String key) async {
    setState(() => _busyKey = key);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.length > 700 * 1024) {
        _snack('La imagen es muy pesada. Elegí una más chica.');
        return;
      }
      if (!mounted) return;
      await context.read<AppearanceProvider>().setGlobalLogo(key, bytes);
      _snack('Logo guardado.');
    } catch (_) {
      _snack('No se pudo abrir la galería o guardar el logo.');
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _reset(String key) async {
    setState(() => _busyKey = key);
    try {
      await context.read<AppearanceProvider>().setGlobalLogo(key, null);
      _snack('Se volvió al logo original.');
    } catch (_) {
      _snack('No se pudo restablecer el logo.');
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Widget _section({
    required String title,
    required String help,
    required String key,
    required AppLogoSlot slot,
    required bool hasCustom,
  }) {
    final busy = _busyKey == key;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(help, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AppLogo(height: 90, slot: slot),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(hasCustom ? 'Logo cargado' : 'Logo original',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _pick(key),
                    icon: busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_library_outlined),
                    label: const Text('Elegir imagen'),
                  ),
                ),
                if (hasCustom) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: busy ? null : () => _reset(key),
                    child: const Text('Original'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Logos de la app')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            title: 'Logo de inicio',
            help: 'Se ve al ingresar, en la pantalla de bienvenida del '
                'complejo y en el acceso de administrador.',
            key: AppearanceProvider.kHomeLogoKey,
            slot: AppLogoSlot.home,
            hasCustom: appearance.homeLogo != null,
          ),
          const SizedBox(height: 12),
          _section(
            title: 'Logo de la interfaz',
            help: 'Se ve en la barra superior de las pantallas de trabajo '
                '(panel del complejo). Si un complejo tiene logo propio '
                '(Apariencia de cada complejo), ese tiene prioridad.',
            key: AppearanceProvider.kUiLogoKey,
            slot: AppLogoSlot.ui,
            hasCustom: appearance.uiLogo != null,
          ),
          const SizedBox(height: 12),
          const Text(
            'Recomendado: imagen cuadrada o apaisada, con fondo transparente '
            '(PNG). Se reduce sola a 512 px y puede pesar hasta 700 KB.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
