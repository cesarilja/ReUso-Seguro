// Pruebas de widget de la HU02: la línea de tiempo del pedido.
//
// Ejecutar con:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/widgets/pedido_widgets.dart';

import '../datos_de_prueba.dart';

Future<void> _mostrar(WidgetTester tester, Pedido pedido) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                LineaDeTiempo(pedido: pedido),
                DondeEstaTuDinero(pedido: pedido),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('W-02.1 Recién pagado: fase 1 actual, sin fases terminadas',
      (tester) async {
    await _mostrar(tester, pedidoDePrueba(EstadoPedido.pagoEnCustodia));
    expect(find.text('Pago en custodia (ahora)'), findsOneWidget);
    expect(find.text('04/11/2026, 10:30'), findsNothing); // fecha futura oculta
    expect(find.textContaining('en custodia'), findsWidgets);
  });

  testWidgets('W-02.2 En diagnóstico: 2 fases terminadas con su fecha',
      (tester) async {
    await _mostrar(tester, pedidoDePrueba(EstadoPedido.enDiagnostico));
    expect(find.text('En diagnóstico (ahora)'), findsOneWidget);
    expect(find.text('03/11/2026, 09:00'), findsOneWidget);
    expect(find.text('04/11/2026, 10:30'), findsOneWidget);
  });

  testWidgets('W-02.3 Pago liberado: las 5 fases alcanzadas', (tester) async {
    await _mostrar(
      tester,
      pedidoDePrueba(EstadoPedido.pagoLiberado, dictamen: dictamenDePrueba()),
    );
    expect(find.text('Pago liberado al vendedor (ahora)'), findsOneWidget);
    expect(find.text('Dictamen: Aprobado'), findsOneWidget);
    expect(find.textContaining('liberó al vendedor'), findsOneWidget);
  });
}
