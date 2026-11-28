import 'dart:typed_data';

/// Respaldo para plataformas sin navegador (pruebas unitarias/VM).
bool disponible() => false;

Future<String> leerTexto(Uint8List bytes, String mimeType) async => '';
