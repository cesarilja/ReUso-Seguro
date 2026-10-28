/// Resultado del dictamen técnico (HU08).
enum ResultadoDictamen {
  aprobado('aprobado', 'Aprobado'),
  rechazado('rechazado', 'Rechazado');

  const ResultadoDictamen(this.clave, this.nombre);

  final String clave;
  final String nombre;

  static ResultadoDictamen desde(String? valor) =>
      valor == 'rechazado' ? rechazado : aprobado;
}

/// El dictamen que emite el inspector técnico («entity» Dictamen).
///
/// Es definitivo: una vez emitido no se cambia.
class Dictamen {
  const Dictamen({
    required this.pedidoId,
    required this.resultado,
    required this.motivo,
    required this.emitidoEn,
  });

  factory Dictamen.desdeFila(Map<String, dynamic> fila) => Dictamen(
        pedidoId: fila['pedido_id'] as String,
        resultado: ResultadoDictamen.desde(fila['resultado'] as String?),
        motivo: (fila['motivo'] as String?) ?? '',
        emitidoEn: DateTime.parse(fila['creado_en'] as String).toLocal(),
      );

  /// La relación puede llegar como objeto o como lista, según Supabase.
  static Dictamen? desdeRelacion(Object? dato) {
    if (dato is Map<String, dynamic>) return Dictamen.desdeFila(dato);
    if (dato is List && dato.isNotEmpty && dato.first is Map<String, dynamic>) {
      return Dictamen.desdeFila(dato.first as Map<String, dynamic>);
    }
    return null;
  }

  final String pedidoId;
  final ResultadoDictamen resultado;

  /// Por qué se rechazó, o por qué se aprobó a pesar de alguna falla.
  final String motivo;
  final DateTime emitidoEn;

  bool get aprobado => resultado == ResultadoDictamen.aprobado;
}
