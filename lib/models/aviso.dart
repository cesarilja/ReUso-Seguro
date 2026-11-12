import 'pedido.dart';

DateTime? _fecha(Object? valor) =>
    valor is String ? DateTime.parse(valor).toLocal() : null;

/// HU10: un aviso que crea el servidor cada vez que cambia el estado de un
/// pedido. Guarda cuándo lo vio el comprador y cuándo el vendedor.
class Aviso {
  const Aviso({
    required this.id,
    required this.pedidoId,
    required this.estado,
    required this.mensajeComprador,
    required this.mensajeVendedor,
    required this.creadoEn,
    this.compradorVistoEn,
    this.vendedorVistoEn,
    this.compradorId,
    this.vendedorId,
    this.numero,
    this.titulo,
  });

  /// Una fila de `avisos`, con su pedido y su equipo si vienen en la consulta.
  factory Aviso.desdeFila(Map<String, dynamic> fila) {
    final pedido = fila['pedidos'] is Map<String, dynamic>
        ? fila['pedidos'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final equipo = pedido['equipos'] is Map<String, dynamic>
        ? pedido['equipos'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return Aviso(
      id: (fila['id'] as num).toInt(),
      pedidoId: fila['pedido_id'] as String,
      estado: EstadoPedido.desde(fila['estado'] as String?),
      mensajeComprador: (fila['mensaje_comprador'] as String?) ?? '',
      mensajeVendedor: (fila['mensaje_vendedor'] as String?) ?? '',
      creadoEn: _fecha(fila['creado_en']) ?? DateTime.now(),
      compradorVistoEn: _fecha(fila['comprador_visto_en']),
      vendedorVistoEn: _fecha(fila['vendedor_visto_en']),
      compradorId: pedido['comprador_id'] as String?,
      vendedorId: equipo['vendedor_id'] as String?,
      numero: (pedido['numero'] as num?)?.toInt(),
      titulo: equipo['titulo'] as String?,
    );
  }

  final int id;
  final String pedidoId;
  final EstadoPedido estado;
  final String mensajeComprador;
  final String mensajeVendedor;
  final DateTime creadoEn;
  final DateTime? compradorVistoEn;
  final DateTime? vendedorVistoEn;
  final String? compradorId;
  final String? vendedorId;
  final int? numero;
  final String? titulo;

  String get codigo => numero == null ? 'Pedido' : 'P-$numero';

  bool get vistoPorComprador => compradorVistoEn != null;
  bool get vistoPorVendedor => vendedorVistoEn != null;

  /// Los dos ya lo vieron.
  bool get vistoPorAmbos => vistoPorComprador && vistoPorVendedor;
}

/// Qué avisos le tocan a una persona y cuáles todavía no ha visto (HU10).
class ReglasAvisos {
  const ReglasAvisos._();

  /// Los mensajes sin ver de [usuario] (como comprador o como vendedor) y
  /// los ids de esos avisos, para marcarlos como vistos.
  static ({List<String> mensajes, List<int> ids}) pendientesDe(
    String usuario,
    Iterable<Aviso> avisos,
  ) {
    final mensajes = <String>[];
    final ids = <int>{};
    final ordenados = avisos.toList()..sort((a, b) => a.creadoEn.compareTo(b.creadoEn));
    for (final aviso in ordenados) {
      if (aviso.compradorId == usuario && !aviso.vistoPorComprador) {
        mensajes.add(aviso.mensajeComprador);
        ids.add(aviso.id);
      }
      if (aviso.vendedorId == usuario && !aviso.vistoPorVendedor) {
        mensajes.add(aviso.mensajeVendedor);
        ids.add(aviso.id);
      }
    }
    return (mensajes: mensajes, ids: ids.toList());
  }

  /// Texto para mostrar los avisos de una vez. [alVolver] = la persona no
  /// estaba conectada cuando pasaron (HU10, escenario 2).
  static String? resumen(List<String> mensajes, {required bool alVolver}) {
    if (mensajes.isEmpty) return null;
    final visibles = mensajes.length > 3 ? mensajes.sublist(mensajes.length - 3) : mensajes;
    final extra = mensajes.length - visibles.length;
    final cuerpo = visibles.join('\n');
    final inicio = alVolver
        ? 'Mientras no estabas (${mensajes.length} '
            '${mensajes.length == 1 ? 'aviso' : 'avisos'}):\n'
        : '';
    final fin = extra > 0 ? '\n…y $extra más.' : '';
    return '$inicio$cuerpo$fin';
  }
}
