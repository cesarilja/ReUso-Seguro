import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../models/rastreo.dart';
import '../models/reclamo.dart';
import '../services/pedido_service.dart';
import '../services/sesion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/dictamen_widgets.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import '../widgets/reclamo_widgets.dart';
import 'certificado_screen.dart';
import 'pago_screen.dart';

/// Lista de pedidos del comprador, con el estado de cada pago (HU12 y HU01).
///
/// Es la base del rastreo de la HU02: cada pedido pagado ya muestra su
/// línea de tiempo, que avanzará cuando el Hub registre cada fase.
class MisComprasScreen extends StatefulWidget {
  const MisComprasScreen({super.key});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  late Future<List<Pedido>> _pedidos = _cargar();

  @override
  void initState() {
    super.initState();
    // Si se paga o se cancela un pedido, la lista se vuelve a cargar sola.
    PedidoService.instancia.addListener(_recargar);
    SesionService.instancia.addListener(_recargar);
  }

  @override
  void dispose() {
    PedidoService.instancia.removeListener(_recargar);
    SesionService.instancia.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    if (!mounted) return;
    setState(() => _pedidos = _cargar());
  }

  /// Carga los pedidos. El aviso «Tu equipo pasó a: …» (HU02) ahora lo
  /// crea el servidor y lo muestra AvisosService en cualquier pantalla (HU10).
  Future<List<Pedido>> _cargar() => PedidoService.instancia.misPedidos();

  @override
  Widget build(BuildContext context) {
    final haySesion = SesionService.instancia.haySesion;

    return PaginaBase(
      seccion: Seccion.compras,
      anchoContenido: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BotonVolver(texto: 'Volver al inicio'),
          const SizedBox(height: 20),
          const Text('Mis compras', style: Tipos.titulo),
          const SizedBox(height: 6),
          Text(
            'Aquí ves tus pedidos y en qué estado está cada pago.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 28),
          if (!haySesion)
            const RecuadroInfo(texto: 'Inicia sesión para ver tus compras.')
          else
            FutureBuilder<List<Pedido>>(
              future: _pedidos,
              builder: (context, resultado) {
                if (resultado.connectionState != ConnectionState.done && !resultado.hasData) {
                  return const _Cargando();
                }
                if (resultado.hasError && !resultado.hasData) {
                  final error = resultado.error;
                  return RecuadroInfo(
                    icono: Icons.wifi_off_outlined,
                    texto: error is ErrorDePedido
                        ? error.mensaje
                        : 'No pudimos cargar tus compras.',
                    hijo: TextButton.icon(
                      onPressed: _recargar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  );
                }
                final pedidos = resultado.data ?? const <Pedido>[];
                if (pedidos.isEmpty) return const _SinCompras();
                return Column(
                  children: [
                    for (final pedido in pedidos) ...[
                      _TarjetaPedido(pedido: pedido),
                      const SizedBox(height: 18),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final equipo = pedido.equipo;
    final pagadoEn = pedido.pagadoEn;
    final detalle = pagadoEn == null
        ? 'Creado el ${formatearFecha(pedido.creadoEn)}'
        : 'Pagado el ${formatearFecha(pagadoEn)} · Ref. ${pedido.referencia}';

    return Opacity(
      // Los pedidos cancelados se ven atenuados, pero siguen en la lista.
      opacity: pedido.estaCancelado ? 0.65 : 1,
      child: Pegatina(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: ImagenEquipo(equipo: equipo),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EtiquetaPedido(estado: pedido.estado),
                        const SizedBox(height: 8),
                        Text(
                          equipo.titulo,
                          style: Tipos.subtitulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pedido ${pedido.codigo} · ${pedido.montoFormateado}',
                          style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
                        ),
                        Text(detalle, style: Tipos.pequeno),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (pedido.estaPendiente) ...[
                // ReUso Pay: cada pedido tiene un tiempo límite para pagarse.
                if (pedido.vencido())
                  const RecuadroInfo(
                    icono: Icons.timer_off_outlined,
                    texto: 'Se acabó el tiempo para pagar este pedido. No se '
                        'te cobró nada.',
                  )
                else
                  RecuadroInfo(
                    icono: Icons.timer_outlined,
                    texto: 'Tienes hasta el ${formatearFecha(pedido.expiraEn)} '
                        'para pagar. Después el pedido vence.',
                  ),
                const SizedBox(height: 12),
                BotonPegatina(
                  texto: pedido.vencido() ? 'Volver a intentarlo' : 'Pagar ahora',
                  icono: pedido.vencido() ? Icons.refresh : Icons.lock_outline,
                  expandido: true,
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PagoScreen(pedido: pedido),
                    ),
                  ),
                ),
              ]
              else if (pedido.estaCancelado)
                const RecuadroInfo(
                  icono: Icons.block,
                  texto: 'Este pedido se canceló. No se te cobró nada.',
                )
              else ...[
                // HU08: el resultado de la inspección, con color y texto.
                if (pedido.dictamen != null) ...[
                  TarjetaDictamen(dictamen: pedido.dictamen!),
                  const SizedBox(height: 12),
                ],
                // HU02: dónde está el dinero, siempre a la vista.
                DondeEstaTuDinero(pedido: pedido),
                const SizedBox(height: 12),
                // HU13: si no pasó, el comprobante del reembolso.
                if (pedido.noPasoInspeccion) ...[
                  ComprobanteReembolso(pedido: pedido),
                  const SizedBox(height: 12),
                ],
                // HU05: confirmar que lo recibió y, si hace falta, reclamar
                // dentro de los 3 días.
                if (pedido.reclamo != null) ...[
                  TarjetaReclamo(reclamo: pedido.reclamo!),
                  const SizedBox(height: 12),
                  if (pedido.recepcion != null) ...[
                    FotosRecepcion(recepcion: pedido.recepcion!),
                    const SizedBox(height: 12),
                  ],
                ] else if (ReglasReclamo.situacion(pedido) != SituacionReclamo.noAplica) ...[
                  PlazoReclamo(
                    pedido: pedido,
                    alConfirmarRecibido: () => _confirmarRecibido(context, pedido),
                    alReclamar: () => _abrirReclamo(context, pedido),
                  ),
                  const SizedBox(height: 12),
                ],
                _Seguimiento(pedido: pedido),
                const SizedBox(height: 12),
                // HU03: el certificado técnico del inspector.
                BotonPegatina(
                  texto: 'Ver certificado técnico',
                  icono: pedido.dictamen == null
                      ? Icons.hourglass_top
                      : Icons.workspace_premium_outlined,
                  principal: false,
                  expandido: true,
                  alTocar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CertificadoScreen(pedido: pedido),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// HU02: la línea de tiempo plegable, con la fase actual en el título.
class _Seguimiento extends StatelessWidget {
  const _Seguimiento({required this.pedido});

  final Pedido pedido;

  String _titulo() {
    final rastreo = Rastreo.de(pedido);
    final fase = rastreo.faseActual;
    if (fase == null) return 'Mira en qué va tu pedido.';
    return 'Fase ${rastreo.indiceActual + 1} de ${Rastreo.totalFases}: '
        '${fase.titulo}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        // Quita las líneas que el ExpansionTile pone por defecto.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          leading: const Icon(Icons.local_shipping_outlined,
              color: ColoresApp.tinta),
          // Se abre solo mientras el pedido sigue en camino o en el Hub.
          initiallyExpanded: Rastreo.de(pedido).indiceActual < 3,
          title: Text(
            _titulo(),
            style: Tipos.pequeno.copyWith(
              fontSize: 14.5,
              color: ColoresApp.tinta,
            ),
          ),
          children: [LineaDeTiempo(pedido: pedido)],
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: ColoresApp.orquidea,
            ),
          ),
          const SizedBox(width: 12),
          Text('Cargando tus compras…', style: Tipos.cuerpo),
        ],
      ),
    );
  }
}

class _SinCompras extends StatelessWidget {
  const _SinCompras();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RecuadroInfo(
          icono: Icons.shopping_bag_outlined,
          texto: 'Aún no tienes compras. Cuando compres un equipo, aquí '
              'verás en qué fase va y dónde está tu dinero.',
        ),
        const SizedBox(height: 20),
        BotonPegatina(
          texto: 'Ver equipos',
          alTocar: () =>
              Navigator.of(context).popUntil((ruta) => ruta.isFirst),
        ),
      ],
    );
  }
}

/// HU05: el comprador confirma que recibió su equipo (con confirmación,
/// heurística 5). Desde ahí corren los 3 días para reclamar.
Future<void> _confirmarRecibido(BuildContext context, Pedido pedido) async {
  final seguro = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('¿Ya tienes el equipo en tus manos?'),
      content: Text(
        'Confírmalo solo si ya recibiste «${pedido.equipo.titulo}». Desde ahora '
        'tendrás ${ReglasReclamo.plazoDias} días para reclamar si algo no está bien.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Todavía no'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          style: FilledButton.styleFrom(backgroundColor: ColoresApp.tinta),
          child: const Text('Sí, ya lo recibí'),
        ),
      ],
    ),
  );
  if (seguro != true || !context.mounted) return;
  try {
    await PedidoService.instancia.confirmarRecibido(pedido);
    if (context.mounted) mostrarAviso(context, 'Listo: confirmaste que recibiste tu equipo.');
  } on ErrorDePedido catch (error) {
    if (context.mounted) mostrarAviso(context, error.mensaje);
  }
}

/// HU05, escenario 3: abrir un reclamo dentro del plazo.
Future<void> _abrirReclamo(BuildContext context, Pedido pedido) async {
  final enviado = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoReclamo(pedido: pedido),
  );
  if (enviado == true && context.mounted) {
    mostrarAviso(context, 'Registramos tu reclamo. Lo revisaremos con las fotos del Hub.');
  }
}

class _DialogoReclamo extends StatefulWidget {
  const _DialogoReclamo({required this.pedido});

  final Pedido pedido;

  @override
  State<_DialogoReclamo> createState() => _DialogoReclamoState();
}

class _DialogoReclamoState extends State<_DialogoReclamo> {
  final _texto = TextEditingController();
  bool _enviando = false;
  bool _intento = false;
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _intento = true);
    if (ReglasReclamo.descripcion(_texto.text) != null || _enviando) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await PedidoService.instancia.abrirReclamo(widget.pedido, _texto.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ErrorDePedido catch (error) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = error.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vence = ReglasReclamo.venceEn(widget.pedido);
    final problema = _intento ? ReglasReclamo.descripcion(_texto.text) : null;

    return AlertDialog(
      title: const Text('Reclamo sobre tu equipo'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cuéntanos qué pasa con «${widget.pedido.equipo.titulo}». Lo '
              'compararemos con las fotos de cómo llegó al Hub y con el checklist '
              'del inspector.'
              '${vence == null ? '' : ' Puedes reclamar hasta el ${formatearFecha(vence)}.'}',
              style: Tipos.pequeno.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _texto,
              maxLines: 4,
              maxLength: 500,
              onChanged: (_) {
                if (_intento) setState(() {});
              },
              decoration: InputDecoration(
                labelText: '¿Qué problema encontraste?',
                hintText: 'Por ejemplo: la batería dura 20 minutos y el vendedor dijo 2 horas.',
                errorText: problema,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
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
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          style: FilledButton.styleFrom(backgroundColor: ColoresApp.tinta),
          child: Text(_enviando ? 'Enviando…' : 'Enviar reclamo'),
        ),
      ],
    );
  }
}
