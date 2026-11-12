import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/boveda.dart';
import 'sesion_service.dart';

/// Error con un mensaje listo para mostrarle al administrador.
class ErrorDeAdministracion implements Exception {
  const ErrorDeAdministracion(this.mensaje);

  final String mensaje;
}

/// Todo lo del administrador de la plataforma (HU09), patrón Singleton.
///
/// Sabe si la persona que entró es administradora (para mostrar la
/// sección «Bóveda» solo a ella) y pide al servidor la revisión de la
/// bóveda (`revisar_boveda`, supabase/13_boveda_escrow.sql). El cuadre lo
/// hace el servidor: la app solo lo muestra.
class AdministracionService extends ChangeNotifier {
  AdministracionService._() {
    SesionService.instancia.addListener(_revisarRol);
    _revisarRol();
  }

  static final AdministracionService instancia = AdministracionService._();

  SupabaseClient get _cliente => Supabase.instance.client;

  bool _soyAdmin = false;
  String? _usuarioRevisado;

  /// Si la persona que inició sesión es administradora.
  bool get soyAdmin => _soyAdmin;

  Future<void> _revisarRol() async {
    final usuario = _cliente.auth.currentUser?.id;
    if (usuario == _usuarioRevisado) return;
    _usuarioRevisado = usuario;

    var esAdmin = false;
    if (usuario != null) {
      try {
        esAdmin = await _cliente.rpc('es_admin') == true;
      } catch (_) {
        esAdmin = false; // si falla (o falta el script 13), no se muestra
      }
    }
    if (esAdmin != _soyAdmin) {
      _soyAdmin = esAdmin;
      notifyListeners();
    }
  }

  /// HU09: revisa la bóveda. Con [registrar] la revisión queda guardada
  /// (los descuadres se guardan siempre).
  Future<EstadoBoveda> revisarBoveda({bool registrar = true}) async {
    try {
      final respuesta = await _cliente.rpc(
        'revisar_boveda',
        params: {'p_registrar': registrar},
      );
      if (respuesta is Map<String, dynamic>) return EstadoBoveda.desdeJson(respuesta);
      throw const ErrorDeAdministracion(
        'El servidor respondió algo inesperado. Vuelve a intentarlo.',
      );
    } on PostgrestException catch (error) {
      debugPrint('[Administracion] revisar_boveda: ${error.code} ${error.message}');
      if (error.message.contains('NO_ADMIN')) {
        throw const ErrorDeAdministracion(
          'Solo un administrador puede ver la bóveda.',
        );
      }
      if (error.code == 'PGRST202' ||
          error.message.contains('Could not find the function')) {
        throw const ErrorDeAdministracion(
          'Falta activar la bóveda en el servidor: corre '
          'supabase/13_boveda_escrow.sql en Supabase.',
        );
      }
      throw const ErrorDeAdministracion(
        'No pudimos revisar la bóveda. Vuelve a intentarlo en un momento.',
      );
    } on ErrorDeAdministracion {
      rethrow;
    } catch (error) {
      debugPrint('[Administracion] revisar_boveda: $error');
      throw const ErrorDeAdministracion(
        'No pudimos conectarnos. Revisa tu conexión a internet.',
      );
    }
  }
}
