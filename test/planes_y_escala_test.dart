// Pruebas unitarias del Sprint 4: HU15 (escala del 1 al 4), HU16 (planes
// de inspección), HU17 (cobro al vendedor y comisión del 5 %), HU18 (plazo
// de reclamo) y HU19 (autoevaluación del vendedor).
//
// Las mismas reglas se prueban en el servidor con
// supabase/pruebas/15_verificar_planes_y_escala.sql.
//
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/boveda.dart';
import 'package:reuso_seguro/models/dictamen.dart';
import 'package:reuso_seguro/models/equipo.dart';
import 'package:reuso_seguro/models/escala.dart';
import 'package:reuso_seguro/models/inspeccion.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/models/plan_inspeccion.dart';
import 'package:reuso_seguro/models/reclamo.dart';
import 'package:reuso_seguro/services/filtro_catalogo.dart';
import 'package:reuso_seguro/services/inspeccion_service.dart';
import 'package:reuso_seguro/services/publicacion_service.dart';

/// Una fila de `equipos` como la devuelve Supabase.
Map<String, dynamic> _filaEquipo([Map<String, dynamic> cambios = const {}]) => {
      'id': 'equipo-1',
      'titulo': 'Laptop Lenovo ThinkPad T480',
      'descripcion': 'Core i5, 8 GB de RAM y SSD de 256 GB, con cargador.',
      'estado_declarado': 'Usado, en buen estado. Marcas leves en la tapa.',
      'precio': 250,
      'vendedor_nombre': 'Ana Pérez',
      'categoria': 'Laptop',
      ...cambios,
    };

Equipo _equipo([Map<String, dynamic> cambios = const {}]) =>
    Equipo.desdeFila(_filaEquipo(cambios), (ruta) => ruta);

Pedido _pedido(Equipo equipo, [Map<String, dynamic> cambios = const {}]) =>
    Pedido.desdeFila({
      'id': 'pedido-1',
      'numero': 1001,
      'comprador_id': 'comprador-1',
      'monto': 250,
      'creado_en': '2026-11-18T14:00:00Z',
      'estado': 'pago_en_custodia',
      'pagado_en': '2026-11-18T14:05:00Z',
      ...cambios,
    }, equipo);

void main() {
  group('HU15 · Escala del 1 al 4', () {
    test('CP-15.1 Cada nota tiene número, nombre y si es falla', () {
      expect(Calificacion.values.map((c) => c.valor), [1, 2, 3, 4]);
      expect(Calificacion.excelente.nombre, 'Excelente');
      expect(Calificacion.malo.esFalla, isTrue);
      expect(Calificacion.regular.esFalla, isTrue);
      expect(Calificacion.bueno.esFalla, isFalse);
      expect(Calificacion.excelente.esFalla, isFalse);
      expect(Calificacion.bueno.etiqueta, '3 de 4 (Bueno)');
      expect(Calificacion.desde('4'), Calificacion.excelente);
      expect(Calificacion.desde(2), Calificacion.regular);
      expect(Calificacion.desde(5), isNull);
      expect(Calificacion.desde(null), isNull);
    });

    test('CP-15.2 El puntaje es el promedio, sin contar «No aplica»', () {
      expect(
        ReglasEscala.puntaje([
          Calificacion.excelente,
          Calificacion.bueno,
          null, // No aplica
          Calificacion.bueno,
        ]),
        3.33,
      );
      expect(ReglasEscala.puntaje(const []), isNull);
      expect(ReglasEscala.textoPuntaje(3.76), '3,8 de 4');
    });

    test('CP-15.3 Sugiere rechazar con un 1 o con promedio menor que 2,5', () {
      expect(
        ReglasEscala.sugerirRechazo([Calificacion.excelente, Calificacion.malo]),
        isTrue,
      );
      expect(
        ReglasEscala.sugerirRechazo([Calificacion.regular, Calificacion.bueno]),
        isFalse, // promedio 2,5
      );
      expect(
        ReglasEscala.sugerirRechazo([Calificacion.regular, Calificacion.regular]),
        isTrue,
      );
    });

    test('CP-15.4 El resultado sale de la nota', () {
      final borrador = BorradorPunto();
      expect(borrador.resultado, isNull);
      borrador.calificar(Calificacion.bueno);
      expect(borrador.resultado, ResultadoPunto.ok);
      borrador.calificar(Calificacion.regular);
      expect(borrador.resultado, ResultadoPunto.falla);
      borrador.marcarNoAplica();
      expect(borrador.resultado, ResultadoPunto.noAplica);
      expect(borrador.calificacion, isNull);
    });

    test('CP-15.5 Una nota de 1 o 2 pide descripción y foto', () {
      final borrador = BorradorPunto(calificacion: Calificacion.malo);
      expect(ReglasInspeccion.punto(borrador), contains('Describe la falla'));
      borrador.nota = 'La pantalla tiene una grieta en la esquina.';
      expect(ReglasInspeccion.punto(borrador), contains('foto'));
      expect(
        ReglasInspeccion.punto(BorradorPunto()),
        'Califica este punto del 1 al 4.',
      );
      expect(
        ReglasInspeccion.punto(BorradorPunto(calificacion: Calificacion.bueno)),
        isNull,
      );
    });

    test('CP-15.6 Se guarda la nota y se lee el puntaje', () {
      const revision = RevisionPunto(
        resultado: ResultadoPunto.ok,
        calificacion: Calificacion.excelente,
      );
      expect(revision.aJson(), {'resultado': 'ok', 'calificacion': 4});
      expect(revision.textoCorto, '4 de 4 (Excelente)');

      final leida = RevisionPunto.desdeJson({
        'resultado': 'falla',
        'calificacion': 2,
        'nota': 'Batería de 20 minutos.',
        'evidencias': ['p/1.jpg'],
      });
      expect(leida.calificacion, Calificacion.regular);
      expect(leida.tieneFalla, isTrue);

      final inspeccion = Inspeccion.desdeFila({
        'pedido_id': 'pedido-1',
        'puntos': {
          'encendido': {'resultado': 'ok', 'calificacion': 4},
          'bateria': {'resultado': 'falla', 'calificacion': 2, 'nota': 'x' * 12},
        },
        'completa': true,
        'actualizado_en': '2026-11-18T15:00:00Z',
        'puntaje': 3,
      });
      expect(inspeccion.puntaje, 3);
      expect(inspeccion.calificaciones, {'encendido': 4, 'bateria': 2});
      expect(inspeccion.sugerirRechazo, isFalse);
    });
  });

  group('HU16 · Planes de inspección', () {
    test('CP-16.1 Básica: 4 % con mínimo de \$5 y máximo de \$30', () {
      expect(PlanInspeccion.basica.costo(250), 10);
      expect(PlanInspeccion.basica.costo(50), 5);
      expect(PlanInspeccion.basica.costo(1000), 30);
    });

    test('CP-16.2 Detallada: 8 % con mínimo de \$10 y máximo de \$60', () {
      expect(PlanInspeccion.detallada.costo(250), 20);
      expect(PlanInspeccion.detallada.costo(80), 10);
      expect(PlanInspeccion.detallada.costo(1000), 60);
    });

    test('CP-16.3 La Express suma \$8', () {
      expect(PlanInspeccion.basica.costo(250, express: true), 18);
      expect(PlanInspeccion.detallada.costo(1000, express: true), 68);
    });

    test('CP-16.4 La Detallada pide una observación en cada punto', () {
      final borrador = BorradorPunto(calificacion: Calificacion.excelente);
      expect(ReglasInspeccion.punto(borrador), isNull);
      expect(
        ReglasInspeccion.punto(borrador, plan: PlanInspeccion.detallada),
        contains('observación'),
      );
      borrador.nota = 'Pantalla sin píxeles muertos.';
      expect(ReglasInspeccion.punto(borrador, plan: PlanInspeccion.detallada), isNull);
      // «No aplica» no necesita observación.
      expect(
        ReglasInspeccion.punto(
          BorradorPunto(noAplica: true),
          plan: PlanInspeccion.detallada,
        ),
        isNull,
      );
    });

    test('CP-16.5 El equipo lee su plan y el filtro encuentra los detallados', () {
      final basico = _equipo();
      final detallado = _equipo({
        'id': 'equipo-2',
        'plan_inspeccion': 'detallada',
        'express': true,
        'puntaje_inspeccion': 3.75,
      });
      expect(basico.plan, PlanInspeccion.basica);
      expect(detallado.inspeccionDetallada, isTrue);
      expect(detallado.express, isTrue);
      expect(detallado.puntajeInspeccion, 3.75);

      const filtro = FiltroCatalogo(soloDetallada: true);
      expect(filtro.activo, isTrue);
      expect(filtro.aplicar([basico, detallado]), [detallado]);
      expect(filtro.copiar(soloDetallada: false).activo, isFalse);
    });
  });

  group('HU17 · El vendedor paga la inspección', () {
    test('CP-17.1 La comisión bajó al 5 %', () {
      expect(ReglasPlan.tasaComision, 0.05);
      expect(Pedido.tasaComision, 0.05);
      expect(ReglasPlan.comision(250), 12.5);
    });

    test('CP-17.2 Un pedido nuevo debe pagar la inspección antes de entregar', () {
      final pedido = _pedido(
        _equipo({'plan_inspeccion': 'detallada'}),
        {'inspeccion_requerida': true},
      );
      expect(pedido.inspeccionPendiente, isTrue);
      expect(pedido.costoInspeccion, 20);
      expect(pedido.debeEntregar, isTrue);
    });

    test('CP-17.3 Ya pagada, queda con el monto que cobró el servidor', () {
      final pedido = _pedido(_equipo(), {
        'inspeccion_requerida': true,
        'inspeccion_plan': 'basica',
        'inspeccion_express': true,
        'inspeccion_monto': 18,
        'inspeccion_pagada_en': '2026-11-18T16:00:00Z',
        'entregado_en': '2026-11-18T16:00:00Z',
      });
      expect(pedido.inspeccionPendiente, isFalse);
      expect(pedido.inspeccionPagada, isTrue);
      expect(pedido.conExpress, isTrue);
      expect(pedido.costoInspeccion, 18);
      expect(pedido.esperandoAlHub, isTrue);
    });

    test('CP-17.4 Los pedidos de antes del Sprint 4 no pagan inspección', () {
      final viejo = _pedido(_equipo());
      expect(viejo.inspeccionRequerida, isFalse);
      expect(viejo.inspeccionPendiente, isFalse);
      expect(viejo.costoInspeccion, 0);
    });

    test('CP-17.5 Si el equipo se rechaza no hay comisión', () {
      final rechazado = _pedido(_equipo(), {
        'estado': 'rechazado',
        'inspeccion_requerida': true,
        'inspeccion_monto': 10,
        'inspeccion_pagada_en': '2026-11-18T16:00:00Z',
      });
      expect(rechazado.comisionEstimada, 0);
      expect(rechazado.recibeVendedor, 0);
      // La inspección no se devuelve.
      expect(rechazado.costoInspeccion, 10);
    });

    test('CP-17.6 La bóveda muestra lo cobrado por inspecciones aparte', () {
      final estado = EstadoBoveda.desdeJson({
        'revisado_en': '2026-11-18T19:30:00Z',
        'cuadrada': true,
        'totales': {
          'en_custodia': 100,
          'liberado': 0,
          'reembolsado': 0,
          'comisiones': 0,
          'inspecciones': 28,
        },
        'declaraciones_inexactas': [
          {'vendedor': 'Ana Pérez', 'cuantas': 2, 'ultima': '2026-11-18T18:00:00Z'},
        ],
      });
      expect(estado.totales.inspecciones, 28);
      // Fuera de la custodia: no cuenta en lo que pagaron los compradores.
      expect(estado.totales.totalIngresado, 100);
      expect(estado.declaracionesInexactas.single.vendedor, 'Ana Pérez');
      expect(estado.declaracionesInexactas.single.cuantas, 2);
    });
  });

  group('HU18 · Plazo para reclamar', () {
    test('CP-18.1 Con la Básica son 3 días y con la Detallada 7', () {
      final recibido = {'recibido_comprador_en': '2026-11-18T10:00:00Z'};
      final basico = _pedido(_equipo(), {'estado': 'pago_liberado', ...recibido});
      final detallado = _pedido(
        _equipo({'plan_inspeccion': 'detallada'}),
        {'estado': 'pago_liberado', ...recibido},
      );
      expect(ReglasReclamo.plazoDe(basico), 3);
      expect(ReglasReclamo.plazoDe(detallado), 7);
      expect(
        ReglasReclamo.venceEn(detallado)!.difference(detallado.recibidoCompradorEn!),
        const Duration(days: 7),
      );
      // A los 5 días ya no puede reclamar con la Básica, pero sí con la
      // Detallada.
      final cincoDias = detallado.recibidoCompradorEn!.add(const Duration(days: 5));
      expect(ReglasReclamo.situacion(basico, cincoDias), SituacionReclamo.fueraDePlazo);
      expect(ReglasReclamo.situacion(detallado, cincoDias), SituacionReclamo.enPlazo);
    });

    test('CP-18.2 Vale el plan con el que se pagó la inspección', () {
      final pedido = _pedido(_equipo(), {'inspeccion_plan': 'detallada'});
      expect(pedido.diasParaReclamar, 7);
    });
  });

  group('HU19 · Autoevaluación del vendedor', () {
    test('CP-19.1 Todos los puntos no opcionales llevan nota del 1 al 4', () {
      final completa = {
        for (final p in PuntoChecklist.para('Teléfono'))
          if (!p.opcional) p.clave: 3,
      };
      expect(ReglasPublicacion.autoevaluacion('Teléfono', completa), isNull);

      final sinBateria = Map.of(completa)..remove('bateria');
      expect(
        ReglasPublicacion.autoevaluacion('Teléfono', sinBateria),
        contains('Batería'),
      );
      expect(
        ReglasPublicacion.autoevaluacion('Teléfono', {...completa, 'camaras': 5}),
        isNotNull,
      );
      expect(ReglasPublicacion.autoevaluacion(null, completa), isNotNull);
    });

    test('CP-19.2 Al cambiar de tipo se descartan los puntos que no van', () {
      final limpia = ReglasPublicacion.autoevaluacionLimpia(
        'Audio',
        {'encendido': 4, 'teclado': 3, 'microfono': 2},
      );
      expect(limpia, {'encendido': 4, 'microfono': 2});
    });

    test('CP-19.3 Es inexacta con 2 o más puntos 2 notas por encima', () {
      const declarado = {'pantalla': 4, 'bateria': 4, 'teclado': 3};
      expect(
        ReglasEscala.puntosInexactos(declarado, {'pantalla': 2, 'bateria': 1, 'teclado': 2}),
        ['bateria', 'pantalla'],
      );
      expect(
        ReglasEscala.esInexacta(declarado, {'pantalla': 2, 'bateria': 1, 'teclado': 2}),
        isTrue,
      );
      // Un solo punto no alcanza.
      expect(
        ReglasEscala.esInexacta(declarado, {'pantalla': 2, 'bateria': 3, 'teclado': 3}),
        isFalse,
      );
      // Si el inspector encontró algo mejor, no es inexacta.
      expect(
        ReglasEscala.esInexacta({'pantalla': 2, 'bateria': 1}, {'pantalla': 4, 'bateria': 4}),
        isFalse,
      );
    });

    test('CP-19.4 El equipo y el dictamen guardan la comparación', () {
      final equipo = _equipo({
        'autoevaluacion': {'encendido': 4, 'pantalla': 4},
      });
      expect(equipo.autoevaluacion, {'encendido': 4, 'pantalla': 4});

      final dictamen = Dictamen.desdeFila({
        'pedido_id': 'pedido-1',
        'resultado': 'aprobado',
        'motivo': '',
        'creado_en': '2026-11-18T17:00:00Z',
        'declaracion_inexacta': true,
        'puntos_inexactos': ['bateria', 'pantalla'],
      });
      expect(dictamen.declaracionInexacta, isTrue);
      expect(dictamen.puntosInexactos, ['bateria', 'pantalla']);
    });
  });
}
