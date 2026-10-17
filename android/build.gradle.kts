allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = file("D:/disco_meter_build")
rootProject.layout.buildDirectory.set(newBuildDir.resolve("root"))

subprojects {
    val newSubprojectBuildDir = newBuildDir.resolve(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(newBuildDir)
}
