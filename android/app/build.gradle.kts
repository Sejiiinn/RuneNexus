plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigning = mapOf(
    "storeFile" to System.getenv("ANDROID_KEYSTORE_PATH"),
    "storePassword" to System.getenv("ANDROID_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("ANDROID_KEY_ALIAS"),
    "keyPassword" to System.getenv("ANDROID_KEY_PASSWORD"),
)
val hasReleaseSigning = releaseSigning.values.all { !it.isNullOrBlank() }
// 로컬 3D 검수 앱의 설치·데이터 영역 분리. 일반/배포 빌드 기본값 유지.
val isGodotPreview = providers.gradleProperty("runeNexusGodotPreview").orNull == "true"
require(hasReleaseSigning || releaseSigning.values.all { it.isNullOrBlank() }) {
    "All Android release signing environment variables must be provided together."
}
require(System.getenv("RUNE_NEXUS_REQUIRE_RELEASE_SIGNING") != "true" || hasReleaseSigning) {
    "Distribution builds require the existing Android release signing key."
}

android {
    namespace = "com.example.rune_nexus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.rune_nexus"
        if (isGodotPreview) applicationIdSuffix = ".godotpreview"
        manifestPlaceholders["appLabel"] = when {
            isGodotPreview -> "Rune Nexus Godot 테스트"
            else -> "rune_nexus"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("distribution") {
                storeFile = file(releaseSigning.getValue("storeFile")!!)
                storePassword = releaseSigning.getValue("storePassword")
                keyAlias = releaseSigning.getValue("keyAlias")
                keyPassword = releaseSigning.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 로컬 실행용 기본 서명, 배포 CI에서는 기존 배포 키 필수
            signingConfig = signingConfigs.getByName(
                if (hasReleaseSigning) "distribution" else "debug"
            )
            proguardFiles("proguard-rules.pro")
        }
    }

    sourceSets.getByName("main") {
        assets.srcDir(rootProject.file("../build/godot/android-assets"))
        if (isGodotPreview) {
            // 검수 앱의 설치 영역·진입점만 분리하고 엔진과 프로젝트 팩은 공용.
            manifest.srcFile("src/godotPreview/AndroidManifest.xml")
            java.srcDir("src/godotPreview/kotlin")
        }
    }
    androidResources.noCompress += "pck"
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.godotengine:godot:4.7.2.stable")
    implementation("androidx.credentials:credentials:1.6.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.6.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.2.0")
}

val prepareGodotPack by tasks.registering(Exec::class) {
    // 증분 판단·Godot 실행 파일 탐색은 공용 팩 빌더에서 처리.
    workingDir(rootProject.file(".."))
    commandLine("python3", "scripts/build_godot_pack.py")
}
tasks.named("preBuild") { dependsOn(prepareGodotPack) }
