# Ignore warnings for specific Java and Android classes
-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient
-dontwarn javax.lang.model.SourceVersion
-dontwarn javax.lang.model.element.Element
-dontwarn javax.lang.model.element.ElementKind
-dontwarn javax.lang.model.element.Modifier
-dontwarn javax.lang.model.type.TypeMirror
-dontwarn javax.lang.model.type.TypeVisitor
-dontwarn javax.lang.model.util.SimpleTypeVisitor8
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry
-dontwarn j$.util.concurrent.ConcurrentHashMap$TreeBin
-dontwarn j$.util.concurrent.ConcurrentHashMap
-dontwarn j$.util.concurrent.ConcurrentHashMap$CounterCell
-dontwarn j$.util.IntSummaryStatistics
-dontwarn j$.util.LongSummaryStatistics
-dontwarn j$.util.DoubleSummaryStatistics
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn org.checkerframework.**
-dontwarn javax.annotation.**
-dontwarn io.flutter.embedding.**

# MediaPipe classes
-keep public interface com.google.mediapipe.framework.* {
  public *;
}
-keep public class com.google.mediapipe.framework.Packet {
  public static *** create(***);
  public long getNativeHandle();
  public void release();
}
-keep public class com.google.mediapipe.framework.PacketCreator {
  *** releaseWithSyncToken(...);
}
-keep public class com.google.mediapipe.framework.MediaPipeException {
  <init>(int, byte[]);
}
-keep class com.google.mediapipe.framework.ProtoUtil$SerializedMessage { *; }

# Jackson Databind
-keepnames class com.fasterxml.** { *; }
-keep class org.codehaus.** { *; }
-keepnames class org.codehaus.** { *; }
-keep class java.beans.** { *; }
-keep class com.fasterxml.** { *; }
-keep class org.opencv.** { *; }

# Specific classes
-keep class java.beans.ConstructorProperties.** { *; }
-keep class java.beans.Transient.** { *; }
-keep class javax.lang.model.SourceVersion.** { *; }
-keep class javax.lang.model.element.Element.** { *; }
-keep class javax.lang.model.element.ElementKind.** { *; }
-keep class javax.lang.model.element.Modifier.** { *; }
-keep class javax.lang.model.type.TypeMirror.** { *; }
-keep class javax.lang.model.type.TypeVisitor.** { *; }
-keep class javax.lang.model.util.SimpleTypeVisitor8.** { *; }
-keep class org.w3c.dom.bootstrap.DOMImplementationRegistry.** { *; }

# Google Play Services
-keep public class com.google.android.gms.* { public *; }
-keepnames @com.google.android.gms.common.annotation.KeepName class *
-keepclassmembernames class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

# Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }

# Flutter WebRTC
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
-keep class org.webrtc.audio.* { *; }
-keep class org.webrtc.voiceengine.* { *; }

# Telegram classes
-keep class org.telegram.messenger.* { *; }
-keep class org.telegram.messenger.camera.* { *; }
-keep class org.telegram.messenger.secretmedia.* { *; }
-keep class org.telegram.messenger.support.* { *; }
-keep class org.telegram.messenger.time.* { *; }
-keep class org.telegram.messenger.video.* { *; }
-keep class org.telegram.messenger.voip.* { *; }
-keep class org.telegram.SQLite.** { *; }

# ExoPlayer extension classes
-keep class com.google.android.exoplayer2.ext.** { *; }

# Huawei Services
-keep class com.huawei.hianalytics.**{ *; }
-keep class com.huawei.updatesdk.**{ *; }
-keep class com.huawei.hms.**{ *; }

# TypeToken and subclasses for Gson
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# ProGuard settings
-dontoptimize
-dontobfuscate
