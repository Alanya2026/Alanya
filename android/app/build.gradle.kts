plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.alanya237.alanya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications pour les APIs Java 8+ sur
        // d'anciennes versions Android.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.alanya237.alanya"
        // Firebase Messaging et flutter_callkit_incoming requièrent au moins API 23.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // Phase 4 — MessagingStyle natif + actions (data-only FCM côté backend).
        manifestPlaceholders["talkyNotificationNativeV2"] = "true"
        manifestPlaceholders["talkyFlutterFcmEnabled"] = "false"
    }

    testOptions {
        // Les stubs android.jar lèvent « not mocked » : neutralisés pour les
        // tests JVM purs (file d'actions, politique HTTP), qui n'utilisent de
        // toute façon aucune API Android.
        unitTests.isReturnDefaultValues = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.core:core-ktx:1.15.0")
    // Tests JVM purs (aucun impact APK). `org.json:json` fournit la vraie
    // implémentation à la place des stubs android.jar, qui lèvent sinon
    // « not mocked » sur JSONArray/JSONObject.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
