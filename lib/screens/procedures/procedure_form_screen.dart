import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/procedure.dart';
import '../../providers/procedure_provider.dart';
import '../../providers/vehicle_provider.dart';

/// Alta / edición / detalle de un trámite.
/// [procedure] null = alta. [readOnly] true = usuario común (solo ve).
class ProcedureFormScreen extends StatefulWidget {
  final Procedure? procedure;
  final bool readOnly;

  const ProcedureFormScreen({super.key, this.procedure, this.readOnly = false});

  @override
  State<ProcedureFormScreen> createState() => _ProcedureFormScreenState();
}

class _ProcedureFormScreenState extends State<ProcedureFormScreen> {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _otherTypeCtrl;
  late final TextEditingController _fileNumberCtrl;
  late final TextEditingController _presentedAtCtrl;
  DateTime? _endDate;
  String _vehicleId = ''; // '' = sin móvil
  late String _typeChoice; // uno de Procedure.types o Procedure.otherType
  late String _status;
  late DateTime _startDate;

  bool get _isEditing => widget.procedure != null;

  @override
  void initState() {
    super.initState();
    final p = widget.procedure;
    if (p == null) {
      _typeChoice = Procedure.types.first;
      _otherTypeCtrl = TextEditingController();
      _status = Procedure.statusStarted;
      _startDate = DateTime.now();
      _fileNumberCtrl = TextEditingController();
      _presentedAtCtrl = TextEditingController();
    } else {
      final isPreset = Procedure.types.contains(p.type);
      _typeChoice = isPreset ? p.type : Procedure.otherType;
      _otherTypeCtrl = TextEditingController(text: isPreset ? '' : p.type);
      _status = Procedure.statuses.contains(p.status)
          ? p.status
          : Procedure.statusStarted;
      _startDate = p.startDate;
      _fileNumberCtrl = TextEditingController(text: p.fileNumber);
      _presentedAtCtrl = TextEditingController(text: p.presentedAt);
      _endDate = p.endDate;
      _vehicleId = p.vehicleId;
    }
  }

  @override
  void dispose() {
    _otherTypeCtrl.dispose();
    _fileNumberCtrl.dispose();
    _presentedAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _onStatusChanged(String? v) {
    if (v == null) return;
    setState(() {
      _status = v;
      // Al finalizar o rechazar se propone la fecha de hoy.
      if (!(v == Procedure.statusDone || v == Procedure.statusRejected)) return;
      _endDate ??= DateTime.now();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ProcedureProvider>();
    final type = _typeChoice == Procedure.otherType
        ? _otherTypeCtrl.text.trim()
        : _typeChoice;
    final fileNumber = _fileNumberCtrl.text.trim();
    final presentedAt = _presentedAtCtrl.text.trim();
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La fecha de finalización no puede ser anterior a la de inicio.')));
      return;
    }
    final vehicles = context.read<VehicleProvider>().vehicles;
    final matches = vehicles.where((v) => v.id == _vehicleId);
    final vehicleNumber = matches.isNotEmpty
        ? matches.first.internalNumber
        : (widget.procedure?.vehicleId == _vehicleId
            ? widget.procedure!.vehicleNumber
            : '');

    if (_isEditing) {
      await provider.updateProcedure(widget.procedure!.copyWith(
        type: type,
        startDate: _startDate,
        status: _status,
        endDate: _endDate,
        clearEndDate: _endDate == null,
        fileNumber: fileNumber,
        presentedAt: presentedAt,
        vehicleId: _vehicleId,
        vehicleNumber: vehicleNumber,
      ));
    } else {
      await provider.addProcedure(
        type: type,
        startDate: _startDate,
        status: _status,
        endDate: _endDate,
        fileNumber: fileNumber,
        presentedAt: presentedAt,
        vehicleId: _vehicleId,
        vehicleNumber: vehicleNumber,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar trámite'),
        content: const Text('¿Seguro que querés eliminar este trámite?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context
          .read<ProcedureProvider>()
          .deleteProcedure(widget.procedure!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    return Scaffold(
      appBar: AppBar(
        title: Text(readOnly
            ? 'Detalle del trámite'
            : (_isEditing ? 'Editar trámite' : 'Nuevo trámite')),
        actions: [
          if (_isEditing && !readOnly)
            IconButton(
                tooltip: 'Eliminar',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _typeChoice,
              decoration: const InputDecoration(
                labelText: 'Trámite',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in [...Procedure.types, Procedure.otherType])
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: readOnly
                  ? null
                  : (v) => setState(() => _typeChoice = v ?? _typeChoice),
            ),
            if (_typeChoice == Procedure.otherType) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _otherTypeCtrl,
                enabled: !readOnly,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre del trámite',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribí el nombre del trámite'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: readOnly ? null : _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de inicio del trámite',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.event),
                ),
                child: Text(_dateFmt.format(_startDate)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Estado del trámite',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in Procedure.statuses)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: readOnly ? null : _onStatusChanged,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: readOnly ? null : _pickEndDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha de finalización (opcional)',
                  border: const OutlineInputBorder(),
                  suffixIcon: (!readOnly && _endDate != null)
                      ? IconButton(
                          tooltip: 'Quitar fecha',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _endDate = null),
                        )
                      : const Icon(Icons.event_available),
                ),
                child: Text(_endDate == null
                    ? (readOnly ? 'Sin dato' : 'Seleccionar fecha')
                    : _dateFmt.format(_endDate!)),
              ),
            ),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final vehicles = [...context.watch<VehicleProvider>().vehicles]
                ..sort((a, b) => a.internalNumber.compareTo(b.internalNumber));
              final known = vehicles.any((v) => v.id == _vehicleId);
              final savedNumber = widget.procedure?.vehicleNumber ?? '';
              return DropdownButtonFormField<String>(
                value: (_vehicleId.isEmpty || known || savedNumber.isNotEmpty)
                    ? _vehicleId
                    : '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Móvil',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Sin móvil / general')),
                  if (_vehicleId.isNotEmpty && !known)
                    DropdownMenuItem(
                        value: _vehicleId,
                        child: Text('Móvil $savedNumber (dado de baja)')),
                  for (final v in vehicles)
                    DropdownMenuItem(
                      value: v.id,
                      child: Text(
                          '${v.internalNumber} · ${v.brand} ${v.model} · ${v.plate}'
                              .trim(),
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: readOnly
                    ? null
                    : (v) => setState(() => _vehicleId = v ?? ''),
              );
            }),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fileNumberCtrl,
              enabled: !readOnly,
              decoration: const InputDecoration(
                labelText: 'Número de expediente (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _presentedAtCtrl,
              enabled: !readOnly,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Dónde se presentó (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (!readOnly) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
