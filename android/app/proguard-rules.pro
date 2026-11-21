# Reglas para que R8 (minify) no elimine lo necesario para las alertas
# en segundo plano (WorkManager) y las notificaciones locales.
-keep class androidx.work.** { *; }
-keep class be.tramckrijte.workmanager.** { *; }
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
