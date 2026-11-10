// Pruebas de widget de la HU03: el certificado técnico.
//
// Ejecutar con:  flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/certificado.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/screens/certificado_screen.dart';

import '../datos_de_prueba.dart';

Future<void> _mostrar(WidgetTester tester, Widget hijo) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo))),
  );
}

void main() {
  testWidgets('W-03.1 Certificado aprobado', (tester) async {
    final certificado = Certificado.desde(pedidoDePrueba(
      EstadoPedido.pagoLiberado,
      dictamen: dictamenDePrueba(),
      inspeccion: inspeccionDePrueba(),
    ))!;
    await _mostrar(tester, CertificadoTecnico(certificado: certificado));

    expect(find.text('Equipo aprobado'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget); // color + ícono + texto
    expect(find.text('Lo que declaró el vendedor'), findsOneWidget);
    expect(find.text('Lo que encontró el inspector'), findsOneWidget);
    expect(find.text('Bien'), findsNWidgets(certificado.puntos.length));
    expect(find.textContaining('Lucas Gomez'), findsOneWidget);
  });

  testWidgets('W-03.2 Certificado rechazado con su falla y motivo', (tester) async {
    final certificado = Certificado.desde(pedidoDePrueba(
      EstadoPedido.reembolsado,
      dictamen: dictamenDePrueba(
        aprobado: false,
        motivo: 'La batería no cumple con lo publicado.',
      ),
      inspeccion: inspeccionDePrueba(falla: 'bateria'),
    ))!;
    await _mostrar(tester, CertificadoTecnico(certificado: certificado));

    expect(find.text('Equipo rechazado'), findsOneWidget);
    expect(find.text('Motivo del rechazo'), findsOneWidget);
    expect(find.text('Falla'), findsOneWidget);
    expect(find.textContaining('La batería dura solo 20 minutos.'), findsWidgets);
  });

  testWidgets('W-03.3 Todavía no está listo', (tester) async {
    await _mostrar(
      tester,
      CertificadoPendiente(pedido: pedidoDePrueba(EstadoPedido.enDiagnostico)),
    );
    expect(
      find.textContaining('estará listo cuando el inspector termine'),
      findsOneWidget,
    );
    expect(find.text('En diagnóstico (ahora)'), findsOneWidget);
  });
}
