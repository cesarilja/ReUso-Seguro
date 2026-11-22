import 'dictamen.dart';
import 'escala.dart';
import 'inspeccion.dart';
import 'pedido.dart';
import 'plan_inspeccion.dart';

/// Un punto del checklist con lo que encontró el inspector.
class PuntoCertificado {
  const PuntoCertificado({
    required this.punto,
    required this.revision,
    this.declarado,
  });

  final PuntoChecklist punto;

  /// null si el punto quedó sin revisar (no debería pasar con un dictamen).
  final RevisionPunto? revision;

  /// HU19: cómo lo calificó el vendedor al publicar (null si no lo hizo).
  final Calificacion? declarado;

  ResultadoPunto? get resultado => revision?.resultado;

  /// HU15: la nota del inspector, del 1 al 4.
  Calificacion? get calificacion => revision?.calificacion;

  /// HU19: el vendedor dijo 2 notas o más de lo que encontró el inspector.
  bool get inexacto =>
      declarado != null &&
      calificacion != null &&
      declarado!.valor - calificacion!.valor >= ReglasEscala.diferenciaInexacta;

  /// Texto corto del resultado, como pide la HU03: «Bien», «Falla» o
  /// «No aplica».
  String get textoResultado {
    final nota = calificacion;
    if (nota != null) return nota.etiqueta;
    return switch (resultado) {
      ResultadoPunto.ok => 'Bien',
      ResultadoPunto.falla => 'Falla',
      ResultadoPunto.noAplica => 'No aplica',
      null => 'Sin revisar',
    };
  }
}

/// El certificado técnico de un pedido (HU03): se arma con el dictamen y
/// el checklist del Hub, según el tipo de equipo.
///
/// Solo existe cuando el inspector ya emitió el dictamen. Quién puede
/// leerlo lo decide el servidor (reglas RLS): el comprador, el vendedor y
/// los inspectores.
class Certificado {
  Certificado._({
    required this.pedido,
    required this.dictamen,
    required this.inspeccion,
    required this.puntos,
  });

  /// Null si todavía no hay dictamen o checklist (HU03, escenario 3).
  static Certificado? desde(Pedido pedido) {
    final dictamen = pedido.dictamen;
    final inspeccion = pedido.inspeccion;
    if (dictamen == null || inspeccion == null) return null;
    return Certificado._(
      pedido: pedido,
      dictamen: dictamen,
      inspeccion: inspeccion,
      puntos: [
        for (final punto in PuntoChecklist.para(pedido.equipo.categoria))
          PuntoCertificado(
            punto: punto,
            revision: inspeccion.puntos[punto.clave],
            declarado: Calificacion.desde(
              pedido.equipo.autoevaluacion[punto.clave],
            ),
          ),
      ],
    );
  }

  final Pedido pedido;
  final Dictamen dictamen;
  final Inspeccion inspeccion;

  /// Los puntos del checklist del tipo de equipo, en orden.
  final List<PuntoCertificado> puntos;

  bool get aprobado => dictamen.aprobado;

  /// Número del certificado, por ejemplo CT-1001.
  String get codigo => 'CT-${pedido.numero}';

  int _contar(ResultadoPunto resultado) =>
      puntos.where((p) => p.resultado == resultado).length;

  int get puntosBien => _contar(ResultadoPunto.ok);
  int get puntosConFalla => _contar(ResultadoPunto.falla);
  int get puntosNoAplica => _contar(ResultadoPunto.noAplica);

  List<PuntoCertificado> get fallas =>
      puntos.where((p) => p.resultado == ResultadoPunto.falla).toList();

  /// HU15: puntaje general (de 1 a 4), si el checklist tiene notas.
  double? get puntaje =>
      inspeccion.puntaje ??
      ReglasEscala.puntaje(puntos.map((p) => p.calificacion));

  /// HU16: el plan de la inspección.
  PlanInspeccion get plan => pedido.planInspeccion;

  /// HU19: si el vendedor calificó su equipo al publicar.
  bool get hayAutoevaluacion => puntos.any((p) => p.declarado != null);

  /// HU19: lo marca el servidor al dictaminar; si el dictamen es de antes
  /// del Sprint 4 se calcula aquí con la misma regla.
  bool get declaracionInexacta =>
      dictamen.declaracionInexacta ||
      puntos.where((p) => p.inexacto).length >= ReglasEscala.puntosParaInexacta;

  List<PuntoCertificado> get puntosInexactos =>
      puntos.where((p) => p.inexacto).toList();

  /// Resumen de una línea para la comparación «declarado vs. encontrado».
  String get resumenInspector {
    final total = puntos.length;
    final conPuntaje = puntaje == null
        ? ''
        : ' Puntaje general: ${ReglasEscala.textoPuntaje(puntaje!)}.';
    if (fallas.isEmpty) {
      return 'Revisó $total puntos y todos funcionan bien'
          '${puntosNoAplica > 0 ? ' ($puntosNoAplica no aplican a este equipo)' : ''}.'
          '$conPuntaje';
    }
    final nombres = fallas.map((f) => f.punto.nombre.toLowerCase()).join(', ');
    final una = fallas.length == 1;
    return 'Revisó $total puntos y encontró ${fallas.length} '
        '${una ? 'falla' : 'fallas'}: $nombres.$conPuntaje';
  }

  /// Nombre del PDF: el código del pedido y la fecha del dictamen
  /// (HU03, escenario 4). Por ejemplo: Certificado_P-1001_2026-11-10.pdf
  String get nombreArchivo {
    final f = dictamen.emitidoEn;
    String dos(int n) => n.toString().padLeft(2, '0');
    return 'Certificado_${pedido.codigo}_${f.year}-${dos(f.month)}-${dos(f.day)}.pdf';
  }
}
