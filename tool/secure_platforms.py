#!/usr/bin/env python3
"""Apply deterministic camera, biometrics and backup rules to generated hosts."""
from pathlib import Path
import plistlib

manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    xml = manifest.read_text()
    if 'android:allowBackup=' not in xml:
        xml = xml.replace('<application', '<application android:allowBackup="false" android:fullBackupContent="false"', 1)
    if 'android.permission.CAMERA' not in xml:
        xml = xml.replace('<application', '<uses-permission android:name="android.permission.CAMERA" />\n    <application', 1)
    if 'android.permission.RECEIVE_BOOT_COMPLETED' not in xml:
        xml = xml.replace('<application', '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />\n    <application', 1)
    if 'ScheduledNotificationReceiver' not in xml:
        notification_receivers = """
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false" />
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
        """
        xml = xml.replace('</application>', notification_receivers + '\n    </application>', 1)
    xml = xml.replace('android:label="selquaro"', 'android:label="SELQUARO"')
    manifest.write_text(xml)

activity = Path('android/app/src/main/kotlin/com/selquaro/selquaro/MainActivity.kt')
if activity.exists():
    kotlin = activity.read_text().replace('import io.flutter.embedding.android.FlutterActivity',
        'import io.flutter.embedding.android.FlutterFragmentActivity')
    kotlin = kotlin.replace(': FlutterActivity()', ': FlutterFragmentActivity()')
    activity.write_text(kotlin)

podfile = Path('ios/Podfile')
if not podfile.exists():
    podfile.write_text("""platform :ios, '15.5'
ENV['COCOAPODS_DISABLE_STATS'] = 'true'
project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}
def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "Generated.xcconfig must exist. Run flutter pub get first"
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found"
end
require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)
flutter_ios_podfile_setup
target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
""")
if podfile.exists():
    source = podfile.read_text()
    source = "platform :ios, '15.5'\n" + "\n".join(
        line for line in source.splitlines() if not line.lstrip().startswith("platform :ios,")
    ) + "\n"
    podfile.write_text(source)

plist = Path('ios/Runner/Info.plist')
if plist.exists():
    with plist.open('rb') as f:
        info = plistlib.load(f)
    info['CFBundleDisplayName'] = 'SELQUARO'
    info['NSCameraUsageDescription'] = 'Photograph receipts and warranty documents on your device.'
    info['NSPhotoLibraryUsageDescription'] = 'Choose receipts to import into your encrypted local vault.'
    info['NSFaceIDUsageDescription'] = 'Unlock your encrypted receipts and warranties using Face ID.'
    with plist.open('wb') as f:
        plistlib.dump(info, f)

project = Path('ios/Runner.xcodeproj/project.pbxproj')
if project.exists():
    source = project.read_text()
    for old in ['IPHONEOS_DEPLOYMENT_TARGET = 12.0;', 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;', 'IPHONEOS_DEPLOYMENT_TARGET = 14.0;']:
        source = source.replace(old, 'IPHONEOS_DEPLOYMENT_TARGET = 15.5;')
    project.write_text(source)

# Exclude encrypted private vault files from iCloud device backup.
app_delegate = Path('ios/Runner/AppDelegate.swift')
if app_delegate.exists():
    swift = app_delegate.read_text()
    needle = 'GeneratedPluginRegistrant.register(with: self)'
    channel = '''
    let securityChannel = FlutterMethodChannel(
      name: "com.selquaro/security",
      binaryMessenger: controller.binaryMessenger
    )
    securityChannel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var vault = support.appendingPathComponent("selquaro_v1", isDirectory: true)
        try vault.setResourceValue(true, forKey: .isExcludedFromBackupKey)
        result(true)
      } catch {
        result(FlutterError(code: "BACKUP_EXCLUSION", message: error.localizedDescription, details: nil))
      }
    }
'''
    # Register after plugins, before application launch returns.
    if 'com.selquaro/security' not in swift and needle in swift:
        swift = swift.replace(needle, needle + '\n    if let controller = window?.rootViewController as? FlutterViewController {' + channel + '\n    }')
    app_delegate.write_text(swift)

# Never generate signing identities or credentials in version control.

# R8 sees the OCR plugin's optional script implementations. SELQUARO only uses
# bundled Latin OCR. Suppress only absent optional language classes.
rules = Path('android/app/proguard-rules.pro')
rules.write_text("""-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
""")
gradle = Path('android/app/build.gradle.kts')
if gradle.exists():
    source = gradle.read_text()
    if 'isCoreLibraryDesugaringEnabled = true' not in source:
        source = source.replace(
            'compileOptions {',
            'compileOptions {\n        isCoreLibraryDesugaringEnabled = true',
            1,
        )
    if 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' not in source:
        source += """
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
"""
    source = source.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
    needle = 'signingConfig = signingConfigs.getByName("debug")'
    if needle in source and 'proguard-rules.pro' not in source:
        source = source.replace(
            needle,
            needle + '\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")'
        )
    gradle.write_text(source)
