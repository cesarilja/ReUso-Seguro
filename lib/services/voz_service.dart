import 'voz_service_stub.dart'
    if (dart.library.js_interop) 'voz_service_web.dart' as impl;

/// Servicio de accesibilidad por voz y anuncios ARIA live.
///
/// En navegadores compatibles (Google Chrome / Edge) utiliza la Web Speech API
/// (SpeechRecognition para dictado en búsqueda y SpeechSynthesis para lectura
/// en voz alta) junto con la región `aria-live="polite"` del documento.
class VozService {
  VozService._();

  static final VozService instancia = VozService._();

  bool get soportaDictado => impl.soportaDictado();

  bool get soportaLectura => impl.soportaLectura();

  /// Actualiza la región ARIA live para lectores de pantalla como NVDA.
  void anunciar(String texto) => impl.anunciar(texto);

  /// Lee un texto en voz alta mediante Web Speech API (SpeechSynthesis).
  bool leerEnVozAlta(String texto) => impl.leerEnVozAlta(texto);

  /// Detiene cualquier lectura en curso.
  void detenerLectura() => impl.detenerLectura();

  /// Inicia el dictado por voz (SpeechRecognition) en español.
  bool iniciarDictado({
    required void Function(String texto) alRecibirTexto,
    required void Function(String error) alFallar,
    required void Function() alTerminar,
  }) {
    return impl.iniciarDictado(
      alRecibirTexto: alRecibirTexto,
      alFallar: alFallar,
      alTerminar: alTerminar,
    );
  }

  /// Detiene el dictado por voz si está activo.
  void detenerDictado() => impl.detenerDictado();
}
