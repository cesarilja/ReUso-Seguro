import 'package:flutter/material.dart';

import '../tema.dart';
import '../widgets/navegacion.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pegatina.dart';
import 'publicar_screen.dart';
import '../widgets/avisos.dart';

/// «¿Cómo funciona?»: ayuda y preguntas frecuentes.
///
/// Resuelve el hallazgo de la heurística 10 del taller de UX (ayuda y
/// documentación): explica la custodia, qué revisa el Hub, la comisión y el
/// reembolso en un solo lugar, siempre a un clic desde la barra de arriba.
class ComoFuncionaScreen extends StatelessWidget {
  const ComoFuncionaScreen({super.key});

  Future<void> _publicar(BuildContext context) async {
    final listo = await asegurarSesion(context);
    if (!listo || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PublicarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancha = MediaQuery.sizeOf(context).width >= 900;

    return PaginaBase(
      seccion: Seccion.comoFunciona,
      anchoContenido: 1000,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Encabezado
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ancha ? 40 : 24),
            decoration: BoxDecoration(
              color: ColoresApp.lila,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ColoresApp.tinta, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cómo funciona ReUso Seguro?',
                  style: Tipos.titular.copyWith(fontSize: ancha ? 40 : 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'Compras y vendes tecnología usada sin miedo: el dinero no '
                  'pasa directo al vendedor. Lo guardamos en custodia hasta que '
                  'nuestro centro de revisión técnica (el Hub) confirma que el '
                  'equipo funciona.',
                  style: Tipos.cuerpo.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    BotonPegatina(
                      texto: 'Ver equipos',
                      icono: Icons.storefront_outlined,
                      alTocar: () => irA(context, Seccion.inicio),
                    ),
                    BotonPegatina(
                      texto: 'Publicar un equipo',
                      icono: Icons.add,
                      principal: false,
                      alTocar: () => _publicar(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 44),
          const Text('Los 4 pasos', style: Tipos.titulo),
          const SizedBox(height: 18),
          _Pasos(ancha: ancha),
          const SizedBox(height: 44),
          const Text('Por qué es seguro', style: Tipos.titulo),
          const SizedBox(height: 18),
          _Beneficios(ancha: ancha),
          const SizedBox(height: 44),
          const Text('Preguntas frecuentes', style: Tipos.titulo),
          const SizedBox(height: 14),
          const _Preguntas(),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ColoresApp.nube,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, color: ColoresApp.tinta),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ReUso Seguro es un proyecto académico de la Universidad '
                    'Metropolitana. Los pagos son simulados: no se mueve '
                    'dinero real.',
                    style: Tipos.pequeno.copyWith(
                      fontSize: 14,
                      color: ColoresApp.tinta,
                    ),
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

class _Pasos extends StatelessWidget {
  const _Pasos({required this.ancha});

  final bool ancha;

  static const _datos = [
    (
      '1',
      Icons.add_a_photo_outlined,
      'El vendedor publica',
      'Sube al menos 3 fotos y cuenta con honestidad cómo está el equipo.',
    ),
    (
      '2',
      Icons.lock_outline,
      'El comprador paga',
      'El dinero queda en custodia. El vendedor todavía no lo recibe.',
    ),
    (
      '3',
      Icons.fact_check_outlined,
      'El Hub lo revisa',
      'Un inspector técnico prueba el equipo punto por punto y emite un '
          'dictamen.',
    ),
    (
      '4',
      Icons.lock_open,
      'Se libera el pago',
      'Si pasa, el vendedor cobra y el comprador recibe su equipo. Si no, '
          'se devuelve el dinero.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tarjetas = [
      for (final (numero, icono, titulo, texto) in _datos)
        Pegatina(
          radio: 20,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: ColoresApp.tinta,
                      child: Text(
                        numero,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(icono, color: ColoresApp.orquidea, size: 30),
                  ],
                ),
                const SizedBox(height: 14),
                Text(titulo, style: Tipos.subtitulo),
                const SizedBox(height: 6),
                Text(texto, style: Tipos.pequeno.copyWith(fontSize: 14)),
              ],
            ),
          ),
        ),
    ];

    if (!ancha) {
      return Column(
        children: [
          for (final t in tarjetas) ...[t, const SizedBox(height: 14)],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tarjetas.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: tarjetas[i]),
          ],
        ],
      ),
    );
  }
}

class _Beneficios extends StatelessWidget {
  const _Beneficios({required this.ancha});

  final bool ancha;

  @override
  Widget build(BuildContext context) {
    Widget tarjeta(String titulo, IconData icono, List<String> puntos) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: ColoresApp.nube,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: ColoresApp.tinta),
                const SizedBox(width: 10),
                Text(titulo, style: Tipos.subtitulo),
              ],
            ),
            const SizedBox(height: 12),
            for (final punto in puntos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFF1F7A44),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        punto,
                        style: Tipos.pequeno.copyWith(
                          fontSize: 14.5,
                          color: ColoresApp.tinta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    final comprador = tarjeta('Si compras', Icons.shopping_bag_outlined, [
      'Nunca pagas directo a un desconocido.',
      'Un experto revisa el equipo por ti.',
      'Si no pasa la inspección, recuperas el 100 % de tu dinero.',
      'Ves en todo momento en qué va tu pedido.',
    ]);
    final vendedor = tarjeta('Si vendes', Icons.sell_outlined, [
      'El comprador ya pagó antes de que envíes el equipo.',
      'Una inspección imparcial respalda tu equipo.',
      'Cobras automáticamente cuando el equipo se aprueba.',
      'Solo pagas una comisión del 8 % cuando vendes.',
    ]);

    if (!ancha) {
      return Column(children: [comprador, const SizedBox(height: 14), vendedor]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: comprador),
          const SizedBox(width: 16),
          Expanded(child: vendedor),
        ],
      ),
    );
  }
}

class _Preguntas extends StatelessWidget {
  const _Preguntas();

  static const _preguntas = [
    (
      '¿Qué significa que mi pago queda «en custodia»?',
      'Que el dinero queda guardado por ReUso Seguro, no lo recibe el '
          'vendedor. Solo se le entrega cuando el Hub aprueba el equipo. Si '
          'no lo aprueba, te lo devolvemos completo.',
    ),
    (
      '¿Qué es el Hub?',
      'Es nuestro centro de revisión técnica. Ahí un inspector prueba cada '
          'equipo con un checklist según su tipo: no se revisa igual una '
          'laptop que unos audífonos.',
    ),
    (
      '¿Qué revisa el inspector?',
      'Depende del equipo. En una laptop: encendido, pantalla, teclado, '
          'batería, puertos y chasis. En una consola: imagen por HDMI, '
          'controles, lectora y ventilación. En unos audífonos: sonido, '
          'micrófono, botones y almohadillas. Cada falla queda con nota y foto.',
    ),
    (
      '¿Cuánto cuesta usar ReUso Seguro?',
      'Para el comprador, nada: paga el precio publicado y la inspección '
          'está incluida. El vendedor paga una comisión del 8 % solo cuando '
          'el equipo se vende y se aprueba.',
    ),
    (
      '¿Qué pasa si el equipo no pasa la inspección?',
      'El inspector explica el motivo en su dictamen, el comprador recibe '
          'el reembolso completo y el equipo vuelve a su vendedor.',
    ),
    (
      '¿Puedo cancelar una compra?',
      'Sí, mientras no la hayas pagado. Entra a «Mis compras», abre el pedido '
          'y toca «Cancelar pedido».',
    ),
    (
      '¿Dónde veo en qué va mi pedido?',
      'En «Mis compras» (si compraste) o en «Mis ventas» (si vendiste). Se '
          'actualizan solas en cuanto el Hub avanza, sin recargar la página.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (pregunta, respuesta) in _preguntas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColoresApp.tinta, width: 2),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(
                    pregunta,
                    style: Tipos.subtitulo.copyWith(fontSize: 15.5),
                  ),
                  children: [Text(respuesta, style: Tipos.cuerpo)],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
