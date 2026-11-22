// Pruebas de widget del Sprint 4: escala del 1 al 4 (HU15), resumen de
// cobro del vendedor (HU16 y HU17) y aviso de declaración inexacta (HU19).
//
// Ejecutar con:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/escala.dart';
import 'package:reuso_seguro/models/plan_inspeccion.dart';
import 'package:reuso_seguro/widgets/plan_widgets.dart';

Future<void> _mostrar(WidgetTester tester, Widget hijo) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo))),
  );
}

void main() {
  testWidgets('W-15.1 Las 4 notas se ven con número y nombre, y se eligen',
      (tester) async {
    Calificacion? elegida;
    await _mostrar(
      tester,
      SelectorCalificacion(valor: null, alElegir: (nota) => elegida = nota),
    );
    for (final nota in Calificacion.values) {
      expect(find.text('${nota.valor} ${nota.nombre}'), findsOneWidget);
    }
    // Sin «No aplica» si el punto no es opcional.
    expect(find.text('No aplica'), findsNothing);

    await tester.tap(find.text('3 Bueno'));
    expect(elegida, Calificacion.bueno);
  });

  testWidgets('W-15.2 «No aplica» solo en los puntos opcionales', (tester) async {
    var noAplica = false;
    await _mostrar(
      tester,
      SelectorCalificacion(
        valor: null,
        alElegir: (_) {},
        permiteNoAplica: true,
        alElegirNoAplica: () => noAplica = true,
      ),
    );
    await tester.tap(find.text('No aplica'));
    expect(noAplica, isTrue);
  });

  testWidgets('W-17.1 El vendedor ve cuánto recibiría con la comisión del 5 %',
      (tester) async {
    await _mostrar(
      tester,
      const ResumenCobro(precio: 250, plan: PlanInspeccion.basica, express: false),
    );
    expect(find.text('- \$10,00'), findsOneWidget); // inspección básica
    expect(find.text('- \$12,50'), findsOneWidget); // comisión del 5 %
    expect(find.text('\$227,50'), findsOneWidget);
    expect(find.textContaining('No se devuelve si el equipo se rechaza'), findsOneWidget);
  });

  testWidgets('W-19.1 El aviso de declaración inexacta nombra los puntos',
      (tester) async {
    await _mostrar(
      tester,
      const AvisoDeclaracionInexacta(puntos: ['Batería', 'Pantalla']),
    );
    expect(find.text('Declaración inexacta'), findsOneWidget);
    expect(find.textContaining('Batería, Pantalla'), findsOneWidget);
  });
}
