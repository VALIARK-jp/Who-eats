import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun loadDotEnv(rootDir: File): Map<String, String> {
    val envFile = rootDir.resolve(".env")
    if (!envFile.exists()) return emptyMap()
    return envFile.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .associate { line ->
            val idx = line.indexOf("=")
            val key = line.substring(0, idx).trim()
            val value = line.substring(idx + 1).trim()
            key to value
        }
}

// Flutter プロジェクトルートの .env（android/app ではなく Who_eats/.env）
val flutterProjectRoot = rootProject.rootDir.parentFile
val dotEnv = loadDotEnv(flutterProjectRoot)
val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        load(FileInputStream(localPropertiesFile))
    }
}
val androidMapsApiKey =
    dotEnv["WHOEATS_ANDROID_MAPS_API_KEY"]
        ?: localProperties.getProperty("WHOEATS_ANDROID_MAPS_API_KEY")
        ?: (project.findProperty("MAPS_API_KEY") as String?)
        ?: "YOUR_ANDROID_MAPS_API_KEY"

if (androidMapsApiKey == "YOUR_ANDROID_MAPS_API_KEY") {
    logger.warn(
        "WHOEATS_ANDROID_MAPS_API_KEY is missing in ${flutterProjectRoot}/.env " +
            "(or android/local.properties). Google Map tiles will be blank on Android.",
    )
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.valiark.whoeats"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.valiark.whoeats"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = androidMapsApiKey
        manifestPlaceholders["lineChannelId"] = "2010102462"
    }

    buildTypes {
        release {
            if (!keystorePropertiesFile.exists()) {
                error("android/key.properties is missing. Create a release keystore first.")
            }
            signingConfig = signingConfigs.create("release") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
