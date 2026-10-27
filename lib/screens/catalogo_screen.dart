import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/equipo.dart';
import '../services/catalogo_service.dart';
import '../tema.dart';
import '../widgets/barra_superior.dart';
import '../widgets/equipo_widgets.dart';
import '../widgets/pegatina.dart';
import '../widgets/pie_de_pagina.dart';
import 'detalle_equipo_screen.dart';

/// Pantalla inicial: la portada y el catálogo de equipos publicados.
///
/// Es pública, cualquiera la ve sin iniciar sesión.
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _clavePortada = GlobalKey();
  late Future<List<Equipo>> _equipos = const CatalogoService().obtenerEquipos();

  /// Vuelve a pedir los equipos (por ejemplo, después de un error).
  void _recargar() {
    if (!mounted) return;
    setState(() => _equipos = const CatalogoService().obtenerEquipos());
  }

  @override
  void initState() {
    super.initState();
    // Cuando alguien publica un equipo, el catálogo se vuelve a cargar.
    CatalogoService.cambios.addListener(_recargar);
  }

  @override
  void dispose() {
    CatalogoService.cambios.removeListener(_recargar);
    _scroll.dispose();
    super.dispose();
  }

  /// Baja la página hasta donde empieza el catálogo.
  void _verEquipos() {
    final caja =
        _clavePortada.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || !_scroll.hasClients) return;

    final destino = math.min(
      caja.size.height,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      destino,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _abrirDetalle(Equipo equipo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleEquipoScreen(equipo: equipo),
      ),
    );
  }

  /// Un mensaje centrado en el lugar del catálogo.
  Widget _sliverMensaje(double margen, Widget mensaje) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(margen, 0, margen, 64),
        child: mensaje,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final margen = margenLateral(context);

    return Scaffold(
      body: Column(
        children: [
          const BarraSuperior(),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    key: _clavePortada,
                    padding: EdgeInsets.fromLTRB(margen, 56, margen, 64),
                    child: _Portada(alVerEquipos: _verEquipos),
                  ),
                ),
                // El catálogo llega de Supabase: mientras carga, si falla o
                // si está vacío, se le dice al usuario qué está pasando.
                FutureBuilder<List<Equipo>>(
                  future: _equipos,
                  builder: (context, resultado) {
                    if (resultado.connectionState != ConnectionState.done) {
                      return _sliverMensaje(
                        margen,
                        const _EstadoCatalogo(
                          cargando: true,
                          texto: 'Cargando equipos…',
                        ),
                      );
                    }
                    final error = resultado.error;
                    if (error != null) {
                      return _sliverMensaje(
                        margen,
                        _EstadoCatalogo(
                          texto: error is ErrorDeCatalogo
                              ? error.mensaje
                              : 'No pudimos cargar los equipos.',
                          alReintentar: _recargar,
                        ),
                      );
                    }
                    final equipos = resultado.data ?? const <Equipo>[];
                    if (equipos.isEmpty) {
                      return _sliverMensaje(
                        margen,
                        const _EstadoCatalogo(
                          texto: 'Todavía no hay equipos publicados.',
                        ),
                      );
                    }
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.fromLTRB(margen, 0, margen, 22),
                            child:
                                _CabeceraCatalogo(cantidad: equipos.length),
                          ),
                        ),
                        SliverPadding(
                          padding:
                              EdgeInsets.fromLTRB(margen, 0, margen, 64),
                          sliver: SliverGrid(
                            // La cantidad de columnas se ajusta sola.
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              mainAxisExtent: 340,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, indice) {
                                final equipo = equipos[indice];
                                return TarjetaEquipo(
                                  equipo: equipo,
                                  alTocar: () => _abrirDetalle(equipo),
                                );
                              },
                              childCount: equipos.length,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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

/// Portada: el mensaje principal y, al lado, la ruta que sigue el pago.
class _Portada extends StatelessWidget {
  const _Portada({required this.alVerEquipos});

  final VoidCallback alVerEquipos;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final pantallaAncha = ancho >= 1000;
    // El titular se achica en pantallas pequeñas para que no se corte.
    final double tamanoTitular =
        pantallaAncha ? 46.0 : (ancho >= 480 ? 36.0 : 30.0);

    final mensaje = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transacciones de segunda mano, sin riesgo a estafas',
          style: Tipos.titular.copyWith(fontSize: tamanoTitular),
        ),
        const SizedBox(height: 16),
        Text(
          'Tu pago queda guardado hasta que revisamos el equipo en nuestro '
          'Hub. Solo entonces cobra el vendedor.',
          style: Tipos.cuerpo.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 28),
        BotonPegatina(texto: 'Ver equipos', alTocar: alVerEquipos),
      ],
    );

    const ruta = _RutaDelPago();

    if (pantallaAncha) {
      return Row(
        children: [
          Expanded(flex: 5, child: mensaje),
          const SizedBox(width: 56),
          const Expanded(flex: 6, child: ruta),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [mensaje, const SizedBox(height: 40), ruta],
    );
  }
}

/// Los tres pasos por los que pasa el dinero del comprador.
class _RutaDelPago extends StatelessWidget {
  const _RutaDelPago();

  @override
  Widget build(BuildContext context) {
    return const Pegatina(
      color: ColoresApp.lila,
      radio: 24,
      sombra: 8,
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Paso(
              imagen: 'assets/images/pasos/custodia.png',
              titulo: '1. Pagas y tu dinero queda en custodia',
              detalle: 'Nadie lo toca mientras revisamos el equipo.',
            ),
            _Conector(),
            _Paso(
              imagen: 'assets/images/pasos/revision.png',
              titulo: '2. Revisamos el equipo en nuestro Hub',
              detalle: 'Pantalla, batería, chasis, puertos y encendido.',
            ),
            _Conector(),
            _Paso(
              imagen: 'assets/images/pasos/liberado.png',
              titulo: '3. Se libera el pago',
              detalle:
                  'Si el equipo pasa, te lo enviamos. Si no, te devolvemos '
                  'tu dinero.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.imagen,
    required this.titulo,
    required this.detalle,
  });

  final String imagen;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          imagen,
          width: 72,
          height: 72,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: Tipos.subtitulo),
              const SizedBox(height: 3),
              Text(
                detalle,
                style: Tipos.pequeno.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tres puntitos que unen un paso con el siguiente.
class _Conector extends StatelessWidget {
  const _Conector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 34, top: 6, bottom: 6),
      child: Column(
        children: [
          _Punto(),
          SizedBox(height: 5),
          _Punto(),
          SizedBox(height: 5),
          _Punto(),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: ColoresApp.tinta,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CabeceraCatalogo extends StatelessWidget {
  const _CabeceraCatalogo({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Expanded(
          child: Text('Equipos publicados', style: Tipos.titulo),
        ),
        Text(
          '$cantidad equipos',
          style: Tipos.pequeno.copyWith(fontSize: 15),
        ),
      ],
    );
  }
}

/// Lo que se ve en lugar del catálogo mientras carga, si falla o si está
/// vacío (visibilidad del estado del sistema y recuperación de errores).
class _EstadoCatalogo extends StatelessWidget {
  const _EstadoCatalogo({
    required this.texto,
    this.cargando = false,
    this.alReintentar,
  });

  final String texto;
  final bool cargando;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (cargando)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: ColoresApp.orquidea,
              ),
            )
          else
            const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: ColoresApp.pizarra,
            ),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Tipos.cuerpo.copyWith(color: ColoresApp.tinta),
          ),
          if (alReintentar != null) ...[
            const SizedBox(height: 20),
            BotonPegatina(
              texto: 'Reintentar',
              icono: Icons.refresh,
              alTocar: alReintentar!,
            ),
          ],
        ],
      ),
    );
  }
}
