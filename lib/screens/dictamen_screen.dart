import 'package:flutter/material.dart';

import '../models/dictamen.dart';
import '../models/pedido.dart';
import '../services/inspeccion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/dictamen_widgets.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';

/// El inspector técnico aprueba o rechaza el equipo (HU08).
///
/// Ve el resumen del checklist, elige el resultado y, si hace falta,
/// escribe el motivo. El dictamen es definitivo, por eso se confirma antes.
class DictamenScreen extends StatefulWidget {
  const DictamenScreen({super.key, required this.pedido});

  final Pedido pedido;

  @override
  State<DictamenScreen> createState() => _DictamenScreenState();
}

class _DictamenScreenState extends State<DictamenScreen> {
  static const Color _verde = Color(0xFF1F7A44);
  static const Color _rojo = Color(0xFFB3261E);

  final _motivo = TextEditingController();
  ResultadoDictamen? _resultado;
  bool _intento = false;
  bool _emitiendo = false;
  String? _error;

  int get _fallas => widget.pedido.inspeccion?.fallas ?? 0;

  @override
  void initState() {
    super.initState();
    // Vuelve a revisar el motivo mientras se escribe.
    _motivo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  String? get _problema => ReglasDictamen.motivo(
        resultado: _resultado,
        motivo: _motivo.text,
        fallas: _fallas,
      );

  Future<void> _emitir() async {
    if (_emitiendo) return;
    setState(() {
      _intento = true;
      _error = null;
    });
    final resultado = _resultado;
    if (_problema != null || resultado == null) return;

    final aprobado = resultado == ResultadoDictamen.aprobado;
    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(aprobado ? '¿Aprobar el equipo?' : '¿Rechazar el equipo?'),
        content: Text(
          aprobado
              ? 'El dictamen es definitivo. El comprador y el vendedor verán '
                  'que el equipo pasó la inspección.'
              : 'El dictamen es definitivo. El comprador y el vendedor verán '
                  'el motivo del rechazo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: aprobado ? _verde : _rojo,
            ),
            child: Text(aprobado ? 'Sí, aprobar' : 'Sí, rechazar'),
          ),
        ],
      ),
    );
    if (seguro != true || !mounted) return;

    setState(() => _emitiendo = true);
    try {
      await InspeccionService.instancia.emitirDictamen(
        widget.pedido,
        resultado: resultado,
        motivo: _motivo.text,
      );
      if (!mounted) return;
      mostrarAviso(
        context,
        'Dictamen emitido: pedido ${widget.pedido.codigo} '
        '${aprobado ? 'aprobado' : 'rechazado'}.',
      );
      Navigator.of(context).pop();
    } on ErrorDeInspeccion catch (error) {
      if (!mounted) return;
      mostrarAviso(context, 'No se emitió: ${error.mensaje}');
      setState(() {
        _error = error.mensaje;
        _emitiendo = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final equipo = pedido.equipo;
    final inspeccion = pedido.inspeccion;
    final pideMotivo = _resultado == ResultadoDictamen.rechazado ||
        (_resultado == ResultadoDictamen.aprobado && _fallas > 0);

    return PaginaBase(
      anchoContenido: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BotonVolver(texto: 'Volver al panel'),
          const SizedBox(height: 16),
          Text('Dictamen · Pedido ${pedido.codigo}', style: Tipos.titulo),
          const SizedBox(height: 18),
          Pegatina(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: ImagenEquipo(equipo: equipo),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(equipo.titulo, style: Tipos.subtitulo),
                        const SizedBox(height: 4),
                        Text(
                          'El vendedor declaró: ${equipo.estadoDeclarado}',
                          style: Tipos.pequeno,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _fallas == 0
                ? 'Checklist: sin fallas'
                : 'Checklist: ${_fallas == 1 ? '1 falla' : '$_fallas fallas'}',
            style: Tipos.subtitulo.copyWith(
              color: _fallas == 0 ? _verde : _rojo,
            ),
          ),
          const SizedBox(height: 8),
          if (inspeccion == null)
            const RecuadroInfo(
              icono: Icons.warning_amber_rounded,
              texto: 'Este pedido no tiene checklist guardado.',
            )
          else
            ResumenChecklist(inspeccion: inspeccion, categoria: equipo.categoria),
          const SizedBox(height: 24),
          const Text('¿Cuál es el dictamen?', style: Tipos.subtitulo),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OpcionDictamen(
                  texto: 'Aprobar',
                  ayuda: 'Pasa la inspección',
                  icono: Icons.verified,
                  color: _verde,
                  elegida: _resultado == ResultadoDictamen.aprobado,
                  alTocar: _emitiendo
                      ? null
                      : () => setState(
                          () => _resultado = ResultadoDictamen.aprobado),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OpcionDictamen(
                  texto: 'Rechazar',
                  ayuda: 'No pasa la inspección',
                  icono: Icons.cancel_outlined,
                  color: _rojo,
                  elegida: _resultado == ResultadoDictamen.rechazado,
                  alTocar: _emitiendo
                      ? null
                      : () => setState(
                          () => _resultado = ResultadoDictamen.rechazado),
                ),
              ),
            ],
          ),
          if (pideMotivo) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _motivo,
              enabled: !_emitiendo,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _resultado == ResultadoDictamen.rechazado
                    ? 'Motivo del rechazo'
                    : 'Por qué se aprueba a pesar de las fallas',
                hintText: _resultado == ResultadoDictamen.rechazado
                    ? 'Ejemplo: la batería está inflada y no coincide con lo '
                        'declarado por el vendedor.'
                    : 'Ejemplo: el rayón en la tapa coincide con lo que '
                        'declaró el vendedor.',
                hintStyle: const TextStyle(color: Color(0xFF6B7088)),
                helperText: 'Lo leerán el comprador y el vendedor.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (_intento && _problema != null) ...[
            const SizedBox(height: 8),
            Text(
              _problema!,
              style: const TextStyle(fontSize: 12.5, color: _rojo, height: 1.3),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            RecuadroInfo(
              icono: Icons.error_outline,
              color: const Color(0xFFFBE9E8),
              colorIcono: _rojo,
              colorTexto: _rojo,
              texto: _error!,
            ),
          ],
          const SizedBox(height: 24),
          if (_emitiendo)
            const Center(
              child: CircularProgressIndicator(color: ColoresApp.orquidea),
            )
          else
            BotonPegatina(
              texto: 'Emitir dictamen',
              icono: Icons.gavel_outlined,
              expandido: true,
              alTocar: _emitir,
            ),
        ],
      ),
    );
  }
}

/// Opción grande con color, ícono y texto.
class _OpcionDictamen extends StatelessWidget {
  const _OpcionDictamen({
    required this.texto,
    required this.ayuda,
    required this.icono,
    required this.color,
    required this.elegida,
    required this.alTocar,
  });

  final String texto;
  final String ayuda;
  final IconData icono;
  final Color color;
  final bool elegida;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: elegida,
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: elegida ? color : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: elegida ? color : ColoresApp.tinta, width: 2),
          ),
          child: Column(
            children: [
              Icon(icono, size: 32, color: elegida ? Colors.white : color),
              const SizedBox(height: 6),
              Text(
                texto,
                style: Tipos.subtitulo.copyWith(
                  color: elegida ? Colors.white : ColoresApp.tinta,
                ),
              ),
              Text(
                ayuda,
                textAlign: TextAlign.center,
                style: Tipos.pequeno.copyWith(
                  color: elegida ? Colors.white : ColoresApp.pizarra,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
