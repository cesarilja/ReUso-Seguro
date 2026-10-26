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

  /// Los equipos publicados, del más nuevo al más viejo.
  Future<List<Equipo>> obtenerEquipos() async {
    try {
      final filas = await _cliente
          .from(_tabla)
          .select()
          .order('creado_en', ascending: false);
      return filas
          .map((fila) => Equipo.desdeFila(fila, _urlDeFoto))
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

  String _urlDeFoto(String ruta) =>
      _cliente.storage.from(_almacenFotos).getPublicUrl(ruta);
}
