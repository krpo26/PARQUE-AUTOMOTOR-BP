import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';

/// Arma el tema de la app a partir del color, la letra, el modo y el
/// estilo de superficie (estándar, negro puro, alto contraste, papel).
ThemeData buildAppTheme({
  required Brightness brightness,
  required Color seed,
  required AppFont font,
  AppThemeStyle style = AppThemeStyle.standard,
}) {
  var scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    contrastLevel: style == AppThemeStyle.highContrast ? 1.0 : 0.0,
  );
  Color? scaffold;
  if (style == AppThemeStyle.amoled && brightness == Brightness.dark) {
    scheme = scheme.copyWith(surface: Colors.black);
    scaffold = Colors.black;
  } else if (style == AppThemeStyle.paper && brightness == Brightness.light) {
    const paper = Color(0xFFF4ECD8);
    scheme = scheme.copyWith(surface: paper);
    scaffold = paper;
  }
  var theme = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
  final textTheme = textThemeForFont(font);
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

/// 'light' / 'dark' / 'system' -> ThemeMode (null si no hay valor).
ThemeMode? themeModeFromKey(String? key) {
  switch (key) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
  }
  return null;
}

/// Nombre guardado -> letra (null si no hay valor o ya no existe).
AppFont? fontFromKey(String? key) {
  if (key == null) return null;
  for (final f in AppFont.values) {
    if (f.name == key) return f;
  }
  return null;
}
