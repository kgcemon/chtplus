# The Flutter Gradle plugin adds the engine's own keep rules; these cover the
# plugins this app uses that rely on reflection.

# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Google Sign-In / Play Services auth
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.**

# Keep annotations used by the above.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
