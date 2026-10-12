/// Estado de una publicación dentro del catálogo.
enum EstadoPublicacion {
  disponible('Disponible'),
  reservado('Reservado');

  const EstadoPublicacion(this.nombre);

  /// Texto que se le muestra al usuario.
  final String nombre;
}

/// Un equipo publicado por un vendedor.
class Equipo {
  const Equipo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.estadoDeclarado,
    required this.precio,
    required this.imagen,
    required this.vendedor,
    this.estado = EstadoPublicacion.disponible,
  });

  final String id;
  final String titulo;
  final String descripcion;

  /// Cómo dice el vendedor que está el equipo.
  final String estadoDeclarado;

  /// Precio de venta en dólares.
  final double precio;

  /// Ruta de la imagen dentro de la carpeta assets.
  final String imagen;

  final String vendedor;
  final EstadoPublicacion estado;

  /// Solo los equipos disponibles se pueden comprar.
  bool get estaDisponible => estado == EstadoPublicacion.disponible;

  /// Precio listo para mostrar, por ejemplo: $180,00
  String get precioFormateado =>
      '\$${precio.toStringAsFixed(2).replaceAll('.', ',')}';
}
