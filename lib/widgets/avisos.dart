import 'package:flutter/material.dart';

import '../screens/acceso_screen.dart';
import '../services/sesion_service.dart';

/// Permite mostrar avisos desde cualquier pantalla (HU04: «Te compraron…»).
final GlobalKey<ScaffoldMessengerState> avisosGlobales =
    GlobalKey<ScaffoldMessengerState>();

/// Muestra un aviso en la pantalla que esté abierta, sea cual sea.
void mostrarAvisoGlobal(String mensaje) {
  avisosGlobales.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Muestra un mensaje corto en la parte de abajo de la pantalla.
void mostrarAviso(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// Se asegura de que haya una sesión antes de una acción (HU14).
///
/// Si la persona ya entró, responde `true` de una vez. Si no, abre la
/// pantalla de acceso y espera: al terminar, la persona vuelve a donde
/// estaba y esto responde si logró entrar o no.
Future<bool> asegurarSesion(BuildContext context) async {
  if (SesionService.instancia.haySesion) return true;

  final entro = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => const AccesoScreen()),
  );
  return entro ?? false;
}
