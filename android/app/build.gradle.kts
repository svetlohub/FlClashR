import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties().apply {
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val mStoreFile: File = file("keystore.jks")
val mStorePassword: String = localProperties.getProperty("storePassword") ?: "123456"
val mKeyAlias: String = localProperties.getProperty("keyAlias") ?: "flclashr"
val mKeyPassword: String = localProperties.getProperty("keyPassword") ?: "123456"
val isRelease = mStoreFile.exists()

android {
    // namespace ДОЛЖЕН совпадать с package в Kotlin-файлах (com.follow.clashx)
    // applicationId — уникальный ID нашего приложения (com.follow.clashr)
    // Это разные вещи, их можно и нужно разделять
    namespace = "com.follow.clashx"
    compileSdk = 36

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.follow.clashr"
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = mStoreFile
            storePassword = mStorePassword
            keyAlias = mKeyAlias
            keyPassword = mKeyPassword
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (isRelease) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(project(":core"))
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("com.android.tools.smali:smali-dexlib2:3.0.9")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
