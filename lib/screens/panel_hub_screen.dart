import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../models/reclamo.dart';
import '../services/inspeccion_service.dart';
import '../services/publicacion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import '../widgets/dictamen_widgets.dart';
import 'dictamen_screen.dart';
import 'inspeccion_screen.dart';

/// Panel del inspector técnico del Hub (HU07).
///
/// Muestra los pedidos pagados en tres grupos, en el orden en que se
/// trabajan: por recibir, por inspeccionar e inspeccionados.
class PanelHubScreen extends StatefulWidget {
  const PanelHubScreen({super.key});

  @override
  State<PanelHubScreen> createState() => _PanelHubScreenState();
}

class _PanelHubScreenState extends State<PanelHubScreen> {
  late Future<List<PedidoHub>> _pedidos =
      InspeccionService.instancia.pedidosDelHub();

  @override
  void initState() {
    super.initState();
    InspeccionService.instancia.addListener(_recargar);
  }

  @override
  void dispose() {
    InspeccionService.instancia.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    if (!mounted) return;
    setState(() => _pedidos = InspeccionService.instancia.pedidosDelHub());
  }

  /// HU05: para registrar la llegada hacen falta de 2 a 6 fotos de cómo
  /// llegó el equipo (respaldo ante reclamos).
  Future<void> _recibir(Pedido pedido) async {
    final listo = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoRecepcion(pedido: pedido),
    );
    if (listo == true && mounted) {
      mostrarAviso(context, 'Registramos la llegada del pedido ${pedido.codigo} con sus fotos.');
    }
  }

  // Al volver de cada pantalla, el panel se recarga para mostrar el
  // pedido en su grupo nuevo, sin recargar la página.
  Future<void> _dictaminar(PedidoHub item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DictamenScreen(pedido: item.pedido),
      ),
    );
    _recargar();
  }

  Future<void> _inspeccionar(PedidoHub item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InspeccionScreen(
          pedido: item.pedido,
          inspeccion: item.inspeccion,
        ),
      ),
    );
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    if (!InspeccionService.instancia.soyInspector) {
      return const PaginaBase(
        child: RecuadroInfo(
          icono: Icons.lock_outline,
          texto: 'Esta sección es solo para inspectores técnicos del Hub.',
        ),
      );
    }

    return PaginaBase(
      seccion: Seccion.hub,
      anchoContenido: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BotonVolver(texto: 'Volver al inicio'),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Panel del Hub', style: Tipos.titulo),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _recargar,
                icon: const Icon(Icons.refresh, color: ColoresApp.tinta),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Registra la llegada de cada equipo y revísalo con el checklist. '
            'Los más antiguos aparecen primero.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<PedidoHub>>(
            future: _pedidos,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done && !resultado.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: ColoresApp.orquidea),
                  ),
                );
              }
              if (resultado.hasError && !resultado.hasData) {
                final error = resultado.error;
                return RecuadroInfo(
                  icono: Icons.wifi_off_outlined,
                  texto: error is ErrorDeInspeccion
                      ? error.mensaje
                      : 'No pudimos cargar los pedidos.',
                  hijo: TextButton.icon(
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                );
              }

              final todos = resultado.data ?? const <PedidoHub>[];
              // HU04: primero los que el vendedor ya avisó que entregó.
              final porRecibir = todos
                  .where((i) => i.pedido.estado == EstadoPedido.pagoEnCustodia)
                  .toList()
                ..sort((a, b) => (b.pedido.entregadoEn != null ? 1 : 0)
                    .compareTo(a.pedido.entregadoEn != null ? 1 : 0));
              final porInspeccionar = todos
                  .where((i) =>
                      i.pedido.estado == EstadoPedido.recibidoEnHub ||
                      (i.pedido.estado == EstadoPedido.enDiagnostico &&
                          !(i.inspeccion?.completa ?? false)))
                  .toList();
              final listos = todos
                  .where((i) =>
                      i.pedido.estado == EstadoPedido.enDiagnostico &&
                      (i.inspeccion?.completa ?? false))
                  .toList();
              final conDictamen = todos
                  .where((i) => i.pedido.dictamen != null)
                  .toList()
                  .reversed // los más recientes primero
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Resumen(
                    porRecibir: porRecibir.length,
                    porInspeccionar: porInspeccionar.length,
                    listos: listos.length,
                    conDictamen: conDictamen.length,
                  ),
                  const SizedBox(height: 28),
                  _Grupo(
                    titulo: '1. Por recibir',
                    vacio: 'No hay equipos en camino al Hub.',
                    items: porRecibir,
                    accion: (item) => BotonPegatina(
                      texto: 'Registrar llegada',
                      icono: Icons.move_to_inbox_outlined,
                      principal: false,
                      alTocar: () => _recibir(item.pedido),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Grupo(
                    titulo: '2. Por inspeccionar',
                    vacio: 'No hay equipos esperando revisión.',
                    items: porInspeccionar,
                    accion: (item) => BotonPegatina(
                      texto: 'Abrir checklist',
                      icono: Icons.fact_check_outlined,
                      alTocar: () => _inspeccionar(item),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Grupo(
                    titulo: '3. Listos para dictamen',
                    vacio: 'Todavía no hay checklists guardados.',
                    items: listos,
                    accion: (item) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        BotonPegatina(
                          texto: 'Corregir checklist',
                          icono: Icons.edit_note,
                          principal: false,
                          alTocar: () => _inspeccionar(item),
                        ),
                        BotonPegatina(
                          texto: 'Emitir dictamen',
                          icono: Icons.gavel_outlined,
                          alTocar: () => _dictaminar(item),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Grupo(
                    titulo: '4. Con dictamen',
                    vacio: 'Todavía no se ha emitido ningún dictamen.',
                    items: conDictamen,
                    accion: (item) => const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Tres contadores arriba, para ver de un vistazo cuánto trabajo hay.
class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.porRecibir,
    required this.porInspeccionar,
    required this.listos,
    required this.conDictamen,
  });

  final int porRecibir;
  final int porInspeccionar;
  final int listos;
  final int conDictamen;

  @override
  Widget build(BuildContext context) {
    Widget contador(String texto, int numero, IconData icono) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColoresApp.nube,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icono, color: ColoresApp.tinta),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$numero', style: Tipos.precio),
                      Text(texto, style: Tipos.pequeno),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    final fila1 = [
      contador('Por recibir', porRecibir, Icons.local_shipping_outlined),
      const SizedBox(width: 12),
      contador('Por inspeccionar', porInspeccionar, Icons.fact_check_outlined),
    ];
    final fila2 = [
      contador('Para dictamen', listos, Icons.task_alt),
      const SizedBox(width: 12),
      contador('Con dictamen', conDictamen, Icons.gavel_outlined),
    ];
    // En pantallas angostas van en dos filas para que se lean bien.
    if (MediaQuery.sizeOf(context).width < 700) {
      return Column(
        children: [
          Row(children: fila1),
          const SizedBox(height: 12),
          Row(children: fila2),
        ],
      );
    }
    return Row(children: [...fila1, const SizedBox(width: 12), ...fila2]);
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({
    required this.titulo,
    required this.vacio,
    required this.items,
    required this.accion,
  });

  final String titulo;
  final String vacio;
  final List<PedidoHub> items;
  final Widget Function(PedidoHub item) accion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$titulo (${items.length})', style: Tipos.subtitulo),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Text(vacio, style: Tipos.cuerpo)
        else
          for (final item in items) ...[
            _TarjetaHub(item: item, accion: accion(item)),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _TarjetaHub extends StatelessWidget {
  const _TarjetaHub({required this.item, required this.accion});

  final PedidoHub item;
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    final pedido = item.pedido;
    final pagadoEn = pedido.pagadoEn;
    final inspeccion = item.inspeccion;
    final ancha = MediaQuery.sizeOf(context).width >= 700;

    final datos = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EtiquetaPedido(estado: pedido.estado),
          const SizedBox(height: 6),
          Text(
            pedido.equipo.titulo,
            style: Tipos.subtitulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Pedido ${pedido.codigo} · Vende ${pedido.equipo.vendedor}',
            style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
          ),
          if (pagadoEn != null)
            Text('Pagado el ${formatearFecha(pagadoEn)}', style: Tipos.pequeno),
          // HU04: el vendedor avisó «Ya entregué el equipo».
          if (pedido.esperandoAlHub)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF1F7A44)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'El vendedor lo entregó el ${formatearFecha(pedido.entregadoEn!)}',
                      style: Tipos.pequeno.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F7A44),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (pedido.dictamen != null) ...[
            const SizedBox(height: 8),
            TarjetaDictamen(dictamen: pedido.dictamen!),
          ] else if (inspeccion != null && inspeccion.completa)
            Text(
              inspeccion.fallas == 0
                  ? 'Checklist: sin fallas'
                  : 'Checklist: ${inspeccion.fallas} '
                      '${inspeccion.fallas == 1 ? 'falla' : 'fallas'}',
              style: Tipos.pequeno.copyWith(
                fontWeight: FontWeight.w700,
                color: inspeccion.fallas == 0
                    ? const Color(0xFF1F7A44)
                    : const Color(0xFFB3261E),
              ),
            ),
        ],
      ),
    );

    final foto = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: ImagenEquipo(equipo: pedido.equipo),
      ),
    );

    return Pegatina(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ancha
            ? Row(
                children: [
                  foto,
                  const SizedBox(width: 14),
                  datos,
                  const SizedBox(width: 14),
                  accion,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [foto, const SizedBox(width: 14), datos]),
                  const SizedBox(height: 12),
                  accion,
                ],
              ),
      ),
    );
  }
}

/// HU05, escenario 1: el inspector sube de 2 a 6 fotos del estado en que
/// llegó el equipo antes de confirmar la recepción.
class DialogoRecepcion extends StatefulWidget {
  const DialogoRecepcion({super.key, required this.pedido});

  final Pedido pedido;

  @override
  State<DialogoRecepcion> createState() => _DialogoRecepcionState();
}

class _DialogoRecepcionState extends State<DialogoRecepcion> {
  final List<FotoElegida> _fotos = [];
  final _nota = TextEditingController();
  bool _guardando = false;
  bool _intento = false;
  String? _error;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final espacio = ReglasReclamo.maximoFotosRecepcion - _fotos.length;
    if (espacio <= 0) return;
    try {
      final archivos = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
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
          _fotos.add(foto);
        } else {
          rechazos.add(problema);
        }
      }
      if (!mounted) return;
      setState(() => _error = rechazos.isEmpty ? null : rechazos.first);
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos abrir las fotos.');
    }
  }

  Future<void> _confirmar() async {
    setState(() => _intento = true);
    if (_guardando || ReglasReclamo.fotosRecepcion(_fotos.length) != null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await InspeccionService.instancia.recibirEnHub(
        widget.pedido,
        fotos: _fotos,
        nota: _nota.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ErrorDeInspeccion catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final falta = _intento ? ReglasReclamo.fotosRecepcion(_fotos.length) : null;

    return AlertDialog(
      title: Text('Registrar llegada · ${widget.pedido.codigo}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Toma de ${ReglasReclamo.minimoFotosRecepcion} a '
                '${ReglasReclamo.maximoFotosRecepcion} fotos de cómo llegó '
                '«${widget.pedido.equipo.titulo}»: frente, atrás, pantalla y '
                'cualquier golpe o rayón. Son el respaldo ante reclamos y después '
                'no se pueden cambiar ni borrar.',
                style: Tipos.pequeno.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _fotos.length; i++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_fotos[i].bytes, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Quitar esta foto',
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(backgroundColor: Colors.white),
                            onPressed: _guardando ? null : () => setState(() => _fotos.removeAt(i)),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ),
                      ],
                    ),
                  if (_fotos.length < ReglasReclamo.maximoFotosRecepcion)
                    InkWell(
                      onTap: _guardando ? null : _agregar,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: falta != null ? const Color(0xFFB3261E) : ColoresApp.tinta,
                            width: 1.5,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: ColoresApp.tinta),
                            Text('Agregar', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                falta ??
                    '${_fotos.length} de ${ReglasReclamo.maximoFotosRecepcion} fotos '
                        '(mínimo ${ReglasReclamo.minimoFotosRecepcion}).',
                style: TextStyle(
                  fontSize: 12.5,
                  color: falta != null ? const Color(0xFFB3261E) : ColoresApp.pizarra,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nota,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Nota (opcional)',
                  hintText: 'Por ejemplo: llegó con una marca leve en la tapa.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                RecuadroInfo(
                  icono: Icons.error_outline,
                  color: const Color(0xFFFBE9E8),
                  colorIcono: const Color(0xFFB3261E),
                  colorTexto: const Color(0xFFB3261E),
                  texto: _error!,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _confirmar,
          style: FilledButton.styleFrom(backgroundColor: ColoresApp.tinta),
          icon: Icon(_guardando ? Icons.hourglass_top : Icons.move_to_inbox_outlined),
          label: Text(_guardando ? 'Subiendo fotos…' : 'Confirmar llegada'),
        ),
      ],
    );
  }
}
