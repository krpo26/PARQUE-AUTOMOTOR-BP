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
  AppColorOption('Azul marino', Color(0xFF0B2545)),
  AppColorOption('Azul cielo', Color(0xFF1E88E5)),
  AppColorOption('Cian', Color(0xFF00ACC1)),
  AppColorOption('Verde esmeralda', Color(0xFF00796B)),
  AppColorOption('Verde bosque', Color(0xFF1B5E20)),
  AppColorOption('Lima', Color(0xFF9E9D24)),
  AppColorOption('Amarillo', Color(0xFFF9A825)),
  AppColorOption('Ámbar', Color(0xFFFF8F00)),
  AppColorOption('Terracota', Color(0xFFBF360C)),
  AppColorOption('Rojo oscuro', Color(0xFF7F0000)),
  AppColorOption('Magenta', Color(0xFFC2185B)),
  AppColorOption('Lavanda', Color(0xFF7E57C2)),
  AppColorOption('Púrpura oscuro', Color(0xFF4A148C)),
  AppColorOption('Gris azulado', Color(0xFF546E7A)),
  AppColorOption('Café', Color(0xFF6D4C41)),
  AppColorOption('Negro', Color(0xFF000000)),
];

/// Estilos de superficie del tema (además de claro/oscuro y del color).
enum AppThemeStyle { standard, amoled, highContrast, paper }

extension AppThemeStyleX on AppThemeStyle {
  String get label {
    switch (this) {
      case AppThemeStyle.standard:
        return 'Estándar';
      case AppThemeStyle.amoled:
        return 'Negro puro (oscuro, ahorra batería)';
      case AppThemeStyle.highContrast:
        return 'Alto contraste';
      case AppThemeStyle.paper:
        return 'Papel / sepia (claro, para leer)';
    }
  }
}

/// Tema listo para elegir con un toque: combina modo, color y estilo.
class ThemePreset {
  final String name;
  final String description;
  final ThemeMode mode;
  final String colorName; // nombre en [kColorOptions]
  final AppThemeStyle style;
  const ThemePreset(this.name, this.description, this.mode, this.colorName,
      [this.style = AppThemeStyle.standard]);

  int get colorIndex {
    final i = kColorOptions.indexWhere((c) => c.name == colorName);
    return i < 0 ? 0 : i;
  }
}

const List<ThemePreset> kThemePresets = [
  ThemePreset('Clásico institucional', 'Claro, azul institucional',
      ThemeMode.light, 'Azul institucional'),
  ThemePreset('Automático', 'Sigue al celular (claro u oscuro)',
      ThemeMode.system, 'Azul institucional'),
  ThemePreset('Noche', 'Oscuro, índigo', ThemeMode.dark, 'Índigo'),
  ThemePreset('Medianoche', 'Negro puro, ahorra batería', ThemeMode.dark,
      'Azul cielo', AppThemeStyle.amoled),
  ThemePreset('Alto contraste', 'Claro, textos muy marcados', ThemeMode.light,
      'Azul marino', AppThemeStyle.highContrast),
  ThemePreset('Alto contraste oscuro', 'Oscuro, textos muy marcados',
      ThemeMode.dark, 'Ámbar', AppThemeStyle.highContrast),
  ThemePreset('Papel', 'Fondo color papel, cómodo para leer', ThemeMode.light,
      'Café', AppThemeStyle.paper),
  ThemePreset('Bosque', 'Claro, verde bosque', ThemeMode.light, 'Verde bosque'),
  ThemePreset('Océano', 'Claro, azul cielo', ThemeMode.light, 'Azul cielo'),
  ThemePreset('Atardecer', 'Claro, terracota', ThemeMode.light, 'Terracota'),
  ThemePreset('Bordó', 'Claro, bordó', ThemeMode.light, 'Bordó'),
  ThemePreset('Lavanda', 'Claro, violeta suave', ThemeMode.light, 'Lavanda'),
  ThemePreset('Grafito', 'Oscuro, gris acero', ThemeMode.dark, 'Gris acero'),
  ThemePreset('Esmeralda nocturno', 'Oscuro, verde esmeralda', ThemeMode.dark,
      'Verde esmeralda'),
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
  karla,
  cabin,
  dmSans,
  manrope,
  ptSans,
  bitter,
  josefinSans,
  spaceGrotesk,
  libreBaskerville,
  cairo,
  titilliumWeb,
  mulish,
  outfit,
  lexend,
  archivo,
  atkinson,
  comfortaa,
  exo2,
  kanit,
  heebo,
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
        return 'Rubik';
      case AppFont.barlow:
        return 'Barlow';
      case AppFont.karla:
        return 'Karla';
      case AppFont.cabin:
        return 'Cabin';
      case AppFont.dmSans:
        return 'DM Sans';
      case AppFont.manrope:
        return 'Manrope';
      case AppFont.ptSans:
        return 'PT Sans';
      case AppFont.bitter:
        return 'Bitter (con serifa)';
      case AppFont.josefinSans:
        return 'Josefin Sans (elegante)';
      case AppFont.spaceGrotesk:
        return 'Space Grotesk';
      case AppFont.libreBaskerville:
        return 'Libre Baskerville (clásica)';
      case AppFont.cairo:
        return 'Cairo';
      case AppFont.titilliumWeb:
        return 'Titillium Web';
      case AppFont.mulish:
        return 'Mulish';
      case AppFont.outfit:
        return 'Outfit';
      case AppFont.lexend:
        return 'Lexend (fácil de leer)';
      case AppFont.archivo:
        return 'Archivo';
      case AppFont.atkinson:
        return 'Atkinson Hyperlegible (máxima legibilidad)';
      case AppFont.comfortaa:
        return 'Comfortaa (redondeada)';
      case AppFont.exo2:
        return 'Exo 2 (técnica)';
      case AppFont.kanit:
        return 'Kanit';
      case AppFont.heebo:
        return 'Heebo';
    }
  }
}

/// Estilos de texto de cada letra. null = la predeterminada del
/// celular. Las letras de Google se bajan de internet la primera vez
/// que se usan y quedan guardadas; sin conexión se ve la
/// predeterminada hasta que se puedan bajar.
/// Letra de Google por nombre de familia. Si el nombre no existe o algo
/// falla, devuelve null (queda la letra predeterminada del celular).
TextTheme? _googleTheme(String family) {
  try {
    return GoogleFonts.getTextTheme(family);
  } catch (_) {
    return null;
  }
}

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
    case AppFont.karla:
      return _googleTheme('Karla');
    case AppFont.cabin:
      return _googleTheme('Cabin');
    case AppFont.dmSans:
      return _googleTheme('DM Sans');
    case AppFont.manrope:
      return _googleTheme('Manrope');
    case AppFont.ptSans:
      return _googleTheme('PT Sans');
    case AppFont.bitter:
      return _googleTheme('Bitter');
    case AppFont.josefinSans:
      return _googleTheme('Josefin Sans');
    case AppFont.spaceGrotesk:
      return _googleTheme('Space Grotesk');
    case AppFont.libreBaskerville:
      return _googleTheme('Libre Baskerville');
    case AppFont.cairo:
      return _googleTheme('Cairo');
    case AppFont.titilliumWeb:
      return _googleTheme('Titillium Web');
    case AppFont.mulish:
      return _googleTheme('Mulish');
    case AppFont.outfit:
      return _googleTheme('Outfit');
    case AppFont.lexend:
      return _googleTheme('Lexend');
    case AppFont.archivo:
      return _googleTheme('Archivo');
    case AppFont.atkinson:
      return _googleTheme('Atkinson Hyperlegible');
    case AppFont.comfortaa:
      return _googleTheme('Comfortaa');
    case AppFont.exo2:
      return _googleTheme('Exo 2');
    case AppFont.kanit:
      return _googleTheme('Kanit');
    case AppFont.heebo:
      return _googleTheme('Heebo');
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
  static const _kThemeStyleKey = 'settings_theme_style';
  static const _kVehiclesSectionIconKey = 'settings_vehicles_section_icon';
  static const _kDriversSectionIconKey = 'settings_drivers_section_icon';

  ThemeMode themeMode = ThemeMode.system;
  int colorIndex = 0;
  AppFont font = AppFont.system;
  AppThemeStyle themeStyle = AppThemeStyle.standard;
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
    final styleIndex = prefs.getInt(_kThemeStyleKey);
    if (styleIndex != null && styleIndex < AppThemeStyle.values.length) {
      themeStyle = AppThemeStyle.values[styleIndex];
    }
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

  Future<void> setThemeStyle(AppThemeStyle value) async {
    themeStyle = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeStyleKey, value.index);
  }

  /// Aplica un tema listo (modo + color + estilo) de un solo toque.
  Future<void> applyPreset(ThemePreset p) async {
    themeMode = p.mode;
    colorIndex = p.colorIndex;
    themeStyle = p.style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, p.mode.index);
    await prefs.setInt(_kColorIndexKey, p.colorIndex);
    await prefs.setInt(_kThemeStyleKey, p.style.index);
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
