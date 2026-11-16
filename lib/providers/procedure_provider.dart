import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/complex.dart';
import '../models/procedure.dart';
import '../services/audit_service.dart';
import '../services/database_helper.dart';
import '../services/sync_service.dart';

/// Estado de los trámites (pedidos de service, compras, arreglos…) del
/// complejo en el que se está trabajando.
class ProcedureProvider extends ChangeNotifier {
  final List<Procedure> _items = [];
  bool isLoading = false;

  /// Complejo activo. null = todos (solo al arrancar).
  String? _complexId;
  String? get complexId => _complexId;

  Future<void> setComplex(String? id) async {
    _complexId = id;
    await load();
  }

  /// Todos los trámites del complejo, del más reciente al más antiguo.
  List<Procedure> get procedures => List.unmodifiable(_items);

  /// Cantidad de trámites todavía abiertos (iniciados o en trámite).
  int get openCount => _items.where((p) => p.isOpen).length;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final data =
        await DatabaseHelper.instance.getProcedures(complexId: _complexId);
    _items
      ..clear()
      ..addAll(data);
    isLoading = false;
    notifyListeners();
  }

  Future<void> addProcedure({
    required String type,
    required DateTime startDate,
    required String status,
    String fileNumber = '',
    String presentedAt = '',
    String? vehicleId,
    DateTime? endDate,
  }) async {
    final p = Procedure(
      id: const Uuid().v4(),
      type: type,
      startDate: startDate,
      status: status,
      fileNumber: fileNumber,
      presentedAt: presentedAt,
      complexId: _complexId ?? kDefaultComplexId,
      vehicleId: vehicleId,
      endDate: endDate,
    );
    await DatabaseHelper.instance.insertProcedure(p);
    await load();
    unawaited(SyncService.instance.pushProcedure(p));
    unawaited(AuditService.log(
      action: 'creó',
      entityType: 'Trámite',
      entityLabel: p.type,
    ));
  }

  Future<void> updateProcedure(Procedure p) async {
    final updated = p.copyWith(); // renueva updatedAt
    await DatabaseHelper.instance.updateProcedure(updated);
    await load();
    unawaited(SyncService.instance.pushProcedure(updated));
    unawaited(AuditService.log(
      action: 'editó',
      entityType: 'Trámite',
      entityLabel: updated.type,
    ));
  }

  Future<void> deleteProcedure(Procedure p) async {
    await DatabaseHelper.instance.deleteProcedure(p.id);
    await DatabaseHelper.instance.insertTombstone('procedure', p.id);
    await load();
    unawaited(SyncService.instance.deleteProcedureRemote(p.id));
    unawaited(SyncService.instance.pushTombstone('procedure', p.id));
    unawaited(AuditService.log(
      action: 'eliminó definitivamente',
      entityType: 'Trámite',
      entityLabel: p.type,
    ));
  }
}
