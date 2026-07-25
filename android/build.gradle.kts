allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    fun configureNamespace(proj: Project) {
        if (proj.plugins.hasPlugin("com.android.library")) {
            proj.extensions.configure<com.android.build.gradle.LibraryExtension> {
                if (namespace == null) {
                    val fallbackGroup = "com.bitchat.${proj.name.replace('-', '_')}"
                    namespace = if (proj.group.toString().isNotEmpty()) proj.group.toString() else fallbackGroup
                }
            }
        }
    }

    if (state.executed) {
        configureNamespace(this)
    } else {
        afterEvaluate {
            configureNamespace(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
