import 'dart:typed_data';

import 'ocr_cedula_stub.dart'
    if (dart.library.js_interop) 'ocr_cedula_web.dart' as impl;

/// Servicio de lectura OCR en el navegador para validar fotos de cédula.
class OcrCedulaService {
  OcrCedulaService._();

  /// Indica si el motor OCR del navegador (Tesseract.js) está disponible.
  static bool get disponible => impl.disponible();

  /// Extrae el texto de la imagen de la cédula mediante OCR local.
  static Future<String> leerTexto(Uint8List bytes, String mimeType) =>
      impl.leerTexto(bytes, mimeType);
}
