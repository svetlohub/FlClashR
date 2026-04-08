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
val mStorePassword: String? = localProperties.getProperty("storePassword") ?: "123456"
val mKeyAlias: String? = localProperties.getProperty("keyAlias") ?: "flclashr"
val mKeyPassword: String? = localProperties.getProperty("keyPassword") ?: "123456"
val isRelease = mStoreFile.exists()

android {
    namespace = "com.follow.clashx"
    compileSdk = 34

    // Принудительно устанавливаем стабильную версию NDK для совместимости с CMake
    ndkVersion = "25.2.9519653"

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
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Указываем CMake использовать Ninja для ускорения сборки в Codespaces
        externalNativeBuild {
            cmake {
                arguments("-GNinja")
            }
        }
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
            signingConfig = if (isRelease) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(project(":core"))
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
