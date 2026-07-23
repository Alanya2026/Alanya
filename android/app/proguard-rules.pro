# Gson — signatures génériques requises par TypeToken (flutter_local_notifications)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses, EnclosingMethod
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# WebRTC + CallKit
-keep class org.webrtc.** { *; }
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
