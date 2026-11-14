import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';

import '../models/fuel_log.dart';
import '../models/fuel_station.dart';
import '../models/vehicle.dart';
import '../models/vehicle_tech_sheet.dart';

/// Genera planillas en formato .csv de combustible y ficha técnica, y
/// las comparte con el mismo mecanismo que ya se usa para los PDF
/// (podés guardarlas, mandarlas por WhatsApp/mail, subirlas a Drive,
/// etc. desde el selector que abre el propio sistema operativo). Un
/// .csv se abre perfecto con doble clic en Excel o Google Sheets.
class ExcelExportService {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static const _monthNames = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  static Future<void> _writeAndShare({
    required List<List<dynamic>> rows,
    required String fileName,
    required String shareText,
  }) async {
    final csvText = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    // BOM UTF-8 para que Excel abra bien las tildes/ñ.
    await file.writeAsBytes(
      [0xEF, 0xBB, 0xBF, ...utf8Bytes(csvText)],
      flush: true,
    );
    await Share.shareXFiles([XFile(file.path)], text: shareText);
  }

  static List<int> utf8Bytes(String s) => const Utf8Codec().encode(s);

  /// Exporta las cargas de combustible de un vehículo correspondientes
  /// a un mes puntual (monthKey "2026-08"). El archivo generado
  /// corresponde SOLO a ese mes — para tener el historial completo de
  /// varios meses hay que exportar mes por mes, lo que deja un archivo
  /// separado por cada uno (igual que la planilla se "reinicia" cada
  /// mes en la app, pero sin perder nada de lo anterior).
  static Future<void> exportFuelLogsForMonth({
    required Vehicle vehicle,
    required String monthKey,
    required List<FuelLog> logs,
  }) async {
    String monthLabel;
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      monthLabel = '${_monthNames[month]} $year';
    } catch (_) {
      monthLabel = monthKey;
    }

    final rows = <List<dynamic>>[
      ['PARQUE AUTOMOTOR — Carga de combustible'],
      ['Vehículo: ${vehicle.internalNumber} — ${vehicle.plate}'],
      ['Mes: $monthLabel'],
      [],
      ['Fecha', 'Chofer', 'Litros', 'Kilometraje', 'Notas'],
    ];

    final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));
    for (final log in sorted) {
      rows.add([
        _dateFmt.format(log.date),
        log.driverName ?? '',
        log.liters,
        log.mileage,
        log.notes ?? '',
      ]);
    }

    final totalLiters = logs.fold(0.0, (sum, l) => sum + l.liters);
    rows.add([]);
    rows.add(['TOTAL', '', totalLiters]);

    final safePlate = vehicle.plate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    await _writeAndShare(
      rows: rows,
      fileName: 'combustible_${safePlate}_$monthKey.csv',
      shareText: 'Combustible ${vehicle.internalNumber} — $monthLabel',
    );
  }

  /// Exporta la ficha técnica de un vehículo: la tabla de renglones
  /// (FECHA, CHOFER, KILOMETRO, REPUESTOS, COMERCIO), igual que la
  /// planilla que se usaba antes.
  static Future<void> exportTechSheet({
    required Vehicle vehicle,
    required List<TechSheetEntry> entries,
  }) async {
    final brandModel =
        [vehicle.brand, vehicle.model].where((s) => s.isNotEmpty).join(' ');

    final rows = <List<dynamic>>[
      [
        'FICHA TECNICA DEL MOVIL TUC- $brandModel dominio '
            '${vehicle.plate} TUC- ${vehicle.internalNumber}',
      ],
      ['FECHA', 'CHOFER', 'KILOMETRO', 'REPUESTOS', 'COMERCIO'],
    ];

    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      rows.add([
        _dateFmt.format(e.date),
        e.driverName ?? '',
        e.mileage?.toString() ?? '',
        e.parts ?? '',
        e.shop ?? '',
      ]);
    }

    final safePlate = vehicle.plate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    await _writeAndShare(
      rows: rows,
      fileName: 'ficha_tecnica_$safePlate.csv',
      shareText: 'Ficha técnica ${vehicle.internalNumber}',
    );
  }

  /// Exporta un listado de estaciones de servicio (las que se están
  /// viendo en pantalla) para abrir en Excel o Google Sheets. Incluye
  /// una columna con el enlace de Google Maps de cada una. Usa ";"
  /// como separador porque así lo espera Excel en español.
  static Future<void> exportFuelStations({
    required List<FuelStation> stations,
    required String title,
  }) async {
    final rows = <List<dynamic>>[
      [
        'N°',
        'Nombre de fantasía',
        'Razón social',
        'CUIT',
        'Dirección',
        'Localidad',
        'Provincia',
        'Google Maps',
      ],
      for (var i = 0; i < stations.length; i++)
        [
          i + 1,
          stations[i].name,
          stations[i].owner,
          stations[i].cuit,
          stations[i].address,
          stations[i].locality,
          stations[i].province,
          'https://www.google.com/maps/search/?api=1&query='
              '${Uri.encodeComponent(stations[i].mapsAddress)}',
        ],
    ];
    final csvText =
        const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    final dir = await getTemporaryDirectory();
    final safe = title.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final file = File('${dir.path}/Estaciones_$safe.csv');
    await file.writeAsBytes(
      [0xEF, 0xBB, 0xBF, ...utf8Bytes(csvText)],
      flush: true,
    );
    await Share.shareXFiles([XFile(file.path)],
        text: 'Estaciones de servicio Ticket Car — $title');
  }
}
