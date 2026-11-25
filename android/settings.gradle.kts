pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Optional Maven mirror (e.g. LUMORA_MAVEN_MIRROR=https://maven.aliyun.com/repository/public)
    // for networks where repo.maven.apache.org is throttled; unset by default, so
    // CI and normal builds resolve exactly as before.
    val pluginMirror = System.getenv("LUMORA_MAVEN_MIRROR") ?: ""

    repositories {
        if (pluginMirror.isNotEmpty()) {
            maven { url = uri("$pluginMirror/gradle-plugin") }
            maven { url = uri("$pluginMirror/public") }
        }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")
