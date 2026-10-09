# The Flutter Gradle plugin adds the engine's own keep rules; these cover the
# plugins this app uses that rely on reflection.

# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Google Sign-In / Play Services auth
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.**

# google_sign_in 7 goes through Credential Manager, which finds its Play
# Services provider by reflection. Without these R8 strips it from the release
# build and sign-in fails even though debug builds work.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }
-keep class androidx.credentials.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn androidx.credentials.**
-dontwarn com.google.android.libraries.identity.googleid.**

# Keep annotations used by the above.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
