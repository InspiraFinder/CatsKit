plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// ========== 添加：读取 local.properties ==========
val localProperties = java.util.Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

android {
    namespace = "com.example.catskit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_26
        targetCompatibility = JavaVersion.VERSION_26
    }

    // ========== 添加：签名配置 ==========
    signingConfigs {
        create("release") {
            storeFile = file("catskit_keystore.jks")           // 相对 android/app/ 目录
            storePassword = localProperties.getProperty("storePassword", "")
            keyAlias = "catskit_alias"
            keyPassword = localProperties.getProperty("keyPassword", "")
        }
    }

    defaultConfig {
        applicationId = "com.example.catskit"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ========== 修改：使用 release 签名 ==========
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
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