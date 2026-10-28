import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../tema.dart';

/// Ícono de cada forma de pago (la vista decide cómo se ve; el modelo no).
IconData iconoDeMetodo(MetodoPago metodo) => switch (metodo) {
      MetodoPago.tarjeta => Icons.credit_card,
      MetodoPago.pagoMovil => Icons.phone_iphone,
      MetodoPago.zelle => Icons.account_balance_outlined,
    };

/// Etiqueta con el estado de un pedido.
///
/// El estado se reconoce por el texto y el ícono, no solo por el color
/// (WCAG 1.4.1, visto en el taller de UX).
class EtiquetaPedido extends StatelessWidget {
  const EtiquetaPedido({super.key, required this.estado});

  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    final (fondo, icono, colorIcono) = switch (estado) {
      EstadoPedido.pendienteDePago => (Colors.white, Icons.schedule, ColoresApp.tinta),
      EstadoPedido.cancelado => (ColoresApp.nube, Icons.block, ColoresApp.pizarra),
      EstadoPedido.rechazado ||
      EstadoPedido.reembolsado =>
        (const Color(0xFFFBE9E8), Icons.undo, const Color(0xFFB3261E)),
      _ => (const Color(0xFFDFF3E6), Icons.lock, const Color(0xFF1F7A44)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColoresApp.tinta, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: colorIcono),
          const SizedBox(width: 6),
          Text(
            estado.nombre,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: ColoresApp.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Las fases del pedido, como el rastreo de una encomienda.
///
/// Resuelve el hallazgo 4 de la heurística 1 (visibilidad del estado del
/// sistema): el comprador ve qué ya pasó y qué viene después.
class LineaDeTiempo extends StatelessWidget {
  const LineaDeTiempo({super.key, required this.estado});

  final EstadoPedido estado;

  static const List<(EstadoPedido, String)> _fases = [
    (EstadoPedido.pagoEnCustodia, 'Pago en custodia'),
    (EstadoPedido.recibidoEnHub, 'El vendedor lo entrega en el Hub'),
    (EstadoPedido.enDiagnostico, 'El inspector técnico lo revisa'),
    (EstadoPedido.aprobado, 'Aprobado: el pago se libera al vendedor'),
    (EstadoPedido.enCamino, 'Va en camino a tus manos'),
  ];

  int get _actual {
    final orden = [
      EstadoPedido.pagoEnCustodia,
      EstadoPedido.recibidoEnHub,
      EstadoPedido.enDiagnostico,
      EstadoPedido.aprobado,
      EstadoPedido.pagoLiberado,
      EstadoPedido.enCamino,
    ];
    final indice = orden.indexOf(estado);
    if (indice < 0) return -1;
    // «Pago liberado» y «Aprobado» son la misma fase para el comprador.
    return indice >= 4 ? indice - 1 : indice;
  }

  @override
  Widget build(BuildContext context) {
    final actual = _actual;

    return Column(
      children: [
        for (var i = 0; i < _fases.length; i++)
          _Fase(
            texto: _fases[i].$2,
            hecha: i < actual,
            esActual: i == actual,
            ultima: i == _fases.length - 1,
          ),
      ],
    );
  }
}

class _Fase extends StatelessWidget {
  const _Fase({
    required this.texto,
    required this.hecha,
    required this.esActual,
    required this.ultima,
  });

  final String texto;
  final bool hecha;
  final bool esActual;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1F7A44);
    final activa = hecha || esActual;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: activa ? verde : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activa ? verde : ColoresApp.cielo,
                      width: 2,
                    ),
                  ),
                  child: activa
                      ? Icon(
                          hecha ? Icons.check : Icons.circle,
                          size: hecha ? 14 : 8,
                          color: Colors.white,
                        )
                      : null,
                ),
                if (!ultima)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: hecha ? verde : ColoresApp.cielo,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 1),
              child: Text(
                esActual ? '$texto (ahora)' : texto,
                style: Tipos.pequeno.copyWith(
                  fontSize: 14,
                  color: activa ? ColoresApp.tinta : ColoresApp.pizarra,
                  fontWeight: esActual ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una fila con un dato a la izquierda y su valor a la derecha.
class FilaDato extends StatelessWidget {
  const FilaDato({
    super.key,
    required this.titulo,
    required this.valor,
    this.destacado = false,
  });

  final String titulo;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = destacado
        ? Tipos.subtitulo
        : Tipos.cuerpo.copyWith(fontSize: 15, color: ColoresApp.tinta);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              titulo,
              style: destacado
                  ? Tipos.subtitulo
                  : Tipos.cuerpo.copyWith(fontSize: 15),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(valor, textAlign: TextAlign.right, style: estilo),
          ),
        ],
      ),
    );
  }
}

/// Recuadro suave con un ícono y un texto.
class RecuadroInfo extends StatelessWidget {
  const RecuadroInfo({
    super.key,
    required this.texto,
    this.icono = Icons.info_outline,
    this.color = ColoresApp.nube,
    this.colorIcono = ColoresApp.tinta,
    this.colorTexto = ColoresApp.tinta,
    this.hijo,
  });

  final String texto;
  final IconData icono;
  final Color color;
  final Color colorIcono;
  final Color colorTexto;

  /// Algo extra debajo del texto (por ejemplo, un interruptor).
  final Widget? hijo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: colorIcono),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: Tipos.pequeno.copyWith(
                    fontSize: 14.5,
                    color: colorTexto,
                  ),
                ),
              ),
            ],
          ),
          if (hijo != null) ...[const SizedBox(height: 8), hijo!],
        ],
      ),
    );
  }
}
