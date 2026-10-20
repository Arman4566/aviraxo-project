plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.galla_pro"

    // ✅ REQUIRED by your current plugins/dependencies
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.galla_pro"

        // Keep as-is unless a plugin forces higher
        minSdk = flutter.minSdkVersion

        // Target SDK can be lower than compile SDK, but you can set it to 34/35/36.
        // ✅ Safe + modern choice:
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildTypes {
        release {
            // Local release APK build works with debug signing
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
