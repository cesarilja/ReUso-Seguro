// Pruebas de widget de la HU05 (plazo para reclamar) y la HU10 (monitor e
// indicador de conexión).
//
// Ejecutar con:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/aviso.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/screens/monitor_avisos_screen.dart';
import 'package:reuso_seguro/widgets/indicador_conexion.dart';
import 'package:reuso_seguro/widgets/reclamo_widgets.dart';

import '../datos_de_prueba.dart';

Future<void> _mostrar(WidgetTester tester, Widget hijo) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo))),
  );
}

Pedido _liberado({String? recibido}) => Pedido.desdeFila({
      'id': 'pedido-1',
      'numero': 1001,
      'comprador_id': 'comprador-1',
      'monto': 250,
      'creado_en': '2026-11-10T14:00:00Z',
      'estado': 'pago_liberado',
      'recibido_comprador_en': recibido,
    }, laptopDePrueba);

void main() {
  group('HU05 · Plazo para reclamar', () {
    testWidgets('W-05.1 Sin confirmar: pide confirmar que lo recibió', (tester) async {
      var confirmo = false;
      await _mostrar(
        tester,
        PlazoReclamo(
          pedido: _liberado(),
          alConfirmarRecibido: () => confirmo = true,
          alReclamar: () {},
        ),
      );
      await tester.tap(find.text('Ya recibí mi equipo'));
      expect(confirmo, isTrue);
    });

    testWidgets('W-05.2 Dentro del plazo: puede reclamar', (tester) async {
      await _mostrar(
        tester,
        PlazoReclamo(
          pedido: _liberado(recibido: '2026-11-10T13:00:00Z'),
          ahora: DateTime.parse('2026-11-11T13:00:00Z').toLocal(),
          alConfirmarRecibido: () {},
          alReclamar: () {},
        ),
      );
      expect(find.text('Tengo un problema con el equipo'), findsOneWidget);
      expect(find.textContaining('puedes reclamar hasta el'), findsOneWidget);
    });

    testWidgets('W-05.3 Fuera del plazo: lo explica y no deja reclamar', (tester) async {
      await _mostrar(
        tester,
        PlazoReclamo(
          pedido: _liberado(recibido: '2026-11-01T13:00:00Z'),
          ahora: DateTime.parse('2026-11-11T13:00:00Z').toLocal(),
          alConfirmarRecibido: () {},
          alReclamar: () {},
        ),
      );
      expect(find.textContaining('terminó'), findsOneWidget);
      expect(find.text('Tengo un problema con el equipo'), findsNothing);
    });
  });

  group('HU10 · Monitor de avisos', () {
    testWidgets('W-10.1 Vacío', (tester) async {
      await _mostrar(tester, const ListaMonitor(avisos: []));
      expect(find.textContaining('Todavía no hay avisos'), findsOneWidget);
    });

    testWidgets('W-10.2 Muestra quién vio cada aviso', (tester) async {
      final aviso = Aviso(
        id: 1,
        pedidoId: 'pedido-1',
        estado: EstadoPedido.enDiagnostico,
        mensajeComprador: 'Tu equipo pasó a: En diagnóstico.',
        mensajeVendedor: 'El inspector está revisando tu equipo.',
        creadoEn: DateTime(2026, 11, 11, 16, 0),
        compradorVistoEn: DateTime(2026, 11, 11, 16, 2),
        numero: 1001,
        titulo: 'Laptop Lenovo',
      );
      await _mostrar(tester, ListaMonitor(avisos: [aviso]));
      expect(find.textContaining('P-1001'), findsOneWidget);
      expect(find.text('Comprador: visto 11/11/2026, 16:02'), findsOneWidget);
      expect(find.text('Vendedor: sin ver'), findsOneWidget);
      expect(find.textContaining('1 de 1 avisos todavía no'), findsOneWidget);
    });
  });

  group('HU10 · Indicador de conexión', () {
    testWidgets('W-10.3 Aparece al perder la conexión y desaparece al volver',
        (tester) async {
      final sinConexion = ValueNotifier<bool>(false);
      await _mostrar(tester, IndicadorConexion(sinConexion: sinConexion));
      expect(find.text('Sin conexión en vivo, reintentando…'), findsNothing);

      sinConexion.value = true;
      await tester.pump();
      expect(find.text('Sin conexión en vivo, reintentando…'), findsOneWidget);

      sinConexion.value = false;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sin conexión en vivo, reintentando…'), findsNothing);
    });
  });
}
