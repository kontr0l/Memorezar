# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.memorezar.app.**$$serializer { *; }
-keepclassmembers class com.memorezar.app.** { *** Companion; }
-keepclasseswithmembers class com.memorezar.app.** { kotlinx.serialization.KSerializer serializer(...); }

# Ktor
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**

# Tink / androidx.security.crypto references Error Prone annotations that
# aren't shipped at runtime. Suppressing the warnings is the standard fix.
-dontwarn com.google.errorprone.annotations.**
