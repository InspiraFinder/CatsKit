plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    FileInputStream(localPropertiesFile).use { stream ->
        localProperties.load(stream)
    }
}

android {
    namespace = "com.tcits.inspira.catskit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            storeFile = file("catskit_keystore.jks")
            storePassword = localProperties.getProperty("storePassword", "")
            keyAlias = "catskit_alias"
            keyPassword = localProperties.getProperty("keyPassword", "")
        }
    }

    defaultConfig {
        applicationId = "com.tcits.inspira.catskit"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
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

// 添加在这里 ↓
dependencies {
    // ML Kit 中文文字识别（必须显式添加，否则运行时找不到 ChineseTextRecognizerOptions）
    implementation("com.google.mlkit:text-recognition-chinese:16.0.0")
    
    // 如果还需要其他语言，按需添加（每个约增加 8-10MB）：
    // implementation("com.google.mlkit:text-recognition-japanese:16.0.0")
    // implementation("com.google.mlkit:text-recognition-korean:16.0.0")
    // implementation("com.google.mlkit:text-recognition-devanagari:16.0.0")
}