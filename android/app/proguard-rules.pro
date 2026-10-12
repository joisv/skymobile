# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep annotations and signatures for reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# Mobile Scanner & ML Kit
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Bluetooth Thermal Printer
-keep class com.example.print_bluetooth_thermal.** { *; }
-keep class com.print_bluetooth_thermal.** { *; }
-dontwarn com.print_bluetooth_thermal.**

# Shared Preferences & Permissions
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }

# JNI & Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Android app classes
-keep class com.example.skyrental_admin.** { *; }
