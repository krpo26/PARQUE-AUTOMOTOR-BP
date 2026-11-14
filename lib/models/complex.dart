import 'package:flutter/material.dart';

/// Complejo penitenciario. Cada uno tiene su propia sección dentro de
/// la app, con sus propios vehículos (móviles) y choferes.
class Complex {
  final String id;
  final String name;
  final String shortName;
  final IconData icon;
  final Color color;

  const Complex({
    required this.id,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.color,
  });
}

/// Complejo al que pertenecen los datos cargados ANTES de existir las
/// 4 secciones (todo lo que ya estaba en la app era de Benjamín Paz).
const String kDefaultComplexId = 'benjamin_paz';

/// Único complejo de la app.
const List<Complex> kComplexes = [
  Complex(
    id: 'benjamin_paz',
    name: 'COMPLEJO PENITENCIARIO BENJAMIN PAZ',
    shortName: 'BENJAMIN PAZ',
    icon: Icons.shield_outlined,
    color: Color(0xFF1565C0),
  ),
];

Complex complexById(String id) => kComplexes.firstWhere(
      (c) => c.id == id,
      orElse: () => kComplexes.first,
    );
