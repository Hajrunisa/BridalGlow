allprojects {
    repositories {
        // local-stubs must come before google()/mavenCentral() so that Gradle
        // resolves play-services-tapandpay:17.1.2 from the project-committed stub
        // instead of trying to download it from Google Maven (where it is not
        // publicly available). The stub is an empty AAR — it satisfies dependency
        // resolution for stripe-android-issuing-push-provisioning without adding
        // any real NFC/push-provisioning code that BridalGlow does not use.
        maven { url = uri("${rootProject.projectDir}/local-stubs") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
