# Publicar SuRoute en Google Play

Guía para llenar Play Console con respuestas que coinciden con lo que la app hace de verdad y con la
[política de privacidad](https://suroute.com/privacidad.html). Si cambia algo en la app
(un dato nuevo, un proveedor nuevo), actualiza primero la política y luego estas respuestas.

## 1. Antes de empezar

- [ ] Correo de contacto publicado en los documentos legales (hoy dice "correo por confirmar").
- [ ] `supabase/schema.sql` ejecutado en Supabase (consentimientos, moderación, errores, métricas).
- [ ] Al menos una cuenta en la tabla `moderadores`.
- [ ] En Supabase › Authentication › URL Configuration: *Site URL* `https://suroute.com/`.
- [ ] Firma de publicación configurada (secretos del repositorio) y el `.aab` de la versión de publicación.
- [x] `targetSdk` 36 (Android 16): Play lo exige a apps nuevas y actualizaciones desde el 31 de agosto de 2026.
- [ ] `supabase/2026-11-03-coach-reportes.sql` ejecutado (reportes de respuestas del coach de IA).
- [ ] Función `coach` publicada en Supabase con el secreto `ANTHROPIC_API_KEY`.
- [ ] Cuenta de desarrollador personal nueva: Google exige una **prueba cerrada con al menos 12 personas
      durante 14 días** antes de pedir el acceso a producción (revisa el número vigente en Play Console).

## 2. Contenido de la app (Política › Contenido de la app)

| Sección | Respuesta |
|---|---|
| Política de privacidad | `https://suroute.com/privacidad.html` |
| Anuncios | No contiene anuncios |
| Acceso a la app | Casi todo funciona sin cuenta. Para revisar la comunidad, deja a los revisores una cuenta de prueba (correo y contraseña) creada para eso, sin datos reales |
| Clasificación de contenido | Cuestionario IARC: categoría *Social* o *Estilo de vida*; **sí** hay contenido generado por usuarios y comunicación entre usuarios; **no** violencia, sexo, drogas ni apuestas |
| Público objetivo | 13 a 15, 16 a 17 y 18 o más. La app exige 14 años para crear cuenta y autorización del representante entre 14 y 17. No está dirigida a niños (no marques menores de 13) |
| Apps de noticias | No |
| Apps de salud | No es una app de salud: es desarrollo personal. Si el formulario pregunta, marca que no ofrece funciones médicas |
| Servicio en primer plano | `mediaPlayback`: reproducir los audiolibros con la pantalla apagada. Adjunta un video corto que muestre el reproductor y la notificación |
| Eliminación de cuenta | Sí, en la app (Perfil › Ajustes › Cuenta › Eliminar mi cuenta) y en la web. URL: `https://suroute.com/privacidad.html#eliminar-cuenta` |
| Contenido generado por usuarios | Hay reportes y bloqueo en la app, ocultamiento automático con 3 reportes, panel de moderación con suspensiones y [normas de la comunidad](https://suroute.com/normas.html) que se aceptan al crear la cuenta. Las Fogatas en vivo tienen botón de reportar y moderación puede cortarlas |
| Contenido generado por IA | El coach de IA responde con controles por tema (no recomienda productos financieros ni promete rendimientos, no da asesoría médica, legal ni tributaria). Cada respuesta tiene una bandera para **reportarla** (ofensiva, peligrosa, equivocada u otra); los reportes llegan a Moderación › Coach IA |
| Funciones financieras (declaración) | Marca **solo** «Otra» o la opción de herramientas de presupuesto o registro de finanzas personales. La app **no** ofrece préstamos, pagos, transferencias, inversiones, criptomonedas, seguros ni conexión con bancos: la persona anota sus propias cifras |

## 3. Seguridad de los datos (Data safety)

**Preguntas generales**

| Pregunta | Respuesta |
|---|---|
| ¿Recopila o comparte datos de usuario? | Sí |
| ¿Todos los datos están cifrados en tránsito? | Sí (HTTPS) |
| ¿Ofrece una forma de pedir que se borren los datos? | Sí (en la app, en la web y por correo) |
| ¿Se comparten datos con terceros? | **No**. Supabase, Anthropic, LiveKit y GitHub actúan como proveedores de servicio por cuenta de SuRoute, lo que Google no considera "compartir" |

**Datos recopilados.** Todo es *opcional* (la app funciona completa sin cuenta), salvo donde se indica.

| Tipo de dato (Play) | ¿Recopilado? | Obligatorio | Para qué (Play) | Detalle |
|---|---|---|---|---|
| Información personal › Correo electrónico | Sí | Obligatorio para crear cuenta | Funcionalidad de la app, Administración de la cuenta | Iniciar sesión |
| Información personal › Nombre | Sí | Opcional | Funcionalidad de la app | Nombre visible en la comunidad |
| Información personal › ID de usuario | Sí | Obligatorio para crear cuenta | Funcionalidad de la app, Administración de la cuenta | Usuario (@) y su identificador |
| Información personal › Número de teléfono | Sí | Opcional | Funcionalidad de la app | Solo si activa «Que mis contactos me encuentren»: se guarda una huella SHA-256 del número, nunca el número |
| Fotos y videos › Fotos | Sí | Opcional | Funcionalidad de la app | Fotos que la persona publica, usa en su vision board en la nube o adjunta como recibo de un movimiento (depósito privado) |
| Fotos y videos › Videos | Sí, **procesado de forma efímera** | Opcional | Funcionalidad de la app | La imagen de la cámara en una Fogata en vivo, transmitida en tiempo real por LiveKit. No se graba ni se guarda |
| Audio › Voz o grabaciones de sonido | Sí, **procesado de forma efímera** | Opcional | Funcionalidad de la app | La voz en una Fogata en vivo, en tiempo real. No se graba ni se guarda |
| Archivos y documentos | Sí | Opcional | Funcionalidad de la app | PDF de recibos o documentos de una deuda o un activo (depósito privado, solo la persona) |
| Contactos | Sí, **procesado de forma efímera** | Opcional | Funcionalidad de la app | «Agregar contactos»: el teléfono envía huellas SHA-256 de números y correos para compararlas; la agenda no se guarda |
| Mensajes › Otros mensajes en la app | Sí | Opcional | Funcionalidad de la app | Mensajes 1 a 1 y notas de cordada |
| Actividad en la app › Otro contenido generado por el usuario | Sí | Opcional | Funcionalidad de la app | Publicaciones, comentarios, impulsos y la ruta si vincula la web |
| Actividad en la app › Interacciones con la app | No | — | — | No hay analítica ni rastreo |
| Salud y actividad física › Información de salud | Sí | Opcional | Funcionalidad de la app | Solo si la persona escribe sobre su salud en su ruta y la sincroniza o se la cuenta al coach IA (dato sensible, con autorización expresa) |
| Información financiera › Otra información financiera | Sí | Opcional | Funcionalidad de la app | Ascenso financiero: ingresos, gastos, ahorro, inversión, deudas, activos y metas que la persona anota. Viaja al servidor para sincronizar con la web y, solo con el tema *Finanzas*, un resumen de 3 meses al coach de IA |
| Información financiera › Información de pago / historial de compras / crédito | No | — | — | Sin pagos ni conexión con bancos |
| Ubicación, calendario, SMS, historial web | No | — | — | — |
| Información y rendimiento de la app › Registros de fallas | Sí | Opcional (se puede apagar en Ajustes) | Análisis (corregir fallas) | Anónimos: versión, sistema, modelo y líneas de código, sin cuenta ni mensajes |
| Identificadores del dispositivo | No | — | — | No se usa el ID de publicidad |

### Permisos que pide la app (deben coincidir con la política, sección «Permisos del teléfono»)

| Permiso | Para qué |
|---|---|
| `CAMERA` | Fotos de publicaciones, vision board y recibos; leer el QR para vincular la web; imagen en la Fogata en vivo |
| `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` | Voz en la Fogata en vivo |
| `READ_CONTACTS` | «Agregar contactos» (huellas, la agenda no se sube) |
| `POST_NOTIFICATIONS` | Recordatorios y avisos que la persona activa |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Audiolibros con la pantalla apagada |

## 4. Ficha de la tienda (español)

**Nombre:** SuRoute

**Descripción breve (80 caracteres como máximo):**

> Encuentra tu cumbre y súbela paso a paso: metas, hábitos y una comunidad que sube.

**Descripción completa:**

> SuRoute es un método para descubrir tu cumbre personal —eso que le da sentido a tu vida— y subirla un paso cada día.
>
> TU RUTA
> • Las guías del método Ruta a la Cima, con tus respuestas guardadas en tu teléfono.
> • Tus seis ejes: Voluntad, Maestría, Voz, Valor, Evolución y Trascendencia.
> • Metas del año y del mes, hábitos diarios y tu vida año por año.
> • La Brújula de la Cima: tu vision board en una cuadrícula de 9 × 9 con 64 pasos, que se explora en tres niveles.
> • Un ascenso de 8.848 mm al año: cada paso que ganas te acerca a la cumbre.
>
> NO SUBES SOLO
> • Una comunidad para compartir avances, caídas y cumbres, con la visibilidad que tú elijas.
> • Cordadas: pequeños grupos con un reto compartido.
> • Coaches de vida y un coach con inteligencia artificial que conoce tu ruta.
>
> TUS DATOS SON TUYOS
> • Sin cuenta, todo se queda en tu teléfono.
> • Sin publicidad y sin venta de datos.
> • Elimina tu cuenta cuando quieras.
>
> También en tu computador con SuRoute Web.

**Gráficos que pide Play:**

- Ícono de 512 × 512 (ya está en `diseno/`).
- Gráfico destacado de 1024 × 500.
- Entre 2 y 8 capturas del teléfono (mínimo 320 px por lado): Hoy, Mi ruta, la Brújula, la comunidad, una guía y la carta de bienvenida.

## 5. Después de publicar

- Revisa a diario el panel de **Moderación** (pendientes y errores) durante las primeras semanas.
- Cada vez que cambien los documentos legales de forma sustancial, sube `Legal.VERSION` en la app y
  `LEGAL_VERSION` en `web/js/13-cuenta.js`: se vuelve a pedir la autorización.
