// Pruebas de widget de la HU09: el panel de la bóveda cuadrado, con
// descuadre y vacío.
//
// Ejecutar con:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/boveda.dart';
import 'package:reuso_seguro/screens/boveda_screen.dart';

import '../boveda_datos.dart';

Future<void> _mostrar(WidgetTester tester, Map<String, dynamic> json,
    {VoidCallback? alRevisar}) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PanelBoveda(
            estado: EstadoBoveda.desdeJson(json),
            alRevisar: alRevisar ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('W-09.1 Bóveda cuadrada: verde, con ícono y hora', (tester) async {
    var revisada = false;
    await _mostrar(tester, bovedaCuadrada(), alRevisar: () => revisada = true);
    expect(find.text('Bóveda cuadrada'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user), findsOneWidget);
    expect(find.textContaining('Última revisión'), findsOneWidget);
    // Los 4 totales grandes.
    expect(find.text('En custodia'), findsOneWidget);
    expect(find.text('Comisiones'), findsOneWidget);
    expect(find.text('\$70,00'), findsOneWidget);
    // HU06 escenario 3: la liberación pendiente con su motivo.
    expect(find.textContaining('Falta tu cuenta para cobrar'), findsOneWidget);
    await tester.tap(find.text('Revisar ahora'));
    expect(revisada, isTrue);
  });

  testWidgets('W-09.2 Con descuadre: alerta roja con el pedido y la diferencia',
      (tester) async {
    await _mostrar(tester, bovedaConDescuadre());
    expect(find.text('Descuadre en la bóveda'), findsOneWidget);
    expect(find.byIcon(Icons.gpp_bad), findsOneWidget);
    expect(find.textContaining('P-1003'), findsOneWidget);
    expect(find.text('Diferencia: - \$276,00'), findsOneWidget);
    expect(find.textContaining('Qué hacer'), findsOneWidget);
  });

  testWidgets('W-09.3 Vacía: lo explica', (tester) async {
    await _mostrar(tester, bovedaVacia());
    expect(find.textContaining('Todavía no hay dinero en la bóveda'), findsOneWidget);
    expect(find.text('No hay liberaciones pendientes.'), findsOneWidget);
    expect(find.text('Ningún descuadre registrado.'), findsOneWidget);
  });
}
