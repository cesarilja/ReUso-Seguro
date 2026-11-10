import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../formato.dart';
import '../models/certificado.dart';
import '../models/inspeccion.dart';

/// Arma el PDF del certificado técnico (HU03, escenario 4).
///
/// Usa la misma letra de la app (Poppins) y, si se pueden descargar,
/// incluye las fotos de evidencia de cada falla.
class CertificadoPdf {
  const CertificadoPdf._();

  static const PdfColor _tinta = PdfColor.fromInt(0xFF15133D);
  static const PdfColor _gris = PdfColor.fromInt(0xFF4F5878);
  static const PdfColor _linea = PdfColor.fromInt(0xFFE6ECF8);
  static const PdfColor _verde = PdfColor.fromInt(0xFF1F7A44);
  static const PdfColor _rojo = PdfColor.fromInt(0xFFB3261E);

  static Future<Uint8List> generar(
    Certificado c, {
    String Function(String ruta)? urlEvidencia,
  }) async {
    final normal = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
    final negrita = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    final fotos = urlEvidencia == null
        ? const <String, List<pw.MemoryImage>>{}
        : await _fotosDeFallas(c, urlEvidencia);

    final pedido = c.pedido;
    final equipo = pedido.equipo;
    final aprobado = c.aprobado;
    final colorResultado = aprobado ? _verde : _rojo;

    final documento = pw.Document(
      title: 'Certificado técnico ${c.codigo}',
      author: 'ReUso Seguro',
    );

    pw.TextStyle estilo({double tamano = 10, bool fuerte = false, PdfColor? color}) =>
        pw.TextStyle(
          font: fuerte ? negrita : normal,
          fontSize: tamano,
          color: color ?? _tinta,
        );

    pw.Widget dato(String titulo, String valor) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 120, child: pw.Text(titulo, style: estilo(color: _gris))),
              pw.Expanded(child: pw.Text(valor, style: estilo(fuerte: true))),
            ],
          ),
        );

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: normal, bold: negrita),
        header: (contexto) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          margin: const pw.EdgeInsets.only(bottom: 14),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _tinta, width: 1.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('ReUso Seguro · Hub de inspección', style: estilo(fuerte: true, tamano: 11)),
              pw.Text('Certificado ${c.codigo}', style: estilo(color: _gris)),
            ],
          ),
        ),
        footer: (contexto) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Pagos simulados: documento de un proyecto universitario.',
              style: estilo(tamano: 8, color: _gris),
            ),
            pw.Text(
              'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
              style: estilo(tamano: 8, color: _gris),
            ),
          ],
        ),
        build: (contexto) => [
          pw.Text('Certificado técnico', style: estilo(tamano: 22, fuerte: true)),
          pw.SizedBox(height: 10),
          // Resultado
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: colorResultado, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  aprobado ? 'EQUIPO APROBADO' : 'EQUIPO RECHAZADO',
                  style: estilo(tamano: 16, fuerte: true, color: colorResultado),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${c.puntosBien} puntos bien · ${c.puntosConFalla} con falla'
                  '${c.puntosNoAplica > 0 ? ' · ${c.puntosNoAplica} no aplica' : ''}',
                  style: estilo(),
                ),
                if (c.dictamen.motivo.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '${aprobado ? 'Nota del inspector' : 'Motivo del rechazo'}: '
                    '«${c.dictamen.motivo}»',
                    style: estilo(),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          dato('Pedido', pedido.codigo),
          dato('Equipo', equipo.titulo),
          dato('Tipo de equipo', equipo.categoria ?? 'Otro'),
          dato('Vendedor', equipo.vendedor),
          dato('Precio', pedido.montoFormateado),
          dato('Fecha del dictamen', formatearFecha(c.dictamen.emitidoEn)),
          dato('Inspector', c.dictamen.firmadoPor),
          pw.SizedBox(height: 14),
          pw.Text('Lo publicado frente a lo revisado', style: estilo(tamano: 13, fuerte: true)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: _linea),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _linea),
                children: [
                  _celda('Lo que declaró el vendedor', estilo(fuerte: true)),
                  _celda('Lo que encontró el inspector', estilo(fuerte: true)),
                ],
              ),
              pw.TableRow(
                children: [
                  _celda('${equipo.estadoDeclarado}\n\n${equipo.descripcion}', estilo()),
                  _celda(c.resumenInspector, estilo()),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text('Revisión punto por punto', style: estilo(tamano: 13, fuerte: true)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: _linea),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _linea),
                children: [
                  _celda('Punto', estilo(fuerte: true)),
                  _celda('Resultado', estilo(fuerte: true)),
                  _celda('Observación', estilo(fuerte: true)),
                ],
              ),
              for (final punto in c.puntos)
                pw.TableRow(
                  children: [
                    _celda(punto.punto.nombre, estilo(fuerte: true)),
                    _celda(
                      punto.textoResultado,
                      estilo(
                        fuerte: true,
                        color: punto.resultado == ResultadoPunto.falla
                            ? _rojo
                            : (punto.resultado == ResultadoPunto.ok ? _verde : _gris),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            punto.revision?.tieneFalla ?? false
                                ? punto.revision!.nota
                                : punto.punto.queRevisar,
                            style: estilo(tamano: 9),
                          ),
                          if ((fotos[punto.punto.clave] ?? const []).isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final foto in fotos[punto.punto.clave]!)
                                  pw.Image(foto, width: 70, height: 70, fit: pw.BoxFit.cover),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Firmado por ${c.dictamen.firmadoPor}, inspector técnico del Hub de ReUso '
            'Seguro, el ${formatearFecha(c.dictamen.emitidoEn)}. Este certificado se '
            'generó desde la plataforma y no se puede modificar.',
            style: estilo(tamano: 9, color: _gris),
          ),
        ],
      ),
    );

    return documento.save();
  }

  static pw.Widget _celda(String texto, pw.TextStyle estilo) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(texto, style: estilo),
      );

  /// Descarga las fotos de evidencia (máximo 4 por falla). Si alguna no
  /// se puede bajar, el PDF se arma igual, sin esa foto.
  static Future<Map<String, List<pw.MemoryImage>>> _fotosDeFallas(
    Certificado c,
    String Function(String ruta) urlEvidencia,
  ) async {
    final resultado = <String, List<pw.MemoryImage>>{};
    for (final falla in c.fallas) {
      final rutas = (falla.revision?.evidencias ?? const <String>[]).take(4);
      for (final ruta in rutas) {
        try {
          final respuesta = await http
              .get(Uri.parse(urlEvidencia(ruta)))
              .timeout(const Duration(seconds: 10));
          // Solo JPG o PNG: otros formatos podrían romper el PDF.
          final b = respuesta.bodyBytes;
          final esJpg = b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;
          final esPng = b.length > 3 && b[0] == 0x89 && b[1] == 0x50;
          if (respuesta.statusCode == 200 && (esJpg || esPng)) {
            (resultado[falla.punto.clave] ??= []).add(pw.MemoryImage(respuesta.bodyBytes));
          }
        } catch (error) {
          debugPrint('[CertificadoPdf] Sin foto $ruta: $error');
        }
      }
    }
    return resultado;
  }
}
