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

// Keystore from environment (CI) or local.properties (local dev)
val mStorePassword: String = System.getenv("STORE_PASSWORD")
    ?: localProperties.getProperty("storePassword")
    ?: "changeme"
val mKeyAlias: String = System.getenv("KEY_ALIAS")
    ?: localProperties.getProperty("keyAlias")
    ?: "raketa"
val mKeyPassword: String = System.getenv("KEY_PASSWORD")
    ?: localProperties.getProperty("keyPassword")
    ?: "changeme"

// keystore.jks is written by CI from the KEYSTORE_BASE64 secret
val mStoreFile: File = file("keystore.jks")
val isRelease = mStoreFile.exists()

android {
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
