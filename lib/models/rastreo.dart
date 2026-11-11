import 'pedido.dart';

/// En qué punto está una fase del pedido.
enum EstadoFase { hecha, actual, pendiente }

/// Una fase del rastreo del pedido (HU02).
class FaseRastreo {
  const FaseRastreo({
    required this.titulo,
    required this.estado,
    this.fecha,
    this.negativa = false,
  });

  final String titulo;
  final EstadoFase estado;

  /// Cuándo se completó. Solo se muestra en las fases ya alcanzadas.
  final DateTime? fecha;

  /// La fase terminó mal para el comprador (equipo rechazado): se muestra
  /// en rojo, con su ícono y su texto.
  final bool negativa;

  bool get alcanzada => estado != EstadoFase.pendiente;
}

/// Dónde está el dinero del comprador en cada momento (HU02, escenario 3).
enum DondeEstaElDinero {
  sinCobrar('No se te ha cobrado nada.'),
  enCustodia('Tu dinero está en custodia: ReUso Seguro lo guarda y el '
      'vendedor todavía no lo recibe.'),
  liberandose('El equipo pasó la inspección: tu dinero se está liberando '
      'al vendedor.'),
  liberado('Tu dinero se liberó al vendedor porque el equipo pasó la '
      'inspección.'),
  devolviendose('El equipo no pasó la inspección: te estamos devolviendo '
      'tu dinero.'),
  devuelto('Tu dinero fue devuelto a ti: el 100 % de lo que pagaste.');

  const DondeEstaElDinero(this.texto);

  final String texto;
}

/// Arma el rastreo de un pedido a partir de su estado y sus fechas
/// (HU02). No depende de la pantalla, así que se prueba con pruebas
/// unitarias.
class Rastreo {
  Rastreo._(this.pedido);

  factory Rastreo.de(Pedido pedido) => Rastreo._(pedido);

  final Pedido pedido;

  /// Número de fases que se muestran.
  static const int totalFases = 5;

  bool get _rechazado =>
      pedido.estado == EstadoPedido.rechazado ||
      pedido.estado == EstadoPedido.reembolsado;

  /// Índice de la fase actual (0 a 4), o -1 si el pedido no se ha pagado o
  /// se canceló.
  int get indiceActual => switch (pedido.estado) {
        EstadoPedido.pendienteDePago || EstadoPedido.cancelado => -1,
        EstadoPedido.pagoEnCustodia => 0,
        EstadoPedido.recibidoEnHub => 1,
        EstadoPedido.enDiagnostico => 2,
        EstadoPedido.aprobado ||
        EstadoPedido.liberacionPendiente ||
        EstadoPedido.rechazado =>
          3,
        EstadoPedido.pagoLiberado ||
        EstadoPedido.enCamino ||
        EstadoPedido.reembolsado =>
          4,
      };

  /// Las 5 fases: Pago en custodia → Recibido en el Hub → En diagnóstico
  /// → Dictamen → Pago liberado o Reembolso.
  List<FaseRastreo> get fases {
    final actual = indiceActual;
    final dictamen = pedido.dictamen;

    final String tituloDictamen;
    if (dictamen == null) {
      tituloDictamen = 'Dictamen del inspector';
    } else {
      tituloDictamen = 'Dictamen: ${dictamen.resultado.nombre}';
    }

    final String tituloFinal;
    final DateTime? fechaFinal;
    if (_rechazado) {
      tituloFinal = 'Reembolso: te devolvimos tu dinero';
      fechaFinal = pedido.reembolsadoEn;
    } else if (actual >= 3) {
      tituloFinal = 'Pago liberado al vendedor';
      fechaFinal = pedido.liberadoEn;
    } else {
      tituloFinal = 'Pago liberado o reembolso';
      fechaFinal = null;
    }

    final datos = <(String, DateTime?, bool)>[
      ('Pago en custodia', pedido.pagadoEn, false),
      ('Recibido en el Hub', pedido.recibidoEn, false),
      ('En diagnóstico', pedido.diagnosticoEn, false),
      (tituloDictamen, dictamen?.emitidoEn, _rechazado),
      (tituloFinal, fechaFinal, _rechazado),
    ];

    return [
      for (var i = 0; i < datos.length; i++)
        FaseRastreo(
          titulo: datos[i].$1,
          estado: i < actual
              ? EstadoFase.hecha
              : (i == actual ? EstadoFase.actual : EstadoFase.pendiente),
          // Solo las fases alcanzadas muestran su fecha.
          fecha: i <= actual ? datos[i].$2 : null,
          negativa: datos[i].$3 && i <= actual,
        ),
    ];
  }

  /// La fase en la que está el pedido, o null si no se ha pagado.
  FaseRastreo? get faseActual {
    final actual = indiceActual;
    return actual < 0 ? null : fases[actual];
  }

  /// HU02, escenario 3: un texto que dice dónde está el dinero.
  DondeEstaElDinero get dinero => switch (pedido.estado) {
        EstadoPedido.pendienteDePago ||
        EstadoPedido.cancelado =>
          DondeEstaElDinero.sinCobrar,
        EstadoPedido.pagoEnCustodia ||
        EstadoPedido.recibidoEnHub ||
        EstadoPedido.enDiagnostico =>
          DondeEstaElDinero.enCustodia,
        EstadoPedido.aprobado ||
        EstadoPedido.liberacionPendiente =>
          DondeEstaElDinero.liberandose,
        EstadoPedido.pagoLiberado ||
        EstadoPedido.enCamino =>
          DondeEstaElDinero.liberado,
        EstadoPedido.rechazado => DondeEstaElDinero.devolviendose,
        EstadoPedido.reembolsado => DondeEstaElDinero.devuelto,
      };

  /// HU02, escenario 2: el aviso cuando el pedido cambia de fase en vivo,
  /// por ejemplo «Tu equipo pasó a: En diagnóstico». Null si no avanzó.
  static String? avisoDeCambio(EstadoPedido antes, Pedido ahora) {
    final rastreo = Rastreo.de(ahora);
    final indiceAntes = Rastreo.de(_conEstado(ahora, antes)).indiceActual;
    if (rastreo.indiceActual <= indiceAntes) return null;
    final fase = rastreo.faseActual;
    if (fase == null) return null;
    return 'Tu equipo «${ahora.equipo.titulo}» pasó a: ${fase.titulo}';
  }

  static Pedido _conEstado(Pedido pedido, EstadoPedido estado) => Pedido(
        id: pedido.id,
        numero: pedido.numero,
        equipo: pedido.equipo,
        compradorId: pedido.compradorId,
        monto: pedido.monto,
        creadoEn: pedido.creadoEn,
        estado: estado,
      );
}
