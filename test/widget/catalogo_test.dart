// ignore_for_file: depend_on_referenced_packages, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/equipo.dart';
import 'package:reuso_seguro/models/plan_inspeccion.dart';
import 'package:reuso_seguro/screens/catalogo_screen.dart';
import 'package:reuso_seguro/tema.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Revisa la pantalla principal del catálogo en distintos tamaños de
/// pantalla y con todos sus controles: no debe haber desbordes ni errores.

List<Equipo> _equipos() => [
      const Equipo(
        id: '1',
        titulo: 'Laptop Dell XPS 13 9370',
        descripcion: 'Core i7, 16 GB de RAM y SSD de 512 GB.',
        estadoDeclarado: 'Usado, muy bien cuidada.',
        precio: 420,
        vendedor: 'Sebastian Quijada',
        categoria: 'Laptop',
        fotos: ['http://x/1.jpg', 'http://x/2.jpg', 'http://x/3.jpg'],
        plan: PlanInspeccion.detallada,
        express: true,
      ),
      const Equipo(
        id: '2',
        titulo: 'iPhone 13 de 128 GB Azul Medianoche con caja original',
        descripcion: 'Liberado, batería 87 %.',
        estadoDeclarado: 'Usado, pantalla impecable.',
        precio: 390,
        vendedor: 'Marcelo Piñeiro',
        categoria: 'Teléfono',
        fotos: ['http://x/1.jpg', 'http://x/2.jpg', 'http://x/3.jpg'],
        plan: PlanInspeccion.detallada,
        express: true,
      ),
      const Equipo(
        id: '3',
        titulo: 'Nintendo Switch OLED Blanca 64 GB',
        descripcion: 'Con dock y Joy-Con.',
        estadoDeclarado: 'Usado, excelente estado.',
        precio: 260,
        vendedor: 'Lucas Gomez',
        categoria: 'Consola',
        plan: PlanInspeccion.detallada,
        puntajeInspeccion: 3.5,
      ),
      const Equipo(
        id: '4',
        titulo: 'iPad de 6ta generación',
        descripcion: 'Pantalla de 9,7 pulgadas.',
        estadoDeclarado: 'Usado, marcas leves.',
        precio: 150,
        vendedor: 'Mariana Colmenares',
        categoria: 'Tablet',
        estado: EstadoPublicacion.reservado,
      ),
      const Equipo(
        id: '5',
        titulo: 'Audífonos Sony WH-CH710N',
        descripcion: 'Inalámbricos.',
        estadoDeclarado: 'Usado, buen estado.',
        precio: 45,
        vendedor: 'José Graterol',
        categoria: 'Audio',
      ),
      const Equipo(
        id: '6',
        titulo: 'Monitor LG UltraGear 24 pulgadas 144 Hz',
        descripcion: 'IPS Full HD.',
        estadoDeclarado: 'Usado, sin píxeles muertos.',
        precio: 135,
        vendedor: 'Lucas Gomez',
        categoria: 'Otro',
      ),
      const Equipo(
        id: '7',
        titulo: 'MacBook Air 2017',
        descripcion: 'Core i5, 8 GB.',
        estadoDeclarado: 'Usado, marcas en la tapa.',
        precio: 320,
        vendedor: 'Andrea Rivas',
        categoria: 'Laptop',
      ),
    ];

Future<void> _mostrar(
  WidgetTester tester,
  Size tamano, {
  List<Equipo>? equipos,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: temaApp(),
      home: CatalogoScreen(cargador: () async => equipos ?? _equipos()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Desplaza la página hasta el final y vuelve, para construir todo.
Future<void> _recorrer(WidgetTester tester) async {
  final lista = find.byType(CustomScrollView).first;
  for (var i = 0; i < 12; i++) {
    await tester.drag(lista, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < 12; i++) {
    await tester.drag(lista, const Offset(0, 500));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tocarTexto(WidgetTester tester, String texto) async {
  final objetivo = find.text(texto, skipOffstage: false).first;
  await tester.ensureVisible(objetivo);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(objetivo, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // La fuente real de la app: con la de prueba (cuadrados anchos) todo
    // parecería desbordarse.
    final fuente = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await fuente.load();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://prueba.supabase.co',
      anonKey: 'clave-de-prueba',
    );
  });

  const tamanos = <String, Size>{
    'móvil 390': Size(390, 844),
    'tablet 800': Size(800, 1000),
    'laptop 1280': Size(1280, 800),
    'monitor 1920': Size(1920, 1080),
  };

  for (final entrada in tamanos.entries) {
    group('Catálogo · ${entrada.key}', () {
      testWidgets('se dibuja y se recorre sin errores', (tester) async {
        await _mostrar(tester, entrada.value);
        expect(find.text('Últimos publicados', skipOffstage: false),
            findsOneWidget);
        expect(find.text('Con Inspección Detallada', skipOffstage: false),
            findsOneWidget);
        await _recorrer(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Solo disponibles / Detallada / Express filtran',
          (tester) async {
        await _mostrar(tester, entrada.value);
        final ancho = entrada.value.width >= 1024;

        if (ancho) {
          // Sidebar: tres switches.
          for (var i = 0; i < 3; i++) {
            final switches = find.byType(Switch, skipOffstage: false);
            expect(switches, findsNWidgets(3), reason: 'antes del switch $i');
            await tester.ensureVisible(switches.at(i));
            await tester.tap(switches.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull, reason: 'switch $i');
          }
        } else {
          await _tocarTexto(tester, 'Solo disponibles');
          await _tocarTexto(tester, 'Inspección detallada');
          await _tocarTexto(tester, 'Express 24h');
        }
        expect(tester.takeException(), isNull);
        // Las vitrinas permanecen fijas arriba para que el catálogo no salte.
        expect(find.text('Últimos publicados', skipOffstage: false),
            findsOneWidget);
        await _recorrer(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('categorías y buscador funcionan', (tester) async {
        await _mostrar(tester, entrada.value);
        await _tocarTexto(tester, 'Laptop');
        expect(tester.takeException(), isNull);
        await _recorrer(tester);

        await tester.enterText(find.byType(TextField).first, 'macbook');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('MacBook Air 2017', skipOffstage: false),
            findsWidgets);

        await tester.enterText(find.byType(TextField).first, 'zzzzzz');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.textContaining('Ningún equipo coincide', skipOffstage: false),
          findsOneWidget,
        );
        await _tocarTexto(tester, 'Limpiar filtros');
        expect(tester.takeException(), isNull);
        await _recorrer(tester);
      });

      testWidgets('carruseles: las flechas se pueden pulsar', (tester) async {
        await _mostrar(tester, entrada.value);
        final flechas = find.byIcon(Icons.chevron_right, skipOffstage: false);
        final cantidad = flechas.evaluate().length;
        for (var i = 0; i < cantidad; i++) {
          await tester.ensureVisible(flechas.at(i));
          await tester.tap(flechas.at(i), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('con un solo equipo no se rompe', (tester) async {
        await _mostrar(tester, entrada.value, equipos: [_equipos().first]);
        await _recorrer(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('con 30 equipos no se rompe', (tester) async {
        final muchos = [
          for (var i = 0; i < 30; i++)
            Equipo(
              id: 'm$i',
              titulo: 'Equipo número $i con un título bastante largo para probar',
              descripcion: 'Descripción del equipo $i.',
              estadoDeclarado: 'Usado.',
              precio: 20.0 + i * 37,
              vendedor: 'Vendedor con un nombre muy largo $i',
              categoria: const [
                'Laptop',
                'Teléfono',
                'Tablet',
                'Consola',
                'Audio',
                'Otro',
              ][i % 6],
              plan: i.isEven ? PlanInspeccion.detallada : PlanInspeccion.basica,
              express: i % 3 == 0,
            ),
        ];
        await _mostrar(tester, entrada.value, equipos: muchos);
        await _recorrer(tester);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
