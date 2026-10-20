import com.android.build.gradle.BaseExtension
import org.gradle.api.file.Directory

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

    // ✅ Force ALL Android library modules (including isar_flutter_libs) to use compileSdk 36
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt is BaseExtension) {

            // Fix for "Namespace not specified" in external plugins
            if (androidExt.namespace == null) {
                androidExt.namespace = "dev.isar.${project.name.replace(":", ".")}"
            }

            // ✅ This is the important part: force compileSdkVersion
            androidExt.compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
