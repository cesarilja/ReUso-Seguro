import '../formato.dart';
import 'plan_inspeccion.dart';

/// Estado de una publicación dentro del catálogo.
enum EstadoPublicacion {
  disponible('Disponible'),
  reservado('Reservado');

  const EstadoPublicacion(this.nombre);

  /// Texto que se le muestra al usuario.
  final String nombre;

  /// Convierte el texto guardado en la base de datos.
  static EstadoPublicacion desde(String? valor) =>
      valor == 'reservado' ? reservado : disponible;
}

/// Un equipo publicado por un vendedor («entity» Equipo).
class Equipo {
  const Equipo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.estadoDeclarado,
    required this.precio,
    required this.vendedor,
    this.vendedorId,
    this.categoria,
    this.fotos = const [],
    this.ilustracion,
    this.estado = EstadoPublicacion.disponible,
    this.plan = PlanInspeccion.basica,
    this.express = false,
    this.autoevaluacion = const {},
    this.puntajeInspeccion,
  });

  /// Crea un equipo a partir de una fila de la tabla `equipos`.
  ///
  /// [urlDeFoto] convierte la ruta guardada en la tabla en la dirección
  /// pública de la foto en Supabase Storage.
  factory Equipo.desdeFila(
    Map<String, dynamic> fila,
    String Function(String ruta) urlDeFoto,
  ) {
    final rutas = (fila['fotos'] as List?)?.whereType<String>() ?? const [];
    return Equipo(
      id: fila['id'] as String,
      titulo: fila['titulo'] as String,
      descripcion: fila['descripcion'] as String,
      estadoDeclarado: fila['estado_declarado'] as String,
      precio: (fila['precio'] as num).toDouble(),
      vendedor: fila['vendedor_nombre'] as String,
      vendedorId: fila['vendedor_id'] as String?,
      categoria: fila['categoria'] as String?,
      fotos: rutas.map(urlDeFoto).toList(growable: false),
      ilustracion: fila['ilustracion'] as String?,
      estado: EstadoPublicacion.desde(fila['estado'] as String?),
      plan: PlanInspeccion.desde(fila['plan_inspeccion'] as String?),
      express: fila['express'] as bool? ?? false,
      autoevaluacion: _leerAutoevaluacion(fila['autoevaluacion']),
      puntajeInspeccion: (fila['puntaje_inspeccion'] as num?)?.toDouble(),
    );
  }

  static Map<String, int> _leerAutoevaluacion(Object? dato) {
    if (dato is! Map) return const {};
    return {
      for (final entrada in dato.entries)
        if (entrada.value is num)
          '${entrada.key}': (entrada.value as num).toInt(),
    };
  }

  final String id;
  final String titulo;
  final String descripcion;

  /// Cómo dice el vendedor que está el equipo.
  final String estadoDeclarado;

  /// Precio de venta en dólares.
  final double precio;

  final String vendedor;

  /// Cuenta de quien publicó el equipo (los de demostración no tienen).
  final String? vendedorId;

  /// Tipo de equipo: Laptop, Teléfono, Tablet... (HU11).
  final String? categoria;

  /// Direcciones de las fotos reales del equipo (pueden ser varias).
  final List<String> fotos;

  /// Ilustración de respaldo dentro de assets, si el equipo no tiene fotos.
  final String? ilustracion;

  final EstadoPublicacion estado;

  /// HU16: el plan de inspección que eligió (y paga) el vendedor.
  final PlanInspeccion plan;

  /// HU16: si pidió la inspección Express (menos de 24 h en el Hub).
  final bool express;

  /// HU19: cómo calificó el vendedor cada punto del checklist (1 a 4).
  /// Vacío en las publicaciones de antes del Sprint 4.
  final Map<String, int> autoevaluacion;

  /// HU15: el puntaje de su última inspección (de 1 a 4), si ya tuvo una.
  final double? puntajeInspeccion;

  bool get inspeccionDetallada => plan == PlanInspeccion.detallada;

  /// Solo los equipos disponibles se pueden comprar.
  bool get estaDisponible => estado == EstadoPublicacion.disponible;

  /// Precio listo para mostrar, por ejemplo: $180,00
  String get precioFormateado => formatearDolares(precio);
}
