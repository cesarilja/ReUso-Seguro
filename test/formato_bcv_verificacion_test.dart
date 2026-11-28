import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/formato.dart';
import 'package:reuso_seguro/services/tasa_bcv_service.dart';
import 'package:reuso_seguro/services/verificacion_vendedor_service.dart';

void main() {
  group('Formato de montos (USD y Bs.)', () {
    test('formatearDolares usa punto decimal (500.00)', () {
      expect(formatearDolares(500), r'$500.00');
      expect(formatearDolares(180.5), r'$180.50');
      expect(formatearDolares(0), r'$0.00');
    });

    test('formatearBolivares formatea miles y decimales con punto', () {
      expect(formatearBolivares(926.3592), 'Bs. 926.36');
      expect(formatearBolivares(463179.6), 'Bs. 463,179.60');
    });
  });

  group('Tasa BCV', () {
    test('convierte USD a Bs. correctamente y formatea fecha corta', () {
      final tasa = TasaBcv(
        tasa: 926.3592,
        fechaActualizacion: DateTime(2026, 11, 28),
      );
      expect(tasa.convertirABolivares(500), closeTo(463179.6, 0.01));
      expect(tasa.fechaCorta, '28/11/2026');
    });
  });

  group('Verificación de identidad del vendedor', () {
    test('valida y normaliza cédulas venezolanas', () {
      expect(VerificacionVendedorService.validarCedula(''), isNotNull);
      expect(VerificacionVendedorService.validarCedula('12345678'), isNotNull);
      expect(VerificacionVendedorService.validarCedula('V-12345678'), isNull);
      expect(VerificacionVendedorService.validarCedula('e1234567'), isNull);
      expect(
        VerificacionVendedorService.normalizarCedula('v12345678'),
        'V-12345678',
      );
    });
  });
}
