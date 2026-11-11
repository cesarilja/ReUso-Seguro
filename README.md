# ReUso Seguro

Plataforma web para comprar y vender tecnología de segunda mano sin riesgo de estafas: el pago queda en custodia hasta que el Hub técnico revisa el equipo. En el MVP los pagos son simulados.

**Grupo D** · Cesar Ilja, Lucas Gomez, Marcelo Piñeiro y Sebastian Quijada
Ingeniería de Software · Universidad Metropolitana

## Cómo correrlo

```bash
flutter pub get
flutter run -d chrome
```

## Sprint 1 (01/10 al 15/10/2026)

| Historia | Puntos | Estado |
|---|---|---|
| HU14. Registro e inicio de sesión | 3 | Hecha |
| HU12. Compra de un equipo | 3 | Hecha |

- Catálogo público: se ve sin iniciar sesión, como en Amazon o Mercado Libre.
- Detalle de cada equipo con foto, descripción, estado declarado y precio. Los equipos reservados no muestran el botón «Comprar».
- Registro, inicio y cierre de sesión con Supabase Auth. La cuenta se pide solo al comprar o publicar.
- Validaciones del registro y del inicio de sesión (`lib/services/validaciones.dart`):
  - cada campo trae un ejemplo en gris (por ejemplo, `ejemplo@gmail.com`) y un texto de ayuda;
  - cada error dice qué corregir y aparece debajo de su campo: falta la @, falta la terminación, hay espacios, el nombre no tiene apellido, etc.;
  - sugiere el correo correcto si hay un error de escritura común (`gmial.com` → `gmail.com`);
  - la contraseña nueva muestra sus requisitos (8 caracteres, mayúscula, minúscula y número) y se marcan solos mientras se escribe;
  - hay que repetir la contraseña y el botón del ojo permite verla;
  - los errores de Supabase se traducen al español.
- Al iniciar sesión, si el correo o la contraseña no coinciden, el mensaje no dice cuál de los dos falló. Es a propósito: así nadie puede averiguar qué correos tienen cuenta (buena práctica de seguridad de OWASP).
- «Comprar» crea un pedido en «Pendiente de pago» y abre la pantalla de pago. El pago protegido es la HU01 (Sprint 2).

## Sprint 2 (en curso)

| Historia | Puntos | Estado |
|---|---|---|
| HU11. Publicar un equipo | 5 | Hecha |
| HU01. Pago protegido (simulado) | 5 | Hecha |
| HU07. Checklist de inspección | 5 | Hecha |
| HU08. Dictamen técnico | 3 | Hecha |
| HU06. Liberación automática del pago | 5 | Hecha |

- El catálogo se carga desde Supabase (tabla `equipos`) con fotos reales en Supabase Storage. Mientras carga dice «Cargando equipos…» y, si falla, ofrece «Reintentar».
- **Publicar un equipo** (`lib/screens/publicar_screen.dart` y `lib/services/publicacion_service.dart`):
  - pide iniciar sesión antes de abrir el formulario;
  - **todos los datos son obligatorios**: título, tipo de equipo, precio, condición, detalles del estado, descripción y **de 3 a 6 fotos** (JPG, PNG o WEBP, hasta 5 MB cada una);
  - cada error dice qué corregir debajo de su campo, y el contador de fotos se marca en verde al llegar a 3;
  - la primera foto es la portada; se puede cambiar con la estrella o quitar cualquier foto;
  - si hay datos sin publicar y la persona intenta salir, la app pregunta antes;
  - al publicar, las fotos se suben a la carpeta del vendedor en Storage (`<id del vendedor>/...`) y el equipo se guarda en la tabla; aparece de una vez en el catálogo;
  - si algo falla a mitad de camino, se borran las fotos subidas y no se publica nada;
  - el vendedor no puede comprar su propio equipo.
- La base de datos revisa las mismas reglas (`supabase/03_publicar.sql`): nadie puede publicar con datos incompletos ni a nombre de otro, aunque lo intente desde fuera de la app.
- **Pago protegido con ReUso Pay, nuestra pasarela simulada** (HU01: `lib/screens/pago_screen.dart`, `lib/services/pasarela.dart`, `lib/widgets/pasarela_widgets.dart`, `supabase/10_pasarela_simulada.sql`):
  - «Comprar» crea el pedido en Supabase en «Pendiente de pago» (HU12). Hay **15 minutos** para pagarlo (cuenta regresiva); si vence, se cancela solo y se puede volver a intentar;
  - el comprador elige cómo pagar y escribe sus datos como en una pasarela real:
    - **Tarjeta**: la tarjeta se dibuja mientras se escribe (y se voltea al escribir el CVV); la app revisa el número (algoritmo de Luhn), la fecha y el CVV antes de enviarlo. Solo se guarda la marca y los últimos 4 dígitos;
    - **Pago Móvil y Zelle**: se muestran los datos para transferir (con botón de copiar) y el comprador confirma con su banco, teléfono, cédula o correo, la referencia y el monto;
  - el **servidor hace de banco** (`procesar_pago`): aprueba o rechaza con un motivo real (fondos insuficientes, tarjeta vencida, referencia no encontrada, monto distinto, referencia ya usada…). La app no decide nada;
  - mientras se procesa se ven los pasos («Conectando con tu banco», «Verificando…», «Autorizando…»); si se rechaza, se explica qué pasó, qué hacer, que no se cobró nada y cuántos intentos quedan. Con 5 rechazos el pedido se cancela por seguridad;
  - al aprobarse, el pedido pasa a «Pago en custodia», el equipo queda «Reservado» y se muestra el comprobante (con «Pagado con: Visa •••• 4242», por ejemplo);
  - cada intento queda guardado en la tabla `intentos_pago`, como el registro de una pasarela;
  - el pedido se puede cancelar mientras no se haya pagado, y «Mis compras» muestra hasta cuándo se puede pagar cada pedido pendiente.
- **Datos de prueba de ReUso Pay** (también se ven tocando la insignia «Modo de prueba» en la pantalla de pago). Ningún banco está conectado y **no se mueve dinero real**:

  | Método | Dato | Respuesta |
  |---|---|---|
  | Tarjeta | 4242 4242 4242 4242 | Aprobado |
  | Tarjeta | 5555 5555 5555 4444 | Aprobado (Mastercard) |
  | Tarjeta | 4000 0000 0000 0002 | Tarjeta rechazada |
  | Tarjeta | 4000 0000 0000 9995 | Fondos insuficientes |
  | Tarjeta | 4000 0000 0000 0069 | Tarjeta vencida |
  | Tarjeta | 4000 0000 0000 0127 | CVV incorrecto |
  | Pago Móvil o Zelle | Referencia terminada en 0000 | Pago no encontrado |
  | Pago Móvil o Zelle | Monto distinto al del pedido | Monto no coincide |
  | Pago Móvil o Zelle | Una referencia ya usada en otro pedido | Referencia ya usada |
  | Pago Móvil o Zelle | Cualquier otra referencia y el monto exacto | Aprobado |

  En las tarjetas sirve cualquier fecha futura y cualquier CVV. Pruebas: `flutter test` (`test/pasarela_test.dart`) y `supabase/pruebas/10_verificar_pasarela.sql` (hace pagos de prueba, lo deshace todo al final y todas las filas deben decir «OK»).
- **El navegador nunca cambia el estado del pago ni la reserva**: lo hacen las funciones del servidor `crear_pedido`, `procesar_pago` y `cancelar_pedido`, que bloquean el equipo mientras se paga para que dos personas no lo compren a la vez. **No se mueve dinero real.**
- **Checklist de inspección en el Hub** (HU07: `lib/screens/panel_hub_screen.dart`, `lib/screens/inspeccion_screen.dart`, `lib/services/inspeccion_service.dart`):
  - solo las cuentas de inspector técnico ven «Panel del Hub» en el menú de la cuenta;
  - el panel ordena el trabajo en tres grupos (por recibir, por inspeccionar e inspeccionados) con contadores arriba;
  - el checklist cambia según el tipo de equipo (laptop, teléfono, tablet, consola, audio u otro): unos audífonos se revisan por sonido, micrófono y almohadillas, no por pantalla; cada punto trae una ayuda de qué revisar;
  - todos los puntos son obligatorios; los que algunos equipos no tienen (cámaras, lectora de discos, micrófono) se pueden marcar «No aplica»;
  - cada falla pide una nota y de 1 a 4 fotos de evidencia; la barra de progreso dice cuántos puntos van listos («3 de 5»);
  - no se puede guardar con puntos sin marcar: se marcan en rojo con lo que falta;
  - arriba se ve lo que declaró el vendedor, para compararlo con el equipo;
  - el comprador ve en «Mis compras» que su pedido llegó al Hub y está en revisión.
- **Dictamen técnico** (HU08: `lib/screens/dictamen_screen.dart`, `lib/widgets/dictamen_widgets.dart`):
  - desde «Listos para dictamen», el inspector ve el resumen del checklist y elige **Aprobar** o **Rechazar** (botones grandes con color, ícono y texto);
  - rechazar exige un motivo; aprobar un equipo con fallas exige explicar por qué (por ejemplo, un rayón que el vendedor declaró);
  - se confirma antes de emitir porque el dictamen es definitivo;
  - el comprador ve en «Mis compras» el dictamen («Aprobado» en verde o «Rechazado» en rojo, siempre con texto) y puede abrir lo que revisó el inspector;
  - la función del servidor `emitir_dictamen` (`supabase/06_dictamen.sql`) solo acepta dictámenes de inspectores, con checklist completo y una sola vez por pedido.
- **Liberación automática del pago** (HU06: `supabase/07_liberacion_pago.sql`, `lib/screens/mis_ventas_screen.dart`):
  - cuando el inspector aprueba el equipo, un disparador (trigger) en el servidor pasa el pedido a «Pago liberado» sin que nadie lo haga a mano;
  - se descuenta la comisión de la plataforma (8 %) y se guarda cuánto recibe el vendedor;
  - **Mis ventas** (menú de la cuenta) muestra cada venta con el desglose: precio, comisión y lo que recibe; arriba, lo ya recibido y lo que sigue en custodia;
  - el vendedor ve en cada venta qué sigue (llevar el equipo al Hub, en revisión, pago liberado) y el dictamen del inspector;
  - el navegador no puede liberar pagos: la función no tiene permisos para la app. **No se mueve dinero real.**
- **Reembolso por equipo rechazado** (HU13 · Sprint 3: `supabase/09_reembolso.sql`, `lib/widgets/pedido_widgets.dart`):
  - cuando el inspector rechaza el equipo, un disparador en el servidor pasa el pedido a «Reembolsado» y le devuelve al comprador el 100 % de lo que pagó, sin comisión;
  - en **Mis compras** el comprador ve el comprobante del reembolso: número (RE-…), monto, comisión $0,00, a dónde se devolvió y la fecha;
  - en **Mis ventas** el vendedor ve «No recibes pago» y la comisión «no se cobra»; el equipo vuelve a estar «Disponible» en el catálogo;
  - el navegador no puede hacer reembolsos: la función no tiene permisos para la app. **No se mueve dinero real.**
  - Pruebas: `flutter test` (pruebas unitarias en `test/reembolso_test.dart`) y `supabase/pruebas/09_verificar_reembolso.sql` (las 5 filas deben decir «OK»).
- **Rastreo del pedido** (HU02 · Sprint 3: `lib/models/rastreo.dart`, `lib/widgets/pedido_widgets.dart`, `supabase/11_rastreo_y_certificado.sql`):
  - en «Mis compras» cada pedido muestra sus 5 fases: Pago en custodia → Recibido en el Hub → En diagnóstico → Dictamen → Pago liberado o Reembolso, con la fase actual resaltada y la **fecha y hora** de cada fase terminada (las anota el servidor);
  - un recuadro dice siempre **dónde está el dinero**: en custodia, liberado al vendedor o devuelto al comprador;
  - si el pedido cambia de fase con la página abierta, aparece el aviso «Tu equipo pasó a: En diagnóstico», sin recargar.
- **Certificado técnico** (HU03 · Sprint 3: `lib/screens/certificado_screen.dart`, `lib/models/certificado.dart`, `lib/services/certificado_pdf.dart`):
  - el botón «Ver certificado técnico» (en «Mis compras» y en «Mis ventas») abre el certificado: resultado, inspector que lo firmó, fecha, checklist según el tipo de equipo con «Bien», «Falla» o «No aplica», y las fotos de evidencia de cada falla (se amplían al tocarlas);
  - compara **lado a lado** lo que declaró el vendedor y lo que encontró el inspector;
  - si todavía no hay dictamen, explica que estará listo cuando termine la revisión y muestra la fase actual;
  - **«Guardar en PDF»** descarga el certificado como `Certificado_P-1001_2026-11-05.pdf` (código del pedido y fecha del dictamen), con las fotos de evidencia;
  - solo lo pueden ver el comprador, el vendedor y los inspectores (reglas RLS del servidor).
  - Pruebas: `flutter test` (`test/rastreo_test.dart`, `test/certificado_test.dart` y las pruebas de widget en `test/widget/`) y `supabase/pruebas/11_verificar_rastreo_certificado.sql` (todas las filas deben decir «OK»).
- **Confirmación de fondos para el vendedor** (HU04 · Sprint 3: `lib/services/vendedor_service.dart`, `lib/widgets/venta_widgets.dart`, `supabase/12_vendedor_y_liberacion.sql`):
  - cuando le compran, el vendedor ve en cualquier pantalla el aviso «Te compraron [equipo]. El pago está en custodia» y «Mis ventas» muestra en la barra un número rojo con las ventas nuevas (se borra al abrirla);
  - cada venta pagada muestra los pasos para llevar el equipo al Hub: dirección, horario y el código del pedido (con botón de copiar);
  - con «Ya entregué el equipo» (y su confirmación) la venta pasa a «Esperando que el Hub lo reciba» y el inspector lo ve marcado en «Por recibir». Solo el vendedor de ese pedido puede hacerlo, y solo si el pago ya está en custodia.
- **La transferencia al vendedor puede fallar** (HU06, escenario pendiente · Sprint 3, SIMULADO):
  - el vendedor registra en «Mis ventas» su **cuenta para cobrar** (Pago Móvil);
  - si el equipo se aprueba y no hay cuenta, o el banco rechaza la transferencia, la venta queda en **«Liberación pendiente»** con el motivo y qué hacer, y el dinero **sigue en custodia**;
  - al registrar o corregir la cuenta, el servidor **reintenta solo**; también hay un botón «Reintentar el cobro». Cuando funciona, la venta pasa a «Pago liberado» y llega el aviso;
  - dato de prueba: una cuenta con teléfono terminado en **0000** hace que el banco rechace la transferencia.
  - Pruebas: `flutter test` (`test/vendedor_test.dart` y `test/widget/venta_test.dart`) y `supabase/pruebas/12_verificar_vendedor_y_liberacion.sql` (todas las filas deben decir «OK»).
- **Todo en tiempo real** (`lib/services/tiempo_real_service.dart`, `supabase/08_tiempo_real.sql`): con Supabase Realtime, el catálogo, el detalle de un equipo, Mis compras, Mis ventas y el Panel del Hub se actualizan solos cuando otra persona compra, publica, guarda un checklist o emite un dictamen. No hay que recargar la página. Cada persona solo recibe los cambios que tiene permiso de ver.
- **Navegación y nuevas páginas** (`lib/widgets/navegacion.dart`, `lib/widgets/barra_superior.dart`):
  - la barra de arriba muestra las secciones: **Inicio**, **Cómo funciona**, **Mis compras**, **Mis ventas** y (solo inspectores) **Panel del Hub**. La sección actual queda subrayada en orquídea y en negrita (heurística 1: el usuario sabe dónde está);
  - en pantallas angostas las secciones se juntan en el botón «Menú»; la cuenta es un círculo con flecha ▾ para que se note que abre un menú (heurística 6);
  - ir a una sección funciona como pestañas: «Volver al inicio» siempre regresa al catálogo y no se apilan pantallas.
- **Cómo funciona** (`lib/screens/como_funciona_screen.dart`): los 4 pasos de la custodia, qué gana el comprador y el vendedor, y preguntas frecuentes (comisión, qué revisa el Hub, reembolso, pagos simulados). Resuelve la heurística 10 (ayuda y documentación).
- **Buscar y filtrar el catálogo** (`lib/services/filtro_catalogo.dart`): buscador (sin importar tildes ni mayúsculas), categorías, «Solo disponibles» y orden por fecha o precio. Si nada coincide, se dice y se ofrece «Limpiar filtros» (heurística 7).
- **Mis ventas** ahora también lista **Tus equipos publicados** con su estado (Disponible / Reservado, con ícono y texto, no solo color).
- La portada muestra las tres garantías (pago en custodia, revisión en el Hub, reembolso) y el pie de página trae accesos a las secciones.
- Cuando llega un cambio en tiempo real, las listas se actualizan sin parpadear: se sigue viendo lo anterior hasta que llega lo nuevo.
- La función del servidor `guardar_inspeccion` (`supabase/05_inspeccion.sql`) vuelve a revisar todas las reglas. Para dar acceso de inspector a una cuenta:
  ```sql
  insert into public.inspectores (usuario_id)
    select id from auth.users where email = 'correo-del-inspector@gmail.com'
  on conflict do nothing;
  ```

## Cómo cumple la arquitectura

Arquitectura en **capas cerradas** sobre un modelo cliente-servidor, con Supabase como backend (BaaS). Cada capa solo usa la que tiene justo debajo: las pantallas nunca hablan directo con Supabase.

| Capa | Carpeta | Estereotipo |
|---|---|---|
| Presentación | `lib/screens`, `lib/widgets` | «boundary» |
| Lógica de la aplicación | `lib/services` | «control» |
| Modelos de datos | `lib/models` | «entity» |
| Datos | Supabase (Auth; PostgreSQL y Storage en los próximos sprints) | — |

| Patrón de diseño | Dónde está |
|---|---|
| Repository | `CatalogoService`, `PublicacionService`, `PedidoService`, `InspeccionService` y `SesionService`: las pantallas no saben de dónde vienen los datos |
| Singleton | `SesionService.instancia` y `PedidoService.instancia` |
| Observer | `SesionService` avisa cuando alguien entra o sale y la barra superior se actualiza sola; `TiempoRealService` escucha los cambios de la base de datos y avisa a `CatalogoService`, `PedidoService` e `InspeccionService`, cuyas pantallas se recargan solas |
| Facade | `SesionService` esconde el cliente de Supabase y traduce sus errores al español |

## Diferencias con el documento de arquitectura (y por qué)

- **El catálogo ya sale de Supabase**: la tabla `equipos` (PostgreSQL) guarda los datos y el almacén `equipos` (Storage) guarda las fotos; la tabla solo guarda la ruta de cada foto. El script está en `supabase/01_catalogo.sql`. Los 8 equipos de muestra tienen `es_demo = true` y se borran con `delete from public.equipos where es_demo;` cuando haya equipos reales (HU11). Gracias al patrón Repository, el cambio solo tocó `CatalogoService`.
- **Seguridad del catálogo (RLS)**: cualquiera puede ver los equipos; cada vendedor solo puede publicar a su nombre y subir fotos a su propia carpeta. Nadie puede cambiar el estado «reservado» desde el navegador.
- **Los pedidos ya están en Supabase** (tabla `pedidos`). El cambio de estado del pago lo hace el servidor con funciones de PostgreSQL (`security definer`) en lugar de Edge Functions: cumplen la misma regla (el navegador nunca cambia el estado) y son más simples para el MVP.
