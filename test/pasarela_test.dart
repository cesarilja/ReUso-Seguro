// Pruebas unitarias de ReUso Pay (la pasarela de pago simulada).
//
// Ejecutar desde la carpeta del proyecto con:  flutter test
//
// Revisan lo que la app comprueba ANTES de enviar el pago, la traducción
// de cada respuesta del banco y el tiempo límite para pagar. Las reglas
// del «banco» (aprobar o rechazar) se prueban en el servidor con
// supabase/pruebas/10_verificar_pasarela.sql.
import 'package:flutter_test/flutter_test.dart';
import 'package:reuso_seguro/models/equipo.dart';
import 'package:reuso_seguro/models/pedido.dart';
import 'package:reuso_seguro/services/pasarela.dart';

void main() {
  group('Tarjeta', () {
    test('CP-PU1 Luhn acepta las tarjetas de prueba y rechaza un error', () {
      expect(luhnValido('4242 4242 4242 4242'), isTrue);
      expect(luhnValido('5555555555554444'), isTrue);
      expect(luhnValido('4000000000009995'), isTrue);
      expect(luhnValido('4242 4242 4242 4241'), isFalse); // un dígito mal
      expect(luhnValido('1234'), isFalse); // muy corta
    });

    test('CP-PU2 Reconoce la marca por los primeros dígitos', () {
      expect(MarcaTarjeta.de('4242'), MarcaTarjeta.visa);
      expect(MarcaTarjeta.de('5555 5555'), MarcaTarjeta.mastercard);
      expect(MarcaTarjeta.de('2221 0000'), MarcaTarjeta.mastercard);
      expect(MarcaTarjeta.de('3782 822463 10005'), MarcaTarjeta.amex);
      expect(MarcaTarjeta.de('6011'), MarcaTarjeta.otra);
    });

    test('CP-PU3 Agrupa el número como en la tarjeta física', () {
      expect(formatearNumeroTarjeta('4242424242424242'), '4242 4242 4242 4242');
      expect(formatearNumeroTarjeta('378282246310005'), '3782 822463 10005');
      expect(formatearNumeroTarjeta('42424'), '4242 4');
    });

    test('CP-PU4 Mensajes del número: vacío, incompleto e inválido', () {
      expect(validarNumeroTarjeta(''), isNotNull);
      expect(validarNumeroTarjeta('4242 4242'), contains('Faltan dígitos'));
      expect(validarNumeroTarjeta('4242 4242 4242 4241'), contains('no es válido'));
      expect(validarNumeroTarjeta('4242 4242 4242 4242'), isNull);
    });

    test('CP-PU5 Vencimiento: formato, mes y tarjeta vencida', () {
      final hoy = DateTime(2026, 11, 9);
      expect(validarVencimiento('1128', hoy: hoy), isNotNull); // sin barra
      expect(validarVencimiento('13/28', hoy: hoy), contains('mes'));
      expect(validarVencimiento('10/26', hoy: hoy), contains('venció'));
      expect(validarVencimiento('11/26', hoy: hoy), isNull); // vence a fin de mes
      expect(validarVencimiento('08/30', hoy: hoy), isNull);
    });

    test('CP-PU6 CVV: 3 dígitos, o 4 en American Express', () {
      expect(validarCvv('123', MarcaTarjeta.visa), isNull);
      expect(validarCvv('12', MarcaTarjeta.visa), isNotNull);
      expect(validarCvv('1234', MarcaTarjeta.amex), isNull);
      expect(validarCvv('123', MarcaTarjeta.amex), isNotNull);
    });
  });

  group('Pago Móvil y Zelle', () {
    test('CP-PU7 Referencia, teléfono, cédula y correo', () {
      expect(validarReferencia('012345'), isNull);
      expect(validarReferencia('ab12cd34'), isNull);
      expect(validarReferencia('123'), isNotNull);
      expect(validarReferencia('12-34-56'), isNotNull);
      expect(validarTelefono('0414 123 4567'), isNull);
      expect(validarTelefono('0212 123 4567'), isNotNull); // fijo, no móvil
      expect(validarCedula('V-12.345.678'), isNull);
      expect(validarCedula('12345678'), isNotNull); // falta la letra
      expect(validarCorreo('ana@correo.com'), isNull);
      expect(validarCorreo('ana@correo'), isNotNull);
    });

    test('CP-PU8 Lee montos con coma o punto decimal', () {
      expect(leerMonto('250,00'), 250.0);
      expect(leerMonto('250.50'), 250.5);
      expect(leerMonto('\$1.250,75'), 1250.75);
      expect(leerMonto('abc'), isNull);
      expect(validarMonto('0'), isNotNull);
    });
  });

  group('Respuesta del banco', () {
    test('CP-PU9 Cada código tiene título y qué hacer', () {
      for (final respuesta in RespuestaBanco.values) {
        expect(respuesta.titulo, isNotEmpty);
        if (respuesta != RespuestaBanco.aprobado) {
          expect(respuesta.queHacer, isNotEmpty);
        }
      }
      expect(RespuestaBanco.desde('FONDOS_INSUFICIENTES'),
          RespuestaBanco.fondosInsuficientes);
      expect(RespuestaBanco.desde('ALGO_RARO'), RespuestaBanco.desconocido);
    });

    test('CP-PU10 Solo se reintenta si el pedido sigue abierto', () {
      expect(RespuestaBanco.fondosInsuficientes.permiteReintentar, isTrue);
      expect(RespuestaBanco.pagoNoEncontrado.permiteReintentar, isTrue);
      expect(RespuestaBanco.vencido.permiteReintentar, isFalse);
      expect(RespuestaBanco.reservado.permiteReintentar, isFalse);
      expect(RespuestaBanco.demasiadosIntentos.permiteReintentar, isFalse);
    });

    test('CP-PU11 Los datos de prueba tienen tarjetas válidas', () {
      final tarjetas = DatoDePrueba.todos.where((d) => d.metodo == 'Tarjeta');
      for (final dato in tarjetas) {
        expect(luhnValido(dato.dato), isTrue, reason: dato.dato);
      }
    });
  });

  group('Tiempo para pagar', () {
    const equipo = Equipo(
      id: 'equipo-1',
      titulo: 'Laptop de prueba',
      descripcion: 'Equipo usado para las pruebas de la pasarela.',
      estadoDeclarado: 'Usado, en buen estado.',
      precio: 250,
      vendedor: 'Vendedor de prueba',
    );
    final creado = DateTime(2026, 11, 9, 10, 0);
    final pedido = Pedido(
      id: 'pedido-1',
      numero: 1001,
      equipo: equipo,
      compradorId: 'comprador-1',
      monto: 250,
      creadoEn: creado,
    );

    test('CP-PU12 Hay 15 minutos para pagar y luego vence', () {
      expect(pedido.expiraEn, creado.add(const Duration(minutes: 15)));
      expect(pedido.tiempoRestante(creado.add(const Duration(minutes: 5))),
          const Duration(minutes: 10));
      expect(pedido.vencido(creado.add(const Duration(minutes: 14))), isFalse);
      expect(pedido.vencido(creado.add(const Duration(minutes: 16))), isTrue);
      expect(pedido.tiempoRestante(creado.add(const Duration(hours: 1))),
          Duration.zero);
    });
  });
}
