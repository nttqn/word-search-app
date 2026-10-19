# Appended onto the freshly-generated android/app/proguard-rules.pro by
# the CI workflow's "Enable release code shrinking" step.
#
# WorkManager's Room-backed WorkDatabase_Impl is only referenced via
# reflection, so R8 (especially on recent AGP versions) strips it as
# "unused", which crashes the app on launch with "Unable to get provider
# androidx.startup.InitializationProvider" / "Failed to create an
# instance of androidx.work.impl.WorkDatabase". WorkManager itself is
# pulled in transitively by google_mobile_ads, not used directly by this
# app. See CLAUDE.md for the full story.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}

# shared_preferences_android backs onto Jetpack DataStore internally and
# talks to it partly through Protobuf-generated/reflection-accessed
# classes. A real-device report (sound effects entirely silent, best
# scores never saving — both read/write shared_preferences) matched the
# exact symptom shape of this series' other "R8 silently strips a
# plugin's internals in the release build only" incidents (see the
# WorkManager rule above, and [[feedback_admob_workmanager_r8]]) — nothing
# in local/CI/web testing catches this since none of those build with the
# same aggressive shrinking as a real release APK. Kept broadly rather
# than naming exact classes since the DataStore/protobuf internals aren't
# a public, stable API surface to pin to.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class androidx.datastore.*.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**
