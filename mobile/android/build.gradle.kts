allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(file("../../build"))

subprojects {
    val newSubprojectBuildDir: Directory = rootProject.layout.buildDirectory.dir(project.name).get()
    project.layout.buildDirectory.set(newSubprojectBuildDir.asFile)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}