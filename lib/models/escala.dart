/// Escala de calificación del checklist (HU15) y comparación con lo que
/// declaró el vendedor (HU19).
///
/// Las reglas son las mismas del servidor (`guardar_inspeccion` y
/// `puntos_inexactos` en supabase/15_planes_y_escala.sql).
enum Calificacion {
  malo(1, 'Malo', 'No funciona o está roto.'),
  regular(2, 'Regular', 'Funciona con una falla que se nota.'),
  bueno(3, 'Bueno', 'Funciona bien, con detalles menores de uso.'),
  excelente(4, 'Excelente', 'Funciona como nuevo.');

  const Calificacion(this.valor, this.nombre, this.descripcion);

  final int valor;
  final String nombre;
  final String descripcion;

  /// 1 y 2 cuentan como falla: piden una nota y una foto.
  bool get esFalla => valor <= ReglasEscala.maximoFalla;

  /// Texto corto como «3 · Bueno».
  String get etiqueta => '$valor de 4 ($nombre)';

  static Calificacion? desde(Object? valor) {
    final numero = valor is num ? valor.toInt() : int.tryParse('$valor');
    for (final calificacion in Calificacion.values) {
      if (calificacion.valor == numero) return calificacion;
    }
    return null;
  }
}

class ReglasEscala {
  const ReglasEscala._();

  /// Una nota de este valor o menos es una falla.
  static const int maximoFalla = 2;

  /// Se sugiere rechazar si el promedio queda por debajo de esto.
  static const double minimoPuntaje = 2.5;

  /// HU19: cuántos puntos de diferencia cuentan como declaración inexacta,
  /// y cuántos puntos así hacen falta.
  static const int diferenciaInexacta = 2;
  static const int puntosParaInexacta = 2;

  /// Promedio de las notas (sin contar «No aplica»), redondeado a 2
  /// decimales. Null si no hay ninguna.
  static double? puntaje(Iterable<Calificacion?> notas) {
    final validas = notas.whereType<Calificacion>().toList();
    if (validas.isEmpty) return null;
    final suma = validas.fold<int>(0, (total, c) => total + c.valor);
    return (suma / validas.length * 100).round() / 100;
  }

  /// HU15: el dictamen lo decide el inspector, pero la app le sugiere
  /// rechazar si hay algún punto en 1 o el promedio es bajo.
  static bool sugerirRechazo(Iterable<Calificacion?> notas) {
    final validas = notas.whereType<Calificacion>().toList();
    if (validas.any((c) => c == Calificacion.malo)) return true;
    final promedio = puntaje(validas);
    return promedio != null && promedio < minimoPuntaje;
  }

  /// Texto del puntaje con un decimal, por ejemplo «3,8 de 4».
  static String textoPuntaje(double puntaje) =>
      '${puntaje.toStringAsFixed(1).replaceAll('.', ',')} de 4';

  /// HU19: los puntos donde el vendedor dijo 2 o más que el inspector.
  static List<String> puntosInexactos(
    Map<String, int> declarado,
    Map<String, int> encontrado,
  ) {
    return [
      for (final entrada in declarado.entries)
        if (encontrado[entrada.key] != null &&
            entrada.value - encontrado[entrada.key]! >= diferenciaInexacta)
          entrada.key,
    ]..sort();
  }

  static bool esInexacta(
    Map<String, int> declarado,
    Map<String, int> encontrado,
  ) =>
      puntosInexactos(declarado, encontrado).length >= puntosParaInexacta;
}
