import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../tema.dart';
import '../widgets/barra_superior.dart';
import '../widgets/pegatina.dart';
import '../widgets/pie_de_pagina.dart';

/// Pantalla de pago de un pedido recién creado (HU12).
///
/// En el Sprint 1 muestra el resumen del pedido en "Pendiente de pago".
/// El pago protegido con el dinero en custodia es la HU01 (Sprint 2).
class PagoScreen extends StatelessWidget {
  const PagoScreen({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final margen = margenLateral(context);

    return Scaffold(
      body: Column(
        children: [
          BarraSuperior(
            alTocarLogo: () =>
                Navigator.of(context).popUntil((ruta) => ruta.isFirst),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margen, 20, margen, 72),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: _Contenido(pedido: pedido),
                      ),
                    ),
                  ),
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: PieDePagina(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final equipo = pedido.equipo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: ColoresApp.tinta),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Volver al equipo'),
        ),
        const SizedBox(height: 20),
        const Text('Tu pedido', style: Tipos.titulo),
        const SizedBox(height: 6),
        const Text(
          'Creamos tu pedido. Cuando lo pagues, el dinero quedará en '
          'custodia hasta que nuestro Hub revise el equipo.',
          style: Tipos.cuerpo,
        ),
        const SizedBox(height: 28),
        Pegatina(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        equipo.imagen,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            equipo.titulo,
                            style: Tipos.subtitulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pedido ${pedido.id} · Vende ${equipo.vendedor}',
                            style: Tipos.pequeno,
                          ),
                          const SizedBox(height: 8),
                          _EtiquetaPedido(texto: pedido.estado.nombre),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(height: 2, color: ColoresApp.nube),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Total a pagar', style: Tipos.subtitulo),
                    ),
                    Text(equipo.precioFormateado, style: Tipos.precio),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColoresApp.lila,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, color: ColoresApp.tinta),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El pago protegido estará disponible en la próxima '
                  'versión. Tu pedido queda guardado en "Pendiente de pago".',
                  style: Tipos.pequeno.copyWith(
                    fontSize: 14.5,
                    color: ColoresApp.tinta,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        BotonPegatina(
          texto: 'Seguir viendo equipos',
          principal: false,
          expandido: true,
          alTocar: () =>
              Navigator.of(context).popUntil((ruta) => ruta.isFirst),
        ),
      ],
    );
  }
}

/// Etiqueta con el estado del pedido.
class _EtiquetaPedido extends StatelessWidget {
  const _EtiquetaPedido({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColoresApp.tinta, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 14, color: ColoresApp.tinta),
          const SizedBox(width: 6),
          Text(
            texto,
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
