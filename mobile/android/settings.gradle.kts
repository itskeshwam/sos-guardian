import java.util.Properties

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.10" apply false
}

include(":app")

val flutterProjectRoot: File? = rootDir.parentFile
val pluginsFile = File(flutterProjectRoot, ".flutter-plugins")
if (pluginsFile.exists()) {
    pluginsFile.readLines().forEach {
        val parts = it.split("=")
        if (parts.size == 2) {
            val pluginName = parts[0]
            val pluginPath = parts[1]
            val androidPluginPath = File(pluginPath, "android")
            if (androidPluginPath.exists()) {
                include(":$pluginName")
                project(":$pluginName").projectDir = androidPluginPath
            }
        }
    }
}
