import 'package:flutter/material.dart';

import '../models/equipo.dart';
import '../models/pedido.dart';
import '../services/catalogo_service.dart';
import '../services/pedido_service.dart';
import '../services/sesion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/barra_superior.dart';
import '../widgets/equipo_widgets.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/pegatina.dart';
import '../widgets/pie_de_pagina.dart';
import 'mis_compras_screen.dart';
import 'pago_screen.dart';

/// Detalle de un equipo publicado (HU12).
///
/// Se mantiene al día solo: si alguien compra el equipo mientras está
/// abierto, pasa a «Reservado» sin recargar la página.
class DetalleEquipoScreen extends StatefulWidget {
  const DetalleEquipoScreen({super.key, required this.equipo});

  final Equipo equipo;

  @override
  State<DetalleEquipoScreen> createState() => _DetalleEquipoScreenState();
}

class _DetalleEquipoScreenState extends State<DetalleEquipoScreen> {
  late Equipo equipo = widget.equipo;

  @override
  void initState() {
    super.initState();
    CatalogoService.cambios.addListener(_actualizar);
  }

  @override
  void dispose() {
    CatalogoService.cambios.removeListener(_actualizar);
    super.dispose();
  }

  Future<void> _actualizar() async {
    final nuevo = await const CatalogoService().obtenerEquipo(equipo.id);
    if (nuevo != null && mounted) setState(() => equipo = nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final margen = margenLateral(context);
    final pantallaAncha = MediaQuery.sizeOf(context).width >= 900;

    final imagen = _Galeria(equipo: equipo);
    // La clave cambia con el estado: así el botón «Comprar» y el aviso se
    // actualizan cuando el equipo pasa a «Reservado».
    final info = _InfoEquipo(
      key: ValueKey('${equipo.id}-${equipo.estado.name}'),
      equipo: equipo,
    );

    return Scaffold(
      body: Column(
        children: [
          BarraSuperior(
            // El logo devuelve al catálogo.
            alTocarLogo: () =>
                Navigator.of(context).popUntil((ruta) => ruta.isFirst),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margen, 20, margen, 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: ColoresApp.tinta,
                          ),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Volver al catálogo'),
                        ),
                        const SizedBox(height: 20),
                        // En pantallas anchas van lado a lado; en angostas,
                        // uno debajo del otro.
                        if (pantallaAncha)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: imagen),
                              const SizedBox(width: 56),
                              Expanded(flex: 5, child: info),
                            ],
                          )
                        else ...[
                          imagen,
                          const SizedBox(height: 36),
                          info,
                        ],
                      ],
                    ),
                  ),
                ),
                // El pie queda pegado abajo aunque haya poco contenido.
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: PieDePagina(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoEquipo extends StatefulWidget {
  const _InfoEquipo({super.key, required this.equipo});

  final Equipo equipo;

  @override
  State<_InfoEquipo> createState() => _InfoEquipoState();
}

class _InfoEquipoState extends State<_InfoEquipo> {
  bool _creando = false;

  Equipo get equipo => widget.equipo;

  /// Para comprar hay que tener cuenta: si no hay sesión, la pide primero
  /// y luego devuelve a la persona a esta misma pantalla (HU14).
  ///
  /// Después el servidor crea el pedido en «Pendiente de pago» (HU12) y se
  /// abre la pantalla del pago protegido (HU01).
  Future<void> _comprar() async {
    if (_creando) return;
    final listo = await asegurarSesion(context);
    if (!listo || !mounted) return;

    final usuario = SesionService.instancia.usuario;
    if (usuario == null) return;
    if (usuario.id == equipo.vendedorId) {
      mostrarAviso(context, 'No puedes comprar un equipo que tú publicaste.');
      return;
    }

    setState(() => _creando = true);
    try {
      final pedido = await PedidoService.instancia.crearPedido(equipo);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PagoScreen(pedido: pedido)),
      );
    } on ErrorDePedido catch (error) {
      if (mounted) mostrarAviso(context, error.mensaje);
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inicial = equipo.vendedor.isEmpty ? '?' : equipo.vendedor[0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EtiquetaEstado(estado: equipo.estado),
        const SizedBox(height: 14),
        Text(equipo.titulo, style: Tipos.titulo.copyWith(fontSize: 30)),
        const SizedBox(height: 10),
        Text(
          equipo.precioFormateado,
          style: Tipos.precio.copyWith(fontSize: 40, letterSpacing: -1),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: ColoresApp.cielo,
              child: Text(
                inicial,
                style: Tipos.subtitulo.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Vende ${equipo.vendedor}',
                style: Tipos.pequeno.copyWith(
                  fontSize: 15,
                  color: ColoresApp.tinta,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 2, color: ColoresApp.nube),
        const SizedBox(height: 24),
        _Dato(titulo: 'Estado declarado', valor: equipo.estadoDeclarado),
        const SizedBox(height: 18),
        _Dato(titulo: 'Descripción', valor: equipo.descripcion),
        const SizedBox(height: 28),
        const _CompraProtegida(),
        const SizedBox(height: 28),
        // Un equipo reservado no se puede comprar, y el vendedor tampoco
        // puede comprar el suyo: en esos casos no mostramos el botón.
        if (SesionService.instancia.usuario?.id == equipo.vendedorId &&
            equipo.vendedorId != null)
          const _Aviso('Este equipo es tuyo. Así lo ven los compradores.')
        else if (equipo.estaDisponible)
          BotonPegatina(
            texto: _creando ? 'Creando tu pedido…' : 'Comprar',
            icono: _creando ? Icons.hourglass_top : Icons.lock_outline,
            expandido: true,
            alTocar: _comprar,
          )
        else
          _AvisoReservado(equipo: equipo),
      ],
    );
  }
}

/// Un dato del equipo: un título pequeño y su valor debajo.
class _Dato extends StatelessWidget {
  const _Dato({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Tipos.subtitulo.copyWith(fontSize: 15)),
        const SizedBox(height: 4),
        Text(valor, style: Tipos.cuerpo),
      ],
    );
  }
}

/// Recuadro que explica cómo funciona el pago en custodia.
class _CompraProtegida extends StatelessWidget {
  const _CompraProtegida();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColoresApp.lila,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compra protegida', style: Tipos.subtitulo),
          SizedBox(height: 12),
          _PasoCorto(
            imagen: 'assets/images/pasos/custodia.png',
            texto: 'Pagas y tu dinero queda en custodia.',
          ),
          SizedBox(height: 10),
          _PasoCorto(
            imagen: 'assets/images/pasos/revision.png',
            texto: 'Revisamos el equipo en nuestro Hub.',
          ),
          SizedBox(height: 10),
          _PasoCorto(
            imagen: 'assets/images/pasos/liberado.png',
            texto:
                'Si pasa la inspección, te lo enviamos. Si no, te '
                'devolvemos tu dinero.',
          ),
        ],
      ),
    );
  }
}

class _PasoCorto extends StatelessWidget {
  const _PasoCorto({required this.imagen, required this.texto});

  final String imagen;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          imagen,
          width: 36,
          height: 36,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: Tipos.pequeno.copyWith(
              fontSize: 14.5,
              color: ColoresApp.tinta,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aviso de un equipo reservado. Si la persona fue quien lo compró, se lo
/// dice y le ofrece ir a «Mis compras».
class _AvisoReservado extends StatelessWidget {
  const _AvisoReservado({required this.equipo});

  final Equipo equipo;

  @override
  Widget build(BuildContext context) {
    if (!SesionService.instancia.haySesion) {
      return const _Aviso('Este equipo ya está reservado por otro comprador.');
    }
    return FutureBuilder<Pedido?>(
      future: PedidoService.instancia.compraPagada(equipo),
      builder: (context, resultado) {
        final mio = resultado.data;
        if (mio == null) {
          return const _Aviso(
            'Este equipo ya está reservado por otro comprador.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Aviso('Tú compraste este equipo (pedido ${mio.codigo}).'),
            const SizedBox(height: 14),
            BotonPegatina(
              texto: 'Ver mis compras',
              icono: Icons.receipt_long_outlined,
              principal: false,
              expandido: true,
              alTocar: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MisComprasScreen(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: ColoresApp.tinta),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Tipos.pequeno.copyWith(
                fontSize: 15,
                color: ColoresApp.tinta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto principal del equipo y, debajo, sus miniaturas para cambiarla.
class _Galeria extends StatefulWidget {
  const _Galeria({required this.equipo});

  final Equipo equipo;

  @override
  State<_Galeria> createState() => _GaleriaState();
}

class _GaleriaState extends State<_Galeria> {
  int _actual = 0;

  @override
  Widget build(BuildContext context) {
    final equipo = widget.equipo;
    final cantidad = equipo.fotos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pegatina(
          radio: 24,
          sombra: 8,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Las fotos reales se ven completas, sin recortar.
                ImagenEquipo(
                  equipo: equipo,
                  indice: _actual,
                  ajuste: cantidad > 0 ? BoxFit.contain : BoxFit.cover,
                ),
                if (cantidad > 1)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ColoresApp.tinta,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Foto ${_actual + 1} de $cantidad',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (cantidad > 1) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < cantidad; i++)
                Semantics(
                  button: true,
                  label: 'Ver foto ${i + 1} de $cantidad',
                  child: InkWell(
                    onTap: () => setState(() => _actual = i),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 84,
                      height: 63,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: i == _actual
                              ? ColoresApp.orquidea
                              : ColoresApp.tinta,
                          width: i == _actual ? 3 : 2,
                        ),
                      ),
                      child: ImagenEquipo(equipo: equipo, indice: i),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
