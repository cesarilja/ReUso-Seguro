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
- **Pago protegido simulado** (HU01: `lib/screens/pago_screen.dart`, `lib/services/pedido_service.dart`):
  - «Comprar» crea el pedido en Supabase en «Pendiente de pago» (HU12);
  - el comprador elige cómo pagar (tarjeta, Pago Móvil o Zelle), confirma el monto en un diálogo y ve «Verificando el pago…» mientras se procesa;
  - al pagar, el pedido pasa a «Pago en custodia», el equipo queda «Reservado» y se muestra un comprobante con referencia y la línea de tiempo del pedido;
  - si el pago se rechaza (hay un interruptor para simularlo), se explica qué pasó, no se cobra nada y se puede reintentar;
  - el pedido se puede cancelar mientras no se haya pagado;
  - «Mis compras» (menú de la cuenta) lista los pedidos con su estado.
- **El navegador nunca cambia el estado del pago ni la reserva**: lo hacen las funciones del servidor `crear_pedido`, `pagar_pedido` y `cancelar_pedido` (`supabase/04_pago_protegido.sql`), que bloquean el equipo mientras se paga para que dos personas no lo compren a la vez. **No se mueve dinero real.**
- **Checklist de inspección en el Hub** (HU07: `lib/screens/panel_hub_screen.dart`, `lib/screens/inspeccion_screen.dart`, `lib/services/inspeccion_service.dart`):
  - solo las cuentas de inspector técnico ven «Panel del Hub» en el menú de la cuenta;
  - el panel ordena el trabajo en tres grupos (por recibir, por inspeccionar e inspeccionados) con contadores arriba;
  - el checklist cambia según el tipo de equipo (laptop, teléfono, tablet, consola, audio u otro): unos audífonos se revisan por sonido, micrófono y almohadillas, no por pantalla; cada punto trae una ayuda de qué revisar;
  - todos los puntos son obligatorios; los que algunos equipos no tienen (cámaras, lectora de discos, micrófono) se pueden marcar «No aplica»;
  - cada falla pide una nota y de 1 a 4 fotos de evidencia; la barra de progreso dice cuántos puntos van listos («3 de 5»);
  - no se puede guardar con puntos sin marcar: se marcan en rojo con lo que falta;
  - arriba se ve lo que declaró el vendedor, para compararlo con el equipo;
  - el comprador ve en «Mis compras» que su pedido llegó al Hub y está en revisión.
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
| Observer | `SesionService` avisa cuando alguien entra o sale y la barra superior se actualiza sola; `CatalogoService.cambios` avisa cuando se publica un equipo y el catálogo se recarga |
| Facade | `SesionService` esconde el cliente de Supabase y traduce sus errores al español |

## Diferencias con el documento de arquitectura (y por qué)

- **El catálogo ya sale de Supabase**: la tabla `equipos` (PostgreSQL) guarda los datos y el almacén `equipos` (Storage) guarda las fotos; la tabla solo guarda la ruta de cada foto. El script está en `supabase/01_catalogo.sql`. Los 8 equipos de muestra tienen `es_demo = true` y se borran con `delete from public.equipos where es_demo;` cuando haya equipos reales (HU11). Gracias al patrón Repository, el cambio solo tocó `CatalogoService`.
- **Seguridad del catálogo (RLS)**: cualquiera puede ver los equipos; cada vendedor solo puede publicar a su nombre y subir fotos a su propia carpeta. Nadie puede cambiar el estado «reservado» desde el navegador.
- **Los pedidos ya están en Supabase** (tabla `pedidos`). El cambio de estado del pago lo hace el servidor con funciones de PostgreSQL (`security definer`) en lugar de Edge Functions: cumplen la misma regla (el navegador nunca cambia el estado) y son más simples para el MVP.
