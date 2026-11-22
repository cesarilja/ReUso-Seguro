import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/escala.dart';
import '../models/inspeccion.dart';
import '../models/pedido.dart';
import '../models/plan_inspeccion.dart';
import '../services/inspeccion_service.dart';
import '../services/publicacion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import '../widgets/plan_widgets.dart';

/// Checklist digital de inspección de un equipo (HU07).
///
/// HU15: el inspector califica cada punto del 1 al 4 (4 Excelente,
/// 3 Bueno, 2 Regular, 1 Malo) o «No aplica» en los opcionales. Una nota de
/// 1 o 2 es una falla y pide una nota y al menos una foto de evidencia. En la
/// inspección Detallada (HU16) cada punto lleva además una observación.
/// Arriba se ve cuántos puntos van listos y el puntaje general.
class InspeccionScreen extends StatefulWidget {
  const InspeccionScreen({super.key, required this.pedido, this.inspeccion});

  final Pedido pedido;

  /// El checklist que ya se había guardado, si existe (para corregirlo).
  final Inspeccion? inspeccion;

  @override
  State<InspeccionScreen> createState() => _InspeccionScreenState();
}

class _InspeccionScreenState extends State<InspeccionScreen> {
  static const Color _rojo = Color(0xFFB3261E);

  /// Los puntos que tocan según el tipo de equipo (no es lo mismo revisar
  /// unos audífonos que una laptop).
  late final List<PuntoChecklist> _checklist =
      PuntoChecklist.para(widget.pedido.equipo.categoria);

  /// HU16: el plan que pagó el vendedor (igual que en el servidor).
  late final PlanInspeccion _plan = widget.pedido.equipo.plan;
  late final Map<String, BorradorPunto> _borradores = {
    for (final punto in _checklist)
      punto.clave: BorradorPunto.desde(widget.inspeccion?.puntos[punto.clave]),
  };
  late final Map<String, TextEditingController> _notas = {
    for (final punto in _checklist)
      punto.clave: TextEditingController(text: _borradores[punto.clave]!.nota),
  };

  bool _intento = false;
  bool _guardando = false;
  bool _huboCambios = false;
  String? _error;

  @override
  void dispose() {
    for (final controlador in _notas.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  int get _revisados => _borradores.values
      .where((b) => ReglasInspeccion.punto(b, plan: _plan) == null)
      .length;

  Iterable<Calificacion?> get _notasDadas => _borradores.values
      .where((b) => !b.noAplica)
      .map((b) => b.calificacion);

  void _calificar(PuntoChecklist punto, Calificacion nota) {
    setState(() {
      _borradores[punto.clave]!.calificar(nota);
      _huboCambios = true;
      _error = null;
    });
  }

  void _marcarNoAplica(PuntoChecklist punto) {
    setState(() {
      _borradores[punto.clave]!.marcarNoAplica();
      _huboCambios = true;
      _error = null;
    });
  }

  Future<void> _agregarFotos(PuntoChecklist punto) async {
    final borrador = _borradores[punto.clave]!;
    final espacio = ReglasInspeccion.maximoFotosPorPunto - borrador.totalFotos;
    if (espacio <= 0) return;

    try {
      final archivos = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
      );
      final rechazos = <String>[];
      for (final archivo in archivos.take(espacio)) {
        final nombre = archivo.name.toLowerCase();
        final tipo = archivo.mimeType ??
            (nombre.endsWith('.png')
                ? 'image/png'
                : nombre.endsWith('.webp')
                    ? 'image/webp'
                    : 'image/jpeg');
        final foto = FotoElegida(
          bytes: await archivo.readAsBytes(),
          nombre: archivo.name,
          tipo: tipo == 'image/jpg' ? 'image/jpeg' : tipo,
        );
        final problema = ReglasPublicacion.foto(foto);
        if (problema == null) {
          borrador.nuevas.add(foto);
        } else {
          rechazos.add(problema);
        }
      }
      if (!mounted) return;
      setState(() => _huboCambios = true);
      if (rechazos.isNotEmpty) mostrarAviso(context, rechazos.first);
    } catch (_) {
      if (mounted) mostrarAviso(context, 'No pudimos abrir las fotos.');
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    for (final punto in _checklist) {
      _borradores[punto.clave]!.nota = _notas[punto.clave]!.text;
    }
    setState(() {
      _intento = true;
      _error = null;
    });

    final pendientes = _checklist
        .where((p) =>
            ReglasInspeccion.punto(_borradores[p.clave]!, plan: _plan) != null)
        .map((p) => p.nombre)
        .toList();
    if (pendientes.isNotEmpty) {
      mostrarAviso(context, 'Faltan puntos por completar: ${pendientes.join(', ')}.');
      setState(() {
        _error = 'Falta completar: ${pendientes.join(', ')}. Revisa lo marcado '
            'en rojo.';
      });
      return;
    }

    setState(() => _guardando = true);
    try {
      await InspeccionService.instancia.guardar(widget.pedido, _borradores);
      if (!mounted) return;
      mostrarAviso(
        context,
        'Guardamos el checklist del pedido ${widget.pedido.codigo}.',
      );
      Navigator.of(context).pop();
    } on ErrorDeInspeccion catch (error) {
      if (!mounted) return;
      // El error se ve junto al botón y también abajo de la pantalla, para
      // que no pase desapercibido.
      mostrarAviso(context, 'No se guardó: ${error.mensaje}');
      setState(() {
        _error = error.mensaje;
        _guardando = false;
      });
    }
  }

  Future<void> _alIntentarSalir(bool yaSalio, Object? _) async {
    if (yaSalio || _guardando) return;
    final salir = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Se perderá lo que marcaste en este checklist.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Seguir revisando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: TextButton.styleFrom(foregroundColor: _rojo),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (salir == true && mounted) Navigator.of(context).pop();
  }

  String _tipoDeEquipo(String? categoria) => switch (categoria) {
        'Laptop' => 'laptop',
        'Teléfono' => 'teléfono',
        'Tablet' => 'tablet',
        'Consola' => 'consola',
        'Audio' => 'audio (audífonos o parlantes)',
        _ => 'equipo de otro tipo',
      };

  @override
  Widget build(BuildContext context) {
    final pedido = widget.pedido;
    final equipo = pedido.equipo;
    final total = _checklist.length;
    final revisados = _revisados;
    final puntaje = ReglasEscala.puntaje(_notasDadas);
    final sugerirRechazo = ReglasEscala.sugerirRechazo(_notasDadas);

    return PopScope(
      canPop: !_huboCambios && !_guardando,
      onPopInvokedWithResult: _alIntentarSalir,
      child: PaginaBase(
        anchoContenido: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.tinta),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver al panel'),
            ),
            const SizedBox(height: 16),
            Text('Checklist · Pedido ${pedido.codigo}', style: Tipos.titulo),
            const SizedBox(height: 4),
            Text(
              'Checklist de ${_tipoDeEquipo(equipo.categoria)}: $total puntos. '
              'Califica cada uno del 1 al 4.',
              style: Tipos.cuerpo,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_plan == PlanInspeccion.detallada)
                  const SelloDetallada()
                else
                  const Text('Inspección básica', style: Tipos.pequeno),
                if (equipo.express)
                  Text(
                    'Express: revisar en menos de 24 h',
                    style: Tipos.pequeno.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ColoresApp.tinta,
                    ),
                  ),
              ],
            ),
            if (_plan == PlanInspeccion.detallada) ...[
              const SizedBox(height: 6),
              const Text(
                'El vendedor pagó la inspección detallada: escribe una '
                'observación en cada punto que califiques.',
                style: Tipos.pequeno,
              ),
            ],
            const SizedBox(height: 18),
            // Lo que declaró el vendedor, para compararlo con el equipo.
            Pegatina(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: ImagenEquipo(equipo: equipo),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(equipo.titulo, style: Tipos.subtitulo),
                          const SizedBox(height: 6),
                          Text(
                            'El vendedor declaró:',
                            style: Tipos.pequeno.copyWith(
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.tinta,
                            ),
                          ),
                          Text(equipo.estadoDeclarado, style: Tipos.pequeno),
                          const SizedBox(height: 4),
                          Text(equipo.descripcion, style: Tipos.pequeno),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Visibilidad del estado: cuántos puntos van listos.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$revisados de $total puntos listos',
                    style: Tipos.subtitulo.copyWith(fontSize: 15),
                  ),
                ),
                if (revisados == total)
                  const Icon(Icons.check_circle, color: Color(0xFF1F7A44)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: revisados / total,
                minHeight: 10,
                backgroundColor: ColoresApp.nube,
                color: revisados == total
                    ? const Color(0xFF1F7A44)
                    : ColoresApp.orquidea,
              ),
            ),
            if (puntaje != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  EtiquetaPuntaje(puntaje: puntaje),
                  if (sugerirRechazo)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: _rojo),
                        const SizedBox(width: 4),
                        Text(
                          'Sugerencia: rechazar (hay un punto en 1 o el '
                          'promedio es menor que 2,5).',
                          style: Tipos.pequeno.copyWith(color: _rojo),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            for (final punto in _checklist) ...[
              _TarjetaPunto(
                punto: punto,
                borrador: _borradores[punto.clave]!,
                nota: _notas[punto.clave]!,
                plan: _plan,
                declarado: Calificacion.desde(equipo.autoevaluacion[punto.clave]),
                error: _intento
                    ? ReglasInspeccion.punto(_borradores[punto.clave]!, plan: _plan)
                    : null,
                habilitado: !_guardando,
                alCalificar: (nota) => _calificar(punto, nota),
                alNoAplica: () => _marcarNoAplica(punto),
                alEscribir: (texto) {
                  _borradores[punto.clave]!.nota = texto;
                  setState(() => _huboCambios = true);
                },
                alAgregarFotos: () => _agregarFotos(punto),
                alQuitarNueva: (i) => setState(() {
                  _borradores[punto.clave]!.nuevas.removeAt(i);
                  _huboCambios = true;
                }),
                alQuitarGuardada: (i) => setState(() {
                  _borradores[punto.clave]!.guardadas.removeAt(i);
                  _huboCambios = true;
                }),
              ),
              const SizedBox(height: 14),
            ],
            if (_error != null) ...[
              RecuadroInfo(
                icono: Icons.error_outline,
                color: const Color(0xFFFBE9E8),
                colorIcono: _rojo,
                colorTexto: _rojo,
                texto: _error!,
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            if (_guardando)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: ColoresApp.nube,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: ColoresApp.orquidea,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Guardando el checklist…',
                      style: Tipos.boton.copyWith(color: ColoresApp.tinta),
                    ),
                  ],
                ),
              )
            else
              BotonPegatina(
                texto: 'Guardar checklist',
                icono: Icons.save_outlined,
                expandido: true,
                alTocar: _guardar,
              ),
          ],
        ),
      ),
    );
  }
}

/// Un punto del checklist: la nota del 1 al 4 y, si hay falla, la
/// descripción y las fotos de evidencia.
class _TarjetaPunto extends StatelessWidget {
  const _TarjetaPunto({
    required this.punto,
    required this.borrador,
    required this.nota,
    required this.plan,
    required this.declarado,
    required this.error,
    required this.habilitado,
    required this.alCalificar,
    required this.alNoAplica,
    required this.alEscribir,
    required this.alAgregarFotos,
    required this.alQuitarNueva,
    required this.alQuitarGuardada,
  });

  static const Color _rojo = Color(0xFFB3261E);
  static const Color _verde = Color(0xFF1F7A44);

  final PuntoChecklist punto;
  final BorradorPunto borrador;
  final TextEditingController nota;
  final PlanInspeccion plan;

  /// HU19: cómo calificó el vendedor este punto al publicar.
  final Calificacion? declarado;
  final String? error;
  final bool habilitado;
  final ValueChanged<Calificacion> alCalificar;
  final VoidCallback alNoAplica;
  final ValueChanged<String> alEscribir;
  final VoidCallback alAgregarFotos;
  final ValueChanged<int> alQuitarNueva;
  final ValueChanged<int> alQuitarGuardada;

  @override
  Widget build(BuildContext context) {
    final listo = ReglasInspeccion.punto(borrador, plan: plan) == null;
    final pideObservacion =
        borrador.tieneFalla || (plan == PlanInspeccion.detallada && borrador.revisado && !borrador.noAplica);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error != null ? _rojo : ColoresApp.tinta,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                listo ? Icons.check_circle : Icons.radio_button_unchecked,
                color: listo ? _verde : ColoresApp.pizarra,
              ),
              const SizedBox(width: 8),
              Text(punto.nombre, style: Tipos.subtitulo),
            ],
          ),
          const SizedBox(height: 4),
          Text(punto.queRevisar, style: Tipos.pequeno),
          const SizedBox(height: 12),
          if (declarado != null) ...[
            Row(
              children: [
                const Text('El vendedor dijo: ', style: Tipos.pequeno),
                EtiquetaCalificacion(calificacion: declarado!),
              ],
            ),
            const SizedBox(height: 10),
          ],
          SelectorCalificacion(
            valor: borrador.calificacion,
            noAplica: borrador.noAplica,
            // Solo en puntos que algunos equipos no tienen (por ejemplo,
            // la lectora de discos de una consola digital).
            permiteNoAplica: punto.opcional,
            habilitado: habilitado,
            alElegir: alCalificar,
            alElegirNoAplica: alNoAplica,
          ),
          if (pideObservacion) ...[
            const SizedBox(height: 14),
            TextField(
              controller: nota,
              enabled: habilitado,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              onChanged: alEscribir,
              decoration: InputDecoration(
                labelText: borrador.tieneFalla
                    ? '¿Qué falla tiene?'
                    : 'Observación del inspector',
                hintText: borrador.tieneFalla
                    ? 'Ejemplo: 3 píxeles muertos en la esquina superior'
                    : 'Ejemplo: brillo parejo, sin rayones visibles',
                hintStyle: const TextStyle(color: Color(0xFF6B7088)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (borrador.tieneFalla) ...[
            const SizedBox(height: 6),
            Text(
              'Fotos de evidencia (${borrador.totalFotos} de '
              '${ReglasInspeccion.maximoFotosPorPunto})',
              style: Tipos.pequeno.copyWith(
                fontWeight: FontWeight.w700,
                color: ColoresApp.tinta,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < borrador.guardadas.length; i++)
                  _Miniatura(
                    imagen: Image.network(
                      InspeccionService.urlEvidencia(borrador.guardadas[i]),
                      fit: BoxFit.cover,
                    ),
                    alQuitar: habilitado ? () => alQuitarGuardada(i) : null,
                  ),
                for (var i = 0; i < borrador.nuevas.length; i++)
                  _Miniatura(
                    imagen: Image.memory(
                      borrador.nuevas[i].bytes,
                      fit: BoxFit.cover,
                    ),
                    alQuitar: habilitado ? () => alQuitarNueva(i) : null,
                  ),
                if (borrador.totalFotos < ReglasInspeccion.maximoFotosPorPunto)
                  InkWell(
                    onTap: habilitado ? alAgregarFotos : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: ColoresApp.nube,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ColoresApp.tinta, width: 2),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: ColoresApp.tinta),
                          SizedBox(height: 4),
                          Text(
                            'Agregar',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ColoresApp.tinta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(fontSize: 12.5, color: _rojo, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.imagen, required this.alQuitar});

  final Widget imagen;
  final VoidCallback? alQuitar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.tinta, width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imagen,
          if (alQuitar != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: ColoresApp.tinta, width: 1.5),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: alQuitar,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.close, size: 14, color: ColoresApp.tinta),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
