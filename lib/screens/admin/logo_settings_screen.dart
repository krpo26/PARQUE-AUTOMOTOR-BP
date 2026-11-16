import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/appearance_provider.dart';
import '../../widgets/app_logo.dart';

/// Pantalla del administrador para cambiar los logos de la app:
/// - Logo de inicio: pantallas de entrada (inicio de sesión, acceso admin).
/// - Logo de la interfaz: pantalla principal de la app.
/// Se guardan en la nube y se ven en todos los celulares.
class LogoSettingsScreen extends StatefulWidget {
  const LogoSettingsScreen({super.key});

  @override
  State<LogoSettingsScreen> createState() => _LogoSettingsScreenState();
}

class _LogoSettingsScreenState extends State<LogoSettingsScreen> {
  bool _busy = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pick(String id) async {
    final provider = context.read<AppearanceProvider>();
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 650 * 1024) {
        _snack('La imagen es muy pesada (máximo 650 KB). Elegí una más chica.');
        return;
      }
      await provider.saveGlobalLogo(id, base64Encode(bytes));
      _snack('Logo guardado.');
    } catch (_) {
      _snack('No se pudo abrir la galería o leer la imagen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    setState(() => _busy = true);
    try {
      await context.read<AppearanceProvider>().saveGlobalLogo(id, null);
      _snack('Se vuelve a usar el logo original.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card({
    required String title,
    required String help,
    required String id,
    required AppLogoKind kind,
    required bool hasCustom,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(help, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 16),
            Center(child: AppLogo(height: 110, kind: kind)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _pick(id),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Elegir imagen'),
                ),
                if (hasCustom)
                  TextButton.icon(
                    onPressed: _busy ? null : () => _remove(id),
                    icon: const Icon(Icons.restore),
                    label: const Text('Volver al original'),
                  ),
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
          _card(
            title: 'Logo de inicio',
            help: 'Se ve en las pantallas de entrada: inicio de sesión y '
                'acceso de administrador.',
            id: AppearanceProvider.kLoginLogoId,
            kind: AppLogoKind.login,
            hasCustom: appearance.loginLogo != null,
          ),
          _card(
            title: 'Logo de la interfaz',
            help: 'Se ve en la pantalla principal de la app, arriba del '
                'nombre del complejo.',
            id: AppearanceProvider.kInterfaceLogoId,
            kind: AppLogoKind.interface,
            hasCustom: appearance.interfaceLogo != null,
          ),
          const Text(
            'Consejos: usá una imagen cuadrada o apaisada, preferentemente PNG '
            'con fondo transparente. Se reduce sola a 600 px. Los cambios '
            'llegan a los demás celulares con la sincronización.',
            style: TextStyle(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
