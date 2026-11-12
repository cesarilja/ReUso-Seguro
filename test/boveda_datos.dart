// Respuestas de ejemplo de revisar_boveda para las pruebas (no es una prueba).

Map<String, dynamic> bovedaCuadrada() => {
      'revisado_en': '2026-11-11T19:30:00Z',
      'cuadrada': true,
      'diferencia_total': 0,
      'descuadres': <Map<String, dynamic>>[],
      'totales': {
        'en_custodia': 70,
        'liberado': 92,
        'reembolsado': 50,
        'comisiones': 8,
      },
      'por_estado': {'pago_en_custodia': 1, 'pago_liberado': 1, 'reembolsado': 1},
      'liberaciones_pendientes': [
        {
          'pedido_id': 'p9',
          'numero': 1009,
          'titulo': 'iPad de 6ta generación',
          'vendedor': 'Ana Pérez',
          'monto': 150,
          'motivo': 'SIN_CUENTA',
          'intentos': 2,
          'ultimo_intento': '2026-11-11T18:00:00Z',
        },
      ],
      'descuadres_registrados': <Map<String, dynamic>>[],
    };

Map<String, dynamic> bovedaConDescuadre() => {
      ...bovedaCuadrada(),
      'cuadrada': false,
      'diferencia_total': -276,
      'descuadres': [
        {
          'pedido_id': 'p1',
          'numero': 1003,
          'titulo': 'Laptop HP Pavilion 15',
          'estado': 'pago_liberado',
          'esperado': 0,
          'real': -276,
          'diferencia': -276,
        },
      ],
      'descuadres_registrados': [
        {'revisado_en': '2026-11-11T19:30:00Z', 'diferencia_total': -276, 'pedidos': 1},
      ],
    };

Map<String, dynamic> bovedaVacia() => {
      'revisado_en': '2026-11-11T19:30:00Z',
      'cuadrada': true,
      'diferencia_total': 0,
      'descuadres': <Map<String, dynamic>>[],
      'totales': {'en_custodia': 0, 'liberado': 0, 'reembolsado': 0, 'comisiones': 0},
      'por_estado': <String, dynamic>{},
      'liberaciones_pendientes': <Map<String, dynamic>>[],
      'descuadres_registrados': <Map<String, dynamic>>[],
    };
