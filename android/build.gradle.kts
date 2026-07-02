allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Aligne compileSdk / Java / Kotlin pour tous les plugins (sous-projets Android
// library), sans dépendance d'évaluation ni hook global : afterEvaluate est
// enregistré ici, à l'intérieur du bloc subprojects, donc toujours au bon
// moment dans le cycle de vie du projet (pas d'ordre non déterministe).
// compileSdk = 36 : nécessaire pour les plugins récents (ex: sqflite_android)
// qui référencent des symboles Android 16 "Baklava" (API 36).
subprojects {
    afterEvaluate {
        pluginManager.withPlugin("com.android.library") {
            extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
                compileSdk = 36
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = JavaVersion.VERSION_17.toString()
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}