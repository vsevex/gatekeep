allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // Only apply custom build directory to non-Flutter-plugin projects
    // Flutter plugins from pub cache are on a different drive and cause cross-drive path issues
    val projectPath = project.projectDir.absolutePath
    val isFlutterPlugin = projectPath.contains("Pub\\Cache") || projectPath.contains("pub.dev")
    
    if (!isFlutterPlugin) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}