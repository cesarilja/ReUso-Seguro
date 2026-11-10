// Pruebas unitarias de la HU03 · Certificado técnico.
//
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/certificado.dart';
import 'package:reuso_seguro/models/inspeccion.dart';
import 'package:reuso_seguro/models/pedido.dart';

import 'datos_de_prueba.dart';

void main() {
  group('HU03 · Armado del certificado', () {
    test('CP-03.1 Sin dictamen todavía no hay certificado', () {
      final pedido = pedidoDePrueba(
        EstadoPedido.enDiagnostico,
        inspeccion: inspeccionDePrueba(),
      );
      expect(Certificado.desde(pedido), isNull);
    });

    test('CP-03.2 Usa el checklist del tipo de equipo', () {
      final certificado = Certificado.desde(pedidoDePrueba(
        EstadoPedido.pagoLiberado,
        dictamen: dictamenDePrueba(),
        inspeccion: inspeccionDePrueba(),
      ))!;
      final claves = certificado.puntos.map((p) => p.punto.clave).toList();
      expect(claves, PuntoChecklist.para('Laptop').map((p) => p.clave).toList());
      expect(claves, contains('teclado')); // una laptop revisa el teclado
    });

    test('CP-03.3 Todo bien: cuenta y resumen', () {
      final certificado = Certificado.desde(pedidoDePrueba(
        EstadoPedido.pagoLiberado,
        dictamen: dictamenDePrueba(),
        inspeccion: inspeccionDePrueba(),
      ))!;
      expect(certificado.aprobado, isTrue);
      expect(certificado.puntosBien, certificado.puntos.length);
      expect(certificado.puntosConFalla, 0);
      expect(certificado.resumenInspector, contains('todos funcionan bien'));
      expect(certificado.puntos.first.textoResultado, 'Bien');
    });

    test('CP-03.4 Con una falla: la nombra en el resumen', () {
      final certificado = Certificado.desde(pedidoDePrueba(
        EstadoPedido.reembolsado,
        dictamen: dictamenDePrueba(
          aprobado: false,
          motivo: 'La batería no cumple con lo publicado.',
        ),
        inspeccion: inspeccionDePrueba(falla: 'bateria'),
      ))!;
      expect(certificado.aprobado, isFalse);
      expect(certificado.puntosConFalla, 1);
      expect(certificado.fallas.single.textoResultado, 'Falla');
      expect(certificado.resumenInspector, contains('1 falla: batería'));
    });

    test('CP-03.5 El PDF lleva el código del pedido y la fecha del dictamen', () {
      final certificado = Certificado.desde(pedidoDePrueba(
        EstadoPedido.pagoLiberado,
        dictamen: dictamenDePrueba(),
        inspeccion: inspeccionDePrueba(),
      ))!;
      expect(certificado.nombreArchivo, 'Certificado_P-1001_2026-11-05.pdf');
      expect(certificado.codigo, 'CT-1001');
      expect(certificado.dictamen.firmadoPor, 'Lucas Gomez');
    });
  });
}
