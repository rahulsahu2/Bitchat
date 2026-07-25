# Suppress warnings for compile-time annotations not needed at runtime
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# Suppress warnings for Tink internal references
-dontwarn com.google.crypto.tink.**
