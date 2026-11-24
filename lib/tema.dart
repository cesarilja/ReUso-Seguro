import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colores de la marca, tomados de las láminas del proyecto.
class ColoresApp {
  ColoresApp._();

  /// Azul casi negro: textos, bordes y sombras.
  static const Color tinta = Color(0xFF15133D);

  /// Morado de la marca (decorativo y acentos).
  static const Color orquidea = Color(0xFFB868C8);

  /// Morado con contraste WCAG AA (6.2:1 sobre blanco) para texto, enlaces y foco.
  static const Color orquideaAccesible = Color(0xFF8A349B);

  static const Color vinca = Color(0xFF5868B8);
  static const Color cielo = Color(0xFFB8C8E8);

  /// Texto secundario (contraste 7.1:1 sobre blanco).
  static const Color pizarra = Color(0xFF4F5878);

  /// Fondos suaves.
  static const Color lila = Color(0xFFF3E9F7);
  static const Color nube = Color(0xFFE6ECF8);

  /// Verde de estado con contraste WCAG AA (5.1:1 sobre blanco).
  static const Color verde = Color(0xFF1E7E45);
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

    // ── Tooltips más bonitos ────────────────────────────────────────────
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: ColoresApp.tinta,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      textStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12.5,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      waitDuration: const Duration(milliseconds: 400),
      preferBelow: true,
    ),

    // ── Botones rellenos (FilledButton) ────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return SystemMouseCursors.forbidden;
          }
          return SystemMouseCursors.click;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return ColoresApp.orquideaAccesible.withAlpha(45);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withAlpha(30);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(
              color: ColoresApp.orquideaAccesible,
              width: 2.5,
            );
          }
          return BorderSide.none;
        }),
      ),
    ),

    // ── Botones de texto (TextButton) ──────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return SystemMouseCursors.forbidden;
          }
          return SystemMouseCursors.click;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(
              color: ColoresApp.orquideaAccesible,
              width: 2.5,
            );
          }
          return BorderSide.none;
        }),
      ),
    ),

    // ── Botones de contorno (OutlinedButton) ───────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ).copyWith(
        mouseCursor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return SystemMouseCursors.forbidden;
          }
          return SystemMouseCursors.click;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(
              color: ColoresApp.orquideaAccesible,
              width: 2.5,
            );
          }
          return null;
        }),
      ),
    ),

    // ── Botones de ícono (IconButton) ──────────────────────────────────
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(
              color: ColoresApp.orquideaAccesible,
              width: 2.5,
            );
          }
          return BorderSide.none;
        }),
      ),
    ),

    // ── Switch (Express) ───────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColoresApp.orquidea;
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColoresApp.lila;
        }
        return null;
      }),
    ),

    // ── Chips (filtros del catálogo) ───────────────────────────────────
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // ── Snackbar ───────────────────────────────────────────────────────
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
