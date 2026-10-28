import 'package:flutter/material.dart';

import '../screens/como_funciona_screen.dart';
import '../screens/mis_compras_screen.dart';
import '../screens/mis_ventas_screen.dart';
import '../screens/panel_hub_screen.dart';
import 'avisos.dart';

/// Las secciones principales de la app, las que van en la barra de arriba.
enum Seccion {
  inicio('Inicio', Icons.storefront_outlined, conCuenta: false),
  comoFunciona('Cómo funciona', Icons.help_outline, conCuenta: false),
  compras('Mis compras', Icons.shopping_bag_outlined),
  ventas('Mis ventas', Icons.sell_outlined),
  hub('Panel del Hub', Icons.fact_check_outlined);

  const Seccion(this.nombre, this.icono, {this.conCuenta = true});

  final String nombre;
  final IconData icono;

  /// Si hace falta iniciar sesión para entrar.
  final bool conCuenta;
}

/// Lleva a una sección como si fueran pestañas: vuelve al inicio y abre la
/// sección encima, para que «Volver» siempre regrese al catálogo y no se
/// acumulen pantallas.
Future<void> irA(BuildContext context, Seccion seccion) async {
  if (seccion.conCuenta) {
    final listo = await asegurarSesion(context);
    if (!listo || !context.mounted) return;
  }

  final navegador = Navigator.of(context);
  navegador.popUntil((ruta) => ruta.isFirst);

  final Widget? pantalla = switch (seccion) {
    Seccion.inicio => null,
    Seccion.comoFunciona => const ComoFuncionaScreen(),
    Seccion.compras => const MisComprasScreen(),
    Seccion.ventas => const MisVentasScreen(),
    Seccion.hub => const PanelHubScreen(),
  };
  if (pantalla != null) {
    navegador.push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }
}
