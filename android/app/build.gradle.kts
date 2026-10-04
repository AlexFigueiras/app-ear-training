import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de upload da Play Store (Play App Signing). Arquivo local e gitignored (android/.gitignore)
// — nunca versionar o keystore nem as senhas. Ver docs/PLAY_STORE.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasUploadKey = keystorePropertiesFile.exists()
if (hasUploadKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    // ID definitivo do app na Play Store: não pode mudar depois do primeiro upload.
    namespace = "com.bosyn.app"
    // Piso explícito: a Play exige targetSdk recente; não depender só do default do Flutter local.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    // NDK r28+ (default do Flutter 3.41) gera .so alinhados a 16 KB, exigência da Play.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.bosyn.app"
        minSdk = 26 // Oboe requer pelo menos API 23+ para Low Latency (AAudio)
        // Fixado (não herdado do Flutter): subir o targetSdk muda comportamento em runtime e deve
        // ser uma decisão explícita. Play Store: ver docs/PLAY_STORE.md.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                cppFlags("-std=c++17")
                // FLEXIBLE_PAGE_SIZES garante páginas de 16 KB mesmo se o NDK for r27.
                arguments("-DANDROID_STL=c++_shared", "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Sem key.properties, só builds locais (flutter run --release / APK de teste) caem na
            // chave debug. O AAB para a Play é bloqueado abaixo.
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "release" else "debug")
            // Símbolos nativos no AAB: permite simbolizar crashes do engine C++ no Play Console.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

// Fail-fast: a Play Console rejeita AAB assinado com chave debug.
gradle.taskGraph.whenReady {
    if (!hasUploadKey && allTasks.any { it.name == "bundleRelease" }) {
        throw GradleException(
            "android/key.properties ausente: o AAB de release precisa da chave de upload. " +
                "Ver docs/PLAY_STORE.md (seção Assinatura).",
        )
    }
}

flutter {
    source = "../.."
}
