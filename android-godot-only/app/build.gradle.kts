plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
layout.buildDirectory.set(rootProject.file("../build/godot-only/app"))
val releaseSigning = mapOf(
    "storeFile" to System.getenv("ANDROID_KEYSTORE_PATH"),
    "storePassword" to System.getenv("ANDROID_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("ANDROID_KEY_ALIAS"),
    "keyPassword" to System.getenv("ANDROID_KEY_PASSWORD"),
)
val hasReleaseSigning = releaseSigning.values.all { !it.isNullOrBlank() }
require(hasReleaseSigning || releaseSigning.values.all { it.isNullOrBlank() }) {
    "All Android release signing environment variables must be provided together."
}
require(System.getenv("RUNE_NEXUS_REQUIRE_RELEASE_SIGNING") != "true" || hasReleaseSigning) {
    "Distribution builds require the existing Android release signing key."
}
android {
    namespace = "com.example.rune_nexus"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.example.rune_nexus"
        minSdk = 24
        targetSdk = 36
        versionCode = System.getenv("VERSION_CODE")?.toIntOrNull() ?: 1
        versionName = System.getenv("VERSION_NAME") ?: "0.1.0"
        manifestPlaceholders["appLabel"] = "rune_nexus"
    }
    flavorDimensions += "deployment"
    productFlavors {
        create("production") {
            dimension = "deployment"
            ndk { abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64") }
        }
        create("inspection") {
            dimension = "deployment"
            applicationIdSuffix = ".godotonly"
            manifestPlaceholders["appLabel"] = "Rune Nexus Godot 테스트"
            ndk { abiFilters += "arm64-v8a" }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    signingConfigs {
        if (hasReleaseSigning) create("distribution") {
            storeFile = file(releaseSigning.getValue("storeFile")!!)
            storePassword = releaseSigning.getValue("storePassword")
            keyAlias = releaseSigning.getValue("keyAlias")
            keyPassword = releaseSigning.getValue("keyPassword")
        }
    }
    buildTypes {
        release {
            isDebuggable = false
            // Local release artifacts without the distribution key stay unsigned.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("distribution") else null
            proguardFiles("proguard-rules.pro")
        }
        debug { isDebuggable = true }
    }
    sourceSets.getByName("main").assets.srcDir(rootProject.file("../build/godot/android-assets"))
    androidResources.noCompress += "pck"
}
dependencies {
    implementation("org.godotengine:godot:4.7.2.stable")
    // Godot exposes FragmentActivity but declares fragment as a runtime dependency.
    implementation("androidx.fragment:fragment:1.8.6")
    implementation("androidx.credentials:credentials:1.6.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.6.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.2.0")
}
