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
// Certains plugins (ex. porcupine_flutter) compilent encore contre une
// ancienne API Android, refusée par les bibliothèques AndroidX récentes.
fun Project.bumpCompileSdk() {
    val android = extensions.findByName("android") as? com.android.build.api.dsl.LibraryExtension ?: return
    if ((android.compileSdk ?: 0) < 36) android.compileSdk = 36
}
subprojects {
    if (state.executed) bumpCompileSdk() else afterEvaluate { bumpCompileSdk() }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
