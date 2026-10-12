import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colores de la marca, tomados de las láminas del proyecto.
class ColoresApp {
  ColoresApp._();

  /// Azul casi negro: textos, bordes y sombras.
  static const Color tinta = Color(0xFF15133D);

  /// Morado de la marca.
  static const Color orquidea = Color(0xFFB868C8);

  static const Color vinca = Color(0xFF5868B8);
  static const Color cielo = Color(0xFFB8C8E8);

  /// Texto secundario.
  static const Color pizarra = Color(0xFF4F5878);

  /// Fondos suaves.
  static const Color lila = Color(0xFFF3E9F7);
  static const Color nube = Color(0xFFE6ECF8);

  static const Color verde = Color(0xFF2E9E5B);
}

/// Estilos de texto que se repiten en la app.
class Tipos {
  Tipos._();

  static const TextStyle titular = TextStyle(
    fontSize: 46,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    color: ColoresApp.tinta,
  );

  static const TextStyle titulo = TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: ColoresApp.tinta,
  );

  static const TextStyle subtitulo = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: ColoresApp.tinta,
  );

  static const TextStyle cuerpo = TextStyle(
    fontSize: 16,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: ColoresApp.pizarra,
  );

  static const TextStyle pequeno = TextStyle(
    fontSize: 13.5,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: ColoresApp.pizarra,
  );

  static const TextStyle precio = TextStyle(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: ColoresApp.tinta,
  );

  static const TextStyle boton = TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
}

/// Ancho máximo del contenido en pantallas grandes.
const double anchoMaximo = 1160;

/// Margen a los lados de la página.
///
/// En pantallas grandes centra el contenido; en pequeñas deja 24 px.
double margenLateral(BuildContext context) {
  final ancho = MediaQuery.sizeOf(context).width;
  return math.max(24.0, (ancho - anchoMaximo) / 2);
}

ThemeData temaApp() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.fromSeed(seedColor: ColoresApp.orquidea),
    scaffoldBackgroundColor: Colors.white,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ColoresApp.tinta,
      contentTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        color: Colors.white,
      ),
    ),
  );
}
