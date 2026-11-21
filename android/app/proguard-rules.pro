# Lumora Studio – R8 keep rules for release builds.
#
# Flutter enables R8 (minify + resource shrinking) for every `--release`
# build. Libraries that are driven from native code via JNI must keep their
# Java class, field and method names: the native side looks them up with
# FindClass / GetMethodID / GetFieldID, and when R8 renamed or removed one
# of them the lookup fails inside native code and the whole process aborts
# ("Lumora Studio has stopped") instead of throwing a catchable error.

# Keep stack traces readable in the on-device error log.
-keepattributes SourceFile,LineNumberTable,Signature,InnerClasses,EnclosingMethod,Exceptions,*Annotation*

# --- ONNX Runtime (com.microsoft.onnxruntime:onnxruntime-android) ----------
# The AAR ships NO consumer rules. libonnxruntime4j_jni.so constructs
# ai.onnxruntime.OnnxTensor / TensorInfo / NodeInfo / MapInfo / SequenceInfo /
# OnnxMap / OnnxSequence / OnnxSparseTensor / OnnxModelMetadata and throws
# ai.onnxruntime.OrtException(int, String) by name from native code.
-keep class ai.onnxruntime.** { *; }
-keep interface ai.onnxruntime.** { *; }
-keep enum ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# flutter_onnxruntime plugin (method-channel bridge to the classes above).
-keep class com.masicai.flutteronnxruntime.** { *; }
-dontwarn com.masicai.flutteronnxruntime.**

# --- FFmpegKit (ffmpeg_kit_flutter_new_min_gpl) ------------------------------
# The plugin ships consumer rules for com.antonkarpenko.ffmpegkit already;
# repeated here (and for the original com.arthenica namespace) so a future
# plugin update that drops them cannot break video export silently.
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**
-keep class com.arthenica.** { *; }
-dontwarn com.arthenica.**
-keep class com.antonkarpenko.smartexception.** { *; }
-dontwarn com.antonkarpenko.smartexception.**

# --- Generic JNI safety net -------------------------------------------------
# Any class with native methods keeps its name and its native methods, and
# the types used in their signatures (already in proguard-android-optimize,
# repeated so the rule survives a change of default file).
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# --- App ---------------------------------------------------------------------
# MainActivity's diagnostics channel and crash recorder.
-keep class com.ctodrs.lumora.** { *; }
