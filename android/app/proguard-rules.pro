# Suppress warnings for compile-time annotations not needed at runtime
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# Suppress warnings for Tink internal references
-dontwarn com.google.crypto.tink.**

# Isar DB Keep rules
-keep class io.isar.** { *; }
-dontwarn io.isar.**

# Flutter Blue Plus Keep rules
-keep class com.boskokg.flutter_blue_plus.** { *; }
