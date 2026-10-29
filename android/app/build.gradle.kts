import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // Après google-services, dont il dépend pour lire google-services.json.
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé de signature commune à toute l'équipe : `android/key.properties` et
// `android/app/alanya-release.jks`, jamais commités (voir android/.gitignore),
// transmis de la main à la main.
//
// Une seule clé, quelle que soit la machine qui compile. Avec la clé debug de
// chaque PC, Google refusait la connexion Drive sur les APK compilés ailleurs
// (« This android application is not registered to use OAuth2.0 ») et Android
// refusait d'installer une mise à jour signée par un autre poste.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
}
val hasSharedKey = keystorePropertiesFile.exists()

// La CI de publication (android-release.yml) signe avec son propre keystore,
// celui des APK déjà installées, qu'elle désigne par ALANYA_DEBUG_KEYSTORE.
// Deux clés coexistent en attendant que l'équipe en choisisse une (28/10/2026).
val ciKeystore = System.getenv("ALANYA_DEBUG_KEYSTORE")

// Une release sans aucune des deux clés serait signée par une clé que Google
// ne connaît pas : mieux vaut s'arrêter net que livrer un APK où Drive échoue.
gradle.taskGraph.whenReady {
    if (!hasSharedKey && ciKeystore == null && allTasks.any { it.name.contains("Release") }) {
        throw GradleException(
            "android/key.properties introuvable : la version release doit être " +
                "signée avec la clé commune d'Alanya. Demandez key.properties et " +
                "alanya-release.jks à l'équipe."
        )
    }
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

    signingConfigs {
        getByName("debug") {
            // La CI désigne explicitement la clé des APK déjà installées : sur
            // le runner, Gradle ignorait ~/.android/debug.keystore et signait
            // avec une clé jetable, différente à chaque build.
            ciKeystore?.let { storeFile = file(it) }
        }
        if (hasSharedKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // La clé commune aussi en debug : Drive fonctionne pendant le
            // développement sur tous les postes, et passer d'une version debug
            // à une release n'oblige pas à désinstaller. Sans la clé, la clé
            // debug du poste reprend la main.
            if (hasSharedKey) signingConfig = signingConfigs.getByName("release")
        }
        release {
            // La clé commune si le poste l'a ; sinon, comme avant, la clé debug
            // (celle de la CI quand ALANYA_DEBUG_KEYSTORE la désigne).
            signingConfig = signingConfigs.getByName(if (hasSharedKey) "release" else "debug")
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
    // Compression des vidéos avant envoi (VideoTranscodeBridge) : réduction en
    // 720p, débit fixé, H.264 ou HEVC, HDR converti. Même version que la
    // media3-exoplayer embarquée par video_player_android : deux versions de
    // media3-common sur le même classpath ne cohabitent pas.
    val media3Version = "1.9.2"
    implementation("androidx.media3:media3-transformer:$media3Version")
    implementation("androidx.media3:media3-effect:$media3Version")
    implementation("androidx.media3:media3-common:$media3Version")
    // Tests JVM purs (aucun impact APK). `org.json:json` fournit la vraie
    // implémentation à la place des stubs android.jar, qui lèvent sinon
    // « not mocked » sur JSONArray/JSONObject.
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
