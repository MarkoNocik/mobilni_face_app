# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google ML Kit - Face Detection
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Google Play Services (used by ML Kit)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ML Kit common
-keep class com.google.mlkit.common.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.mlkit.vision.face.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Camera
-keep class androidx.camera.** { *; }

# image_gallery_saver
-keep class com.example.imagegallerysaver.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# Multidex
-keep class androidx.multidex.** { *; }

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
