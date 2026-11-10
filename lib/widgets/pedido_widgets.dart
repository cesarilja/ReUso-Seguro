import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../models/rastreo.dart';
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

/// Las fases del pedido, como el rastreo de una encomienda (HU02).
///
/// Resuelve el hallazgo 4 de la heurística 1 (visibilidad del estado del
/// sistema): el comprador ve qué ya pasó, cuándo pasó y qué viene después.
/// Cada fase se distingue por ícono, texto y color, nunca solo por color.
class LineaDeTiempo extends StatelessWidget {
  const LineaDeTiempo({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final fases = Rastreo.de(pedido).fases;

    return Column(
      children: [
        for (var i = 0; i < fases.length; i++)
          _Fase(fase: fases[i], ultima: i == fases.length - 1),
      ],
    );
  }
}

class _Fase extends StatelessWidget {
  const _Fase({required this.fase, required this.ultima});

  final FaseRastreo fase;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1F7A44);
    const rojo = Color(0xFFB3261E);
    final hecha = fase.estado == EstadoFase.hecha;
    final esActual = fase.estado == EstadoFase.actual;
    final color = fase.negativa ? rojo : verde;
    final fecha = fase.fecha;

    final IconData? icono;
    if (!fase.alcanzada) {
      icono = null;
    } else if (fase.negativa) {
      icono = Icons.close;
    } else if (hecha || ultima) {
      icono = Icons.check;
    } else {
      icono = Icons.circle;
    }

    return Semantics(
      label: '${fase.titulo}. '
          '${hecha ? 'Hecho' : (esActual ? 'Fase actual' : 'Pendiente')}'
          '${fecha != null ? ', el ${formatearFecha(fecha)}' : ''}',
      child: ExcludeSemantics(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: esActual ? 24 : 22,
                      height: esActual ? 24 : 22,
                      decoration: BoxDecoration(
                        color: fase.alcanzada ? color : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: fase.alcanzada ? color : ColoresApp.cielo,
                          width: 2,
                        ),
                        boxShadow: esActual
                            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)]
                            : null,
                      ),
                      child: icono == null
                          ? null
                          : Icon(
                              icono,
                              size: icono == Icons.circle ? 8 : 14,
                              color: Colors.white,
                            ),
                    ),
                    if (!ultima)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: hecha ? color : ColoresApp.cielo,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esActual ? '${fase.titulo} (ahora)' : fase.titulo,
                        style: Tipos.pequeno.copyWith(
                          fontSize: 14,
                          color: fase.alcanzada
                              ? (fase.negativa ? rojo : ColoresApp.tinta)
                              : ColoresApp.pizarra,
                          fontWeight: esActual ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (fecha != null)
                        Text(
                          formatearFecha(fecha),
                          style: Tipos.pequeno.copyWith(fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// HU02, escenario 3: dónde está el dinero del comprador, en palabras
/// sencillas (heurística 2: lenguaje del usuario).
class DondeEstaTuDinero extends StatelessWidget {
  const DondeEstaTuDinero({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final dinero = Rastreo.de(pedido).dinero;
    final (icono, fondo, color) = switch (dinero) {
      DondeEstaElDinero.enCustodia => (
          Icons.lock_outline,
          ColoresApp.nube,
          ColoresApp.tinta
        ),
      DondeEstaElDinero.liberandose || DondeEstaElDinero.liberado => (
          Icons.check_circle_outline,
          const Color(0xFFDFF3E6),
          const Color(0xFF1F7A44)
        ),
      DondeEstaElDinero.devolviendose || DondeEstaElDinero.devuelto => (
          Icons.undo,
          const Color(0xFFDFF3E6),
          const Color(0xFF1F7A44)
        ),
      DondeEstaElDinero.sinCobrar => (
          Icons.info_outline,
          ColoresApp.nube,
          ColoresApp.tinta
        ),
    };

    return RecuadroInfo(
      icono: icono,
      color: fondo,
      colorIcono: color,
      texto: dinero.texto,
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

/// HU13: comprobante del reembolso cuando el equipo no pasa la inspección.
///
/// Usabilidad: el estado se lee por el título, el ícono y el color a la vez
/// (WCAG 1.4.1) y se aclara que el dinero es simulado (heurística 1:
/// visibilidad del estado; heurística 2: lenguaje del usuario).
class ComprobanteReembolso extends StatelessWidget {
  const ComprobanteReembolso({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1F7A44);
    final hecho = pedido.fueReembolsado;
    final reembolsadoEn = pedido.reembolsadoEn;
    final metodo = pedido.metodo;

    // Mientras el servidor termina, se dice qué está pasando (sin dejar
    // al comprador con la duda).
    if (!hecho) {
      return const RecuadroInfo(
        icono: Icons.hourglass_top,
        texto: 'Estamos procesando tu reembolso. En un momento verás aquí '
            'el comprobante.',
      );
    }

    return Semantics(
      container: true,
      label: 'Comprobante de reembolso',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: verde, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_return_outlined, color: verde, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reembolso completado',
                        style: Tipos.subtitulo.copyWith(color: verde),
                      ),
                      Text(
                        'Te devolvimos el 100 % de lo que pagaste.',
                        style: Tipos.pequeno.copyWith(
                          fontSize: 14,
                          color: ColoresApp.tinta,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 2, color: ColoresApp.nube),
            const SizedBox(height: 4),
            FilaDato(
              titulo: 'Comprobante',
              valor: pedido.referenciaReembolso ?? '—',
            ),
            FilaDato(titulo: 'Pagaste', valor: pedido.montoFormateado),
            FilaDato(
              titulo: 'Comisión cobrada',
              valor: formatearDolares(0),
            ),
            if (metodo != null)
              FilaDato(titulo: 'Devuelto a', valor: metodo.nombre),
            if (reembolsadoEn != null)
              FilaDato(titulo: 'Fecha', valor: formatearFecha(reembolsadoEn)),
            FilaDato(
              titulo: 'Te devolvimos',
              valor: formatearDolares(pedido.montoADevolver),
              destacado: true,
            ),
            const SizedBox(height: 6),
            Text(
              'Reembolso simulado: en esta versión no se mueve dinero real.',
              style: Tipos.pequeno,
            ),
          ],
        ),
      ),
    );
  }
}
