# Flutter [Waterbus](https://docs.waterbus.tech) SDK

WebRTC plugin for Flutter Mobile/Desktop/Web. This plugin fork from [flutter_webrtc](https://pub.dev/packages/flutter_webrtc) to implement `Beauty Filters`, `Virtual Background` and further.

<a href="https://github.com/waterbustech/waterbus"><img src="https://github.com/waterbustech/.github/raw/main/profile/images/waterbus-app.gif?raw=true" width="100%"/></a>

<a href="https://opensource.org/licenses/Apache-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-green.svg"/></a>
<img src="https://img.shields.io/github/issues/waterbustech/flutter-webrtc-plus" alt="GitHub issues"><a href="https://chromium.googlesource.com/external/webrtc/+/branch-heads/6099"><img src="https://img.shields.io/badge/libwebrtc-128.6613.01-yellow.svg" alt="libwebrtc"></a><img src="https://img.shields.io/cocoapods/v/KaiRTC" alt="Cocoapods Version"><a href="https://github.com/lambiengcode"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat&amp;logo=github" alt="PRs Welcome"></a>

## Functionality

| Feature | Android | iOS | [Web](https://flutter.dev/web) | macOS | Windows | Linux | [Embedded](https://github.com/sony/flutter-elinux) | [Fuchsia](https://fuchsia.dev/) |
| :-------------: | :-------------:| :-----: | :-----: | :-----: | :-----: | :-----: | :-----: | :-----: |
| Audio/Video | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Data Channel | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Screen Capture | :heavy_check_mark: | [:heavy_check_mark:(*)](https://github.com/flutter-webrtc/flutter-webrtc/wiki/iOS-Screen-Sharing) | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Unified-Plan | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Simulcast | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| MediaRecorder | :warning: | :warning: | :heavy_check_mark: | | | | | |
| End to End Encryption | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | |
| Insertable Streams | | | | | | | | |

Add `flutter_webrtc_plus` as a [dependency in your pubspec.yaml file](https://flutter.io/using-packages/).

### iOS

Add the following entry to your _Info.plist_ file, located in `<project root>/ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) Camera Usage!</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) Microphone Usage!</string>
```

This entry allows your app to access camera and microphone.

### Note for iOS

The WebRTC.xframework compiled after the m104 release no longer supports iOS arm devices, so need to add the `config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'` to your ios/Podfile in your project

ios/Podfile

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
     target.build_configurations.each do |config|
      # Workaround for https://github.com/flutter/flutter/issues/64502
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES' # <= this line
     end
  end
end
```

### Android

Ensure the following permission is present in your Android Manifest file, located in `<project root>/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

If you need to use a Bluetooth device, please add:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
```

The Flutter project template adds it, so it may already be there.

Also you will need to set your build settings to Java 8, because official WebRTC jar now uses static methods in `EglBase` interface. Just add this to your app level `build.gradle`:

```groovy
android {
    //...
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

If necessary, in the same `build.gradle` you will need to increase `minSdkVersion` of `defaultConfig` up to `23` (currently default Flutter generator set it to `16`).

### Important reminder

When you compile the release apk, you need to add the following operations,
[Setup Proguard Rules](https://github.com/flutter-webrtc/flutter-webrtc/blob/main/android/proguard-rules.pro)

### Example

For more examples, please refer to [waterbus](https://github.com/waterbustech/waterbus).


## License

Apache License 2.0
