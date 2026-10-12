import 'package:flutter/material.dart';

import '../models/equipo.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/barra_superior.dart';
import '../widgets/equipo_widgets.dart';
import '../widgets/pegatina.dart';
import '../widgets/pie_de_pagina.dart';

/// Detalle de un equipo publicado (HU12).
class DetalleEquipoScreen extends StatelessWidget {
  const DetalleEquipoScreen({super.key, required this.equipo});

  final Equipo equipo;

  @override
  Widget build(BuildContext context) {
    final margen = margenLateral(context);
    final pantallaAncha = MediaQuery.sizeOf(context).width >= 900;

    final imagen = Pegatina(
      radio: 24,
      sombra: 8,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.asset(
          equipo.imagen,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
    final info = _InfoEquipo(equipo: equipo);

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

class _InfoEquipo extends StatelessWidget {
  const _InfoEquipo({required this.equipo});

  final Equipo equipo;

  /// Para comprar hay que tener cuenta: si no hay sesión, la pide primero
  /// y luego devuelve a la persona a esta misma pantalla.
  Future<void> _comprar(BuildContext context) async {
    final listo = await asegurarSesion(context);
    if (!listo || !context.mounted) return;

    // TODO(HU12 y HU01): crear aquí el pedido y pasar a la pantalla de pago.
    mostrarAviso(
      context,
      'La compra con pago protegido estará disponible muy pronto.',
    );
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
        // Un equipo reservado no se puede comprar: no mostramos el botón.
        if (equipo.estaDisponible)
          BotonPegatina(
            texto: 'Comprar',
            icono: Icons.lock_outline,
            expandido: true,
            alTocar: () => _comprar(context),
          )
        else
          const _AvisoReservado(),
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

class _AvisoReservado extends StatelessWidget {
  const _AvisoReservado();

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
              'Este equipo ya está reservado por otro comprador.',
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
