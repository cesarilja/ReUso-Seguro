import 'dart:convert';

import 'package:http/http.dart' as http;

/// Tasa oficial USD -> VES del Banco Central de Venezuela (BCV).
class TasaBcv {
  const TasaBcv({
    required this.tasa,
    this.fechaActualizacion,
    this.esRespaldo = false,
  });

  /// Bolívares por cada 1 USD según el BCV.
  final double tasa;
  final DateTime? fechaActualizacion;

  /// Verdadero solo si fallaron las APIs y se usó el valor de respaldo.
  final bool esRespaldo;

  /// Convierte un monto en dólares a bolívares a la tasa del día.
  double convertirABolivares(double dolares) => dolares * tasa;

  /// Fecha corta de la tasa, por ejemplo: 28/11/2026.
  String get fechaCorta {
    final f = fechaActualizacion;
    if (f == null) return 'hoy';
    final d = f.day.toString().padLeft(2, '0');
    final m = f.month.toString().padLeft(2, '0');
    return '$d/$m/${f.year}';
  }
}

/// Consulta la tasa oficial del BCV del día mediante API pública con CORS.
class TasaBcvService {
  TasaBcvService._();

  static final TasaBcvService instancia = TasaBcvService._();

  static final Uri _apiPrincipal =
      Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial');

  /// Tasa de respaldo si el dispositivo no tiene internet o la API está caída.
  static const double _tasaRespaldo = 926.36;

  TasaBcv? _cache;
  DateTime? _consultadaEn;

  /// Obtiene la tasa BCV del día (con caché de 30 minutos).
  Future<TasaBcv> obtener({bool forzar = false, http.Client? cliente}) async {
    final ahora = DateTime.now();
    if (!forzar &&
        _cache != null &&
        _consultadaEn != null &&
        ahora.difference(_consultadaEn!) < const Duration(minutes: 30)) {
      return _cache!;
    }

    final httpClient = cliente ?? http.Client();
    final cerrar = cliente == null;
    try {
      final respuesta = await httpClient
          .get(_apiPrincipal, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
        final promedio = (datos['promedio'] as num?)?.toDouble();
        if (promedio != null && promedio > 0) {
          final fecha = DateTime.tryParse(
            datos['fechaActualizacion'] as String? ?? '',
          );
          final tasa = TasaBcv(
            tasa: promedio,
            fechaActualizacion: fecha,
          );
          _cache = tasa;
          _consultadaEn = ahora;
          return tasa;
        }
      }
    } catch (_) {
      // Se usa respaldo debajo para no bloquear el flujo de pago.
    } finally {
      if (cerrar) httpClient.close();
    }

    return _cache ??
        const TasaBcv(
          tasa: _tasaRespaldo,
          esRespaldo: true,
        );
  }
}
