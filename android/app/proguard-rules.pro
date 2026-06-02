# Flutter / Dart
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_gemma — MediaPipe & protobuf optional classes used reflectively.
# We don't actually use them (cloud LLM is the active path) but R8 complains.
-dontwarn com.google.mediapipe.**
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.protobuf.**
-keep class com.google.protobuf.** { *; }

# Google Play Core (split-install APIs referenced by Flutter but optional)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Firebase (keep model classes for serialization)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Keep classes annotated with @Keep
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class *
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
