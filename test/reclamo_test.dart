// Pruebas unitarias de la HU05 · Respaldo técnico ante reclamos.
//
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/models/reclamo.dart';

import 'datos_de_prueba.dart';

Pedido _pedido(Map<String, dynamic> cambios) => Pedido.desdeFila({
      'id': 'pedido-1',
      'numero': 1001,
      'comprador_id': 'comprador-1',
      'monto': 250,
      'creado_en': '2026-11-10T14:00:00Z',
      'estado': 'pago_liberado',
      ...cambios,
    }, laptopDePrueba);

void main() {
  group('HU05 · Fotos de recepción', () {
    test('CP-05.1 Hacen falta de 2 a 6 fotos', () {
      expect(ReglasReclamo.fotosRecepcion(0), contains('te faltan 2'));
      expect(ReglasReclamo.fotosRecepcion(1), contains('te faltan 1'));
      expect(ReglasReclamo.fotosRecepcion(2), isNull);
      expect(ReglasReclamo.fotosRecepcion(6), isNull);
      expect(ReglasReclamo.fotosRecepcion(7), contains('máximo 6'));
    });

    test('CP-05.2 Lee la recepción y el reclamo del pedido', () {
      final pedido = _pedido({
        'recepciones': {
          'fotos': ['p1/recepcion-1.jpg', 'p1/recepcion-2.jpg'],
          'nota': 'Marca leve en la tapa',
          'creado_en': '2026-11-10T15:00:00Z',
        },
        'reclamos': [
          {
            'descripcion': 'La batería dura menos de lo publicado.',
            'estado': 'abierto',
            'creado_en': '2026-11-11T10:00:00Z',
          },
        ],
      });
      expect(pedido.recepcion!.fotos, hasLength(2));
      expect(pedido.recepcion!.nota, 'Marca leve en la tapa');
      expect(pedido.reclamo!.abierto, isTrue);
    });
  });

  group('HU05 · Plazo de 3 días para reclamar', () {
    final recibido = DateTime(2026, 11, 10, 9, 0);

    test('CP-05.3 Antes de confirmar que lo recibió', () {
      expect(ReglasReclamo.situacion(_pedido({})), SituacionReclamo.porConfirmar);
      expect(ReglasReclamo.venceEn(_pedido({})), isNull);
    });

    test('CP-05.4 Dentro de los 3 días puede reclamar', () {
      final pedido = _pedido({'recibido_comprador_en': recibido.toUtc().toIso8601String()});
      expect(ReglasReclamo.venceEn(pedido), recibido.add(const Duration(days: 3)));
      expect(
        ReglasReclamo.situacion(pedido, recibido.add(const Duration(days: 2))),
        SituacionReclamo.enPlazo,
      );
    });

    test('CP-05.5 Después de 3 días ya no', () {
      final pedido = _pedido({'recibido_comprador_en': recibido.toUtc().toIso8601String()});
      expect(
        ReglasReclamo.situacion(pedido, recibido.add(const Duration(days: 4))),
        SituacionReclamo.fueraDePlazo,
      );
    });

    test('CP-05.6 No aplica si el equipo no ha sido aprobado', () {
      expect(ReglasReclamo.situacion(_pedido({'estado': 'en_diagnostico'})),
          SituacionReclamo.noAplica);
    });

    test('CP-05.7 La descripción necesita al menos 20 caracteres', () {
      expect(ReglasReclamo.descripcion('no sirve'), contains('al menos 20'));
      expect(ReglasReclamo.descripcion('La pantalla tiene una raya que no salía en las fotos.'),
          isNull);
    });
  });
}
