# Flutter & Dart FFI
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# C++ Native JNI / FFI Symbols & Oboe
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep FFI entry points and native bridge bindings
-keep class com.bosyn.** { *; }

# Google Oboe Audio Engine JNI
-keep class com.google.oboe.** { *; }

# Supabase & Serialization models
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-dontwarn okio.**
-dontwarn javax.annotation.**
