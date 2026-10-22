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
| Repository | `CatalogoService`, `PedidoService` y `SesionService`: las pantallas no saben de dónde vienen los datos |
| Singleton | `SesionService.instancia` y `PedidoService.instancia` |
| Observer | `SesionService` avisa cuando alguien entra o sale y la barra superior se actualiza sola |
| Facade | `SesionService` esconde el cliente de Supabase y traduce sus errores al español |

## Diferencias con el documento de arquitectura (y por qué)

- **El catálogo usa datos de prueba** en `CatalogoService`, no la tabla de PostgreSQL. La tabla se llena cuando exista la publicación de equipos (HU11, Sprint 2). Gracias al patrón Repository, ese cambio solo toca el servicio.
- **Los pedidos se guardan en memoria** en `PedidoService`. Pasan a Supabase junto con el pago protegido (HU01). El cambio de estado del pago lo hará el servidor (Edge Functions), nunca el navegador.
