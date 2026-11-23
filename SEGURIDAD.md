# SEGURIDAD — Parque Automotor Benjamín Paz

Guía paso a paso. Hacé los pasos **en este orden**. Lo marcado con 🛑 puede
romper la sincronización si se hace mal; leé la advertencia antes.

> Nota: estos cambios de código se escribieron sin poder compilar ni correr la
> app en el entorno donde se generaron. Antes de distribuir, corré
> `flutter pub get`, `flutter test` y probá en un celular (ver paso 6).

---

## 0. Qué cambió en esta versión del proyecto

| Cambio | Archivo |
|---|---|
| Contraseñas con **PBKDF2-HMAC-SHA256 + sal** (100.000 iteraciones). Los hashes viejos siguen funcionando y se actualizan solos al iniciar sesión. | `lib/services/password_hasher.dart`, `auth_service.dart` |
| El código de admin se verifica con el mismo sistema y **ya viene cambiado** (hash nuevo cargado). Script para generar otro sin escribir el código en ningún archivo. | `tool/gen_admin_hash.dart`, `admin_access_screen.dart` |
| **Reglas de Firestore** con validación de datos y roles, y `audit_log` / `deleted_records` solo de creación. | `firestore.rules` |
| **Reglas de Storage** (faltaban): los respaldos ya no se pueden leer ni borrar desde un cliente. | `storage.rules` |
| **App Check** (Play Integrity) activado en la app. Todavía no bloquea nada hasta el paso 4. | `sync_service.dart`, `pubspec.yaml` |
| Se sacó del README el ejemplo de reglas abiertas (`if true`). | `README.md` |
| Nuevo workflow de Codemagic que compila el `.aab` y lo sube a la **pista interna de Google Play**. | `codemagic.yaml` (`android-play-internal`) |
| `targetSdk` 34 → **36**: Google Play lo exige para apps nuevas y actualizaciones desde el 31/08/2026; con 34 rechazaría la subida. | `android/app/build.gradle` |
| Se quitaron los permisos `SCHEDULE_EXACT_ALARM` (el código no usa alarmas exactas) y `READ_MEDIA_IMAGES` (la galería usa el selector del sistema); Play restringe ambos. | `AndroidManifest.xml` |
| Versión de la app 1.1.0+5 → 1.4.2+10. | `pubspec.yaml` |
| **Pantalla legal / carga:** tope de tiempo en el control de acceso, en la aceptación legal y en la sincronización, para que nada quede girando para siempre. | `auth_gate.dart`, `legal_terms_screen.dart`, `legal_terms_service.dart`, `sync_provider.dart` |
| **App Check solo en la versión de Play** (`--dart-define=APP_CHECK=true`): en un APK instalado a mano Play Integrity no puede verificar la app y volvía lenta la nube. | `sync_service.dart`, `codemagic.yaml` |
| **Notificaciones:** aviso y botón si el celular las tiene bloqueadas, prueba con mensaje del motivo, ícono de respaldo si falla el propio, y el selector de audio muestra todos los archivos (MP3, M4A, OGG, WAV, AAC, OPUS). | `notification_service.dart`, `notification_sound_service.dart`, `notification_settings_screen.dart`, `MainActivity.kt` |
| **Fix de compilación (apariencia por complejo):** el proyecto original usaba `getComplexAppearances`, `upsertComplexAppearance` y `pushAppearance`, que nunca estuvieron escritas, y no registraba el provider en `main.dart` (la pantalla de inicio fallaba al abrirse). Ahora hay tabla en la base (versión 18), sincronización con la nube, el provider registrado, la apariencia se aplica al entrar a cada complejo y el admin la edita desde Panel de administración → *Apariencia de cada complejo*. | `database_helper.dart`, `sync_service.dart`, `main.dart`, `complex_home_screen.dart`, `admin_panel_screen.dart`, `firestore.rules` |
| **Fix de compilación (mío):** al sacar el selector de intervalo del panel admin se habían borrado las funciones de exportar y restaurar respaldo; recuperadas. | `admin_panel_screen.dart` |
| **Trámites:** cada trámite (en cualquiera de los 4 estados) puede llevar un **móvil** y una **fecha de finalización**; se ven en el listado y en el PDF. La base de datos pasa a la versión 17 (se actualiza sola al abrir la app). | `procedure.dart`, `procedure_form_screen.dart`, `procedure_list_screen.dart`, `pdf_report_service.dart`, `database_helper.dart`, `firestore.rules` |
| **Fix de compilación:** el hash del admin contiene `$` y Dart lo leía como variable; ahora es una cadena cruda (`r'...'`). | `admin_access_screen.dart` |
| **Fix de compilación:** `main.dart` tenía un `switch` de tipografías que no cubría las 22 del enum; ahora usa `buildAppTheme`. | `lib/main.dart` |
| **Nombre de respaldos:** `respaldo P.A.B.P <fecha y hora de carga>.json` (manual, nube y Drive). | `backup_service.dart`, `drive_backup_service.dart`, `storage.rules` |
| **MP3 propio** como sonido de las notificaciones (Android). | `notification_sound_service.dart`, `MainActivity.kt` |
| **Aviso en la barra de arriba** con ícono propio (auto) y texto expandible. | `notification_service.dart`, `ic_stat_fleet.xml`, `res/raw/keep.xml` |
| **Frecuencia individual** de cada tipo de aviso (service, carnet, combustible cerca y combustible alcanzado), con interruptor para cada uno. | `notification_service.dart`, `notification_settings_screen.dart` |
| Tests de la función de hash con vectores oficiales. | `test/password_hasher_test.dart` |

**Hallazgo importante:** el proyecto no tenía reglas de Storage, y la app sube
ahí un respaldo completo (con todos los datos y los hashes de usuarios) cada 3
horas. Si tu Storage estaba en modo de prueba, esos respaldos podían ser
públicos. Publicá `storage.rules` (paso 3) y revisá la carpeta `backups/`.

---

## 1. Hoy mismo

### 1.1 Poné el repositorio en privado
GitHub → el repo → **Settings** → **Danger Zone** → **Change visibility** →
Private. Borrar un archivo no alcanza: queda en el historial y en los forks.
Revisá **Settings → Forks** por si alguien lo copió.

### 1.2 Fijate si la keystore alguna vez estuvo en el repo
En una computadora con el repo clonado:

```bash
git log --all --oneline -- '*.jks' '*.keystore' 'android/key.properties'
```

- **No imprime nada:** la keystore nunca se subió. No hace falta cambiarla
  (está en las variables seguras de Codemagic). Seguí al 1.3.
- **Imprime commits:** dala por comprometida. Cualquiera con ese archivo y su
  contraseña puede firmar APKs que se instalan como actualización de los tuyos.
  🛑 Cambiar la firma obliga a **desinstalar la app vieja** en cada equipo, así
  que antes hacé un respaldo JSON desde la app. Pasos:

```bash
keytool -genkeypair -v -keystore fleetapp-release.jks -alias fleetapp \
  -keyalg RSA -keysize 2048 -validity 10000
# Linux:  base64 -w0 fleetapp-release.jks
# macOS:  base64 -i fleetapp-release.jks | tr -d '\n'
```

En Codemagic → grupo de variables **keystore_credentials**, reemplazá
`CM_KEYSTORE` (el base64), `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS` (`fleetapp`) y
`CM_KEY_PASSWORD`, todas marcadas *Secure*. Guardá el `.jks` y las contraseñas
en un gestor de contraseñas; **si lo perdés, no podés actualizar la app**.

### 1.3 Código de activación de admin (ya cambiado en esta versión)
El hash viejo estuvo en el código fuente, así que se reemplazó: este proyecto
ya trae cargado el hash de un **código nuevo de 20 caracteres** que se te
entregó por el chat (el código en sí **no está en ningún archivo**).
- Guardalo en un gestor de contraseñas. Si lo perdés, generás otro (abajo) y
  recompilás.
- El código viejo **ya no funciona**.
- Para poner uno propio (12 o más caracteres), en tu computadora, dentro de
  `fleet_app`: `dart run tool/gen_admin_hash.dart`. Pegá la línea que imprime en
  `lib/screens/auth/admin_access_screen.dart` (`_kActivationCodeHash`) y
  recompilá.

Límite real: esa pantalla se valida dentro del APK. Alguien que modifique el
APK puede saltarla aunque el código sea perfecto. Sirve contra el que adivina,
no contra el que reprograma. Por eso importa el paso 4.

---

## 2. Orden para publicar esta versión
1. Subí el código al repo **privado** y compilá con Codemagic (misma keystore). Para App Check hace falta distribuir por Google Play (paso 4); mientras tanto podés seguir con el workflow `android-apk`.
2. 🛑 **Instalá el APK nuevo en TODOS los celulares antes de que los usuarios
   inicien sesión.** Al ingresar con la versión nueva, la contraseña pasa al
   formato PBKDF2 y se sube a la nube; una versión vieja de la app no puede
   verificar ese formato y esa persona no podría entrar desde ese equipo.
3. Cada usuario debe iniciar sesión una vez (con internet) para actualizar su
   hash. En celulares económicos el primer ingreso puede tardar 1–2 segundos más.

---

## 3. Consola de Firebase

Proyecto: `parque-automotor-benjami-d88ce`.

1. **Firestore → Reglas:** borrá todo, pegá `firestore.rules`, **Publicar**.
   Probá en *Rules Playground* o directamente sincronizando desde la app.
2. **Storage → Reglas:** pegá `storage.rules`, **Publicar**.
3. **Storage → carpeta `backups/`:** revisá que no haya archivos que no
   reconozcas. Se crea uno nuevo cada 3 horas y **nunca se borran solos**:
   borrá los viejos de vez en cuando para no pagar de más.
4. **Firestore → Datos:** buscá documentos que no cargaste vos (fechas raras,
   vehículos desconocidos, usuarios en `common_users` que no creaste).
5. **Authentication → Usuarios:** si ves miles de usuarios anónimos, alguien
   está usando la configuración pública.
6. **Alerta de presupuesto:** Google Cloud Console → Facturación → *Presupuestos
   y alertas* → crear presupuesto (por ejemplo USD 5) con avisos al 50 %, 90 % y
   100 %. Las alertas avisan, no cortan el gasto.
7. **Restringí la API key:** Google Cloud Console → *APIs y servicios* →
   *Credenciales* → la clave que empieza con `AIzaSyA5…` → *Restricciones de
   aplicaciones* → **Apps de Android** → agregá `com.fleetapp.app` y el
   **SHA-1** de tu keystore (`keytool -list -v -keystore fleetapp-release.jks
   -alias fleetapp`). Si más adelante publicás en Play, agregá también el SHA-1
   de la *clave de firma de Play*. 🛑 Si ponés mal el SHA-1, la sincronización
   deja de andar: probala justo después. Esto sube la dificultad pero no es
   infalible, porque esos datos se pueden copiar de un APK.

---

## 4. Google Play (pista interna) + App Check

App Check con Play Integrity solo reconoce apps **instaladas desde Google
Play**. La pista **interna** es privada (no aparece en la tienda), gratis de
usar y admite hasta 100 testers por correo. Este proyecto ya trae el workflow
`android-play-internal` en `codemagic.yaml`.

### 4.0 Lo que tenés que saber antes de empezar
- 🛑 **Play vuelve a firmar la app con su propia clave** (Play App Signing).
  Tu keystore pasa a ser solo la "clave de subida". La app instalada desde
  Play tiene otra firma que el APK que ya instalaste a mano, **no se instala
  encima**: en cada celular hay que hacer un respaldo JSON, desinstalar,
  instalar desde Play y restaurar.
- Se necesita una cuenta de desarrollador de Google Play (pago único).
- Play te va a pedir completar declaraciones de la app (política de
  privacidad, seguridad de los datos, acceso a la app, clasificación de
  contenido). La app usa ubicación, cámara y fotos y guarda datos de personas,
  así que prepará una política de privacidad con una URL. Para la pista interna
  suelen pedir menos que para producción, pero el menú puede variar.
- Ya se quitó `READ_MEDIA_IMAGES` del manifiesto. Al probar, confirmá que
  elegir una foto de la galería sigue funcionando.
- El `targetSdk 36` activa el modo de pantalla completa obligatorio de Android 16
  y el gesto "atrás" predictivo: probá que ningún botón quede tapado por la
  barra del sistema y que "atrás" funcione bien.

### 4.1 Crear la app en Play Console
1. Play Console → **Crear app**. Nombre: PARQUE AUTOMOTOR BENJAMIN PAZ. Idioma
   español, tipo *App*, gratis.
2. Dejá activado **Play App Signing** (es lo predeterminado y es obligatorio
   para los bundles nuevos).
3. El paquete debe ser `com.fleetapp.app` (el mismo de `build.gradle`).

### 4.2 Primera versión: subila a mano
Google no permite crear la primera versión por API.
1. En Codemagic corré el workflow **android-play-internal** (va a fallar al
   publicar, es normal la primera vez; el `.aab` igual queda en *Artifacts*).
   Si querés evitar el error, comentá temporalmente el bloque `publishing:
   google_play` en `codemagic.yaml`.
2. Descargá el `.aab`.
3. Play Console → **Pruebas** → **Pruebas internas** → **Crear versión** →
   subí el `.aab` → guardá y **lanzá**.
4. **Pruebas internas → Testers**: creá una lista de correos (cuentas de Google
   de quienes van a instalar) y copiá el **enlace de aceptación**.

### 4.3 Subidas automáticas desde Codemagic
1. Google Cloud Console (el proyecto de Firebase u otro) → habilitá la **Google
   Play Android Developer API**.
2. *IAM y administración → Cuentas de servicio* → **Crear**. Luego *Claves →
   Agregar clave → JSON* y descargá el archivo.
3. Play Console → *Usuarios y permisos* → **Invitar usuarios nuevos** → pegá el
   correo de la cuenta de servicio y dale permiso de **lanzar versiones en
   pistas de prueba** para esta app.
4. Codemagic → *Teams / Environment variables* → creá el grupo **google_play**
   con la variable segura `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` = **todo el
   contenido** del JSON. Nunca subas ese JSON al repositorio.
5. Desde ahí, cada vez que corras **android-play-internal**, la versión sube
   sola a la pista interna (como borrador; si preferís que quede publicada
   directo, quitá `submit_as_draft` cuando la app ya tenga una versión
   publicada).

### 4.4 Instalar desde Play en los celulares
1. Cada tester abre el **enlace de aceptación** desde el celular con su cuenta
   de Google y acepta.
2. Instala desde Play. Las actualizaciones llegan solas.
3. Recordatorio: primero respaldo JSON, desinstalar el APK anterior (otra
   firma), instalar desde Play y restaurar.

### 4.5 Registrar la firma de Play en Firebase y en la API key
Play Console → **Pruebas y lanzamiento → Integridad de la app → Firma de apps**:
ahí figuran el SHA-1 y el SHA-256 de la **clave de firma de la app** (no la de
subida).
- Firebase → Configuración del proyecto → tu app Android → agregá esas huellas.
- Google Cloud → Credenciales → la API key → en la restricción de apps Android,
  agregá también el **SHA-1 de la clave de firma de Play** (el paso 3.7).

### 4.6 App Check
1. Play Console → Integridad de la app → **API de Play Integrity** → vinculá el
   proyecto de Google Cloud de Firebase.
2. Firebase → **App Check** → *Apps* → tu app Android → **Play Integrity** →
   cargá el **SHA-256 de la clave de firma de Play**.
3. Usá la app instalada desde Play unos días. En App Check → *APIs* mirá las
   métricas: tiene que aparecer casi todo como *verificado*.
4. Recién ahí: *APIs* → **Cloud Firestore** → **Enforce**, y lo mismo con
   **Storage**. 🛑 Desde ese momento, todo equipo que no tenga la app instalada
   desde Play deja de sincronizar (la app sigue funcionando offline). Si algo
   sale mal, se desactiva con un clic en la misma pantalla.

Para probar en modo debug: al correr `flutter run`, la app imprime un *debug
token* en la consola; se registra en App Check → *Administrar tokens de debug*.

---

## 5. Lo que sigue siendo débil (la verdad)
- Con una sesión anónima compartida, **las reglas no pueden saber si sos el
  admin**. Con App Check mejora mucho (solo la app genuina entra), pero un
  equipo con root o la app modificada igual podría hacerlo.
- Cualquier equipo con la app genuina puede **leer todos los datos** de la
  nube, incluidos los hashes de `common_users`. PBKDF2 hace que un robo de datos
  no se convierta enseguida en contraseñas, pero una contraseña débil sigue
  siendo débil: usá contraseñas largas.
- El rol de admin se valida solo dentro de la app.
- La solución definitiva es **Firebase Auth con una cuenta por persona** y el
  rol de admin como *custom claim* verificado en las reglas. Eso requiere
  rehacer el login y un pequeño backend (Cloud Functions). Si querés, se puede
  encarar como siguiente etapa.

---

## 6. Prueba antes de distribuir
```bash
flutter pub get
flutter test                 # verifica el hash contra vectores oficiales
flutter run                  # en un celular real
```
En el celular, comprobá: (1) un usuario común existente puede iniciar sesión;
(2) tras iniciar sesión, en Firestore → `common_users` su `password_hash`
empieza con `pbkdf2-sha256$`; (3) crear un vehículo y verlo en Firestore;
(4) el código de admin nuevo funciona y uno incorrecto no.
Si algo no sincroniza, revisá Firebase → Firestore → *Reglas* → *Monitor* para
ver qué escritura se rechazó.

---

## 7. Funciones nuevas: cómo se usan

**Notificaciones** (Ajustes → *Notificaciones*, o Panel de administración →
*Sonido y frecuencia de avisos*):
- **Sonido:** *Elegir audio* abre el selector de archivos (máximo 5 MB; MP3,
  M4A, OGG, WAV, AAC u OPUS).
  *Probar notificación* la muestra al instante para oírla. *Usar el
  predeterminado* vuelve al sonido del sistema. El sonido vale solo para ese
  celular y solo en Android (en iPhone el sistema no lo permite).
- **Barra de arriba:** cada aviso sale con un ícono de auto en la barra de
  estado, como banner emergente, y se expande para leer el texto completo.
  En Android 13 o superior, aceptá el permiso de notificaciones la primera vez;
  si lo rechazaste, la pantalla muestra un aviso naranja con el botón *Permitir
  notificaciones* (si no alcanza: Ajustes del celular → Aplicaciones → la app →
  Notificaciones).
- **Frecuencia individual:** service, carnet, combustible "cerca del límite" y
  combustible "límite alcanzado" tienen su propio interruptor y su propia
  frecuencia (de 15 minutos a 7 días). En los dos de combustible también existe
  *Solo una vez*: avisa apenas se cruza el límite y no repite. Solo el admin
  cambia esto. Android revisa cada ~15 minutos, así que ese es el mínimo real.
- Si un aviso suena callado, revisá el volumen de notificaciones y el modo
  *No molestar* del celular.

**Trámites:** al crear o editar un trámite hay un selector **Móvil (opcional)**
con las unidades del complejo y un campo **Fecha de finalización (opcional)**
(no puede ser anterior al inicio; se puede quitar con la ✕). Al pasar el estado
a *Finalizado* se propone la fecha de hoy. Los trámites que ya existían quedan
sin móvil y sin fecha. Como los datos nuevos viajan por la sincronización,
instalá la versión nueva en todos los celulares: una versión vieja que edite un
trámite puede borrarle el móvil y la fecha. Volvé a publicar `firestore.rules`
en la consola de Firebase.

**Respaldos:** todos se llaman `respaldo P.A.B.P <fecha y hora de carga>.json`.
En Firebase Storage además hay un `respaldo P.A.B.P ultimo.json` que se pisa en
cada respaldo. Los respaldos viejos (`auto_backup_*.json`) siguen en la nube; las
reglas nuevas aceptan ambos nombres para que las apps viejas no fallen.

**Arreglo silencioso:** la versión anterior pedía un sonido (`alert_sound`) que
nunca estuvo en la app. Esta versión borra esos canales viejos al abrirse y
crea unos nuevos; por eso la primera vez, los avisos de ese celular pueden
mostrarse con otro nombre en los ajustes de Android.

---

## Checklist
- [ ] Repo en privado
- [ ] Revisé el historial por keystore (y la cambié si hacía falta)
- [ ] Guardé el código de admin nuevo en un gestor de contraseñas
- [ ] APK nuevo instalado en todos los celulares
- [ ] `firestore.rules` y `storage.rules` publicadas
- [ ] Revisé datos, usuarios anónimos y la carpeta `backups/`
- [ ] Alerta de presupuesto creada
- [ ] API key restringida (y sincronización probada)
- [ ] App creada en Play Console y primera versión subida a la pista interna
- [ ] Cuenta de servicio y grupo `google_play` cargados en Codemagic
- [ ] Celulares migrados a la versión instalada desde Play (con respaldo JSON)
- [ ] Huellas de Play cargadas en Firebase y en la API key
- [ ] App Check configurado, métricas revisadas y *Enforce* activado


## Fotos de trámites compartidas entre dispositivos

Las fotos de los trámites se guardan en Firestore (colección `procedure_photos`),
sin Storage y sin Drive, bajo las mismas reglas que el resto de los datos.
**Hay que volver a publicar `firestore.rules`** (Firebase → Firestore → Reglas →
pegar → Publicar); sin eso las fotos no se suben ni se bajan. Las reglas permiten
leer una foto puntual pero NO listar la colección, y los nombres son UUID
aleatorios. Para el bloqueo real contra apps ajenas, activá App Check (paso 4).
