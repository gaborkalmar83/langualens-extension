import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.langualens.browser"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.langualens.browser"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        vectorDrawables { useSupportLibrary = true }
    }

    // The keystore is never committed. Locally it sits at app/langualens-browser.jks
    // with its passwords in a gitignored keystore.properties; in CI both come from
    // GitHub Actions secrets. With neither present the release build falls back to
    // the debug key so `gradle assembleRelease` still works on a plain checkout.
    val keystoreFile = file(System.getenv("KEYSTORE_FILE") ?: "langualens-browser.jks")
    val keystoreProps = rootProject.file("keystore.properties").let { f ->
        Properties().apply { if (f.exists()) f.inputStream().use { load(it) } }
    }
    fun secret(env: String, prop: String): String? =
        System.getenv(env) ?: keystoreProps.getProperty(prop)

    val hasReleaseKey = keystoreFile.exists() && secret("KEYSTORE_PASSWORD", "storePassword") != null

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = keystoreFile
                storePassword = secret("KEYSTORE_PASSWORD", "storePassword")
                keyAlias = secret("KEY_ALIAS", "keyAlias") ?: "langualens"
                keyPassword = secret("KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        buildConfig = true
    }
    // A style warning should not stop a release build from producing an APK.
    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// Deliberately no Compose, no Room, no navigation library. This is a browser
// shell: plain views keep it small and keep page rendering the only heavy thing
// in the process.
dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.9.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("com.google.android.material:material:1.12.0")

    implementation("com.google.mlkit:translate:17.0.2")
    implementation("com.google.mlkit:language-id:17.0.5")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
