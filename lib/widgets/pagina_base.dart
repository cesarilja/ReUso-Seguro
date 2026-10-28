import 'package:flutter/material.dart';

import '../tema.dart';
import 'barra_superior.dart';
import 'navegacion.dart';
import 'pie_de_pagina.dart';

/// Estructura común de las pantallas internas: barra superior, contenido
/// centrado con ancho máximo y el pie pegado abajo.
class PaginaBase extends StatelessWidget {
  const PaginaBase({
    super.key,
    required this.child,
    this.anchoContenido = 680,
    this.seccion,
  });

  /// La sección que se marca en la barra de arriba, si es una principal.
  final Seccion? seccion;

  final Widget child;

  /// Ancho máximo del contenido, para que se lea cómodo en pantallas grandes.
  final double anchoContenido;

  @override
  Widget build(BuildContext context) {
    final margen = margenLateral(context);

    return Scaffold(
      body: Column(
        children: [
          BarraSuperior(seccion: seccion),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margen, 20, margen, 72),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: anchoContenido),
                        child: child,
                      ),
                    ),
                  ),
                ),
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

/// Botón de texto para volver a la pantalla anterior.
class BotonVolver extends StatelessWidget {
  const BotonVolver({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(foregroundColor: ColoresApp.tinta),
      icon: const Icon(Icons.arrow_back, size: 18),
      label: Text(texto),
    );
  }
}
