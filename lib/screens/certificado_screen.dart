import 'package:flutter/material.dart';

import '../formato.dart';
import '../models/certificado.dart';
import '../models/inspeccion.dart';
import '../models/pedido.dart';
import '../models/rastreo.dart';
import '../services/certificado_pdf.dart';
import '../services/descarga.dart';
import '../services/inspeccion_service.dart';
import '../tema.dart';
import '../widgets/avisos.dart';
import '../widgets/imagen_equipo.dart';
import '../widgets/pagina_base.dart';
import '../widgets/pedido_widgets.dart';
import '../widgets/pegatina.dart';

const Color _verde = Color(0xFF1F7A44);
const Color _rojo = Color(0xFFB3261E);

/// HU03: el certificado técnico que firma el inspector del Hub.
///
/// Lo ven el comprador y el vendedor del pedido (el servidor no deja que
/// nadie más lea el dictamen ni el checklist). Si todavía no hay dictamen,
/// explica cuándo estará listo y muestra la fase actual.
class CertificadoScreen extends StatefulWidget {
  const CertificadoScreen({super.key, required this.pedido});

  final Pedido pedido;

  @override
  State<CertificadoScreen> createState() => _CertificadoScreenState();
}

class _CertificadoScreenState extends State<CertificadoScreen> {
  bool _generando = false;

  Future<void> _guardarPdf(Certificado certificado) async {
    if (_generando) return;
    setState(() => _generando = true);
    try {
      final bytes = await CertificadoPdf.generar(
        certificado,
        urlEvidencia: InspeccionService.urlEvidencia,
      );
      await descargarArchivo(bytes, certificado.nombreArchivo, 'application/pdf');
      if (!mounted) return;
      mostrarAviso(context, 'Descargamos ${certificado.nombreArchivo}.');
    } catch (error) {
      debugPrint('[Certificado] No se pudo generar el PDF: $error');
      if (!mounted) return;
      mostrarAviso(context, 'No pudimos crear el PDF. Vuelve a intentarlo.');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificado = Certificado.desde(widget.pedido);

    return PaginaBase(
      anchoContenido: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: BotonVolver(texto: 'Volver'),
          ),
          const SizedBox(height: 20),
          if (certificado == null)
            CertificadoPendiente(pedido: widget.pedido)
          else ...[
            CertificadoTecnico(certificado: certificado),
            const SizedBox(height: 24),
            BotonPegatina(
              texto: _generando ? 'Creando el PDF…' : 'Guardar en PDF',
              icono: _generando ? Icons.hourglass_top : Icons.picture_as_pdf_outlined,
              expandido: true,
              alTocar: () => _guardarPdf(certificado),
            ),
            const SizedBox(height: 8),
            Text(
              'Se descarga como ${certificado.nombreArchivo}',
              textAlign: TextAlign.center,
              style: Tipos.pequeno,
            ),
          ],
        ],
      ),
    );
  }
}

/// HU03, escenario 3: todavía no hay dictamen.
class CertificadoPendiente extends StatelessWidget {
  const CertificadoPendiente({super.key, required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final fase = Rastreo.de(pedido).faseActual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Certificado técnico', style: Tipos.titulo),
        const SizedBox(height: 16),
        RecuadroInfo(
          icono: Icons.hourglass_top,
          texto: 'El certificado estará listo cuando el inspector termine la '
              'revisión.${fase == null ? '' : ' Ahora tu pedido está en: ${fase.titulo}.'}',
        ),
        const SizedBox(height: 20),
        const Text('En qué va tu pedido', style: Tipos.subtitulo),
        const SizedBox(height: 12),
        LineaDeTiempo(pedido: pedido),
      ],
    );
  }
}

/// El contenido del certificado. Va aparte de la pantalla para poder
/// probarlo con pruebas de widget.
class CertificadoTecnico extends StatelessWidget {
  const CertificadoTecnico({super.key, required this.certificado});

  final Certificado certificado;

  @override
  Widget build(BuildContext context) {
    final pedido = certificado.pedido;
    final dictamen = certificado.dictamen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: Text('Certificado técnico', style: Tipos.titulo)),
            _Sello(codigo: certificado.codigo),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Pedido ${pedido.codigo} · Emitido el ${formatearFecha(dictamen.emitidoEn)}',
          style: Tipos.cuerpo,
        ),
        const SizedBox(height: 20),
        // Heurística 8: primero el resultado, después el detalle.
        _Resultado(certificado: certificado),
        const SizedBox(height: 20),
        _Equipo(certificado: certificado),
        const SizedBox(height: 20),
        const Text('Lo publicado frente a lo revisado', style: Tipos.subtitulo),
        const SizedBox(height: 10),
        _Comparacion(certificado: certificado),
        const SizedBox(height: 24),
        const Text('Revisión punto por punto', style: Tipos.subtitulo),
        const SizedBox(height: 4),
        Text(
          'Checklist para ${(pedido.equipo.categoria ?? 'este tipo de equipo').toLowerCase()}',
          style: Tipos.pequeno,
        ),
        const SizedBox(height: 10),
        Pegatina(
          sombra: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < certificado.puntos.length; i++) ...[
                  if (i > 0) Container(height: 1, color: ColoresApp.nube),
                  _LineaPunto(punto: certificado.puntos[i]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.verified_user_outlined, size: 16, color: ColoresApp.pizarra),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Firmado por ${dictamen.firmadoPor}, inspector técnico del Hub de '
                'ReUso Seguro. Este certificado no se puede modificar.',
                style: Tipos.pequeno.copyWith(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Sello extends StatelessWidget {
  const _Sello({required this.codigo});

  final String codigo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.tinta, width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium_outlined, color: ColoresApp.tinta, size: 22),
          Text(
            codigo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ColoresApp.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

/// El resultado grande: Aprobado o Rechazado, con color, ícono y texto.
class _Resultado extends StatelessWidget {
  const _Resultado({required this.certificado});

  final Certificado certificado;

  @override
  Widget build(BuildContext context) {
    final aprobado = certificado.aprobado;
    final color = aprobado ? _verde : _rojo;
    final motivo = certificado.dictamen.motivo;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: aprobado ? const Color(0xFFDFF3E6) : const Color(0xFFFBE9E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(aprobado ? Icons.verified : Icons.cancel_outlined, color: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aprobado ? 'Equipo aprobado' : 'Equipo rechazado',
                  style: Tipos.titulo.copyWith(color: color, fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  aprobado
                      ? 'Pasó la inspección técnica del Hub.'
                      : 'No pasó la inspección técnica del Hub.',
                  style: Tipos.cuerpo.copyWith(color: ColoresApp.tinta, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Conteo(
                      icono: Icons.check_circle,
                      color: _verde,
                      texto: '${certificado.puntosBien} bien',
                    ),
                    _Conteo(
                      icono: Icons.warning_amber_rounded,
                      color: _rojo,
                      texto: '${certificado.puntosConFalla} '
                          '${certificado.puntosConFalla == 1 ? 'falla' : 'fallas'}',
                    ),
                    if (certificado.puntosNoAplica > 0)
                      _Conteo(
                        icono: Icons.remove_circle_outline,
                        color: ColoresApp.pizarra,
                        texto: '${certificado.puntosNoAplica} no aplica',
                      ),
                  ],
                ),
                if (motivo.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    aprobado ? 'Nota del inspector' : 'Motivo del rechazo',
                    style: Tipos.pequeno.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '«$motivo»',
                    style: Tipos.cuerpo.copyWith(
                      fontStyle: FontStyle.italic,
                      color: ColoresApp.tinta,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Conteo extends StatelessWidget {
  const _Conteo({required this.icono, required this.color, required this.texto});

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ColoresApp.tinta,
            ),
          ),
        ],
      ),
    );
  }
}

class _Equipo extends StatelessWidget {
  const _Equipo({required this.certificado});

  final Certificado certificado;

  @override
  Widget build(BuildContext context) {
    final equipo = certificado.pedido.equipo;

    return Pegatina(
      sombra: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 72, height: 72, child: ImagenEquipo(equipo: equipo)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(equipo.titulo, style: Tipos.subtitulo),
                  const SizedBox(height: 2),
                  Text(
                    '${equipo.categoria ?? 'Equipo'} · Vende ${equipo.vendedor} · '
                    '${certificado.pedido.montoFormateado}',
                    style: Tipos.pequeno,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HU03, escenario 2: lo que declaró el vendedor y lo que encontró el
/// inspector, lado a lado (heurística 6: reconocer antes que recordar).
class _Comparacion extends StatelessWidget {
  const _Comparacion({required this.certificado});

  final Certificado certificado;

  @override
  Widget build(BuildContext context) {
    final equipo = certificado.pedido.equipo;
    final declarado = _Columna(
      icono: Icons.storefront_outlined,
      titulo: 'Lo que declaró el vendedor',
      principal: equipo.estadoDeclarado,
      secundario: equipo.descripcion,
      color: ColoresApp.nube,
    );
    final encontrado = _Columna(
      icono: Icons.fact_check_outlined,
      titulo: 'Lo que encontró el inspector',
      principal: certificado.resumenInspector,
      secundario: [
        for (final falla in certificado.fallas)
          if ((falla.revision?.nota ?? '').isNotEmpty)
            '${falla.punto.nombre}: ${falla.revision!.nota}',
      ].join('\n'),
      color: certificado.fallas.isEmpty
          ? const Color(0xFFDFF3E6)
          : const Color(0xFFFBE9E8),
    );

    return LayoutBuilder(
      builder: (context, medidas) {
        if (medidas.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [declarado, const SizedBox(height: 12), encontrado],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: declarado),
              const SizedBox(width: 12),
              Expanded(child: encontrado),
            ],
          ),
        );
      },
    );
  }
}

class _Columna extends StatelessWidget {
  const _Columna({
    required this.icono,
    required this.titulo,
    required this.principal,
    required this.secundario,
    required this.color,
  });

  final IconData icono;
  final String titulo;
  final String principal;
  final String secundario;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: ColoresApp.tinta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titulo, style: Tipos.subtitulo.copyWith(fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            principal,
            style: Tipos.cuerpo.copyWith(color: ColoresApp.tinta, fontSize: 15),
          ),
          if (secundario.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(secundario, style: Tipos.pequeno.copyWith(fontSize: 13.5)),
          ],
        ],
      ),
    );
  }
}

/// Un punto del checklist con su resultado y, si falló, la nota y las
/// fotos de evidencia.
class _LineaPunto extends StatelessWidget {
  const _LineaPunto({required this.punto});

  final PuntoCertificado punto;

  @override
  Widget build(BuildContext context) {
    final (icono, color) = switch (punto.resultado) {
      ResultadoPunto.ok => (Icons.check_circle, _verde),
      ResultadoPunto.falla => (Icons.warning_amber_rounded, _rojo),
      ResultadoPunto.noAplica => (Icons.remove_circle_outline, ColoresApp.pizarra),
      null => (Icons.help_outline, ColoresApp.pizarra),
    };
    final revision = punto.revision;
    final evidencias = revision?.evidencias ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        punto.punto.nombre,
                        style: Tipos.pequeno.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: ColoresApp.tinta,
                        ),
                      ),
                    ),
                    Text(
                      punto.textoResultado,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Text(punto.punto.queRevisar, style: Tipos.pequeno.copyWith(fontSize: 12.5)),
                if (revision?.tieneFalla ?? false) ...[
                  const SizedBox(height: 6),
                  Text(
                    revision!.nota,
                    style: Tipos.pequeno.copyWith(fontSize: 14, color: ColoresApp.tinta),
                  ),
                  if (evidencias.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final ruta in evidencias) _Evidencia(ruta: ruta),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto de evidencia: al tocarla se ve en grande.
class _Evidencia extends StatelessWidget {
  const _Evidencia({required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context) {
    final url = InspeccionService.urlEvidencia(ruta);
    return Semantics(
      button: true,
      label: 'Ver foto de evidencia en grande',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (contexto) => Dialog(
            child: Stack(
              children: [
                InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filled(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(contexto).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 96,
              height: 96,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}
