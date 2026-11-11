import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/pedido.dart';
import '../models/venta.dart';
import '../tema.dart';
import 'pasarela_widgets.dart';
import 'pedido_widgets.dart';
import 'pegatina.dart';

const Color _rojo = Color(0xFFB3261E);
const Color _ambar = Color(0xFF8A5A00);

/// HU04, escenario 2: los pasos para llevar el equipo al Hub, con el
/// código del pedido bien visible (heurística 10: ayuda clara).
class InstruccionesEntrega extends StatelessWidget {
  const InstruccionesEntrega({
    super.key,
    required this.venta,
    required this.alEntregar,
    this.ocupado = false,
  });

  final Pedido venta;
  final VoidCallback alEntregar;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF3E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F7A44), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Color(0xFF1F7A44)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El comprador ya pagó y el dinero está en custodia. '
                  'Ya puedes llevar el equipo al Hub.',
                  style: Tipos.subtitulo.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const PasoTransferencia(
            numero: 1,
            texto: 'Empaca el equipo con su cargador y accesorios',
          ),
          const SizedBox(height: 10),
          const PasoTransferencia(numero: 2, texto: 'Llévalo al Hub'),
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 4, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Linea(icono: Icons.place_outlined, texto: DatosDelHub.direccion),
                const SizedBox(height: 4),
                const _Linea(icono: Icons.schedule, texto: DatosDelHub.horario),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const PasoTransferencia(numero: 3, texto: 'Muestra este código al llegar'),
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 4, 0, 0),
            child: Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DatoCopiable(titulo: 'Código del pedido', valor: venta.codigo),
            ),
          ),
          const SizedBox(height: 16),
          BotonPegatina(
            texto: ocupado ? 'Avisando…' : 'Ya entregué el equipo',
            icono: ocupado ? Icons.hourglass_top : Icons.inventory_2_outlined,
            expandido: true,
            alTocar: ocupado ? () {} : alEntregar,
          ),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: ColoresApp.tinta),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: Tipos.pequeno.copyWith(fontSize: 14, color: ColoresApp.tinta),
          ),
        ),
      ],
    );
  }
}

/// HU04, escenario 3: el vendedor ya avisó que lo entregó.
class EsperandoAlHub extends StatelessWidget {
  const EsperandoAlHub({super.key, required this.venta});

  final Pedido venta;

  @override
  Widget build(BuildContext context) {
    final entregado = venta.entregadoEn;
    return RecuadroInfo(
      icono: Icons.hourglass_top,
      texto: 'Esperando que el Hub lo reciba. '
          '${entregado == null ? '' : 'Avisaste que lo entregaste el ${formatearFecha(entregado)}. '}'
          'Cuando el inspector registre la llegada, lo verás aquí.',
    );
  }
}

/// HU06, escenario 1: la transferencia falló. Dice qué pasó, que el dinero
/// sigue seguro y qué hacer (heurística 9), con color, ícono y texto.
class AvisoLiberacionPendiente extends StatelessWidget {
  const AvisoLiberacionPendiente({
    super.key,
    required this.venta,
    required this.alReintentar,
    required this.alRegistrarCuenta,
    this.ocupado = false,
  });

  final Pedido venta;
  final VoidCallback alReintentar;
  final VoidCallback alRegistrarCuenta;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    final motivo = venta.liberacionMotivo ?? MotivoLiberacion.desconocido;
    final faltaCuenta = motivo != MotivoLiberacion.desconocido;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ambar, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sync_problem, color: _ambar, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liberación pendiente: ${motivo.titulo}',
                      style: Tipos.subtitulo.copyWith(fontSize: 15.5, color: const Color(0xFF6B4500)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      motivo.queHacer,
                      style: Tipos.pequeno.copyWith(fontSize: 14, color: ColoresApp.tinta),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu dinero (${formatearDolares(venta.recibeVendedor)}) sigue '
                      'seguro en custodia. Intentos: ${venta.liberacionIntentos}.',
                      style: Tipos.pequeno.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: ColoresApp.tinta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (faltaCuenta)
            BotonPegatina(
              texto: motivo == MotivoLiberacion.sinCuenta
                  ? 'Registrar mi cuenta para cobrar'
                  : 'Revisar mi cuenta para cobrar',
              icono: Icons.account_balance_outlined,
              expandido: true,
              alTocar: alRegistrarCuenta,
            ),
          if (faltaCuenta) const SizedBox(height: 10),
          BotonPegatina(
            texto: ocupado ? 'Intentando…' : 'Reintentar el cobro',
            icono: ocupado ? Icons.hourglass_top : Icons.refresh,
            principal: !faltaCuenta,
            expandido: true,
            alTocar: ocupado ? () {} : alReintentar,
          ),
        ],
      ),
    );
  }
}

/// HU06: dónde cobra el vendedor. Sin cuenta, se le pide registrarla.
class TarjetaCuentaCobro extends StatelessWidget {
  const TarjetaCuentaCobro({super.key, required this.cuenta, required this.alEditar});

  final CuentaCobro? cuenta;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    return Pegatina(
      sombra: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              c == null ? Icons.account_balance_outlined : Icons.account_balance,
              color: c == null ? _rojo : const Color(0xFF1F7A44),
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c == null ? 'Registra dónde quieres cobrar' : 'Cobras por Pago Móvil',
                    style: Tipos.subtitulo.copyWith(fontSize: 15.5),
                  ),
                  Text(
                    c == null
                        ? 'Sin una cuenta no podemos transferirte el dinero de '
                            'tus ventas.'
                        : '${c.banco} · ${c.telefonoOculto} · ${c.titular}',
                    style: Tipos.pequeno.copyWith(fontSize: 13.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: alEditar,
              icon: Icon(c == null ? Icons.add : Icons.edit_outlined),
              label: Text(c == null ? 'Registrar' : 'Cambiar'),
            ),
          ],
        ),
      ),
    );
  }
}
