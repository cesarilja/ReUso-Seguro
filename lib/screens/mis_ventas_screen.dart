import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/equipo.dart';
import '../models/pedido.dart';
import '../models/venta.dart';
import '../services/catalogo_service.dart';
import '../services/pasarela.dart';
import '../services/pedido_service.dart';
import '../services/sesion_service.dart';
import '../services/vendedor_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/dictamen_widgets.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';
import '../widgets/venta_widgets.dart';
import 'certificado_screen.dart';
import 'detalle_equipo_screen.dart';

/// Las ventas del vendedor y en qué estado está cada pago (HU06).
///
/// Cuando el inspector aprueba el equipo, el pago se libera solo y aquí se
/// ve cuánto recibe el vendedor después de la comisión. Todo es SIMULADO.
class MisVentasScreen extends StatefulWidget {
  const MisVentasScreen({super.key});

  @override
  State<MisVentasScreen> createState() => _MisVentasScreenState();
}

class _MisVentasScreenState extends State<MisVentasScreen> {
  late Future<List<Pedido>> _ventas = PedidoService.instancia.misVentas();
  late Future<List<Equipo>> _publicaciones =
      const CatalogoService().misPublicaciones();
  late Future<CuentaCobro?> _cuenta = VendedorService.instancia.miCuenta();

  /// Ventas con una acción en curso (para no tocar dos veces).
  final Set<String> _ocupadas = {};

  @override
  void initState() {
    super.initState();
    PedidoService.instancia.addListener(_recargar);
    SesionService.instancia.addListener(_recargar);
    CatalogoService.cambios.addListener(_recargar);
    // HU04: al abrir «Mis ventas», las ventas nuevas quedan vistas (y si
    // llega otra con la página abierta, también).
    VendedorService.instancia.addListener(_marcarVistas);
    WidgetsBinding.instance.addPostFrameCallback((_) => _marcarVistas());
  }

  @override
  void dispose() {
    PedidoService.instancia.removeListener(_recargar);
    SesionService.instancia.removeListener(_recargar);
    CatalogoService.cambios.removeListener(_recargar);
    VendedorService.instancia.removeListener(_marcarVistas);
    super.dispose();
  }

  void _marcarVistas() {
    if (mounted && VendedorService.instancia.ventasNuevas > 0) {
      VendedorService.instancia.marcarVentasVistas();
    }
  }

  void _recargar() {
    if (!mounted) return;
    setState(() {
      _ventas = PedidoService.instancia.misVentas();
      _publicaciones = const CatalogoService().misPublicaciones();
      _cuenta = VendedorService.instancia.miCuenta();
    });
  }

  /// HU04, escenario 3: «Ya entregué el equipo», con confirmación
  /// (heurística 5: prevención de errores).
  Future<void> _entregar(Pedido venta) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Ya entregaste el equipo en el Hub?'),
        content: Text(
          'Confírmalo solo si ya dejaste «${venta.equipo.titulo}» en el Hub '
          'con el código ${venta.codigo}. El inspector lo verá en «Por recibir».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Todavía no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.tinta),
            child: const Text('Sí, ya lo entregué'),
          ),
        ],
      ),
    );
    if (seguro != true || !mounted) return;
    await _accion(venta, () => VendedorService.instancia.marcarEntregado(venta),
        'Listo: le avisamos al Hub que entregaste el pedido ${venta.codigo}.');
  }

  /// HU06, escenario 2: reintentar la transferencia.
  Future<void> _reintentar(Pedido venta) async {
    await _accion(venta, () async {
      final actualizada = await VendedorService.instancia.reintentarLiberacion(venta);
      if (actualizada.liberacionPendiente) {
        throw ErrorDePedido(
          'La transferencia volvió a fallar: '
          '${(actualizada.liberacionMotivo ?? MotivoLiberacion.desconocido).titulo.toLowerCase()}. '
          'Tu dinero sigue en custodia.',
        );
      }
      return actualizada;
    }, 'Te liberamos el pago de ${venta.codigo}.');
  }

  Future<void> _accion(
    Pedido venta,
    Future<Pedido> Function() hacer,
    String mensajeExito,
  ) async {
    if (_ocupadas.contains(venta.id)) return;
    setState(() => _ocupadas.add(venta.id));
    try {
      await hacer();
      if (mounted) mostrarAviso(context, mensajeExito);
    } on ErrorDePedido catch (error) {
      if (mounted) mostrarAviso(context, error.mensaje);
    } finally {
      if (mounted) setState(() => _ocupadas.remove(venta.id));
      _recargar();
    }
  }

  /// HU06: registrar o cambiar la cuenta donde cobra el vendedor.
  Future<void> _editarCuenta(CuentaCobro? actual) async {
    final liberados = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoCuentaCobro(actual: actual),
    );
    if (liberados == null || !mounted) return;
    mostrarAviso(
      context,
      liberados > 0
          ? 'Guardamos tu cuenta y te liberamos $liberados '
              '${liberados == 1 ? 'pago pendiente' : 'pagos pendientes'}.'
          : 'Guardamos tu cuenta para cobrar.',
    );
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return PaginaBase(
      seccion: Seccion.ventas,
      anchoContenido: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BotonVolver(texto: 'Volver al inicio'),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Text('Mis ventas', style: Tipos.titulo)),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _recargar,
                icon: const Icon(Icons.refresh, color: ColoresApp.tinta),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Aquí ves los equipos que te compraron y cuándo recibes el dinero.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 20),
          // HU06: dónde cobra el vendedor.
          FutureBuilder<CuentaCobro?>(
            future: _cuenta,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done) {
                return const SizedBox(height: 8);
              }
              return TarjetaCuentaCobro(
                cuenta: resultado.data,
                alEditar: () => _editarCuenta(resultado.data),
              );
            },
          ),
          const SizedBox(height: 28),
          FutureBuilder<List<Pedido>>(
            future: _ventas,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done &&
                  !resultado.hasData) {
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
                  texto: error is ErrorDePedido
                      ? error.mensaje
                      : 'No pudimos cargar tus ventas.',
                  hijo: TextButton.icon(
                    onPressed: _recargar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                );
              }
              final ventas = resultado.data ?? const <Pedido>[];
              if (ventas.isEmpty) {
                return const RecuadroInfo(
                  icono: Icons.storefront_outlined,
                  texto: 'Todavía no te han comprado ningún equipo. Cuando '
                      'alguien pague uno de tus equipos, aparecerá aquí.',
                );
              }

              final cobrado = ventas
                  .where((v) => v.pagoLiberado)
                  .fold<double>(0, (suma, v) => suma + v.recibeVendedor);
              final porCobrar = ventas
                  .where((v) => !v.pagoLiberado && !v.noPasoInspeccion)
                  .fold<double>(0, (suma, v) => suma + v.recibeVendedor);

              return Column(
                children: [
                  Row(
                    children: [
                      _Total(
                        titulo: 'Ya recibiste',
                        monto: cobrado,
                        icono: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFFDFF3E6),
                      ),
                      const SizedBox(width: 12),
                      _Total(
                        titulo: 'En custodia (por recibir)',
                        monto: porCobrar,
                        icono: Icons.lock_clock_outlined,
                        color: ColoresApp.nube,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  for (final venta in ventas) ...[
                    _TarjetaVenta(
                      venta: venta,
                      ocupada: _ocupadas.contains(venta.id),
                      alEntregar: () => _entregar(venta),
                      alReintentar: () => _reintentar(venta),
                      alRegistrarCuenta: () async {
                        final cuenta = await VendedorService.instancia.miCuenta();
                        if (mounted) await _editarCuenta(cuenta);
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          const Text('Tus equipos publicados', style: Tipos.titulo),
          const SizedBox(height: 6),
          Text(
            'Todo lo que has publicado, esté disponible o ya reservado.',
            style: Tipos.cuerpo,
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<Equipo>>(
            future: _publicaciones,
            builder: (context, resultado) {
              if (resultado.connectionState != ConnectionState.done &&
                  !resultado.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: ColoresApp.orquidea),
                );
              }
              if (resultado.hasError && !resultado.hasData) {
                return const RecuadroInfo(
                  icono: Icons.wifi_off_outlined,
                  texto: 'No pudimos cargar tus publicaciones.',
                );
              }
              final equipos = resultado.data ?? const <Equipo>[];
              if (equipos.isEmpty) {
                return const RecuadroInfo(
                  icono: Icons.add_a_photo_outlined,
                  texto: 'Todavía no has publicado ningún equipo. Usa el '
                      'botón «Publicar un equipo» de arriba.',
                );
              }
              return Column(
                children: [
                  for (final e in equipos) ...[
                    _FilaPublicacion(equipo: e),
                    const SizedBox(height: 10),
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

/// Un equipo publicado por la persona, con su estado.
class _FilaPublicacion extends StatelessWidget {
  const _FilaPublicacion({required this.equipo});

  final Equipo equipo;

  @override
  Widget build(BuildContext context) {
    final disponible = equipo.estaDisponible;
    return Pegatina(
      sombra: 3,
      alTocar: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetalleEquipoScreen(equipo: equipo),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: ImagenEquipo(equipo: equipo),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipo.titulo,
                    style: Tipos.subtitulo.copyWith(fontSize: 15.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    equipo.precioFormateado,
                    style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Color + ícono + texto, nunca solo color.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: disponible ? const Color(0xFFDFF3E6) : ColoresApp.nube,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    disponible ? Icons.check_circle_outline : Icons.lock_outline,
                    size: 16,
                    color: disponible
                        ? const Color(0xFF1F7A44)
                        : ColoresApp.tinta,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    equipo.estado.nombre,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: disponible
                          ? const Color(0xFF1F7A44)
                          : ColoresApp.tinta,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: ColoresApp.pizarra),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.titulo,
    required this.monto,
    required this.icono,
    required this.color,
  });

  final String titulo;
  final double monto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
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
                  Text(formatearDolares(monto), style: Tipos.precio),
                  Text(titulo, style: Tipos.pequeno),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaVenta extends StatelessWidget {
  const _TarjetaVenta({
    required this.venta,
    required this.ocupada,
    required this.alEntregar,
    required this.alReintentar,
    required this.alRegistrarCuenta,
  });

  final Pedido venta;
  final bool ocupada;
  final VoidCallback alEntregar;
  final VoidCallback alReintentar;
  final VoidCallback alRegistrarCuenta;

  @override
  Widget build(BuildContext context) {
    final equipo = venta.equipo;
    final liberadoEn = venta.liberadoEn;
    // HU13: rechazado o ya reembolsado, el vendedor no cobra ni paga comisión.
    final rechazado = venta.noPasoInspeccion;

    return Pegatina(
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
                      EtiquetaPedido(estado: venta.estado),
                      const SizedBox(height: 8),
                      Text(
                        equipo.titulo,
                        style: Tipos.subtitulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Pedido ${venta.codigo}',
                        style: Tipos.pequeno.copyWith(color: ColoresApp.tinta),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Desglose claro de cuánto recibe el vendedor (sin sorpresas).
            Container(height: 2, color: ColoresApp.nube),
            const SizedBox(height: 6),
            FilaDato(titulo: 'Precio de venta', valor: venta.montoFormateado),
            FilaDato(
              titulo: rechazado
                  ? 'Comisión de ReUso Seguro (no se cobra)'
                  : 'Comisión de ReUso Seguro (8 %)',
              valor: '- ${formatearDolares(venta.comisionEstimada)}',
            ),
            FilaDato(
              titulo: rechazado
                  ? 'No recibes pago'
                  : (venta.pagoLiberado ? 'Recibiste' : 'Recibirás'),
              valor: formatearDolares(venta.recibeVendedor),
              destacado: true,
            ),
            const SizedBox(height: 10),
            if (venta.dictamen != null) ...[
              TarjetaDictamen(dictamen: venta.dictamen!, paraVendedor: true),
              const SizedBox(height: 10),
              // HU03: el vendedor también puede ver el certificado.
              BotonPegatina(
                texto: 'Ver certificado técnico',
                icono: Icons.workspace_premium_outlined,
                principal: false,
                expandido: true,
                alTocar: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CertificadoScreen(pedido: venta),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // HU04: qué hacer con el equipo; HU06: si el cobro falló.
            if (venta.debeEntregar)
              InstruccionesEntrega(
                venta: venta,
                ocupado: ocupada,
                alEntregar: alEntregar,
              )
            else if (venta.esperandoAlHub)
              EsperandoAlHub(venta: venta)
            else if (venta.liberacionPendiente)
              AvisoLiberacionPendiente(
                venta: venta,
                ocupado: ocupada,
                alReintentar: alReintentar,
                alRegistrarCuenta: alRegistrarCuenta,
              )
            else
            RecuadroInfo(
              icono: venta.pagoLiberado
                  ? Icons.check_circle_outline
                  : (rechazado ? Icons.undo : Icons.local_shipping_outlined),
              color: venta.pagoLiberado
                  ? const Color(0xFFDFF3E6)
                  : ColoresApp.nube,
              texto: _queSigue(venta.estado, liberadoEn),
            ),
          ],
        ),
      ),
    );
  }

  String _queSigue(EstadoPedido estado, DateTime? liberadoEn) {
    switch (estado) {
      case EstadoPedido.pagoEnCustodia:
        return 'El comprador ya pagó y el dinero está en custodia. Lleva el '
            'equipo a nuestro Hub para que lo revisen.';
      case EstadoPedido.recibidoEnHub:
      case EstadoPedido.enDiagnostico:
        return 'Tu equipo está en el Hub y el inspector técnico lo está '
            'revisando.';
      case EstadoPedido.aprobado:
        return 'Tu equipo fue aprobado. El pago se está liberando.';
      case EstadoPedido.liberacionPendiente:
        return 'Tu equipo fue aprobado, pero la transferencia está pendiente.';
      case EstadoPedido.pagoLiberado:
      case EstadoPedido.enCamino:
        return liberadoEn == null
            ? 'Te liberamos el pago (simulado).'
            : 'Te liberamos el pago el ${formatearFecha(liberadoEn)} '
                '(simulado, no se mueve dinero real).';
      case EstadoPedido.rechazado:
        return 'El equipo no pasó la inspección. Estamos devolviéndole el '
            'dinero al comprador.';
      case EstadoPedido.reembolsado:
        return 'El equipo no pasó la inspección. Le devolvimos el 100 % al '
            'comprador y tu equipo volvió a estar disponible en el catálogo.';
      case EstadoPedido.pendienteDePago:
      case EstadoPedido.cancelado:
        return '';
    }
  }
}

/// HU06: formulario de la cuenta para cobrar (Pago Móvil, SIMULADO).
/// Al guardarla, el servidor reintenta solo las liberaciones pendientes.
class _DialogoCuentaCobro extends StatefulWidget {
  const _DialogoCuentaCobro({required this.actual});

  final CuentaCobro? actual;

  @override
  State<_DialogoCuentaCobro> createState() => _DialogoCuentaCobroState();
}

class _DialogoCuentaCobroState extends State<_DialogoCuentaCobro> {
  final _clave = GlobalKey<FormState>();
  late String? _banco = widget.actual?.banco;
  late final _telefono = TextEditingController(text: widget.actual?.telefono);
  late final _cedula = TextEditingController(text: widget.actual?.cedula);
  late final _titular = TextEditingController(text: widget.actual?.titular);
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _telefono.dispose();
    _cedula.dispose();
    _titular.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando || !(_clave.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final liberados = await VendedorService.instancia.guardarCuenta(
        banco: _banco!,
        telefono: _telefono.text,
        cedula: _cedula.text,
        titular: _titular.text,
      );
      if (mounted) Navigator.of(context).pop(liberados);
    } on ErrorDePedido catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error.mensaje;
      });
    }
  }

  InputDecoration _decoracion(String etiqueta, IconData icono, {String? pista}) =>
      InputDecoration(
        labelText: etiqueta,
        hintText: pista,
        prefixIcon: Icon(icono),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final bancos = [for (final (codigo, nombre) in bancosVenezuela) '$codigo · $nombre'];
    if (_banco != null && !bancos.contains(_banco)) bancos.insert(0, _banco!);

    return AlertDialog(
      title: const Text('Tu cuenta para cobrar'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _clave,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Aquí te transferimos el dinero de tus ventas por Pago Móvil '
                  '(simulado: no se mueve dinero real).',
                  style: Tipos.pequeno.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _banco,
                  isExpanded: true,
                  decoration: _decoracion('Banco', Icons.account_balance_outlined),
                  items: [
                    for (final banco in bancos)
                      DropdownMenuItem(value: banco, child: Text(banco)),
                  ],
                  onChanged: (valor) => setState(() => _banco = valor),
                  validator: (valor) => valor == null ? 'Elige tu banco.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: _decoracion('Teléfono del Pago Móvil', Icons.phone_iphone,
                      pista: '0414 123 4567'),
                  validator: (valor) => validarTelefono(valor ?? ''),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cedula,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _decoracion('Cédula del titular', Icons.badge_outlined,
                      pista: 'V12345678'),
                  validator: (valor) => validarCedula(valor ?? ''),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _titular,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoracion('Nombre del titular', Icons.person_outline,
                      pista: 'María Pérez'),
                  validator: (valor) => (valor ?? '').trim().length < 5 ||
                          !(valor ?? '').trim().contains(' ')
                      ? 'Escribe el nombre y el apellido del titular.'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 16, color: Color(0xFF6B4500)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Modo de prueba: un teléfono terminado en 0000 hace que el '
                        'banco rechace la transferencia.',
                        style: Tipos.pequeno.copyWith(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
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
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(backgroundColor: ColoresApp.tinta),
          child: Text(_guardando ? 'Guardando…' : 'Guardar cuenta'),
        ),
      ],
    );
  }
}
