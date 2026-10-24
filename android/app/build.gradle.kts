plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // Après google-services, dont il dépend pour lire google-services.json.
    id("com.google.firebase.crashlytics")
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
        // Android 7.0 (API 24) au moins : exigé par pro_video_editor (retouche
        // des vidéos avant envoi, Media3 Transformer). Firebase Messaging et
        // flutter_callkit_incoming en demandaient 23.
        minSdk = maxOf(24, flutter.minSdkVersion)
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

            // Explicite, bien que ce soit déjà la valeur par défaut du plugin :
            // avec `isMinifyEnabled`, c'est cette ligne qui décide si les traces
            // de plantage seront lisibles ou non. Une régression ici serait
            // muette — le rapport continuerait d'arriver, simplement
            // indéchiffrable.
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = true
            }
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
    // Sonde de santé du magasin chiffré au démarrage (SecureStorageRepair).
    // Même version que celle embarquée par flutter_secure_storage, qui la
    // déclare en `implementation` : elle n'est donc pas sur notre classpath de
    // compilation sans cette ligne.
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    // Tests JVM purs (aucun impact APK). `org.json:json` fournit la vraie
    // implémentation à la place des stubs android.jar, qui lèvent sinon
    // « not mocked » sur JSONArray/JSONObject.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
