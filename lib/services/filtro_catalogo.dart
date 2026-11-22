import '../models/equipo.dart';

/// Cómo se ordena el catálogo.
enum OrdenCatalogo {
  recientes('Más recientes'),
  precioMenor('Precio: menor a mayor'),
  precioMayor('Precio: mayor a menor');

  const OrdenCatalogo(this.nombre);

  final String nombre;
}

/// Búsqueda, categoría, disponibilidad, plan, express, rango de precio y orden
/// del catálogo («control»).
///
/// Es inmutable: cada cambio crea un filtro nuevo con [copiar]. La lógica
/// vive aquí y no en la pantalla, para respetar la arquitectura por capas.
class FiltroCatalogo {
  const FiltroCatalogo({
    this.texto = '',
    this.categoria,
    this.soloDisponibles = false,
    this.soloDetallada = false,
    this.soloExpress = false,
    this.precioMin,
    this.precioMax,
    this.orden = OrdenCatalogo.recientes,
  });

  final String texto;

  /// null = todas las categorías.
  final String? categoria;
  final bool soloDisponibles;

  /// HU16: solo equipos con inspección detallada.
  final bool soloDetallada;

  /// HU16: solo equipos con inspección Express (< 24 h).
  final bool soloExpress;

  /// Rango de precio opcional en dólares.
  final double? precioMin;
  final double? precioMax;

  final OrdenCatalogo orden;

  /// Si la persona cambió algo (para mostrar «Limpiar filtros» y ocultar
  /// las vitrinas de portada mientras busca).
  bool get activo =>
      texto.trim().isNotEmpty ||
      categoria != null ||
      soloDisponibles ||
      soloDetallada ||
      soloExpress ||
      precioMin != null ||
      precioMax != null;

  FiltroCatalogo copiar({
    String? texto,
    String? categoria,
    bool quitarCategoria = false,
    bool? soloDisponibles,
    bool? soloDetallada,
    bool? soloExpress,
    double? precioMin,
    bool quitarPrecioMin = false,
    double? precioMax,
    bool quitarPrecioMax = false,
    OrdenCatalogo? orden,
  }) {
    return FiltroCatalogo(
      texto: texto ?? this.texto,
      categoria: quitarCategoria ? null : (categoria ?? this.categoria),
      soloDisponibles: soloDisponibles ?? this.soloDisponibles,
      soloDetallada: soloDetallada ?? this.soloDetallada,
      soloExpress: soloExpress ?? this.soloExpress,
      precioMin: quitarPrecioMin ? null : (precioMin ?? this.precioMin),
      precioMax: quitarPrecioMax ? null : (precioMax ?? this.precioMax),
      orden: orden ?? this.orden,
    );
  }

  /// Quita tildes y mayúsculas, para que «telefono» encuentre «Teléfono».
  static String _normalizar(String s) {
    const con = 'áéíóúüñÁÉÍÓÚÜÑ';
    const sin = 'aeiouunAEIOUUN';
    final buffer = StringBuffer();
    for (final c in s.split('')) {
      final i = con.indexOf(c);
      buffer.write(i >= 0 ? sin[i] : c);
    }
    return buffer.toString().toLowerCase();
  }

  /// Devuelve los equipos que cumplen el filtro, ya ordenados.
  /// La lista que llega de Supabase ya viene de más reciente a más antiguo.
  List<Equipo> aplicar(List<Equipo> equipos) {
    final palabras = _normalizar(texto)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    final resultado = equipos.where((e) {
      if (categoria != null && e.categoria != categoria) return false;
      if (soloDisponibles && !e.estaDisponible) return false;
      if (soloDetallada && !e.inspeccionDetallada) return false;
      if (soloExpress && !e.express) return false;
      if (precioMin != null && e.precio < precioMin!) return false;
      if (precioMax != null && e.precio > precioMax!) return false;
      if (palabras.isEmpty) return true;
      final donde = _normalizar(
        '${e.titulo} ${e.descripcion} ${e.categoria ?? ''} ${e.estadoDeclarado}',
      );
      return palabras.every(donde.contains);
    }).toList();

    switch (orden) {
      case OrdenCatalogo.recientes:
        break;
      case OrdenCatalogo.precioMenor:
        resultado.sort((a, b) => a.precio.compareTo(b.precio));
      case OrdenCatalogo.precioMayor:
        resultado.sort((a, b) => b.precio.compareTo(a.precio));
    }
    return resultado;
  }
}
