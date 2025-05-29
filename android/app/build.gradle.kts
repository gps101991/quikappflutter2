plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.quikapp.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ✅ Enable desugaring
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.quikapp.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 2  // Increment this for each update
        versionName = "1.0.1"  // Update this for each release
    }

    signingConfigs {
        create("release") {
            storeFile = file("../keystore/release.keystore")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "your_keystore_password"
            keyAlias = System.getenv("KEY_ALIAS") ?: "your_key_alias"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "your_key_password"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Required for Java 8+ features in libraries like flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
