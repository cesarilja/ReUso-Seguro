import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/equipo.dart';
import '../services/catalogo_service.dart';
import '../services/filtro_catalogo.dart';
import '../services/publicacion_service.dart';
import '../services/reputacion_service.dart';
import '../services/voz_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/barra_superior.dart';
import '../widgets/equipo_widgets.dart';
import '../widgets/navegacion.dart';
import '../widgets/pegatina.dart';
import '../widgets/pie_de_pagina.dart';
import 'detalle_equipo_screen.dart';
import 'publicar_screen.dart';

/// Pantalla inicial: vitrina estilo marketplace con buscador protagonista,
/// categorías visuales, carruseles destacados y catálogo con filtros laterales.
///
/// Es pública, cualquiera la ve sin iniciar sesión.
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key, this.cargador});

  /// Solo para pruebas: reemplaza la carga de equipos desde Supabase.
  @visibleForTesting
  final Future<List<Equipo>> Function()? cargador;

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _claveCatalogo = GlobalKey();
  final TextEditingController _buscador = TextEditingController();
  late Future<List<Equipo>> _equipos = _pedirEquipos();

  Future<List<Equipo>> _pedirEquipos() =>
      widget.cargador?.call() ?? const CatalogoService().obtenerEquipos();

  /// Lo que la persona eligió para buscar y filtrar.
  FiltroCatalogo _filtro = const FiltroCatalogo();

  void _cambiarFiltro(FiltroCatalogo nuevo) => setState(() => _filtro = nuevo);

  void _limpiarFiltros() {
    _buscador.clear();
    setState(() => _filtro = FiltroCatalogo(orden: _filtro.orden));
  }

  /// Vuelve a pedir los equipos (por ejemplo, después de un error).
  void _recargar() {
    if (!mounted) return;
    setState(() => _equipos = _pedirEquipos());
    ReputacionService.instancia.cargar(forzar: true);
  }

  @override
  void initState() {
    super.initState();
    // HU20: los sellos de los vendedores, una sola vez para todo el catálogo.
    ReputacionService.instancia.cargar();
    // Cuando alguien publica un equipo, el catálogo se vuelve a cargar.
    CatalogoService.cambios.addListener(_recargar);
  }

  @override
  void dispose() {
    CatalogoService.cambios.removeListener(_recargar);
    _scroll.dispose();
    _buscador.dispose();
    super.dispose();
  }

  /// Baja suavemente hasta el catálogo principal.
  ///
  /// Se espera al siguiente cuadro: si antes se cambió un filtro, las vitrinas
  /// desaparecen y la posición del catálogo cambia al redibujar.
  void _irAlCatalogo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contexto = _claveCatalogo.currentContext;
      if (contexto == null) return;
      Scrollable.ensureVisible(
        contexto,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Elegir una categoría filtra y lleva directo a los resultados.
  void _elegirCategoria(String? categoria) {
    if (categoria == null || _filtro.categoria == categoria) {
      _cambiarFiltro(_filtro.copiar(quitarCategoria: true));
    } else {
      _cambiarFiltro(_filtro.copiar(categoria: categoria));
      _irAlCatalogo();
    }
  }

  void _abrirDetalle(Equipo equipo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleEquipoScreen(equipo: equipo),
      ),
    );
  }

  /// Un mensaje centrado en el lugar del catálogo.
  Widget _mensajeCatalogo(double margen, Widget mensaje) {
    return Padding(
      padding: EdgeInsets.fromLTRB(margen, 0, margen, 64),
      child: mensaje,
    );
  }

  @override
  Widget build(BuildContext context) {
    final margen = margenLateral(context);
    final ancho = MediaQuery.sizeOf(context).width;
    final conSidebar = ancho >= 1024;

    return Scaffold(
      body: Column(
        children: [
          const BarraSuperior(seccion: Seccion.inicio),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                // ── Portada compacta estilo marketplace + buscador ───────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margen, 20, margen, 20),
                    child: _PortadaMarketplace(
                      buscador: _buscador,
                      textoBusqueda: _filtro.texto,
                      alBuscarTexto: (t) =>
                          _cambiarFiltro(_filtro.copiar(texto: t)),
                      alEnviarBusqueda: _irAlCatalogo,
                      alLimpiarBusqueda: () {
                        _buscador.clear();
                        _cambiarFiltro(_filtro.copiar(texto: ''));
                      },
                    ),
                  ),
                ),

                // ── Contenido cargado desde Supabase ─────────────────────
                SliverToBoxAdapter(
                  child: FutureBuilder<List<Equipo>>(
                    future: _equipos,
                    builder: (context, resultado) {
                      if (resultado.connectionState != ConnectionState.done &&
                          !resultado.hasData) {
                        return _mensajeCatalogo(
                          margen,
                          const _EstadoCatalogo(
                            cargando: true,
                            texto: 'Cargando equipos…',
                          ),
                        );
                      }
                      final error = resultado.error;
                      if (error != null && !resultado.hasData) {
                        return _mensajeCatalogo(
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
                        return _mensajeCatalogo(
                          margen,
                          const _EstadoCatalogo(
                            texto: 'Todavía no hay equipos publicados.',
                          ),
                        );
                      }

                      final filtrados = _filtro.aplicar(equipos);
                      final ultimos = equipos.take(6).toList(growable: false);
                      final detallados = equipos
                          .where((e) => e.inspeccionDetallada)
                          .take(8)
                          .toList(growable: false);
                      final maxPrecioCatalogo = _techoPrecio(equipos);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Franja de métricas en vivo ─────────────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(margen, 0, margen, 20),
                            child: _FranjaMetricas(equipos: equipos),
                          ),

                          // ── Tira visual de categorías ──────────────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(margen, 0, margen, 24),
                            child: _TiraCategorias(
                              equipos: equipos,
                              categoriaActiva: _filtro.categoria,
                              alElegir: _elegirCategoria,
                            ),
                          ),

                          // ── Vitrinas curadas (siempre fijas para que el
                          //    catálogo no salte ni suba al filtrar/limpiar)
                          Padding(
                            padding: EdgeInsets.fromLTRB(margen, 0, margen, 28),
                            child: _CarruselVitrina(
                              icono: Icons.new_releases_outlined,
                              titulo: 'Últimos publicados',
                              subtitulo:
                                  'Recién llegados al catálogo de ReUso Seguro',
                              equipos: ultimos,
                              marcarNuevos: 3,
                              textoAccion: 'Ver todo el catálogo',
                              alAccion: _irAlCatalogo,
                              alAbrirEquipo: _abrirDetalle,
                            ),
                          ),
                          if (detallados.length >= 2)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                margen,
                                0,
                                margen,
                                28,
                              ),
                              child: _CarruselVitrina(
                                icono: Icons.workspace_premium_outlined,
                                titulo: 'Con Inspección Detallada',
                                subtitulo:
                                    'Revisión punto por punto con notas del inspector y 7 días de garantía',
                                equipos: detallados,
                                textoAccion: 'Filtrar detallados',
                                alAccion: () {
                                  _cambiarFiltro(
                                    _filtro.copiar(soloDetallada: true),
                                  );
                                  _irAlCatalogo();
                                },
                                alAbrirEquipo: _abrirDetalle,
                              ),
                            ),

                          // ── Catálogo principal (sidebar en escritorio) ─
                          Padding(
                            key: _claveCatalogo,
                            padding: EdgeInsets.fromLTRB(margen, 0, margen, 40),
                            child: conSidebar
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 268,
                                        child: _SidebarFiltros(
                                          equipos: equipos,
                                          filtro: _filtro,
                                          maxPrecio: maxPrecioCatalogo,
                                          alCambiar: _cambiarFiltro,
                                          alLimpiar: _limpiarFiltros,
                                        ),
                                      ),
                                      const SizedBox(width: 28),
                                      Expanded(
                                        child: _ColumnaResultados(
                                          filtrados: filtrados,
                                          total: equipos.length,
                                          filtro: _filtro,
                                          alCambiarFiltro: _cambiarFiltro,
                                          alLimpiar: _limpiarFiltros,
                                          alAbrirEquipo: _abrirDetalle,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _BarraFiltrosCompacta(
                                        filtro: _filtro,
                                        maxPrecio: maxPrecioCatalogo,
                                        alCambiar: _cambiarFiltro,
                                        alLimpiar: _limpiarFiltros,
                                      ),
                                      const SizedBox(height: 20),
                                      _ColumnaResultados(
                                        filtrados: filtrados,
                                        total: equipos.length,
                                        filtro: _filtro,
                                        alCambiarFiltro: _cambiarFiltro,
                                        alLimpiar: _limpiarFiltros,
                                        alAbrirEquipo: _abrirDetalle,
                                      ),
                                    ],
                                  ),
                          ),

                          // ── Llamado a vender ───────────────────────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(margen, 0, margen, 48),
                            child: const _LlamadoVender(),
                          ),
                        ],
                      );
                    },
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

  /// Redondea hacia arriba al múltiplo de 50 más cercano (mínimo 100).
  static double _techoPrecio(List<Equipo> equipos) {
    final max = equipos.fold<double>(
      100,
      (prev, e) => math.max(prev, e.precio),
    );
    return (max / 50).ceil() * 50.0;
  }
}

// =============================================================================
// 1. PORTADA COMPACTA + BUSCADOR PROTAGONISTA
// =============================================================================

class _PortadaMarketplace extends StatelessWidget {
  const _PortadaMarketplace({
    required this.buscador,
    required this.textoBusqueda,
    required this.alBuscarTexto,
    required this.alEnviarBusqueda,
    required this.alLimpiarBusqueda,
  });

  final TextEditingController buscador;
  final String textoBusqueda;
  final ValueChanged<String> alBuscarTexto;
  final VoidCallback alEnviarBusqueda;
  final VoidCallback alLimpiarBusqueda;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final ancha = ancho >= 980;
    final double tamanoTitular = ancha ? 34.0 : (ancho >= 520 ? 28.0 : 24.0);

    final cajaBuscador = Row(
      children: [
        Expanded(
          child: TextField(
            controller: buscador,
            onChanged: alBuscarTexto,
            onSubmitted: (_) => alEnviarBusqueda(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Busca laptops, iPhones, consolas, audífonos…',
              hintStyle: const TextStyle(color: ColoresApp.pizarra),
              prefixIcon: const Icon(Icons.search, color: ColoresApp.tinta),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (textoBusqueda.isNotEmpty)
                    IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: const Icon(Icons.close, color: ColoresApp.tinta),
                      onPressed: alLimpiarBusqueda,
                    ),
                  _BotonDictadoVoz(
                    alDictar: (texto) {
                      buscador.text = texto;
                      alBuscarTexto(texto);
                      alEnviarBusqueda();
                    },
                  ),
                ],
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: ColoresApp.tinta, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: ColoresApp.orquideaAccesible,
                  width: 3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        BotonPegatina(
          texto: 'Buscar',
          icono: Icons.search,
          compacto: !ancha,
          tooltip: 'Ir a los resultados de búsqueda',
          alTocar: alEnviarBusqueda,
        ),
      ],
    );

    final izquierda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ColoresApp.tinta,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined,
                  size: 14, color: ColoresApp.cielo),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Compra protegida con inspección técnica',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            'Tecnología de segunda mano, sin riesgo a estafas',
            style: Tipos.titular.copyWith(fontSize: tamanoTitular, height: 1.15),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Tu pago queda en custodia hasta que nuestro Hub revisa el equipo '
                'punto por punto. Si no pasa, te devolvemos el dinero.',
                style: Tipos.cuerpo.copyWith(
                  fontSize: 15.5,
                  color: ColoresApp.tinta,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const _BotonLecturaResumen(),
          ],
        ),
        const SizedBox(height: 18),
        cajaBuscador,
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _Garantia(
                icono: Icons.lock_outline, texto: 'Pago en custodia'),
            const _Garantia(
              icono: Icons.fact_check_outlined,
              texto: 'Revisión en el Hub',
            ),
            const _Garantia(icono: Icons.undo, texto: 'Reembolso garantizado'),
            TextButton.icon(
              onPressed: () => irA(context, Seccion.comoFunciona),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.tinta),
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('¿Cómo funciona?'),
            ),
          ],
        ),
      ],
    );

    const pasosCompactos = _RutaCompacta();

    return Pegatina(
      color: ColoresApp.lila,
      radio: 22,
      sombra: 6,
      child: Padding(
        padding: EdgeInsets.all(ancha ? 28 : 20),
        child: ancha
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: izquierda),
                  const SizedBox(width: 28),
                  const Expanded(flex: 4, child: pasosCompactos),
                ],
              )
            : izquierda,
      ),
    );
  }
}

class _Garantia extends StatelessWidget {
  const _Garantia({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColoresApp.cielo, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: ColoresApp.tinta),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ColoresApp.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

class _RutaCompacta extends StatelessWidget {
  const _RutaCompacta();

  @override
  Widget build(BuildContext context) {
    Widget paso(String img, String titulo, String detalle) {
      return Row(
        children: [
          Image.asset(
            img,
            width: 44,
            height: 44,
            filterQuality: FilterQuality.medium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: Tipos.subtitulo.copyWith(fontSize: 14),
                ),
                Text(
                  detalle,
                  style: Tipos.pequeno.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.tinta, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          paso(
            'assets/images/pasos/custodia.png',
            '1. Pago protegido',
            'Tu dinero queda en custodia segura.',
          ),
          const SizedBox(height: 12),
          paso(
            'assets/images/pasos/revision.png',
            '2. Inspección en el Hub',
            'Un técnico prueba el equipo punto por punto.',
          ),
          const SizedBox(height: 12),
          paso(
            'assets/images/pasos/liberado.png',
            '3. Entrega o reembolso',
            'Si aprueba, te llega. Si no, recuperas tu pago.',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. FRANJA DE MÉTRICAS EN VIVO
// =============================================================================

class _FranjaMetricas extends StatelessWidget {
  const _FranjaMetricas({required this.equipos});

  final List<Equipo> equipos;

  @override
  Widget build(BuildContext context) {
    final disponibles = equipos.where((e) => e.estaDisponible).length;
    final detallados = equipos.where((e) => e.inspeccionDetallada).length;
    final express = equipos.where((e) => e.express && e.estaDisponible).length;

    Widget metrica(IconData icono, String valor, String etiqueta, Color color) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 18, color: color),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valor,
                style: Tipos.subtitulo.copyWith(fontSize: 15, height: 1.1),
              ),
              Text(
                etiqueta,
                style: Tipos.pequeno.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.cielo, width: 1.2),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        children: [
          metrica(
            Icons.storefront_outlined,
            '$disponibles disponibles',
            'Listos para comprar hoy',
            ColoresApp.verde,
          ),
          metrica(
            Icons.workspace_premium_outlined,
            '$detallados con Detallada',
            '7 días de garantía en reclamos',
            ColoresApp.orquidea,
          ),
          metrica(
            Icons.bolt,
            '$express con Express',
            'Revisión en menos de 24 h',
            ColoresApp.vinca,
          ),
          metrica(
            Icons.shield_outlined,
            '100 % en custodia',
            'Sin transferencias directas',
            ColoresApp.tinta,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. TIRA VISUAL DE CATEGORÍAS (ESTILO MERCADO LIBRE / EBAY)
// =============================================================================

IconData _iconoCategoria(String? categoria) => switch (categoria) {
      'Laptop' => Icons.laptop_mac_outlined,
      'Teléfono' => Icons.smartphone_outlined,
      'Tablet' => Icons.tablet_mac_outlined,
      'Consola' => Icons.sports_esports_outlined,
      'Audio' => Icons.headphones_outlined,
      'Otro' => Icons.monitor_outlined,
      _ => Icons.apps_rounded,
    };

class _TiraCategorias extends StatelessWidget {
  const _TiraCategorias({
    required this.equipos,
    required this.categoriaActiva,
    required this.alElegir,
  });

  final List<Equipo> equipos;
  final String? categoriaActiva;
  final ValueChanged<String?> alElegir;

  @override
  Widget build(BuildContext context) {
    int contar(String? cat) {
      if (cat == null) return equipos.length;
      return equipos.where((e) => e.categoria == cat).length;
    }

    final items = <String?>[null, ...ReglasPublicacion.categorias];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explora por categoría',
          style: Tipos.subtitulo.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, caja) {
            const hueco = 12.0;
            const anchoMinimo = 112.0;
            final cabenTodas = caja.maxWidth >=
                items.length * anchoMinimo + (items.length - 1) * hueco;

            Widget tarjeta(String? cat, {double? ancho}) => _TarjetaCategoria(
                  nombre: cat ?? 'Todos',
                  icono: _iconoCategoria(cat),
                  cantidad: contar(cat),
                  activa: categoriaActiva == cat,
                  ancho: ancho,
                  alTocar: () => alElegir(cat),
                );

            // Si caben, se reparten el ancho completo (sin huecos a la
            // derecha); si no, se deslizan de lado.
            if (cabenTodas) {
              return Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    Expanded(child: tarjeta(items[i])),
                    if (i < items.length - 1) const SizedBox(width: hueco),
                  ],
                ],
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    tarjeta(items[i], ancho: 124),
                    if (i < items.length - 1) const SizedBox(width: hueco),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TarjetaCategoria extends StatefulWidget {
  const _TarjetaCategoria({
    required this.nombre,
    required this.icono,
    required this.cantidad,
    required this.activa,
    required this.alTocar,
    this.ancho,
  });

  final String nombre;
  final IconData icono;
  final int cantidad;
  final bool activa;
  final VoidCallback alTocar;

  /// null = ocupa todo el ancho que le den.
  final double? ancho;

  @override
  State<_TarjetaCategoria> createState() => _TarjetaCategoriaState();
}

class _TarjetaCategoriaState extends State<_TarjetaCategoria> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final resaltada = widget.activa || _hover;
    return Semantics(
      button: true,
      selected: widget.activa,
      label: '${widget.nombre}, ${widget.cantidad} equipos',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.alTocar,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.ancho,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: widget.activa
                  ? ColoresApp.tinta
                  : _hover
                      ? ColoresApp.lila
                      : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: resaltada ? ColoresApp.tinta : const Color(0xFFC9CCD8),
                width: widget.activa ? 2 : 1.5,
              ),
              boxShadow: resaltada
                  ? [
                      BoxShadow(
                        color: widget.activa
                            ? ColoresApp.orquidea
                            : ColoresApp.tinta.withAlpha(40),
                        offset: const Offset(3, 3),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: widget.activa
                        ? Colors.white.withAlpha(25)
                        : ColoresApp.nube,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icono,
                    size: 22,
                    color: widget.activa ? Colors.white : ColoresApp.tinta,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: widget.activa ? Colors.white : ColoresApp.tinta,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.cantidad} ${widget.cantidad == 1 ? 'equipo' : 'equipos'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        widget.activa ? ColoresApp.cielo : ColoresApp.pizarra,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 4. CARRUSEL HORIZONTAL DE VITRINA (ÚLTIMOS PUBLICADOS / DETALLADA)
// =============================================================================

class _CarruselVitrina extends StatefulWidget {
  const _CarruselVitrina({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.equipos,
    required this.alAbrirEquipo,
    this.marcarNuevos = 0,
    this.textoAccion,
    this.alAccion,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final List<Equipo> equipos;
  final ValueChanged<Equipo> alAbrirEquipo;
  final int marcarNuevos;
  final String? textoAccion;
  final VoidCallback? alAccion;

  @override
  State<_CarruselVitrina> createState() => _CarruselVitrinaState();
}

class _CarruselVitrinaState extends State<_CarruselVitrina> {
  final ScrollController _controlador = ScrollController();

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  static const double _hueco = 18;

  /// Cuántas tarjetas se ven a la vez y qué tan anchas son, para que el
  /// carrusel llene el ancho disponible sin dejar huecos a los lados.
  ({int visibles, double ancho}) _medidas(double disponible) {
    final visibles = ((disponible + _hueco) / (250 + _hueco)).floor().clamp(1, 6);
    final ancho = (disponible - (visibles - 1) * _hueco) / visibles;
    return (visibles: visibles, ancho: ancho);
  }

  void _desplazar(double delta) {
    if (!_controlador.hasClients) return;
    final destino = (_controlador.offset + delta).clamp(
      0.0,
      _controlador.position.maxScrollExtent,
    );
    _controlador.animateTo(
      destino,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, caja) {
        final medidas = _medidas(caja.maxWidth);
        final hayMas = widget.equipos.length > medidas.visibles;
        final estrecho = caja.maxWidth < 620;

        final accion = (widget.textoAccion != null && widget.alAccion != null)
            ? TextButton.icon(
                onPressed: widget.alAccion,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(widget.textoAccion!),
              )
            : null;

        final flechas = hayMas
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BotonFlecha(
                    icono: Icons.chevron_left,
                    tooltip: 'Ver anteriores',
                    alTocar: () => _desplazar(-(medidas.ancho + _hueco) * 2),
                  ),
                  const SizedBox(width: 6),
                  _BotonFlecha(
                    icono: Icons.chevron_right,
                    tooltip: 'Ver siguientes',
                    alTocar: () => _desplazar((medidas.ancho + _hueco) * 2),
                  ),
                ],
              )
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ColoresApp.lila,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ColoresApp.orquidea, width: 1.5),
                  ),
                  child: Icon(widget.icono, size: 22, color: ColoresApp.tinta),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titulo,
                        style: Tipos.titulo.copyWith(fontSize: 22),
                      ),
                      Text(
                        widget.subtitulo,
                        style: Tipos.pequeno.copyWith(fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                if (!estrecho && accion != null) accion,
                if (flechas != null) ...[
                  const SizedBox(width: 6),
                  flechas,
                ],
              ],
            ),
            if (estrecho && accion != null)
              Align(alignment: Alignment.centerLeft, child: accion),
            const SizedBox(height: 14),
            SizedBox(
              height: 365,
              child: ListView.separated(
                controller: _controlador,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 10, right: 6),
                itemCount: widget.equipos.length,
                separatorBuilder: (_, __) => const SizedBox(width: _hueco),
                itemBuilder: (context, i) {
                  final equipo = widget.equipos[i];
                  return SizedBox(
                    // Con pocos equipos no se estiran demasiado.
                    width: math.min(medidas.ancho, 340),
                    child: TarjetaEquipo(
                      equipo: equipo,
                      esNuevo: i < widget.marcarNuevos,
                      alTocar: () => widget.alAbrirEquipo(equipo),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BotonFlecha extends StatelessWidget {
  const _BotonFlecha({
    required this.icono,
    required this.tooltip,
    required this.alTocar,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: ColoresApp.tinta, width: 1.5),
        ),
        child: InkWell(
          onTap: alTocar,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icono, size: 22, color: ColoresApp.tinta),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. SIDEBAR LATERAL DE FILTROS (ESCRITORIO) + BARRA COMPACTA (MÓVIL)
// =============================================================================

class _SidebarFiltros extends StatelessWidget {
  const _SidebarFiltros({
    required this.equipos,
    required this.filtro,
    required this.maxPrecio,
    required this.alCambiar,
    required this.alLimpiar,
  });

  final List<Equipo> equipos;
  final FiltroCatalogo filtro;
  final double maxPrecio;
  final ValueChanged<FiltroCatalogo> alCambiar;
  final VoidCallback alLimpiar;

  @override
  Widget build(BuildContext context) {
    final minActual = (filtro.precioMin ?? 0).clamp(0.0, maxPrecio);
    final maxActual = (filtro.precioMax ?? maxPrecio).clamp(minActual, maxPrecio);

    int contar(String? cat) {
      if (cat == null) return equipos.length;
      return equipos.where((e) => e.categoria == cat).length;
    }

    Widget tituloSeccion(String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            texto,
            style: Tipos.subtitulo.copyWith(fontSize: 14.5),
          ),
        );

    return Pegatina(
      radio: 18,
      sombra: 4,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 20, color: ColoresApp.tinta),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Filtros',
                    style: Tipos.subtitulo.copyWith(fontSize: 17),
                  ),
                ),
                if (filtro.activo)
                  TextButton(
                    onPressed: alLimpiar,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Limpiar'),
                  ),
              ],
            ),
            const Divider(height: 22),

            // ── Ordenar por ──────────────────────────────────────────────
            tituloSeccion('Ordenar por'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC9CCD8), width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<OrdenCatalogo>(
                  isExpanded: true,
                  value: filtro.orden,
                  icon: const Icon(Icons.swap_vert,
                      size: 18, color: ColoresApp.tinta),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ColoresApp.tinta,
                  ),
                  onChanged: (o) {
                    if (o != null) alCambiar(filtro.copiar(orden: o));
                  },
                  items: [
                    for (final o in OrdenCatalogo.values)
                      DropdownMenuItem(value: o, child: Text(o.nombre)),
                  ],
                ),
              ),
            ),
            const Divider(height: 26),

            // ── Rango de precio ──────────────────────────────────────────
            tituloSeccion('Precio'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatearDolares(minActual),
                  style: Tipos.pequeno.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.tinta,
                  ),
                ),
                Text(
                  formatearDolares(maxActual),
                  style: Tipos.pequeno.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.tinta,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(minActual, maxActual),
              min: 0,
              max: maxPrecio,
              divisions: math.max(1, (maxPrecio / 10).round()),
              activeColor: ColoresApp.orquidea,
              inactiveColor: ColoresApp.nube,
              onChanged: (rango) {
                alCambiar(
                  filtro.copiar(
                    precioMin: rango.start <= 0 ? null : rango.start,
                    quitarPrecioMin: rango.start <= 0,
                    precioMax: rango.end >= maxPrecio ? null : rango.end,
                    quitarPrecioMax: rango.end >= maxPrecio,
                  ),
                );
              },
            ),
            const Divider(height: 22),

            // ── Inspección y disponibilidad ──────────────────────────────
            tituloSeccion('Estado e inspección'),
            _FilaSwitchFiltro(
              etiqueta: 'Solo disponibles',
              valor: filtro.soloDisponibles,
              alCambiar: (v) => alCambiar(filtro.copiar(soloDisponibles: v)),
            ),
            _FilaSwitchFiltro(
              etiqueta: 'Inspección detallada',
              valor: filtro.soloDetallada,
              alCambiar: (v) => alCambiar(filtro.copiar(soloDetallada: v)),
            ),
            _FilaSwitchFiltro(
              etiqueta: 'Express (< 24 h)',
              valor: filtro.soloExpress,
              alCambiar: (v) => alCambiar(filtro.copiar(soloExpress: v)),
            ),
            const Divider(height: 24),

            // ── Categorías ───────────────────────────────────────────────
            tituloSeccion('Categoría'),
            for (final cat in <String?>[null, ...ReglasPublicacion.categorias])
              _ItemCategoriaSidebar(
                nombre: cat ?? 'Todas las categorías',
                icono: _iconoCategoria(cat),
                cantidad: contar(cat),
                activa: filtro.categoria == cat,
                alTocar: () => alCambiar(
                  cat == null
                      ? filtro.copiar(quitarCategoria: true)
                      : filtro.copiar(categoria: cat),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaSwitchFiltro extends StatelessWidget {
  const _FilaSwitchFiltro({
    required this.etiqueta,
    required this.valor,
    required this.alCambiar,
  });

  final String etiqueta;
  final bool valor;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: Tipos.pequeno.copyWith(
                fontSize: 13.5,
                color: ColoresApp.tinta,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(value: valor, onChanged: alCambiar),
          ),
        ],
      ),
    );
  }
}

class _ItemCategoriaSidebar extends StatelessWidget {
  const _ItemCategoriaSidebar({
    required this.nombre,
    required this.icono,
    required this.cantidad,
    required this.activa,
    required this.alTocar,
  });

  final String nombre;
  final IconData icono;
  final int cantidad;
  final bool activa;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: activa ? ColoresApp.lila : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 17,
                color: activa ? ColoresApp.tinta : ColoresApp.pizarra,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                    color: ColoresApp.tinta,
                  ),
                ),
              ),
              Text(
                '$cantidad',
                style: Tipos.pequeno.copyWith(
                  fontSize: 12,
                  fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de filtros para pantallas pequeñas/medianas (< 1024 px).
class _BarraFiltrosCompacta extends StatelessWidget {
  const _BarraFiltrosCompacta({
    required this.filtro,
    required this.maxPrecio,
    required this.alCambiar,
    required this.alLimpiar,
  });

  final FiltroCatalogo filtro;
  final double maxPrecio;
  final ValueChanged<FiltroCatalogo> alCambiar;
  final VoidCallback alLimpiar;

  /// Hoja inferior con el slider de precio (en pantallas pequeñas).
  Future<void> _elegirPrecio(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (hoja) {
        var rango = RangeValues(
          (filtro.precioMin ?? 0).clamp(0.0, maxPrecio).toDouble(),
          (filtro.precioMax ?? maxPrecio).clamp(0.0, maxPrecio).toDouble(),
        );
        return StatefulBuilder(
          builder: (hoja, setHoja) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Rango de precio', style: Tipos.subtitulo),
                const SizedBox(height: 8),
                Text(
                  '${formatearDolares(rango.start)} – ${formatearDolares(rango.end)}',
                  style: Tipos.cuerpo.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.tinta,
                  ),
                ),
                RangeSlider(
                  values: rango,
                  min: 0,
                  max: maxPrecio,
                  divisions: math.max(1, (maxPrecio / 10).round()),
                  activeColor: ColoresApp.orquidea,
                  inactiveColor: ColoresApp.nube,
                  onChanged: (v) => setHoja(() => rango = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        alCambiar(filtro.copiar(
                          quitarPrecioMin: true,
                          quitarPrecioMax: true,
                        ));
                        Navigator.of(hoja).pop();
                      },
                      child: const Text('Quitar precio'),
                    ),
                    const Spacer(),
                    BotonPegatina(
                      texto: 'Aplicar',
                      compacto: true,
                      alTocar: () {
                        alCambiar(filtro.copiar(
                          precioMin: rango.start <= 0 ? null : rango.start,
                          quitarPrecioMin: rango.start <= 0,
                          precioMax: rango.end >= maxPrecio ? null : rango.end,
                          quitarPrecioMax: rango.end >= maxPrecio,
                        ));
                        Navigator.of(hoja).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(String texto, bool elegido, VoidCallback alTocar,
        {IconData? icono}) {
      return FilterChip(
        selected: elegido,
        onSelected: (_) => alTocar(),
        showCheckmark: elegido,
        checkmarkColor: Colors.white,
        avatar: icono == null || elegido
            ? null
            : Icon(icono, size: 17, color: ColoresApp.tinta),
        label: Text(texto),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: elegido ? Colors.white : ColoresApp.tinta,
        ),
        backgroundColor: Colors.white,
        selectedColor: ColoresApp.tinta,
        side: const BorderSide(color: ColoresApp.tinta, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ColoresApp.tinta, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<OrdenCatalogo>(
              value: filtro.orden,
              icon: const Icon(Icons.swap_vert,
                  size: 18, color: ColoresApp.tinta),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ColoresApp.tinta,
              ),
              onChanged: (o) {
                if (o != null) alCambiar(filtro.copiar(orden: o));
              },
              items: [
                for (final o in OrdenCatalogo.values)
                  DropdownMenuItem(value: o, child: Text(o.nombre)),
              ],
            ),
          ),
        ),
        chip(
          'Solo disponibles',
          filtro.soloDisponibles,
          () => alCambiar(
            filtro.copiar(soloDisponibles: !filtro.soloDisponibles),
          ),
          icono: Icons.check_circle_outline,
        ),
        chip(
          'Inspección detallada',
          filtro.soloDetallada,
          () => alCambiar(filtro.copiar(soloDetallada: !filtro.soloDetallada)),
          icono: Icons.workspace_premium_outlined,
        ),
        chip(
          'Express 24h',
          filtro.soloExpress,
          () => alCambiar(filtro.copiar(soloExpress: !filtro.soloExpress)),
          icono: Icons.bolt,
        ),
        chip(
          filtro.precioMin != null || filtro.precioMax != null
              ? 'Precio: ${formatearDolares(filtro.precioMin ?? 0)} – '
                  '${filtro.precioMax != null ? formatearDolares(filtro.precioMax!) : 'máx.'}'
              : 'Precio',
          filtro.precioMin != null || filtro.precioMax != null,
          () => _elegirPrecio(context),
          icono: Icons.attach_money,
        ),
        if (filtro.activo)
          TextButton.icon(
            onPressed: alLimpiar,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Limpiar'),
          ),
      ],
    );
  }
}

// =============================================================================
// 6. COLUMNA DE RESULTADOS + CUADRÍCULA DE EQUIPOS
// =============================================================================

class _ColumnaResultados extends StatelessWidget {
  const _ColumnaResultados({
    required this.filtrados,
    required this.total,
    required this.filtro,
    required this.alCambiarFiltro,
    required this.alLimpiar,
    required this.alAbrirEquipo,
  });

  final List<Equipo> filtrados;
  final int total;
  final FiltroCatalogo filtro;
  final ValueChanged<FiltroCatalogo> alCambiarFiltro;
  final VoidCallback alLimpiar;
  final ValueChanged<Equipo> alAbrirEquipo;

  @override
  Widget build(BuildContext context) {
    final contador = filtrados.length == total
        ? '$total ${total == 1 ? 'equipo' : 'equipos'}'
        : '${filtrados.length} de $total equipos';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                filtro.categoria != null
                    ? 'Equipos · ${filtro.categoria}'
                    : 'Todo el catálogo',
                style: Tipos.titulo.copyWith(fontSize: 24),
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Text(
                contador,
                style: Tipos.pequeno.copyWith(fontSize: 14.5),
              ),
            ),
          ],
        ),
        // Chips removibles de filtros activos
        if (filtro.activo) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (filtro.texto.trim().isNotEmpty)
                InputChip(
                  label: Text('Búsqueda: «${filtro.texto.trim()}»'),
                  onDeleted: () => alCambiarFiltro(filtro.copiar(texto: '')),
                ),
              if (filtro.categoria != null)
                InputChip(
                  label: Text(filtro.categoria!),
                  onDeleted: () =>
                      alCambiarFiltro(filtro.copiar(quitarCategoria: true)),
                ),
              if (filtro.soloDisponibles)
                InputChip(
                  label: const Text('Solo disponibles'),
                  onDeleted: () =>
                      alCambiarFiltro(filtro.copiar(soloDisponibles: false)),
                ),
              if (filtro.soloDetallada)
                InputChip(
                  label: const Text('Inspección detallada'),
                  onDeleted: () =>
                      alCambiarFiltro(filtro.copiar(soloDetallada: false)),
                ),
              if (filtro.soloExpress)
                InputChip(
                  label: const Text('Express 24h'),
                  onDeleted: () =>
                      alCambiarFiltro(filtro.copiar(soloExpress: false)),
                ),
              if (filtro.precioMin != null || filtro.precioMax != null)
                InputChip(
                  label: Text(
                    'Precio: ${filtro.precioMin != null ? formatearDolares(filtro.precioMin!) : '\$0'} – '
                    '${filtro.precioMax != null ? formatearDolares(filtro.precioMax!) : 'máx.'}',
                  ),
                  onDeleted: () => alCambiarFiltro(
                    filtro.copiar(quitarPrecioMin: true, quitarPrecioMax: true),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        if (filtrados.isEmpty)
          _EstadoCatalogo(
            icono: Icons.search_off,
            texto: 'Ningún equipo coincide con lo que buscas. Prueba con '
                'otras palabras o quita algún filtro.',
            textoBoton: 'Limpiar filtros',
            iconoBoton: Icons.filter_alt_off_outlined,
            alReintentar: alLimpiar,
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 290,
              mainAxisExtent: 360,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: filtrados.length,
            itemBuilder: (context, indice) {
              final equipo = filtrados[indice];
              return TarjetaEquipo(
                equipo: equipo,
                alTocar: () => alAbrirEquipo(equipo),
              );
            },
          ),
      ],
    );
  }
}

// =============================================================================
// 7. LLAMADO A VENDER Y ESTADOS DEL CATÁLOGO
// =============================================================================

class _LlamadoVender extends StatelessWidget {
  const _LlamadoVender();

  Future<void> _publicar(BuildContext context) async {
    final listo = await asegurarSesion(context);
    if (!listo || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PublicarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancha = MediaQuery.sizeOf(context).width >= 760;
    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Tienes un equipo que ya no usas?',
          style: Tipos.titulo.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Publícalo gratis. Cobras en cuanto el Hub lo aprueba, y el '
          'comprador ya pagó antes de que lo entregues.',
          style: TextStyle(fontSize: 16, color: ColoresApp.cielo, height: 1.4),
        ),
      ],
    );
    final botones = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        BotonPegatina(
          texto: 'Publicar un equipo',
          icono: Icons.add,
          principal: false,
          tooltip: 'Publica tu equipo en menos de 2 minutos',
          alTocar: () => _publicar(context),
        ),
        TextButton.icon(
          onPressed: () => irA(context, Seccion.comoFunciona),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          ),
          icon: const Icon(Icons.help_outline),
          label: const Text('¿Cómo funciona?'),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ancha ? 36 : 24),
      decoration: BoxDecoration(
        color: ColoresApp.tinta,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ColoresApp.orquidea, width: 3),
      ),
      child: ancha
          ? Row(
              children: [
                Expanded(child: textos),
                const SizedBox(width: 28),
                botones,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [textos, const SizedBox(height: 20), botones],
            ),
    );
  }
}

class _EstadoCatalogo extends StatelessWidget {
  const _EstadoCatalogo({
    required this.texto,
    this.cargando = false,
    this.alReintentar,
    this.icono = Icons.inventory_2_outlined,
    this.textoBoton = 'Reintentar',
    this.iconoBoton = Icons.refresh,
  });

  final String texto;
  final bool cargando;
  final VoidCallback? alReintentar;
  final IconData icono;
  final String textoBoton;
  final IconData iconoBoton;

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
            Icon(icono, size: 40, color: ColoresApp.pizarra),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Tipos.cuerpo.copyWith(color: ColoresApp.tinta),
          ),
          if (alReintentar != null) ...[
            const SizedBox(height: 20),
            BotonPegatina(
              texto: textoBoton,
              icono: iconoBoton,
              alTocar: alReintentar!,
            ),
          ],
        ],
      ),
    );
  }
}


// =============================================================================
// ACCESIBILIDAD WEB — SERVICIO DE VOZ (WEB SPEECH API)
// =============================================================================

/// Botón de búsqueda por voz en el catálogo mediante Web Speech API
/// (SpeechRecognition en Google Chrome / Edge).
class _BotonDictadoVoz extends StatefulWidget {
  const _BotonDictadoVoz({required this.alDictar});

  final ValueChanged<String> alDictar;

  @override
  State<_BotonDictadoVoz> createState() => _BotonDictadoVozState();
}

class _BotonDictadoVozState extends State<_BotonDictadoVoz> {
  bool _escuchando = false;

  void _alternarDictado() {
    final voz = VozService.instancia;
    if (_escuchando) {
      voz.detenerDictado();
      setState(() => _escuchando = false);
      return;
    }

    if (!voz.soportaDictado) {
      mostrarAviso(
        context,
        'La búsqueda por voz está disponible en navegadores compatibles como Google Chrome.',
      );
      return;
    }

    setState(() => _escuchando = true);
    voz.anunciar('Escuchando búsqueda por voz');
    final iniciado = voz.iniciarDictado(
      alRecibirTexto: (texto) {
        if (!mounted) return;
        widget.alDictar(texto);
        mostrarAviso(context, 'Buscando: $texto');
      },
      alFallar: (_) {
        if (!mounted) return;
        mostrarAviso(context, 'No se pudo reconocer la voz. Intenta de nuevo.');
      },
      alTerminar: () {
        if (!mounted) return;
        setState(() => _escuchando = false);
      },
    );
    if (!iniciado && mounted) {
      setState(() => _escuchando = false);
    }
  }

  @override
  void dispose() {
    if (_escuchando) {
      VozService.instancia.detenerDictado();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _escuchando
          ? 'Detener dictado por voz'
          : 'Buscar equipos por voz',
      icon: Icon(
        _escuchando ? Icons.mic : Icons.mic_none_outlined,
        color: _escuchando
            ? ColoresApp.orquideaAccesible
            : ColoresApp.tinta,
      ),
      onPressed: _alternarDictado,
    );
  }
}

/// Botón para escuchar en voz alta el resumen principal de ReUso Seguro
/// mediante Web Speech API (SpeechSynthesis).
class _BotonLecturaResumen extends StatefulWidget {
  const _BotonLecturaResumen();

  @override
  State<_BotonLecturaResumen> createState() => _BotonLecturaResumenState();
}

class _BotonLecturaResumenState extends State<_BotonLecturaResumen> {
  static const _resumen =
      'ReUso Seguro. Tecnología de segunda mano sin riesgo a estafas. '
      'Tu pago queda en custodia hasta que nuestro Hub revisa el equipo punto '
      'por punto. Si pasa la inspección, se entrega y el vendedor cobra. '
      'Si no pasa, te devolvemos el dinero.';

  bool _leyendo = false;

  void _alternarLectura() {
    final voz = VozService.instancia;
    if (_leyendo) {
      voz.detenerLectura();
      setState(() => _leyendo = false);
      return;
    }

    if (!voz.soportaLectura) {
      mostrarAviso(
        context,
        'La lectura en voz alta no está disponible en este navegador.',
      );
      return;
    }

    final ok = voz.leerEnVozAlta(_resumen);
    if (ok) {
      voz.anunciar('Leyendo resumen de ReUso Seguro en voz alta');
      setState(() => _leyendo = true);
    }
  }

  @override
  void dispose() {
    if (_leyendo) {
      VozService.instancia.detenerLectura();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _leyendo
          ? 'Detener lectura en voz alta'
          : 'Escuchar resumen de ReUso Seguro en voz alta',
      icon: Icon(
        _leyendo ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
        color: _leyendo ? ColoresApp.orquideaAccesible : ColoresApp.tinta,
        size: 22,
      ),
      onPressed: _alternarLectura,
    );
  }
}
