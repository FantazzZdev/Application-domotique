plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fr.domotique.deltahome"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.domotique.deltahome"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Clé de signature fixe (app à usage personnel) : chaque nouvel APK
    // s'installe par-dessus le précédent comme une mise à jour, sans
    // désinstaller ni perdre les comptes enregistrés.
    // La clé n'est jamais dans le dépôt (public) : la compilation GitHub la
    // reçoit via les secrets DOMUS_KEYSTORE_B64 / DOMUS_KEYSTORE_PASSWORD.
    val keystorePath = System.getenv("DOMUS_KEYSTORE_PATH")
    val keystorePassword = System.getenv("DOMUS_KEYSTORE_PASSWORD")
    val hasDomusKey = !keystorePath.isNullOrBlank() && !keystorePassword.isNullOrBlank() && file(keystorePath).exists()
    signingConfigs {
        if (hasDomusKey) {
            create("domus") {
                storeFile = file(keystorePath!!)
                storePassword = keystorePassword
                keyAlias = "domus"
                keyPassword = keystorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasDomusKey) "domus" else "debug")
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
