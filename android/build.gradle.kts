allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Pinning every plugin module to a low compileSdk silently breaks the build:
// a plugin that references a newer API level (sqflite_android needs
// VERSION_CODES.BAKLAVA / Locale.of from API 36) fails to compile with
// "cannot find symbol", and the error surfaces in the plugin's source rather
// than in anything this repo owns. Keep this in step with app/build.gradle.kts.
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            android.compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
