# Keep your model classes if using serialization
-keep class your.package.name.models.** { *; }

# Add additional keep rules for libraries as needed
# For example, if using Retrofit:
# -keep class retrofit2.** { *; }

# General optimization rules
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
