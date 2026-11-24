/**
 * Módulo de accesibilidad web para ReUso Seguro.
 * Integra la Web Speech API (SpeechRecognition y SpeechSynthesis)
 * y la región ARIA live para lectores de pantalla como NVDA.
 */
(function () {
  'use strict';

  let reconocimientoActivo = null;

  function obtenerConstructorReconocimiento() {
    return window.SpeechRecognition || window.webkitSpeechRecognition || null;
  }

  function anunciar(texto) {
    const region = document.getElementById('anunciador-accesible');
    if (!region || !texto) return;
    region.textContent = '';
    window.setTimeout(function () {
      region.textContent = String(texto);
    }, 30);
  }

  function soportaLectura() {
    return typeof window !== 'undefined' && 'speechSynthesis' in window;
  }

  function leerEnVozAlta(texto) {
    if (!soportaLectura() || !texto) return false;
    try {
      window.speechSynthesis.cancel();
      const locucion = new SpeechSynthesisUtterance(String(texto));
      locucion.lang = 'es-ES';
      locucion.rate = 1.0;
      window.speechSynthesis.speak(locucion);
      return true;
    } catch (_) {
      return false;
    }
  }

  function detenerLectura() {
    if (soportaLectura()) {
      window.speechSynthesis.cancel();
    }
  }

  function soportaDictado() {
    return obtenerConstructorReconocimiento() !== null;
  }

  function iniciarDictado(onResultado, onError, onFin) {
    const SpeechRec = obtenerConstructorReconocimiento();
    if (!SpeechRec) {
      if (typeof onError === 'function') {
        onError('Tu navegador no soporta búsqueda por voz.');
      }
      return false;
    }

    if (reconocimientoActivo) {
      try {
        reconocimientoActivo.stop();
      } catch (_) {}
      reconocimientoActivo = null;
    }

    const reconocimiento = new SpeechRec();
    reconocimiento.lang = 'es-ES';
    reconocimiento.interimResults = false;
    reconocimiento.maxAlternatives = 1;

    reconocimiento.onresult = function (evento) {
      const transcripcion =
        evento.results && evento.results[0] && evento.results[0][0]
          ? evento.results[0][0].transcript
          : '';
      if (transcripcion && typeof onResultado === 'function') {
        onResultado(transcripcion);
      }
    };

    reconocimiento.onerror = function (evento) {
      if (typeof onError === 'function') {
        onError(evento && evento.error ? String(evento.error) : 'error-voz');
      }
    };

    reconocimiento.onend = function () {
      reconocimientoActivo = null;
      if (typeof onFin === 'function') {
        onFin();
      }
    };

    reconocimientoActivo = reconocimiento;
    reconocimiento.start();
    return true;
  }

  function detenerDictado() {
    if (reconocimientoActivo) {
      try {
        reconocimientoActivo.stop();
      } catch (_) {}
      reconocimientoActivo = null;
    }
  }

  window.reusoAccesibilidad = {
    anunciar: anunciar,
    soportaLectura: soportaLectura,
    leerEnVozAlta: leerEnVozAlta,
    detenerLectura: detenerLectura,
    soportaDictado: soportaDictado,
    iniciarDictado: iniciarDictado,
    detenerDictado: detenerDictado,
  };
})();
