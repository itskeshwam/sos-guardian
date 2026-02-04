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

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("com.android.application") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")

fun includeFlutterPlugins(settings: Settings) {
    val flutterProjectRoot = settings.rootProject.projectDir.parentFile
    val pluginsFile = File(flutterProjectRoot, ".flutter-plugins-dependencies")
    if (pluginsFile.exists()) {
        val properties = java.util.Properties()
        pluginsFile.inputStream().use { properties.load(it) }
        val plugins = properties.getProperty("plugins.flutter.plugin_packages", "")
        plugins.split(',').forEach { pluginName ->
            val plugin = pluginName.trim()
            if (plugin.isNotEmpty()) {
                val pluginPath = properties.getProperty("$plugin.path")
                if (pluginPath != null) {
                    val pluginDir = File(pluginPath)
                    settings.includeBuild(pluginDir) {
                        dependencySubstitution {
                            substitute(module("io.flutter.plugins.${plugin.replace("_", "")}:flutter")).using(project(":"))
                        }
                    }
                }
            }
        }
    }
}

includeFlutterPlugins(settings)
