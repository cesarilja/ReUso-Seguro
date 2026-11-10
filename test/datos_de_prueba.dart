// Datos de ejemplo compartidos por las pruebas (no es una prueba).
import 'package:reuso_seguro/models/dictamen.dart';
import 'package:reuso_seguro/models/equipo.dart';
import 'package:reuso_seguro/models/inspeccion.dart';
import 'package:reuso_seguro/models/pedido.dart';

const Equipo laptopDePrueba = Equipo(
  id: 'equipo-1',
  titulo: 'Laptop Lenovo ThinkPad T480',
  descripcion: 'Batería con 2 horas de duración y cargador original.',
  estadoDeclarado: 'Usado, en buen estado, marcas leves en la tapa.',
  precio: 250,
  vendedor: 'Ana Pérez',
  categoria: 'Laptop',
);

final DateTime pagado = DateTime(2026, 11, 3, 9, 0);
final DateTime recibido = DateTime(2026, 11, 4, 10, 30);
final DateTime diagnostico = DateTime(2026, 11, 4, 15, 0);
final DateTime emitido = DateTime(2026, 11, 5, 11, 15);
final DateTime liberado = DateTime(2026, 11, 5, 11, 15);

/// Checklist de una laptop: todo bien, salvo [falla] si se indica.
Inspeccion inspeccionDePrueba({String? falla}) => Inspeccion(
      pedidoId: 'pedido-1',
      completa: true,
      actualizadaEn: diagnostico,
      puntos: {
        for (final punto in PuntoChecklist.para('Laptop'))
          punto.clave: punto.clave == falla
              ? const RevisionPunto(
                  resultado: ResultadoPunto.falla,
                  nota: 'La batería dura solo 20 minutos.',
                )
              : const RevisionPunto(resultado: ResultadoPunto.ok),
      },
    );

Dictamen dictamenDePrueba({bool aprobado = true, String motivo = ''}) => Dictamen(
      pedidoId: 'pedido-1',
      resultado: aprobado ? ResultadoDictamen.aprobado : ResultadoDictamen.rechazado,
      motivo: motivo,
      emitidoEn: emitido,
      inspectorNombre: 'Lucas Gomez',
    );

/// Un pedido en el [estado] indicado, con las fechas que le corresponden.
Pedido pedidoDePrueba(
  EstadoPedido estado, {
  Dictamen? dictamen,
  Inspeccion? inspeccion,
}) {
  final indice = EstadoPedido.values.indexOf(estado);
  bool llego(EstadoPedido fase) => indice >= EstadoPedido.values.indexOf(fase);
  final rechazado =
      estado == EstadoPedido.rechazado || estado == EstadoPedido.reembolsado;
  return Pedido(
    id: 'pedido-1',
    numero: 1001,
    equipo: laptopDePrueba,
    compradorId: 'comprador-1',
    monto: 250,
    creadoEn: pagado,
    estado: estado,
    metodo: MetodoPago.tarjeta,
    pagadoEn: estado == EstadoPedido.pendienteDePago ? null : pagado,
    recibidoEn: llego(EstadoPedido.recibidoEnHub) ? recibido : null,
    diagnosticoEn: llego(EstadoPedido.enDiagnostico) ? diagnostico : null,
    dictamen: dictamen,
    inspeccion: inspeccion,
    liberadoEn: estado == EstadoPedido.pagoLiberado ? liberado : null,
    reembolsadoEn: estado == EstadoPedido.reembolsado ? liberado : null,
    montoReembolsado: estado == EstadoPedido.reembolsado ? 250 : null,
    comision: rechazado ? 0 : null,
  );
}
