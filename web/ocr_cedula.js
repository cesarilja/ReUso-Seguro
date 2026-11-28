/**
 * Lectura OCR de cédula de identidad en el navegador usando Tesseract.js.
 * No envía la imagen a ningún servidor externo: todo corre localmente en Chrome.
 */
(function () {
  'use strict';

  async function leerTextoCedula(dataUrl) {
    if (!window.Tesseract || typeof window.Tesseract.recognize !== 'function') {
      throw new Error('OCR_NO_DISPONIBLE');
    }
    const resultado = await window.Tesseract.recognize(dataUrl, 'spa');
    const texto =
      resultado && resultado.data && typeof resultado.data.text === 'string'
        ? resultado.data.text
        : '';
    return texto;
  }

  window.reusoOcr = {
    disponible: function () {
      return Boolean(
        window.Tesseract && typeof window.Tesseract.recognize === 'function'
      );
    },
    leerTextoCedula: leerTextoCedula,
  };
})();
