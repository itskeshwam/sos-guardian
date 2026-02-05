import java.util.Properties

pluginManagement {
    val flutterSdkPath = run {
        val properties = Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        requireNotNull(path) { "flutter.sdk not set in local.properties" }
        path
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
    id("com.android.application") version "8.2.1" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

include(":app")