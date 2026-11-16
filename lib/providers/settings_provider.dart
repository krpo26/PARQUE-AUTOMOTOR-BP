import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Colores institucionales disponibles para elegir como acento de la app.
class AppColorOption {
  final String name;
  final Color color;
  const AppColorOption(this.name, this.color);
}

const List<AppColorOption> kColorOptions = [
  AppColorOption('Azul institucional', Color(0xFF0D47A1)),
  AppColorOption('Gris acero', Color(0xFF37474F)),
  AppColorOption('Verde', Color(0xFF2E7D32)),
  AppColorOption('Bordó', Color(0xFF8E1B2E)),
  AppColorOption('Dorado', Color(0xFFB8860B)),
  AppColorOption('Naranja', Color(0xFFE65100)),
  AppColorOption('Violeta', Color(0xFF6A1B9A)),
  AppColorOption('Turquesa', Color(0xFF00838F)),
  AppColorOption('Rojo', Color(0xFFC62828)),
  AppColorOption('Índigo', Color(0xFF283593)),
  AppColorOption('Marrón', Color(0xFF4E342E)),
  AppColorOption('Rosa', Color(0xFFAD1457)),
  AppColorOption('Verde oliva', Color(0xFF558B2F)),
  AppColorOption('Celeste', Color(0xFF0288D1)),
  AppColorOption('Grafito', Color(0xFF212121)),
  AppColorOption('Azul marino', Color(0xFF0B2A5B)),
  AppColorOption('Azul cielo', Color(0xFF1E88E5)),
  AppColorOption('Cian', Color(0xFF00ACC1)),
  AppColorOption('Esmeralda', Color(0xFF00A86B)),
  AppColorOption('Verde bosque', Color(0xFF1B5E20)),
  AppColorOption('Lima', Color(0xFF827717)),
  AppColorOption('Ámbar', Color(0xFFFF8F00)),
  AppColorOption('Coral', Color(0xFFE5533D)),
  AppColorOption('Lavanda', Color(0xFF7E57C2)),
  AppColorOption('Fucsia', Color(0xFFD81B60)),
  AppColorOption('Arena', Color(0xFF8D6E63)),
  AppColorOption('Pizarra', Color(0xFF455A64)),
];

/// Tema listo para usar: combina un color y el modo claro/oscuro (y opcionalmente
/// el fondo negro puro para pantallas OLED) con un solo toque.
class AppThemePreset {
  final String name;
  final String colorName;
  final ThemeMode mode;
  final bool amoled;
  const AppThemePreset(this.name, this.colorName, this.mode, {this.amoled = false});

  int get colorIndex {
    final i = kColorOptions.indexWhere((c) => c.name == colorName);
    return i < 0 ? 0 : i;
  }

  Color get color => kColorOptions[colorIndex].color;
}

const List<AppThemePreset> kThemePresets = [
  AppThemePreset('Institucional', 'Azul institucional', ThemeMode.light),
  AppThemePreset('Noche azul', 'Azul marino', ThemeMode.dark),
  AppThemePreset('Carbón (negro puro)', 'Grafito', ThemeMode.dark, amoled: true),
  AppThemePreset('Bosque', 'Verde bosque', ThemeMode.light),
  AppThemePreset('Océano', 'Cian', ThemeMode.light),
  AppThemePreset('Atardecer', 'Ámbar', ThemeMode.light),
  AppThemePreset('Burdeos nocturno', 'Bordó', ThemeMode.dark),
  AppThemePreset('Lavanda', 'Lavanda', ThemeMode.light),
  AppThemePreset('Menta', 'Esmeralda', ThemeMode.light),
  AppThemePreset('Pizarra', 'Pizarra', ThemeMode.dark),
  AppThemePreset('Arena', 'Arena', ThemeMode.light),
  AppThemePreset('Coral', 'Coral', ThemeMode.light),
];

/// Fuentes disponibles para el texto de toda la app. Los primeros
/// valores se mantienen en el mismo orden de siempre (se guarda la
/// posición), los nuevos van al final.
enum AppFont {
  system,
  roboto,
  poppins,
  montserrat,
  lato,
  openSans,
  nunito,
  raleway,
  ubuntu,
  oswald,
  inter,
  sourceSans,
  firaSans,
  quicksand,
  workSans,
  notoSans,
  merriweather,
  robotoSlab,
  playfair,
  lora,
  serif,
  mono,
  rubik,
  barlow,
  josefinSans,
  dmSans,
  manrope,
  karla,
  cabin,
  mulish,
  ptSans,
  titilliumWeb,
  archivo,
  ibmPlex,
  exo2,
  nunitoSans,
  spaceGrotesk,
  comfortaa,
  ptSerif,
  libreBaskerville,
}

extension AppFontX on AppFont {
  String get label {
    switch (this) {
      case AppFont.system:
        return 'Predeterminada';
      case AppFont.roboto:
        return 'Roboto';
      case AppFont.poppins:
        return 'Poppins';
      case AppFont.montserrat:
        return 'Montserrat';
      case AppFont.lato:
        return 'Lato';
      case AppFont.openSans:
        return 'Open Sans';
      case AppFont.nunito:
        return 'Nunito (redondeada)';
      case AppFont.raleway:
        return 'Raleway';
      case AppFont.ubuntu:
        return 'Ubuntu';
      case AppFont.oswald:
        return 'Oswald (angosta)';
      case AppFont.inter:
        return 'Inter';
      case AppFont.sourceSans:
        return 'Source Sans';
      case AppFont.firaSans:
        return 'Fira Sans';
      case AppFont.quicksand:
        return 'Quicksand';
      case AppFont.workSans:
        return 'Work Sans';
      case AppFont.notoSans:
        return 'Noto Sans';
      case AppFont.merriweather:
        return 'Merriweather (con serifa)';
      case AppFont.robotoSlab:
        return 'Roboto Slab (con serifa)';
      case AppFont.playfair:
        return 'Playfair Display (elegante)';
      case AppFont.lora:
        return 'Lora (con serifa)';
      case AppFont.serif:
        return 'Serif del sistema';
      case AppFont.mono:
        return 'Monoespaciada del sistema';
      case AppFont.rubik:
        return 'Rubik (redondeada)';
      case AppFont.barlow:
        return 'Barlow';
      case AppFont.josefinSans:
        return 'Josefin Sans (geométrica)';
      case AppFont.dmSans:
        return 'DM Sans';
      case AppFont.manrope:
        return 'Manrope';
      case AppFont.karla:
        return 'Karla';
      case AppFont.cabin:
        return 'Cabin';
      case AppFont.mulish:
        return 'Mulish';
      case AppFont.ptSans:
        return 'PT Sans';
      case AppFont.titilliumWeb:
        return 'Titillium Web (técnica)';
      case AppFont.archivo:
        return 'Archivo';
      case AppFont.ibmPlex:
        return 'IBM Plex Sans';
      case AppFont.exo2:
        return 'Exo 2 (moderna)';
      case AppFont.nunitoSans:
        return 'Nunito Sans';
      case AppFont.spaceGrotesk:
        return 'Space Grotesk';
      case AppFont.comfortaa:
        return 'Comfortaa (muy redondeada)';
      case AppFont.ptSerif:
        return 'PT Serif (con serifa)';
      case AppFont.libreBaskerville:
        return 'Libre Baskerville (clásica)';
    }
  }
}

/// Estilos de texto de cada letra. null = la predeterminada del
/// celular. Las letras de Google se bajan de internet la primera vez
/// que se usan y quedan guardadas; sin conexión se ve la
/// predeterminada hasta que se puedan bajar.
TextTheme? textThemeForFont(AppFont font) {
  switch (font) {
    case AppFont.system:
      return null;
    case AppFont.roboto:
      return GoogleFonts.robotoTextTheme();
    case AppFont.poppins:
      return GoogleFonts.poppinsTextTheme();
    case AppFont.montserrat:
      return GoogleFonts.montserratTextTheme();
    case AppFont.lato:
      return GoogleFonts.latoTextTheme();
    case AppFont.openSans:
      return GoogleFonts.openSansTextTheme();
    case AppFont.nunito:
      return GoogleFonts.nunitoTextTheme();
    case AppFont.raleway:
      return GoogleFonts.ralewayTextTheme();
    case AppFont.ubuntu:
      return GoogleFonts.ubuntuTextTheme();
    case AppFont.oswald:
      return GoogleFonts.oswaldTextTheme();
    case AppFont.inter:
      return GoogleFonts.interTextTheme();
    case AppFont.sourceSans:
      return GoogleFonts.sourceSans3TextTheme();
    case AppFont.firaSans:
      return GoogleFonts.firaSansTextTheme();
    case AppFont.quicksand:
      return GoogleFonts.quicksandTextTheme();
    case AppFont.workSans:
      return GoogleFonts.workSansTextTheme();
    case AppFont.notoSans:
      return GoogleFonts.notoSansTextTheme();
    case AppFont.merriweather:
      return GoogleFonts.merriweatherTextTheme();
    case AppFont.robotoSlab:
      return GoogleFonts.robotoSlabTextTheme();
    case AppFont.playfair:
      return GoogleFonts.playfairDisplayTextTheme();
    case AppFont.lora:
      return GoogleFonts.loraTextTheme();
    case AppFont.serif:
      return ThemeData(fontFamily: 'serif').textTheme;
    case AppFont.mono:
      return ThemeData(fontFamily: 'monospace').textTheme;
    case AppFont.rubik:
      return _googleTheme('Rubik');
    case AppFont.barlow:
      return _googleTheme('Barlow');
    case AppFont.josefinSans:
      return _googleTheme('Josefin Sans');
    case AppFont.dmSans:
      return _googleTheme('DM Sans');
    case AppFont.manrope:
      return _googleTheme('Manrope');
    case AppFont.karla:
      return _googleTheme('Karla');
    case AppFont.cabin:
      return _googleTheme('Cabin');
    case AppFont.mulish:
      return _googleTheme('Mulish');
    case AppFont.ptSans:
      return _googleTheme('PT Sans');
    case AppFont.titilliumWeb:
      return _googleTheme('Titillium Web');
    case AppFont.archivo:
      return _googleTheme('Archivo');
    case AppFont.ibmPlex:
      return _googleTheme('IBM Plex Sans');
    case AppFont.exo2:
      return _googleTheme('Exo 2');
    case AppFont.nunitoSans:
      return _googleTheme('Nunito Sans');
    case AppFont.spaceGrotesk:
      return _googleTheme('Space Grotesk');
    case AppFont.comfortaa:
      return _googleTheme('Comfortaa');
    case AppFont.ptSerif:
      return _googleTheme('PT Serif');
    case AppFont.libreBaskerville:
      return _googleTheme('Libre Baskerville');
  }
}

/// Letra de Google por nombre de familia. Si no se puede armar (nombre
/// inexistente), se usa la predeterminada del celular.
TextTheme? _googleTheme(String family) {
  try {
    return GoogleFonts.getTextTheme(family);
  } catch (_) {
    return null;
  }
}

/// Maneja las preferencias visuales del usuario: modo claro/oscuro,
/// color de acento, tipografía, y el ícono de cada sección principal
/// del dashboard (Vehículos, Choferes). Se guardan en el dispositivo
/// (no se sincronizan a la nube) y se aplican a toda la app vía
/// [FleetApp].
class SettingsProvider extends ChangeNotifier {
  static const _kThemeModeKey = 'settings_theme_mode';
  static const _kColorIndexKey = 'settings_color_index';
  static const _kFontKey = 'settings_font';
  static const _kAmoledKey = 'settings_amoled';
  static const _kTextScaleKey = 'settings_text_scale';
  static const _kVehiclesSectionIconKey = 'settings_vehicles_section_icon';
  static const _kDriversSectionIconKey = 'settings_drivers_section_icon';

  ThemeMode themeMode = ThemeMode.system;
  int colorIndex = 0;
  AppFont font = AppFont.system;
  bool amoled = false; // fondo negro puro en modo oscuro
  double textScale = 1.0; // tamaño general de la letra (0.85 a 1.4)
  String? vehiclesSectionIconKey;
  String? driversSectionIconKey;

  Color get seedColor => kColorOptions[colorIndex].color;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_kThemeModeKey);
    if (modeIndex != null && modeIndex < ThemeMode.values.length) {
      themeMode = ThemeMode.values[modeIndex];
    }
    colorIndex = prefs.getInt(_kColorIndexKey) ?? 0;
    if (colorIndex >= kColorOptions.length) colorIndex = 0;
    final fontIndex = prefs.getInt(_kFontKey);
    if (fontIndex != null && fontIndex < AppFont.values.length) {
      font = AppFont.values[fontIndex];
    }
    amoled = prefs.getBool(_kAmoledKey) ?? false;
    textScale = (prefs.getDouble(_kTextScaleKey) ?? 1.0).clamp(0.85, 1.4).toDouble();
    vehiclesSectionIconKey = prefs.getString(_kVehiclesSectionIconKey);
    driversSectionIconKey = prefs.getString(_kDriversSectionIconKey);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, mode.index);
  }

  Future<void> setColorIndex(int index) async {
    colorIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kColorIndexKey, index);
  }

  Future<void> setAmoled(bool value) async {
    amoled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAmoledKey, value);
  }

  Future<void> setTextScale(double value) async {
    textScale = value.clamp(0.85, 1.4).toDouble();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTextScaleKey, textScale);
  }

  /// Aplica un tema listo (color + modo + fondo negro) de una sola vez.
  Future<void> applyPreset(AppThemePreset p) async {
    themeMode = p.mode;
    colorIndex = p.colorIndex;
    amoled = p.amoled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, p.mode.index);
    await prefs.setInt(_kColorIndexKey, p.colorIndex);
    await prefs.setBool(_kAmoledKey, p.amoled);
  }

  Future<void> setFont(AppFont value) async {
    font = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFontKey, value.index);
  }

  Future<void> setVehiclesSectionIcon(String key) async {
    vehiclesSectionIconKey = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVehiclesSectionIconKey, key);
  }

  Future<void> setDriversSectionIcon(String key) async {
    driversSectionIconKey = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDriversSectionIconKey, key);
  }
}
