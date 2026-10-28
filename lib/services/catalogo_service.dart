import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/equipo.dart';

/// Error con un mensaje listo para mostrarle al usuario.
class ErrorDeCatalogo implements Exception {
  const ErrorDeCatalogo(this.mensaje);

  final String mensaje;
}

/// Entrega los equipos del catálogo desde Supabase (patrón Repository).
///
/// Los datos vienen de la tabla `equipos` y las fotos del almacén
/// `equipos` de Supabase Storage. Las pantallas no saben de dónde salen:
/// por eso pasar de los datos de prueba a la base de datos solo cambió
/// este archivo.
class CatalogoService {
  const CatalogoService();

  static const String _tabla = 'equipos';
  static const String _almacenFotos = 'equipos';

  SupabaseClient get _cliente => Supabase.instance.client;

  /// Cambia cada vez que se publica un equipo: el catálogo lo escucha para
  /// volver a cargarse solo (patrón Observer).
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  static void avisarCambio() => cambios.value++;

  /// Los equipos publicados, del más nuevo al más viejo.
  Future<List<Equipo>> obtenerEquipos() async {
    try {
      final filas = await _cliente
          .from(_tabla)
          .select()
          .order('creado_en', ascending: false);
      return filas
          .map((fila) => Equipo.desdeFila(fila, urlDeFoto))
          .toList(growable: false);
    } on PostgrestException {
      throw const ErrorDeCatalogo(
        'No pudimos cargar los equipos. Vuelve a intentarlo en un momento.',
      );
    } catch (_) {
      throw const ErrorDeCatalogo(
        'No pudimos conectarnos. Revisa tu conexión a internet y vuelve a '
        'intentarlo.',
      );
    }
  }

  /// Un equipo con sus datos al día (por ejemplo, si ya lo reservaron).
  /// Responde null si no se pudo cargar.
  Future<Equipo?> obtenerEquipo(String id) async {
    try {
      final fila =
          await _cliente.from(_tabla).select().eq('id', id).maybeSingle();
      return fila == null ? null : Equipo.desdeFila(fila, urlDeFoto);
    } catch (_) {
      return null;
    }
  }

  /// Los equipos que publicó la persona que inició sesión, vendidos o no.
  Future<List<Equipo>> misPublicaciones() async {
    final usuario = _cliente.auth.currentUser?.id;
    if (usuario == null) return const [];
    try {
      final filas = await _cliente
          .from(_tabla)
          .select()
          .eq('vendedor_id', usuario)
          .order('creado_en', ascending: false);
      return filas
          .map((fila) => Equipo.desdeFila(fila, urlDeFoto))
          .toList(growable: false);
    } catch (_) {
      throw const ErrorDeCatalogo('No pudimos cargar tus publicaciones.');
    }
  }

  /// Dirección pública de una foto guardada en el almacén `equipos`.
  static String urlDeFoto(String ruta) => Supabase.instance.client.storage
      .from(_almacenFotos)
      .getPublicUrl(ruta);
}
