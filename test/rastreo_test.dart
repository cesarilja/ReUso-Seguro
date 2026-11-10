// Pruebas unitarias de la HU02 · Rastreo del estado de inspección.
//
// Ejecutar con:  flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/models/rastreo.dart';

import 'datos_de_prueba.dart';

void main() {
  group('HU02 · Fase actual', () {
    test('CP-02.1 Cada estado del pedido cae en su fase', () {
      int fase(EstadoPedido e) => Rastreo.de(pedidoDePrueba(e)).indiceActual;
      expect(fase(EstadoPedido.pendienteDePago), -1);
      expect(fase(EstadoPedido.cancelado), -1);
      expect(fase(EstadoPedido.pagoEnCustodia), 0);
      expect(fase(EstadoPedido.recibidoEnHub), 1);
      expect(fase(EstadoPedido.enDiagnostico), 2);
      expect(fase(EstadoPedido.aprobado), 3);
      expect(fase(EstadoPedido.rechazado), 3);
      expect(fase(EstadoPedido.pagoLiberado), 4);
      expect(fase(EstadoPedido.reembolsado), 4);
    });

    test('CP-02.2 Siempre son 5 fases, con una sola actual', () {
      final fases = Rastreo.de(pedidoDePrueba(EstadoPedido.enDiagnostico)).fases;
      expect(fases, hasLength(Rastreo.totalFases));
      expect(fases.where((f) => f.estado == EstadoFase.actual), hasLength(1));
      expect(fases[2].estado, EstadoFase.actual);
      expect(fases[0].estado, EstadoFase.hecha);
      expect(fases[3].estado, EstadoFase.pendiente);
    });

    test('CP-02.3 Las fases terminadas muestran su fecha y las futuras no', () {
      final fases = Rastreo.de(pedidoDePrueba(EstadoPedido.enDiagnostico)).fases;
      expect(fases[0].fecha, pagado);
      expect(fases[1].fecha, recibido);
      expect(fases[2].fecha, diagnostico);
      expect(fases[3].fecha, isNull);
      expect(fases[4].fecha, isNull);
    });

    test('CP-02.4 Sin pagar no hay fase actual', () {
      final rastreo = Rastreo.de(pedidoDePrueba(EstadoPedido.pendienteDePago));
      expect(rastreo.faseActual, isNull);
      expect(rastreo.fases.every((f) => f.estado == EstadoFase.pendiente), isTrue);
    });

    test('CP-02.5 El final cambia si se aprueba o se rechaza', () {
      final aprobado = Rastreo.de(pedidoDePrueba(EstadoPedido.pagoLiberado,
          dictamen: dictamenDePrueba()));
      expect(aprobado.fases[3].titulo, 'Dictamen: Aprobado');
      expect(aprobado.fases[4].titulo, 'Pago liberado al vendedor');
      expect(aprobado.fases[4].fecha, liberado);
      expect(aprobado.fases[4].negativa, isFalse);

      final rechazado = Rastreo.de(pedidoDePrueba(EstadoPedido.reembolsado,
          dictamen: dictamenDePrueba(aprobado: false)));
      expect(rechazado.fases[3].titulo, 'Dictamen: Rechazado');
      expect(rechazado.fases[4].titulo, startsWith('Reembolso'));
      expect(rechazado.fases[4].negativa, isTrue);
    });
  });

  group('HU02 · Dónde está mi dinero', () {
    test('CP-02.6 Un texto para cada estado', () {
      DondeEstaElDinero dinero(EstadoPedido e) => Rastreo.de(pedidoDePrueba(e)).dinero;
      expect(dinero(EstadoPedido.pendienteDePago), DondeEstaElDinero.sinCobrar);
      expect(dinero(EstadoPedido.pagoEnCustodia), DondeEstaElDinero.enCustodia);
      expect(dinero(EstadoPedido.enDiagnostico), DondeEstaElDinero.enCustodia);
      expect(dinero(EstadoPedido.pagoLiberado), DondeEstaElDinero.liberado);
      expect(dinero(EstadoPedido.reembolsado), DondeEstaElDinero.devuelto);
      expect(DondeEstaElDinero.enCustodia.texto, contains('en custodia'));
      expect(DondeEstaElDinero.liberado.texto, contains('liberó al vendedor'));
      expect(DondeEstaElDinero.devuelto.texto, contains('devuelto a ti'));
    });
  });

  group('HU02 · Aviso en vivo', () {
    test('CP-02.7 Avisa cuando el pedido avanza de fase', () {
      final aviso = Rastreo.avisoDeCambio(
        EstadoPedido.recibidoEnHub,
        pedidoDePrueba(EstadoPedido.enDiagnostico),
      );
      expect(aviso, contains('pasó a: En diagnóstico'));
    });

    test('CP-02.8 No avisa si el pedido no avanzó', () {
      expect(
        Rastreo.avisoDeCambio(
          EstadoPedido.enDiagnostico,
          pedidoDePrueba(EstadoPedido.enDiagnostico),
        ),
        isNull,
      );
      // aprobado → pago liberado sí avanza (fase 4 de 5)
      expect(
        Rastreo.avisoDeCambio(
          EstadoPedido.aprobado,
          pedidoDePrueba(EstadoPedido.pagoLiberado, dictamen: dictamenDePrueba()),
        ),
        contains('Pago liberado'),
      );
    });
  });
}
