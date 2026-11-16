# Respaldo con Google Drive — guía de arreglo

La app tiene **dos formas** de respaldar y restaurar. La segunda no depende de
nada de Google y siempre funciona.

## A) Sin conexión a Google (siempre disponible)

Panel de administración → *Respaldo de la base de datos*:
- **Guardar copia (Drive, Descargas…)**: abre el "Guardar como" del sistema.
  Ahí elegís *Drive* (o Descargas, o una carpeta) y queda guardado el archivo
  `respaldo P.A.B.P <fecha y hora>.json`.
- **Restaurar desde un archivo**: abre el selector del sistema. Acepta
  archivos de cualquier tipo (a propósito): en Drive los `.json` suelen figurar
  con otro tipo y, si se filtraba por `.json`, aparecían deshabilitados.
  La app valida que sea un respaldo de P.A.B.P y, si no lo es, avisa.
- **Exportar respaldo ahora**: abre el menú "Compartir" (WhatsApp, mail,
  Drive, etc.).

## B) Conexión automática con una cuenta de Google Drive

Falla con el mensaje *"falta registrar la huella SHA-1"* (o el selector de
cuentas no aparece) por una razón de configuración, **no de código**: en
`android/app/google-services.json` figura `"oauth_client": []`, es decir, Google
todavía no conoce la firma de la app. Pasos (una sola vez):

1. **Obtener el SHA-1** de la keystore de firma (la de Codemagic):
   ```bash
   keytool -list -v -keystore fleetapp-release.jks -alias fleetapp
   ```
   Copiá la línea `SHA1:`. Si instalás desde Google Play, también necesitás el
   SHA-1 de la *clave de firma de la app* (Play Console → Integridad de la app →
   Firma de apps).
2. **Firebase** → ⚙ Configuración del proyecto → tu app Android
   (`com.fleetapp.app`) → **Agregar huella digital** → pegá el SHA-1 (repetí con
   cada huella). Esto crea el cliente OAuth de Android automáticamente.
   Opcional: descargá el `google-services.json` nuevo y reemplazá el de
   `android/app/` (ahora debería traer `oauth_client` con datos).
3. **Google Cloud Console** (el mismo proyecto `parque-automotor-benjami-d88ce`)
   → *APIs y servicios* → *Biblioteca* → **Google Drive API** → **Habilitar**.
4. **Pantalla de consentimiento de OAuth**: configurala (tipo *Externo*), con el
   permiso `.../auth/drive.file`. Mientras esté en modo *Prueba*, agregá el
   mail del administrador en **Usuarios de prueba**.
5. Compilá e instalá la app de nuevo y, en el Panel de administración →
   *Respaldo en Google Drive* → **Elegir cuenta de Google Drive**.

Errores típicos y qué significan:

| Mensaje | Causa |
|---|---|
| `ApiException: 10` / `DEVELOPER_ERROR` | Falta el SHA-1 o el paquete no coincide (paso 1–2). |
| `ApiException: 12500` / `sign_in_failed` | Pantalla de consentimiento sin configurar o falta el mail de prueba (paso 4). |
| `403` / `accessNotConfigured` | Drive API sin habilitar (paso 3). |
| El selector de cuentas no aparece y no hay error | Mismo caso que 10: faltan las huellas. |

Si cambiás la keystore, hay que registrar el SHA-1 nuevo.
