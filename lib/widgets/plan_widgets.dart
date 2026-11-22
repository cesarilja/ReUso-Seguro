import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/escala.dart';
import '../models/inspeccion.dart';
import '../models/plan_inspeccion.dart';
import '../tema.dart';

/// Widgets del Sprint 4: escala del 1 al 4 (HU15), planes de inspección
/// (HU16), cobro al vendedor (HU17) y autoevaluación (HU19).
///
/// El color nunca va solo: cada nota lleva también su número, su nombre y
/// un ícono, para quien no distingue colores (WCAG 1.4.1).

const Color _rojo = Color(0xFFB3261E);
const Color _ambar = Color(0xFF8A5A00);

/// Color e ícono de cada nota de la escala.
extension EstiloCalificacion on Calificacion {
  Color get color => switch (this) {
        Calificacion.excelente => ColoresApp.verde,
        Calificacion.bueno => ColoresApp.vinca,
        Calificacion.regular => _ambar,
        Calificacion.malo => _rojo,
      };

  Color get fondo => switch (this) {
        Calificacion.excelente => const Color(0xFFE5F4EB),
        Calificacion.bueno => ColoresApp.nube,
        Calificacion.regular => const Color(0xFFFFF1D6),
        Calificacion.malo => const Color(0xFFFBE9E8),
      };

  IconData get icono => switch (this) {
        Calificacion.excelente => Icons.verified_outlined,
        Calificacion.bueno => Icons.check_circle_outline,
        Calificacion.regular => Icons.warning_amber_rounded,
        Calificacion.malo => Icons.cancel_outlined,
      };
}

/// Botones para calificar un punto del 1 al 4, y «No aplica» si se puede.
class SelectorCalificacion extends StatelessWidget {
  const SelectorCalificacion({
    super.key,
    required this.valor,
    required this.alElegir,
    this.noAplica = false,
    this.permiteNoAplica = false,
    this.textoNoAplica = 'No aplica',
    this.alElegirNoAplica,
    this.habilitado = true,
  });

  final Calificacion? valor;
  final ValueChanged<Calificacion> alElegir;
  final bool noAplica;
  final bool permiteNoAplica;
  final String textoNoAplica;
  final VoidCallback? alElegirNoAplica;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final nota in Calificacion.values.reversed)
          _Opcion(
            texto: '${nota.valor} ${nota.nombre}',
            ayuda: nota.descripcion,
            icono: nota.icono,
            color: nota.color,
            fondo: nota.fondo,
            elegida: !noAplica && valor == nota,
            alTocar: habilitado ? () => alElegir(nota) : null,
          ),
        if (permiteNoAplica)
          _Opcion(
            texto: textoNoAplica,
            ayuda: 'Este equipo no tiene esta parte.',
            icono: Icons.remove_circle_outline,
            color: ColoresApp.pizarra,
            fondo: const Color(0xFFEDEEF2),
            elegida: noAplica,
            alTocar: habilitado ? alElegirNoAplica : null,
          ),
      ],
    );
  }
}

class _Opcion extends StatefulWidget {
  const _Opcion({
    required this.texto,
    required this.ayuda,
    required this.icono,
    required this.color,
    required this.fondo,
    required this.elegida,
    required this.alTocar,
  });

  final String texto;
  final String ayuda;
  final IconData icono;
  final Color color;
  final Color fondo;
  final bool elegida;
  final VoidCallback? alTocar;

  @override
  State<_Opcion> createState() => _OpcionState();
}

class _OpcionState extends State<_Opcion> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.alTocar != null;
    return Tooltip(
      message: widget.ayuda,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        selected: widget.elegida,
        label: widget.texto,
        child: MouseRegion(
          cursor: activo ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.elegida
                  ? widget.fondo
                  : _hover && activo
                      ? widget.fondo.withAlpha(100)
                      : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.elegida
                    ? widget.color
                    : _hover && activo
                        ? widget.color.withAlpha(160)
                        : const Color(0xFFC9CCD8),
                width: widget.elegida ? 2 : 1,
              ),
              boxShadow: _hover && activo && !widget.elegida
                  ? [
                      BoxShadow(
                        color: widget.color.withAlpha(30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: InkWell(
              onTap: widget.alTocar,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.elegida ? Icons.radio_button_checked : widget.icono,
                    size: 18,
                    color: widget.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.texto,
                    style: Tipos.pequeno.copyWith(
                      color: widget.elegida ? widget.color : ColoresApp.tinta,
                      fontWeight:
                          widget.elegida ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta con la nota de un punto, por ejemplo «3 de 4 (Bueno)».
class EtiquetaCalificacion extends StatelessWidget {
  const EtiquetaCalificacion({super.key, required this.calificacion});

  final Calificacion calificacion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: calificacion.fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(calificacion.icono, size: 15, color: calificacion.color),
          const SizedBox(width: 4),
          Text(
            calificacion.etiqueta,
            style: Tipos.pequeno.copyWith(
              fontSize: 12.5,
              color: calificacion.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// El puntaje general de una inspección, por ejemplo «Puntaje 3,8 de 4».
class EtiquetaPuntaje extends StatelessWidget {
  const EtiquetaPuntaje({super.key, required this.puntaje, this.compacta = false});

  final double puntaje;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final nota = Calificacion.desde(puntaje.round()) ?? Calificacion.bueno;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacta ? 6 : 10,
        vertical: compacta ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: nota.fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rate_rounded, size: compacta ? 14 : 18, color: nota.color),
          const SizedBox(width: 4),
          Text(
            compacta
                ? ReglasEscala.textoPuntaje(puntaje)
                : 'Puntaje ${ReglasEscala.textoPuntaje(puntaje)}',
            style: Tipos.pequeno.copyWith(
              fontSize: compacta ? 12 : 13.5,
              color: nota.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sello de la inspección detallada (HU16) para el catálogo.
class SelloDetallada extends StatelessWidget {
  const SelloDetallada({super.key, this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 6 : 10,
        vertical: compacto ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: ColoresApp.lila,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColoresApp.orquidea),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined,
              size: compacto ? 14 : 18, color: ColoresApp.tinta),
          const SizedBox(width: 4),
          Text(
            compacto ? 'Detallada' : 'Inspección detallada',
            style: Tipos.pequeno.copyWith(
              fontSize: compacto ? 12 : 13.5,
              color: ColoresApp.tinta,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// HU16: el vendedor elige el plan de inspección y si la quiere Express.
class SelectorPlan extends StatelessWidget {
  const SelectorPlan({
    super.key,
    required this.plan,
    required this.express,
    required this.precio,
    required this.alCambiarPlan,
    required this.alCambiarExpress,
    this.habilitado = true,
  });

  final PlanInspeccion plan;
  final bool express;

  /// Precio que escribió el vendedor (null si todavía no es válido).
  final double? precio;
  final ValueChanged<PlanInspeccion> alCambiarPlan;
  final ValueChanged<bool> alCambiarExpress;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final ancha = MediaQuery.sizeOf(context).width >= 640;
    final tarjetas = [
      for (final opcion in PlanInspeccion.values)
        _TarjetaPlan(
          plan: opcion,
          elegido: opcion == plan,
          precio: precio,
          alTocar: habilitado ? () => alCambiarPlan(opcion) : null,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ancha)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tarjetas[0]),
                const SizedBox(width: 12),
                Expanded(child: tarjetas[1]),
              ],
            ),
          )
        else ...[
          tarjetas[0],
          const SizedBox(height: 12),
          tarjetas[1],
        ],
        const SizedBox(height: 8),
        Tooltip(
          message: 'El Hub revisa tu equipo en menos de 24 h (+\$${ReglasPlan.precioExpress.toStringAsFixed(0)})',
          child: SwitchListTile(
            value: express,
            onChanged: habilitado ? alCambiarExpress : null,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.bolt_outlined, color: ColoresApp.tinta),
            title: Text(
              'Inspección Express (+${formatearDolares(ReglasPlan.precioExpress)})',
              style: Tipos.cuerpo.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'El Hub la revisa en ${ReglasPlan.tiempoExpress} después de '
              'recibirla, en vez de ${plan.tiempo}.',
              style: Tipos.pequeno,
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaPlan extends StatefulWidget {
  const _TarjetaPlan({
    required this.plan,
    required this.elegido,
    required this.precio,
    required this.alTocar,
  });

  final PlanInspeccion plan;
  final bool elegido;
  final double? precio;
  final VoidCallback? alTocar;

  @override
  State<_TarjetaPlan> createState() => _TarjetaPlanState();
}

class _TarjetaPlanState extends State<_TarjetaPlan> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final costo = widget.precio == null ? null : widget.plan.costo(widget.precio!);
    final activo = widget.alTocar != null;
    final resaltado = widget.elegido || (_hover && activo);

    return Semantics(
      button: true,
      selected: widget.elegido,
      label: 'Inspección ${widget.plan.nombre}',
      child: MouseRegion(
        cursor: activo ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.elegido
                ? ColoresApp.lila
                : _hover && activo
                    ? const Color(0xFFF8F4FC)
                    : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.elegido
                  ? ColoresApp.orquidea
                  : _hover && activo
                      ? ColoresApp.orquidea.withAlpha(140)
                      : const Color(0xFFC9CCD8),
              width: widget.elegido ? 2 : 1,
            ),
            boxShadow: resaltado
                ? [
                    BoxShadow(
                      color: ColoresApp.orquidea.withAlpha(40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: InkWell(
            onTap: widget.alTocar,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fila: radio + nombre del plan ─────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        widget.elegido
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: widget.elegido
                            ? ColoresApp.orquidea
                            : ColoresApp.pizarra,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.plan.nombre,
                          style: Tipos.subtitulo.copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  // ── Precio (fila separada para evitar desborde) ────────
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 28),
                    child: Text(
                      costo != null
                          ? '${formatearDolares(costo)}  •  ${widget.plan.tarifa}'
                          : widget.plan.tarifa,
                      style: Tipos.cuerpo.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final linea in widget.plan.incluye)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check, size: 16, color: ColoresApp.verde),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              linea,
                              style: Tipos.pequeno.copyWith(fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Tarda ${widget.plan.tiempo}.',
                    style: Tipos.pequeno.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// HU17: cuánto recibiría el vendedor si el equipo se aprueba.
class ResumenCobro extends StatelessWidget {
  const ResumenCobro({
    super.key,
    required this.precio,
    required this.plan,
    required this.express,
    this.tasaComision = ReglasPlan.tasaComision,
  });

  final double precio;
  final PlanInspeccion plan;
  final bool express;

  /// HU20: 5 %, o 4 % si el vendedor es Confiable o Destacado.
  final double tasaComision;

  @override
  Widget build(BuildContext context) {
    final inspeccion = plan.costo(precio, express: express);
    final comision = (precio * tasaComision * 100).round() / 100;
    final recibirias = precio - comision - inspeccion;

    Widget linea(String texto, String monto, {bool fuerte = false}) {
      final estilo = Tipos.cuerpo.copyWith(
        fontWeight: fuerte ? FontWeight.w700 : FontWeight.w400,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(texto, style: estilo)),
            Text(monto, style: estilo),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.nube,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Si se vende y se aprueba', style: Tipos.subtitulo.copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          linea('Precio de venta', formatearDolares(precio)),
          linea(
            'Inspección ${plan.nombre}${express ? ' Express' : ''} (la pagas al entregar)',
            '- ${formatearDolares(inspeccion)}',
          ),
          linea(
            'Comisión de ReUso Seguro (${(tasaComision * 100).round()} %)',
            '- ${formatearDolares(comision)}',
          ),
          const Divider(),
          linea('Recibirías', formatearDolares(recibirias), fuerte: true),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: ColoresApp.tinta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La inspección se paga cuando avisas que entregaste el equipo '
                  'en el Hub. No se devuelve si el equipo se rechaza: el '
                  'inspector igual hizo el trabajo. Si se rechaza tampoco se '
                  'cobra comisión.',
                  style: Tipos.pequeno.copyWith(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// HU19: el vendedor califica del 1 al 4 cada punto del checklist de su
/// tipo de equipo. El Hub lo compara después con lo que encuentre.
class AutoevaluacionVendedor extends StatelessWidget {
  const AutoevaluacionVendedor({
    super.key,
    required this.categoria,
    required this.notas,
    required this.sinParte,
    required this.alCalificar,
    required this.alMarcarSinParte,
    this.error,
    this.habilitado = true,
  });

  final String categoria;
  final Map<String, int> notas;

  /// Puntos opcionales que el vendedor marcó como «Mi equipo no tiene».
  final Set<String> sinParte;
  final void Function(String clave, Calificacion nota) alCalificar;
  final ValueChanged<String> alMarcarSinParte;
  final String? error;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Califica con honestidad cómo está cada parte. El inspector usa la '
          'misma escala: si en 2 o más puntos lo que encuentra está 2 notas o '
          'más por debajo de lo que dijiste, el comprador lo verá en el '
          'certificado.',
          style: Tipos.pequeno.copyWith(fontSize: 13.5),
        ),
        const SizedBox(height: 12),
        for (final punto in PuntoChecklist.para(categoria)) ...[
          Text(punto.nombre, style: Tipos.cuerpo.copyWith(fontWeight: FontWeight.w600)),
          Text(punto.queRevisar, style: Tipos.pequeno.copyWith(fontSize: 12.5)),
          const SizedBox(height: 6),
          SelectorCalificacion(
            valor: Calificacion.desde(notas[punto.clave]),
            noAplica: sinParte.contains(punto.clave),
            permiteNoAplica: punto.opcional,
            textoNoAplica: 'Mi equipo no tiene',
            alElegir: (nota) => alCalificar(punto.clave, nota),
            alElegirNoAplica: () => alMarcarSinParte(punto.clave),
            habilitado: habilitado,
          ),
          const SizedBox(height: 14),
        ],
        if (error != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, size: 18, color: _rojo),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  error!,
                  style: Tipos.pequeno.copyWith(fontSize: 13, color: _rojo),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// HU19: aviso de que lo declarado no coincidió con lo inspeccionado.
class AvisoDeclaracionInexacta extends StatelessWidget {
  const AvisoDeclaracionInexacta({super.key, required this.puntos});

  /// Nombres de los puntos que no coincidieron.
  final List<String> puntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ambar),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_problem_outlined, color: _ambar),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Declaración inexacta',
                  style: Tipos.subtitulo.copyWith(fontSize: 15, color: _ambar),
                ),
                const SizedBox(height: 4),
                Text(
                  'El vendedor calificó mejor de lo que encontró el inspector '
                  'en: ${puntos.join(', ')}. Revisa la comparación punto por '
                  'punto.',
                  style: Tipos.pequeno.copyWith(fontSize: 13.5, color: ColoresApp.tinta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// HU16, escenario 5: el vendedor cambia el plan de un equipo que todavía
/// no se ha vendido. Responde el plan y si quiere Express, o null.
Future<(PlanInspeccion, bool)?> elegirPlan(
  BuildContext context, {
  required PlanInspeccion plan,
  required bool express,
  required double precio,
  double tasaComision = ReglasPlan.tasaComision,
}) {
  return showDialog<(PlanInspeccion, bool)>(
    context: context,
    builder: (_) => _DialogoPlan(
      plan: plan,
      express: express,
      precio: precio,
      tasaComision: tasaComision,
    ),
  );
}

class _DialogoPlan extends StatefulWidget {
  const _DialogoPlan({
    required this.plan,
    required this.express,
    required this.precio,
    required this.tasaComision,
  });

  final PlanInspeccion plan;
  final bool express;
  final double precio;
  final double tasaComision;

  @override
  State<_DialogoPlan> createState() => _DialogoPlanState();
}

class _DialogoPlanState extends State<_DialogoPlan> {
  late PlanInspeccion _plan = widget.plan;
  late bool _express = widget.express;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Plan de inspección'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorPlan(
                plan: _plan,
                express: _express,
                precio: widget.precio,
                alCambiarPlan: (plan) => setState(() => _plan = plan),
                alCambiarExpress: (valor) => setState(() => _express = valor),
              ),
              const SizedBox(height: 12),
              ResumenCobro(
                precio: widget.precio,
                plan: _plan,
                express: _express,
                tasaComision: widget.tasaComision,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_plan, _express)),
          style: FilledButton.styleFrom(backgroundColor: ColoresApp.tinta),
          child: const Text('Guardar plan'),
        ),
      ],
    );
  }
}
