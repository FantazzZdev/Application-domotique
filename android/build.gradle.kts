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
    if (!plugins.hasPlugin("com.android.library")) return
    val android = extensions.findByName("android") ?: return
    val methods = android.javaClass.methods
    val get = methods.firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 } ?: return
    val set = methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 } ?: return
    val current = (get.invoke(android) as? Int) ?: 0
    if (current < 36) set.invoke(android, 36)
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
