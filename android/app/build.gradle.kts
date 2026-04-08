android {
    namespace = "com.follow.clashr" // Соответствует твоему applicationId
    compileSdk = 34 // Стабильная версия для Play Store

    defaultConfig {
        applicationId = "com.follow.clashr"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Здесь должна быть твоя подпись (signingConfig)
        }
    }
}
