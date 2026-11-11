// Pruebas de widget de la HU04 y la HU06 (pantallas del vendedor).
//
// Ejecutar con:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/models/venta.dart';
import 'package:reuso_seguro/widgets/insignia.dart';
import 'package:reuso_seguro/widgets/venta_widgets.dart';

import '../datos_de_prueba.dart';

Future<void> _mostrar(WidgetTester tester, Widget hijo) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo))),
  );
}

void main() {
  testWidgets('W-04.1 La insignia no aparece con 0 ventas nuevas', (tester) async {
    await _mostrar(tester, const InsigniaContador(cantidad: 0));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('W-04.2 La insignia muestra 3 ventas nuevas', (tester) async {
    final semantica = tester.ensureSemantics();
    await _mostrar(tester, const InsigniaContador(cantidad: 3));
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('3 nuevas'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('W-04.3 Instrucciones de entrega con el código del pedido',
      (tester) async {
    var entregado = false;
    await _mostrar(
      tester,
      InstruccionesEntrega(
        venta: pedidoDePrueba(EstadoPedido.pagoEnCustodia),
        alEntregar: () => entregado = true,
      ),
    );
    expect(find.text('P-1001'), findsOneWidget);
    expect(find.text(DatosDelHub.horario), findsOneWidget);
    await tester.tap(find.text('Ya entregué el equipo'));
    expect(entregado, isTrue);
  });

  testWidgets('W-06.1 La liberación pendiente explica el motivo', (tester) async {
    final venta = Pedido.desdeFila({
      'id': 'pedido-1',
      'numero': 1001,
      'comprador_id': 'comprador-1',
      'monto': 250,
      'creado_en': '2026-11-10T14:00:00Z',
      'estado': 'liberacion_pendiente',
      'liberacion_motivo': 'SIN_CUENTA',
      'liberacion_intentos': 1,
    }, laptopDePrueba);
    await _mostrar(
      tester,
      AvisoLiberacionPendiente(
        venta: venta,
        alReintentar: () {},
        alRegistrarCuenta: () {},
      ),
    );
    expect(find.textContaining('Falta tu cuenta para cobrar'), findsOneWidget);
    expect(find.textContaining('sigue seguro en custodia'), findsOneWidget);
    expect(find.text('Registrar mi cuenta para cobrar'), findsOneWidget);
    expect(find.text('Reintentar el cobro'), findsOneWidget);
  });

  testWidgets('W-06.2 Sin cuenta de cobro se pide registrarla', (tester) async {
    await _mostrar(tester, TarjetaCuentaCobro(cuenta: null, alEditar: () {}));
    expect(find.text('Registra dónde quieres cobrar'), findsOneWidget);
    expect(find.text('Registrar'), findsOneWidget);
  });
}
