import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/appearance_provider.dart';
import '../providers/feature_flags_provider.dart';

/// Dónde se muestra el logo.
/// - [home]: pantallas de inicio (ingreso, bienvenida, administrador).
/// - [ui]: interfaz de trabajo (barra superior, tableros).
enum AppLogoSlot { home, ui }

/// Logo institucional de la app. El administrador puede cargar uno propio
/// para el inicio y otro para la interfaz (Panel de administración →
/// Logos de la app). Si no cargó ninguno, se usa el logo original.
/// En la interfaz, si el complejo en el que se trabaja tiene logo propio,
/// ese tiene prioridad.
class AppLogo extends StatelessWidget {
  final double height;

  /// Complejo cuyo logo mostrar (solo en [AppLogoSlot.ui]). Si no se
  /// indica, se usa el complejo en el que se está trabajando.
  final String? complexId;
  final AppLogoSlot slot;

  const AppLogo({
    super.key,
    required this.height,
    this.complexId,
    this.slot = AppLogoSlot.ui,
  });

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceProvider>();
    Uint8List? bytes;
    if (slot == AppLogoSlot.home) {
      bytes = appearance.homeLogo;
    } else {
      final id = complexId ?? appearance.activeComplexId;
      if (id != null) bytes = appearance.logoOf(id);
      bytes ??= appearance.uiLogo;
    }
    final asset = context.watch<FeatureFlagsProvider>().logoAsset;
    final fallback = Image.asset(
      asset,
      height: height,
      errorBuilder: (_, __, ___) =>
          Image.asset('assets/images/logo.png', height: height),
    );
    if (bytes == null) return fallback;
    return Image.memory(
      bytes,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
