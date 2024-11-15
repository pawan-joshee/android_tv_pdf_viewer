# Preserve classes from your app and libraries
-keep class androidtv.pdfviewer.redflute** { *; }
-keep class androidx.appcompat.** { *; }
-keep class net.** { *; }   # Adjust as needed for your packages
-keep class android.** { *; }

# Don't warn about missing classes or methods
-dontwarn net.**
-dontobfuscate
