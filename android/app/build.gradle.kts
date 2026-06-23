plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.whiteapp"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.whiteapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    aaptOptions {
        noCompress("tflite")
    }

    packaging {
        resources {
            excludes += "META-INF/INDEX.LIST"
            excludes += "META-INF/io.netty.versions.properties"
        }
    }
}

dependencies {
    implementation("org.tensorflow:tensorflow-lite:2.14.0")
    implementation("org.tensorflow:tensorflow-lite-support:0.4.4")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // MITM Proxy Stack
    implementation("io.github.littleproxy:littleproxy:2.7.0")
    implementation("com.github.ganskef:littleproxy-mitm:1.1.0") {
        exclude(group = "org.littleshoot", module = "littleproxy")
        exclude(group = "org.slf4j", module = "slf4j-log4j12")
        exclude(group = "log4j", module = "log4j")
        exclude(group = "io.netty")
    }
    implementation("org.bouncycastle:bcpkix-jdk18on:1.77")
    implementation("org.bouncycastle:bcprov-jdk18on:1.77")
    implementation("commons-io:commons-io:2.14.0")
    // SLF4J -> Android Log bridge so LittleProxy/Netty errors are visible in logcat
    implementation("org.slf4j:slf4j-android:1.7.36")
}

flutter {
    source = "../.."
}

configurations.all {
    exclude(group = "com.lmax", module = "disruptor")
    exclude(group = "org.slf4j", module = "slf4j-log4j12")
    exclude(group = "log4j", module = "log4j")
    resolutionStrategy {
        force("org.bouncycastle:bcprov-jdk18on:1.77")
        force("org.bouncycastle:bcpkix-jdk18on:1.77")
        dependencySubstitution {
            substitute(module("org.bouncycastle:bcprov-jdk15on")).using(module("org.bouncycastle:bcprov-jdk18on:1.77"))
            substitute(module("org.bouncycastle:bcpkix-jdk15on")).using(module("org.bouncycastle:bcpkix-jdk18on:1.77"))
        }
        eachDependency {
            if (requested.group == "io.netty") {
                useVersion("4.2.12.Final")
            }
        }
    }
}
