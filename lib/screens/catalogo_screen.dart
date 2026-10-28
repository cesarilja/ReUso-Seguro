import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/equipo.dart';
import '../services/catalogo_service.dart';
import '../services/filtro_catalogo.dart';
import '../services/publicacion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/barra_superior.dart';
import '../widgets/equipo_widgets.dart';
import '../widgets/navegacion.dart';
import '../widgets/pegatina.dart';
import '../widgets/pie_de_pagina.dart';
import 'detalle_equipo_screen.dart';
import 'publicar_screen.dart';

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
  final TextEditingController _buscador = TextEditingController();
  late Future<List<Equipo>> _equipos = const CatalogoService().obtenerEquipos();

  /// Lo que la persona eligió para buscar y filtrar (heurística 7).
  FiltroCatalogo _filtro = const FiltroCatalogo();

  void _cambiarFiltro(FiltroCatalogo nuevo) => setState(() => _filtro = nuevo);

  void _limpiarFiltros() {
    _buscador.clear();
    setState(() => _filtro = FiltroCatalogo(orden: _filtro.orden));
  }

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
    _buscador.dispose();
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
          const BarraSuperior(seccion: Seccion.inicio),
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
                    // Si ya había equipos (por ejemplo, al llegar un cambio en
                    // tiempo real) se siguen mostrando mientras se actualiza.
                    if (resultado.connectionState != ConnectionState.done &&
                        !resultado.hasData) {
                      return _sliverMensaje(
                        margen,
                        const _EstadoCatalogo(
                          cargando: true,
                          texto: 'Cargando equipos…',
                        ),
                      );
                    }
                    final error = resultado.error;
                    if (error != null && !resultado.hasData) {
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
                    final filtrados = _filtro.aplicar(equipos);
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.fromLTRB(margen, 0, margen, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CabeceraCatalogo(
                                  cantidad: filtrados.length,
                                  total: equipos.length,
                                ),
                                const SizedBox(height: 18),
                                _BarraFiltros(
                                  filtro: _filtro,
                                  buscador: _buscador,
                                  alCambiar: _cambiarFiltro,
                                  alLimpiar: _limpiarFiltros,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (filtrados.isEmpty)
                          _sliverMensaje(
                            margen,
                            _EstadoCatalogo(
                              icono: Icons.search_off,
                              texto: 'Ningún equipo coincide con lo que '
                                  'buscas. Prueba con otras palabras o quita '
                                  'algún filtro.',
                              textoBoton: 'Limpiar filtros',
                              iconoBoton: Icons.filter_alt_off_outlined,
                              alReintentar: _limpiarFiltros,
                            ),
                          )
                        else
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
                                  final equipo = filtrados[indice];
                                  return TarjetaEquipo(
                                    equipo: equipo,
                                    alTocar: () => _abrirDetalle(equipo),
                                  );
                                },
                                childCount: filtrados.length,
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                EdgeInsets.fromLTRB(margen, 0, margen, 64),
                            child: const _LlamadoVender(),
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
          'centro de revisión técnica (el Hub). Solo entonces cobra el '
          'vendedor.',
          style: Tipos.cuerpo.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BotonPegatina(
              texto: 'Ver equipos',
              icono: Icons.arrow_downward,
              alTocar: alVerEquipos,
            ),
            TextButton.icon(
              onPressed: () => irA(context, Seccion.comoFunciona),
              style: TextButton.styleFrom(
                foregroundColor: ColoresApp.tinta,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
              icon: const Icon(Icons.help_outline),
              label: const Text('¿Cómo funciona?'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        // Las tres promesas de la plataforma, siempre con ícono y texto.
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Garantia(icono: Icons.lock_outline, texto: 'Pago en custodia'),
            _Garantia(
              icono: Icons.fact_check_outlined,
              texto: 'Revisión técnica en el Hub',
            ),
            _Garantia(icono: Icons.undo, texto: 'Reembolso si no pasa'),
          ],
        ),
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

/// Una promesa de la plataforma, en forma de etiqueta.
class _Garantia extends StatelessWidget {
  const _Garantia({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: ColoresApp.tinta),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: ColoresApp.tinta,
            ),
          ),
        ],
      ),
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
              detalle: 'Un inspector lo prueba punto por punto, según el '
                  'tipo de equipo.',
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
  const _CabeceraCatalogo({required this.cantidad, required this.total});

  final int cantidad;
  final int total;

  @override
  Widget build(BuildContext context) {
    final texto = cantidad == total
        ? '$total ${total == 1 ? 'equipo' : 'equipos'}'
        : '$cantidad de $total equipos';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Expanded(
          child: Text('Equipos publicados', style: Tipos.titulo),
        ),
        // Se anuncia a los lectores de pantalla cuando cambia el resultado.
        Semantics(
          liveRegion: true,
          child: Text(texto, style: Tipos.pequeno.copyWith(fontSize: 15)),
        ),
      ],
    );
  }
}

/// Buscador, categorías, «solo disponibles» y orden (heurística 7:
/// flexibilidad y eficiencia de uso, hallazgo del taller de UX).
class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({
    required this.filtro,
    required this.buscador,
    required this.alCambiar,
    required this.alLimpiar,
  });

  final FiltroCatalogo filtro;
  final TextEditingController buscador;
  final ValueChanged<FiltroCatalogo> alCambiar;
  final VoidCallback alLimpiar;

  @override
  Widget build(BuildContext context) {
    final ancha = MediaQuery.sizeOf(context).width >= 760;

    final campo = TextField(
      controller: buscador,
      onChanged: (t) => alCambiar(filtro.copiar(texto: t)),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Busca por nombre, marca o modelo (ej. iPhone, PS4)',
        hintStyle: const TextStyle(color: Color(0xFF6B7088)),
        prefixIcon: const Icon(Icons.search, color: ColoresApp.tinta),
        suffixIcon: filtro.texto.isEmpty
            ? null
            : IconButton(
                tooltip: 'Borrar búsqueda',
                icon: const Icon(Icons.close),
                onPressed: () {
                  buscador.clear();
                  alCambiar(filtro.copiar(texto: ''));
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ColoresApp.tinta, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ColoresApp.orquidea, width: 3),
        ),
      ),
    );

    final orden = Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresApp.tinta, width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OrdenCatalogo>(
          value: filtro.orden,
          icon: const Icon(Icons.swap_vert, color: ColoresApp.tinta),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: ColoresApp.tinta,
          ),
          borderRadius: BorderRadius.circular(12),
          onChanged: (o) {
            if (o != null) alCambiar(filtro.copiar(orden: o));
          },
          items: [
            for (final o in OrdenCatalogo.values)
              DropdownMenuItem(value: o, child: Text(o.nombre)),
          ],
        ),
      ),
    );

    Widget chip(String texto, bool elegido, VoidCallback alTocar,
        {IconData? icono}) {
      return FilterChip(
        selected: elegido,
        onSelected: (_) => alTocar(),
        showCheckmark: elegido,
        checkmarkColor: Colors.white,
        avatar: icono == null || elegido
            ? null
            : Icon(icono, size: 18, color: ColoresApp.tinta),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ancha)
          Row(
            children: [
              Expanded(child: campo),
              const SizedBox(width: 12),
              orden,
            ],
          )
        else ...[
          campo,
          const SizedBox(height: 10),
          orden,
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            chip('Todos', filtro.categoria == null,
                () => alCambiar(filtro.copiar(quitarCategoria: true))),
            for (final c in ReglasPublicacion.categorias)
              chip(
                c,
                filtro.categoria == c,
                () => alCambiar(
                  filtro.categoria == c
                      ? filtro.copiar(quitarCategoria: true)
                      : filtro.copiar(categoria: c),
                ),
              ),
            Container(width: 2, height: 24, color: ColoresApp.cielo),
            chip(
              'Solo disponibles',
              filtro.soloDisponibles,
              () => alCambiar(
                filtro.copiar(soloDisponibles: !filtro.soloDisponibles),
              ),
              icono: Icons.check_circle_outline,
            ),
            if (filtro.activo)
              TextButton.icon(
                onPressed: alLimpiar,
                style: TextButton.styleFrom(foregroundColor: ColoresApp.tinta),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Limpiar filtros'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Franja al final del catálogo que invita a vender.
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

/// Lo que se ve en lugar del catálogo mientras carga, si falla o si está
/// vacío (visibilidad del estado del sistema y recuperación de errores).
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
