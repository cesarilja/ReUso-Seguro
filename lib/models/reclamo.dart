import 'pedido.dart';

DateTime? _fecha(Object? valor) =>
    valor is String ? DateTime.parse(valor).toLocal() : null;

Map<String, dynamic>? _relacion(Object? dato) {
  if (dato is Map<String, dynamic>) return dato;
  if (dato is List && dato.isNotEmpty && dato.first is Map<String, dynamic>) {
    return dato.first as Map<String, dynamic>;
  }
  return null;
}

/// HU05: cómo llegó el equipo al Hub, con sus fotos. Es el respaldo
/// imparcial del vendedor y no se puede cambiar ni borrar.
class Recepcion {
  const Recepcion({required this.fotos, required this.nota, required this.creadaEn});

  static Recepcion? desdeRelacion(Object? dato) {
    final fila = _relacion(dato);
    if (fila == null) return null;
    return Recepcion(
      fotos: ((fila['fotos'] as List?) ?? const []).whereType<String>().toList(),
      nota: (fila['nota'] as String?) ?? '',
      creadaEn: _fecha(fila['creado_en']) ?? DateTime.now(),
    );
  }

  /// Rutas de las fotos en el almacén «evidencias».
  final List<String> fotos;
  final String nota;
  final DateTime creadaEn;
}

/// HU05: un reclamo del comprador.
class Reclamo {
  const Reclamo({required this.descripcion, required this.estado, required this.creadoEn});

  static Reclamo? desdeRelacion(Object? dato) {
    final fila = _relacion(dato);
    if (fila == null) return null;
    return Reclamo(
      descripcion: (fila['descripcion'] as String?) ?? '',
      estado: (fila['estado'] as String?) ?? 'abierto',
      creadoEn: _fecha(fila['creado_en']) ?? DateTime.now(),
    );
  }

  final String descripcion;
  final String estado;
  final DateTime creadoEn;

  bool get abierto => estado == 'abierto';
}

/// Qué puede hacer el comprador con su equipo ya enviado (HU05).
enum SituacionReclamo {
  /// Todavía no confirmó que lo recibió.
  porConfirmar,

  /// Dentro de los 3 días: puede reclamar.
  enPlazo,

  /// Pasaron los 3 días.
  fueraDePlazo,

  /// Ya abrió un reclamo.
  reclamado,

  /// El pedido no está en esa etapa (no aplica).
  noAplica,
}

/// Reglas de la HU05 (iguales a las del servidor, 14_reclamos_y_avisos.sql).
class ReglasReclamo {
  const ReglasReclamo._();

  static const int plazoDias = 3;
  static const int minimoDescripcion = 20;
  static const int minimoFotosRecepcion = 2;
  static const int maximoFotosRecepcion = 6;

  /// Mensaje si las fotos de recepción no alcanzan, o null si están bien.
  static String? fotosRecepcion(int cantidad) {
    if (cantidad < minimoFotosRecepcion) {
      return 'Sube al menos $minimoFotosRecepcion fotos de cómo llegó el equipo '
          '(te faltan ${minimoFotosRecepcion - cantidad}).';
    }
    if (cantidad > maximoFotosRecepcion) {
      return 'Son máximo $maximoFotosRecepcion fotos.';
    }
    return null;
  }

  static String? descripcion(String texto) {
    final largo = texto.trim().length;
    if (largo < minimoDescripcion) {
      return 'Cuéntanos qué pasa con al menos $minimoDescripcion caracteres '
          '(llevas $largo).';
    }
    return null;
  }

  /// Hasta cuándo puede reclamar, o null si todavía no confirmó.
  static DateTime? venceEn(Pedido pedido) =>
      pedido.recibidoCompradorEn?.add(const Duration(days: plazoDias));

  static SituacionReclamo situacion(Pedido pedido, [DateTime? ahora]) {
    if (pedido.reclamo != null) return SituacionReclamo.reclamado;
    if (pedido.estado != EstadoPedido.pagoLiberado &&
        pedido.estado != EstadoPedido.enCamino) {
      return SituacionReclamo.noAplica;
    }
    final vence = venceEn(pedido);
    if (vence == null) return SituacionReclamo.porConfirmar;
    return (ahora ?? DateTime.now()).isAfter(vence)
        ? SituacionReclamo.fueraDePlazo
        : SituacionReclamo.enPlazo;
  }
}
