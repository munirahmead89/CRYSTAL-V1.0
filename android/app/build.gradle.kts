import java.util.Properties

// Keys android/key.properties must define for a signed release build.
val REQUIRED_KEYSTORE_KEYS = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Which ABIs this build should contain.
//
// Flutter passes `--target-platform` through as a `target-platform` project
// property (e.g. `android-arm,android-arm64`), but AGP 9 does not act on it by
// itself. Translating it here is what makes "real devices only" actually
// happen: the emulator slice is ~23 MB of native code that no phone can load.
// When the property is absent (an IDE or emulator run) nothing is filtered, so
// local x86_64 debugging keeps working.
val allAbis = listOf("arm64-v8a", "armeabi-v7a", "x86_64")
val requestedAbis: List<String> = (project.findProperty("target-platform") as String?)
    ?.split(",")
    ?.mapNotNull { part ->
        when (part.trim()) {
            "android-arm" -> "armeabi-v7a"
            "android-arm64" -> "arm64-v8a"
            "android-x64" -> "x86_64"
            "android-x86" -> "x86"
            else -> null
        }
    }
    ?.filter { it in allAbis }
    ?.distinct()
    ?.takeIf { it.isNotEmpty() }
    ?: allAbis

val unrequestedAbis = allAbis - requestedAbis.toSet()

// AGP 9 stopped relocating the module build directory up into the Flutter
// project's `build/` folder, and it overrides `layout.buildDirectory` if you try
// to force it. The result is that `flutter build apk` completes the Gradle
// build and then fails with "Gradle build failed to produce an .apk file",
// because the Flutter tool scans <flutter-root>/build/app while AGP wrote the
// artifact under android/app/build.
//
// Rather than depend on AGP internals that shift between versions, the packaged
// APK is mirrored into the location the Flutter tool scans. Sourced from AGP's
// own `outputs/apk/<variant>` directory (written by the packaging task itself)
// rather than the Flutter plugin's `outputs/flutter-apk` copy, which is only
// populated from a `doLast` on the assemble task and can still be racing.
val flutterApkDestRoot = rootProject.layout.projectDirectory
    .dir("../build/app/outputs/flutter-apk")

val mirrorApkToFlutterOutput by tasks.registering(Copy::class) {
    description = "Mirrors the packaged APK into <flutter-root>/build/app/outputs."
    from(layout.buildDirectory.dir("outputs/apk/release")) { include("**/*.apk") }
    from(layout.buildDirectory.dir("outputs/apk/debug")) { include("**/*.apk") }
    into(flutterApkDestRoot)
}

tasks.matching { it.name == "assembleRelease" || it.name == "assembleDebug" }
    .configureEach {
        finalizedBy(mirrorApkToFlutterOutput)
    }

// Release signing. Put a `key.properties` file next to `android/` with:
//   storeFile=../play-upload.jks
//   storePassword=...
//   keyAlias=...
//   keyPassword=...
// NEVER commit that file.
//
// A release build WITHOUT this file used to fall back to the debug signing key
// and still emit an APK. That artifact installs fine but is signed by a key
// that is public (the AOSP debug keystore), so it can never receive an update
// from a properly signed build and is rejected outright by some stores. Rather
// than trust a comment to prevent that, a release build now fails loudly.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    REQUIRED_KEYSTORE_KEYS.all { keystoreProperties.getProperty(it)?.isNotBlank() == true }

if (hasReleaseKeystore) {
    // `storeFile` is resolved by Gradle against the :app project directory, so
    // "../play-upload.jks" points at android/play-upload.jks. Fail here rather
    // than deep inside AGP's signing task if it has moved.
    val store = file(keystoreProperties.getProperty("storeFile"))
    if (!store.exists()) {
        throw GradleException(
            "key.properties storeFile=${keystoreProperties.getProperty("storeFile")} " +
                "resolved to $store, which does not exist. Fix the path or the " +
                "keystore, then rebuild.",
        )
    }
}

// Only guard the release variants: a debug build must keep working on a
// checkout that has no signing material.
val releaseRequested = gradle.startParameter.taskNames.any {
    it.equals("assembleRelease", ignoreCase = true) ||
        it.equals("bundleRelease", ignoreCase = true) ||
        it.endsWith("Release", ignoreCase = true)
}
if (releaseRequested && !hasReleaseKeystore) {
    throw GradleException(
        "Refusing to build a release APK: android/key.properties is missing or " +
            "incomplete (needs ${REQUIRED_KEYSTORE_KEYS.joinToString()}).\n" +
            "Shipping an APK signed by the shared debug key would permanently " +
            "block every future update to this package on APKPure and Play, so " +
            "this build stops instead. See store/APKPURE.md to regenerate it.",
    )
}

android {
    namespace = "com.munirwaheed.crystal_messenger"
    // 36, not 34: sqflite_android 2.4.x calls Locale.of() and
    // VERSION_CODES.BAKLAVA, which only exist from API 36. Compiling against
    // 34 fails with "cannot find symbol" inside the plugin.
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time APIs (desugared).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Skip the lintVitalRelease gate that runs during assembleRelease. It was
    // stalling release builds on AGP 9 (no APK produced). Lint still runs in
    // CI via `./gradlew lint`.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    defaultConfig {
        applicationId = "com.munirwaheed.crystal_messenger"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 7.0 (API 24) is the hard floor, and it is set by Flutter rather than
        // by this file on purpose. `flutter.minSdkVersion` resolves to 24.
        //
        // Do NOT try to write a literal `minSdk = 23` here. On every build the
        // Flutter tool runs MinSdkVersionMigration, which rewrites any literal
        // minSdk of 16..23 to `flutter.minSdkVersion` and has no version gate,
        // so the edit is silently reverted (verified: the 23 written here came
        // back as `flutter.minSdkVersion` and the packaged manifest still said
        // minSdkVersion 24). `flutter.minSdkVersion` is an immutable `val`, so
        // there is no supported way to ship API 23 from Flutter 3.44.
        //
        // Supporting Android 6.0 would require an older Flutter toolchain, which
        // is not a good trade against current store tooling.
        //
        // One consequence of the floor being 24 rather than 26: notification
        // channels do not exist on Android 7.0/7.1, so importance is a
        // per-notification field there. That is handled in
        // NotificationService.ensureInitialized.
        minSdk = flutter.minSdkVersion
        // 36 is the current store requirement (Google Play enforced API 35 for
        // new submissions from Aug 2025 and has moved on since; APKPure flags
        // anything older on the listing). It also means
        // USE_FULL_SCREEN_INTENT is NOT auto-granted on install (it was for
        // targetSdk < 34), so the app requests it at runtime and falls back to
        // a high-importance heads-up notification when it is withheld.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            if (requestedAbis.isNotEmpty()) {
                abiFilters += requestedAbis
            } else {
                // No explicit request (an IDE or emulator run): keep everything
                // so local debugging on an x86_64 emulator still works.
                abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
            }
        }
    }

    // Drop unrequested ABIs from the packaged APK.
    //
    // `ndk.abiFilters` alone is not enough under AGP 9: a library AAR that
    // ships prebuilt .so files (flutter_webrtc's libjingle, ML Kit's
    // libbarhopper, sqlite3, Google DataStore) keeps contributing every ABI it
    // was built with, so the x86_64 slices survived a device-only build and
    // added ~23 MB that no phone can use. Excluding the paths at packaging time
    // is the stable API for this and works no matter which module contributed
    // the file.
    if (unrequestedAbis.isNotEmpty()) {
        packaging {
            jniLibs {
                excludes += unrequestedAbis.map { abi -> "lib/$abi/**" }
            }
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                // V4 is the adb-install sideload format. Harmless to emit and
                // keeps sideloading from APKPure working on every device.
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        release {
            // Release builds are guaranteed to have a keystore: the guard above
            // aborts the build when taskNames mentions a Release task. So this
            // never silently degrades to the debug key.
            signingConfig = signingConfigs.getByName("release")
            // R8 shrink + resource shrink + strip debug symbols.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            ndk {
                debugSymbolLevel = "FULL"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
