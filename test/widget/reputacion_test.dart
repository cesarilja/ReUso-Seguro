// Pruebas de widget de la HU20 (reputación del vendedor).
//
// Ejecutar con:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/reputacion.dart';
import 'package:reuso_seguro/widgets/reputacion_widgets.dart';

Future<void> _mostrar(WidgetTester tester, Widget hijo) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo))),
  );
}

void main() {
  testWidgets('W-20.1 El sello lleva ícono y texto', (tester) async {
    await _mostrar(tester, const SelloVendedor(nivel: NivelVendedor.confiable));
    expect(find.text('Confiable'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
  });

  testWidgets('W-20.2 Vendedor nuevo: sin porcentajes que confundan', (tester) async {
    await _mostrar(
      tester,
      const ResumenReputacion(
        reputacion: Reputacion(vendedorId: 'v1', ventas: 1, aprobadas: 1),
      ),
    );
    expect(find.text('Vendedor nuevo'), findsOneWidget);
    expect(find.textContaining('Lleva 1 venta inspeccionada'), findsOneWidget);
    expect(find.textContaining('aprobados'), findsNothing);
  });

  testWidgets('W-20.3 El vendedor ve su comisión y qué le falta', (tester) async {
    await _mostrar(
      tester,
      const ResumenReputacion(
        reputacion: Reputacion(
          vendedorId: 'v1',
          ventas: 4,
          aprobadas: 4,
          inexactasRecientes: 1,
          nivel: NivelVendedor.vendedor,
        ),
        paraVendedor: true,
      ),
    );
    expect(find.text('Tu reputación'), findsOneWidget);
    expect(find.textContaining('4 de 4 equipos aprobados'), findsOneWidget);
    expect(find.textContaining('Tu comisión por venta: 5 %'), findsOneWidget);
    expect(find.textContaining('Para ser Confiable'), findsOneWidget);
  });
}
