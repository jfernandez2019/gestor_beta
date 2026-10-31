# Bóveda – gestor de contraseñas 100 % offline (Flutter)

Todo vive cifrado en el teléfono. Sin servidores, sin cuentas, sin internet.

## Puesta en marcha

1. `flutter create boveda` (si aún no tienes el proyecto base) y entra a la carpeta.
2. Copia `pubspec.yaml` y la carpeta `lib/` de este zip sobre el proyecto (reemplaza).
3. `flutter pub get`

## Cambios Android (obligatorios)

**a) `android/app/build.gradle(.kts)`** → `minSdk` en 23 o más:

    minSdk = 23            // (build.gradle antiguo: minSdkVersion 23)

**b) `android/app/src/main/kotlin/.../MainActivity.kt`** → usa el contenido de
`android_notes/MainActivity.kt` (biometría + bloqueo de capturas).

**c) `android/app/src/main/AndroidManifest.xml`**
- Dentro de `<manifest>` agrega: `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`
- En la etiqueta `<application ...>` agrega: `android:allowBackup="false"`
- No agregues el permiso INTERNET (el build release no lo trae).

**d) `android/app/src/main/res/values/styles.xml`** (y `values-night/styles.xml`):
cambia el `parent` de `LaunchTheme` a `Theme.AppCompat.DayNight`
(necesario para el diálogo biométrico de local_auth).

## iOS (si lo usas en iPhone)
En `ios/Runner/Info.plist` agrega `NSFaceIDUsageDescription` con un texto, p. ej.
"Desbloquear tu bóveda de contraseñas".

## Instalar sin Play Store

    flutter build apk --release
    # APK en build/app/outputs/flutter-apk/app-release.apk

## Diseño de seguridad

- Contraseña maestra → PBKDF2-HMAC-SHA256 (310.000 iteraciones, sal aleatoria) → clave AES-256.
- Datos cifrados con AES-256-GCM (detecta cualquier alteración del archivo).
- Archivo `vault.bvd` en el almacenamiento privado de la app; escritura atómica.
- La contraseña maestra nunca se guarda. La clave biométrica se guarda en Android Keystore
  (flutter_secure_storage) solo si activas huella/rostro.
- Bloqueo automático (segundo plano e inactividad de 5 min), portapapeles autolimpiable,
  retraso creciente tras 3 intentos fallidos, pantalla protegida (FLAG_SECURE).
- Límite conocido: el retraso por intentos protege la app, no el archivo; contra alguien que
  copie el archivo solo protege la fortaleza de tu contraseña maestra. Usa una frase larga.
- **No hay recuperación** si olvidas la contraseña maestra. Exporta copias cifradas con frecuencia.
