// Android setup for daily reminders (ReminderService,
// flutter_local_notifications) and pronunciation (PronunciationService,
// flutter_tts), applied by CI after `flutter create` regenerates android/.
// Kept here rather than as sed one-liners in the workflow: the multi-line
// XML is far easier to read and get right as plain strings.
//
// - POST_NOTIFICATIONS: runtime permission on Android 13+.
// - RECEIVE_BOOT_COMPLETED + the two receivers: since plugin v16 the app
//   must declare these itself, or scheduled notifications never fire (and
//   don't survive a reboot). Straight from the plugin README.
// - TTS_SERVICE <queries> entry: Android 11+ package visibility hides the
//   TTS engine from the app without it, so speak() stays silent.
// - Core library desugaring: required by flutter_local_notifications, or
//   checkReleaseAarMetadata fails the build. A second android {} /
//   dependencies {} block is valid Gradle (merged with the first).
// - tool/android-res: the monochrome status-bar icon plus a keep.xml so
//   resource shrinking doesn't strip it (it's only referenced by name from
//   Dart).
const fs = require('fs');
const path = require('path');

function patch(file, from, to) {
  const s = fs.readFileSync(file, 'utf8');
  if (!s.includes(from)) throw new Error(`${file}: "${from}" not found`);
  fs.writeFileSync(file, s.replace(from, to));
}

const manifest = 'android/app/src/main/AndroidManifest.xml';
patch(manifest, '<application', `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <application`);
patch(manifest, '</application>', `    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>`);
const ttsIntent = `<intent>
            <action android:name="android.intent.action.TTS_SERVICE"/>
        </intent>`;
if (fs.readFileSync(manifest, 'utf8').includes('<queries>')) {
  patch(manifest, '<queries>', `<queries>
        ${ttsIntent}`);
} else {
  patch(manifest, '</manifest>', `    <queries>
        ${ttsIntent}
    </queries>
</manifest>`);
}

const kts = 'android/app/build.gradle.kts';
const groovy = 'android/app/build.gradle';
if (fs.existsSync(kts)) {
  fs.appendFileSync(kts, `
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
`);
} else {
  fs.appendFileSync(groovy, `
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
`);
}

fs.cpSync('tool/android-res', 'android/app/src/main/res', { recursive: true });
console.log(fs.readFileSync(manifest, 'utf8'));
