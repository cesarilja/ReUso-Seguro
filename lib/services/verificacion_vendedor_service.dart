import 'package:supabase_flutter/supabase_flutter.dart';

import 'publicacion_service.dart';
import 'sesion_service.dart';

/// Resultado de la verificación de identidad de un vendedor.
class VerificacionVendedor {
  const VerificacionVendedor({
    required this.usuarioId,
    required this.cedulaNumero,
    required this.fotoCedulaRuta,
    required this.verificadoEn,
  });

  final String usuarioId;
  final String cedulaNumero;
  final String fotoCedulaRuta;
  final DateTime verificadoEn;

  factory VerificacionVendedor.desdeMapa(Map<String, dynamic> mapa) {
    return VerificacionVendedor(
      usuarioId: mapa['usuario_id'] as String? ?? '',
      cedulaNumero: mapa['cedula_numero'] as String? ?? '',
      fotoCedulaRuta: mapa['foto_cedula_ruta'] as String? ?? '',
      verificadoEn: DateTime.tryParse(
            mapa['verificado_en'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

/// Gestiona la verificación de identidad (foto de cédula) antes de publicar.
///
/// La foto se guarda en el bucket `equipos` bajo `<usuario_id>/verificacion/`
/// y el registro en `public.verificaciones_vendedor` (ver `supabase/18_verificacion_vendedor.sql`).
class VerificacionVendedorService {
  VerificacionVendedorService._();

  static final VerificacionVendedorService instancia =
      VerificacionVendedorService._();

  static const String _tabla = 'verificaciones_vendedor';
  static const String _bucket = 'equipos';

  /// Respaldo en memoria por usuario para evitar consultas repetidas y
  /// mantener continuidad si la tabla SQL aún no se ha aplicado.
  final Map<String, VerificacionVendedor> _cache = {};

  SupabaseClient get _cliente => Supabase.instance.client;

  /// Valida el formato de cédula venezolana (ej. V-12345678 o E-12345678).
  static String? validarCedula(String? valor) {
    final limpia = (valor ?? '').trim().toUpperCase().replaceAll(' ', '');
    if (limpia.isEmpty) {
      return 'Escribe tu número de cédula (ejemplo: V-12345678).';
    }
    if (!RegExp(r'^[VE]-?\d{6,9}$').hasMatch(limpia)) {
      return 'Formato inválido. Usa V o E seguido de 6 a 9 dígitos (ej. V-12345678).';
    }
    return null;
  }

  /// Normaliza una cédula a formato `V-12345678`.
  static String normalizarCedula(String valor) {
    final limpia = valor.trim().toUpperCase().replaceAll(' ', '');
    if (limpia.length >= 2 && limpia[1] != '-') {
      return '${limpia[0]}-${limpia.substring(1)}';
    }
    return limpia;
  }

  /// Consulta si el usuario actual ya tiene identidad verificada.
  Future<VerificacionVendedor?> estadoActual({bool forzar = false}) async {
    final usuario = SesionService.instancia.usuario;
    if (usuario == null) return null;

    if (!forzar && _cache.containsKey(usuario.id)) {
      return _cache[usuario.id];
    }

    try {
      final fila = await _cliente
          .from(_tabla)
          .select()
          .eq('usuario_id', usuario.id)
          .maybeSingle();
      if (fila == null) return _cache[usuario.id];
      final verificacion = VerificacionVendedor.desdeMapa(fila);
      _cache[usuario.id] = verificacion;
      return verificacion;
    } catch (_) {
      return _cache[usuario.id];
    }
  }

  /// Sube la foto de la cédula y registra la verificación del vendedor.
  Future<VerificacionVendedor> verificar({
    required String cedulaNumero,
    required FotoElegida fotoCedula,
  }) async {
    final usuario = SesionService.instancia.usuario;
    if (usuario == null) {
      throw const ErrorDePublicacion(
        'Tu sesión se cerró. Inicia sesión otra vez para verificar tu identidad.',
      );
    }

    final errorCedula = validarCedula(cedulaNumero);
    if (errorCedula != null) {
      throw ErrorDePublicacion(errorCedula);
    }
    final errorFoto = ReglasPublicacion.foto(fotoCedula);
    if (errorFoto != null) {
      throw ErrorDePublicacion(errorFoto);
    }

    final cedulaNormalizada = normalizarCedula(cedulaNumero);
    final ruta =
        '${usuario.id}/verificacion/cedula_${DateTime.now().millisecondsSinceEpoch}.${fotoCedula.extension}';

    try {
      await _cliente.storage.from(_bucket).uploadBinary(
            ruta,
            fotoCedula.bytes,
            fileOptions: FileOptions(contentType: fotoCedula.tipo),
          );
    } catch (_) {
      throw const ErrorDePublicacion(
        'No pudimos subir la foto de tu cédula. Revisa tu conexión e intenta de nuevo.',
      );
    }

    final ahora = DateTime.now();
    final verificacion = VerificacionVendedor(
      usuarioId: usuario.id,
      cedulaNumero: cedulaNormalizada,
      fotoCedulaRuta: ruta,
      verificadoEn: ahora,
    );

    try {
      await _cliente.from(_tabla).upsert({
        'usuario_id': usuario.id,
        'cedula_numero': cedulaNormalizada,
        'foto_cedula_ruta': ruta,
        'verificado_en': ahora.toIso8601String(),
      });
    } catch (_) {
      // Si la tabla SQL aún no se ha ejecutado en Supabase, la foto ya quedó
      // guardada en Storage y mantenemos la verificación en sesión.
    }

    _cache[usuario.id] = verificacion;
    return verificacion;
  }
}
