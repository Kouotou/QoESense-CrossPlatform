import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play upload key: android/key.properties (gitignored) points at a keystore kept OUTSIDE the
// repo. See docs/PLAY_STORE_RELEASE.md. Never commit either file.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "io.github.kouotou.qoesense"
    // 37: required by permission_handler_android (same as the reference app).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Final ID (decision D-2, 2026-11-07). Different from the reference app's
        // com.example.qoesense, so both install side by side during the D-1 handover.
        // Never change it after release: a new ID is a new app.
        applicationId = "io.github.kouotou.qoesense"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties (another machine), fall back to the debug key so
            // `flutter run --release` still works. Play rejects debug-signed bundles, so such a
            // build can never be uploaded by mistake.
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "release" else "debug")
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
    // Pigeon 29 generates `suspend` host APIs dispatched on Dispatchers.Main.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    // The same versions as the reference app's libs.versions.toml.
    implementation("androidx.core:core-ktx:1.19.0")
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    implementation("com.google.android.gms:play-services-location:21.4.0")
    // JVM unit tests for the pure Kotlin pieces (CellChangeCounter, AutoStart.brandOf).
    testImplementation("junit:junit:4.13.2")
}
