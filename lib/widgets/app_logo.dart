import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/appearance_provider.dart';
import '../providers/feature_flags_provider.dart';

/// Dónde se usa el logo: en las pantallas de entrada o en la interfaz.
enum AppLogoKind { login, interface }

/// Logo institucional de la app. Orden de prioridad:
/// 1) el logo general que cargó el admin para ese lugar (inicio o
///    interfaz), 2) el logo propio del complejo, 3) el logo de fábrica.
class AppLogo extends StatelessWidget {
  final double height;
  final AppLogoKind kind;

  /// Complejo cuyo logo mostrar. Si no se indica, se usa el complejo
  /// en el que se está trabajando (si hay uno).
  final String? complexId;

  const AppLogo({
    super.key,
    required this.height,
    this.kind = AppLogoKind.interface,
    this.complexId,
  });

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceProvider>();
    var bytes = kind == AppLogoKind.login
        ? appearance.loginLogo
        : appearance.interfaceLogo;
    if (bytes == null) {
      final id = complexId ?? appearance.activeComplexId;
      if (id != null) bytes = appearance.logoOf(id);
    }
    if (bytes != null) {
      return Image.memory(bytes, height: height, fit: BoxFit.contain);
    }
    final asset = context.watch<FeatureFlagsProvider>().logoAsset;
    return Image.asset(asset, height: height);
  }
}
