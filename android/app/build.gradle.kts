plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

// ========== 签名配置读取 ==========
// 优先从 android/key.properties 读取签名密码（该文件已被 .gitignore 忽略，不会推送到远程）
// 兼容旧配置：若 key.properties 不存在，则回退读取 local.properties
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    FileInputStream(keyPropertiesFile).use { stream ->
        keyProperties.load(stream)
    }
}

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
            storeFile = file(keyProperties.getProperty("storeFile", "catskit_keystore.jks"))
            storePassword = keyProperties.getProperty("storePassword")
                ?: localProperties.getProperty("storePassword", "")
            keyAlias = keyProperties.getProperty("keyAlias", "catskit_alias")
            keyPassword = keyProperties.getProperty("keyPassword")
                ?: localProperties.getProperty("keyPassword", "")
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