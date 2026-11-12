import 'package:flutter/material.dart';

import '../services/tiempo_real_service.dart';

/// HU10, escenario 3: aviso bajo la barra cuando se cae la conexión en vivo.
/// Desaparece solo al reconectar (heurísticas 1 y 9).
class IndicadorConexion extends StatelessWidget {
  const IndicadorConexion({super.key, this.sinConexion});

  /// Para las pruebas; en la app se usa el estado del tiempo real.
  final ValueNotifier<bool>? sinConexion;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: sinConexion ?? TiempoRealService.instancia.sinConexion,
      builder: (context, caida, _) => AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: caida ? const AvisoSinConexion() : const SizedBox(width: double.infinity),
      ),
    );
  }
}

/// La franja ámbar con ícono y texto (nunca solo color).
class AvisoSinConexion extends StatelessWidget {
  const AvisoSinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFFF4D6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 18, color: Color(0xFF6B4500)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Sin conexión en vivo, reintentando…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B4500),
                ),
              ),
            ),
            SizedBox(width: 10),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6B4500)),
            ),
          ],
        ),
      ),
    );
  }
}
