plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val appDisplayName = providers.environmentVariable("APP_DISPLAY_NAME")
    .orElse("BNEO")
    .get()
val configuredAndroidApplicationId = providers.environmentVariable("ANDROID_APPLICATION_ID")
    .orNull
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
val androidApplicationId = configuredAndroidApplicationId ?: "com.arkeonethiopia.commarce"
val storeBrandAssetsApproved =
    providers.environmentVariable("STORE_BRAND_ASSETS_APPROVED").orNull == "true"
val repositoryRoot = rootProject.projectDir.parentFile
val releaseKeystorePath = providers.environmentVariable("ANDROID_KEYSTORE_PATH").orNull
val releaseKeyAlias = providers.environmentVariable("ANDROID_KEY_ALIAS").orNull
val releaseKeyPassword = providers.environmentVariable("ANDROID_KEY_PASSWORD").orNull
val releaseStorePassword = providers.environmentVariable("ANDROID_STORE_PASSWORD").orNull
val releaseKeystoreFile = releaseKeystorePath?.takeIf { it.isNotBlank() }?.let { file(it) }
val hasReleaseSigningInputs = listOf(
    releaseKeystorePath,
    releaseKeyAlias,
    releaseKeyPassword,
    releaseStorePassword,
).all { !it.isNullOrBlank() }
val keystoreOutsideRepository = releaseKeystoreFile?.let { keystore ->
    runCatching {
        !keystore.canonicalFile.toPath().startsWith(repositoryRoot.canonicalFile.toPath())
    }.getOrDefault(false)
} ?: false
val hasReleaseSigning =
    hasReleaseSigningInputs && releaseKeystoreFile?.isFile == true && keystoreOutsideRepository
val firebaseOptionsText = repositoryRoot.resolve("lib/firebase_options.dart")
    .takeIf { it.isFile }
    ?.readText()
    .orEmpty()
val googleServicesText = file("google-services.json")
    .takeIf { it.isFile }
    ?.readText()
    .orEmpty()
val usesUpstreamFirebaseProject =
    firebaseOptionsText.contains("projectId: 'cartxis'") ||
        googleServicesText.contains("\"project_id\": \"cartxis\"")

// Flutter passes --dart-define values to Gradle as URL-safe Base64 entries.
// Decode these here so a release task cannot silently package a staging profile.
val dartDefineValues = providers.gradleProperty("dart-defines").orNull
    .orEmpty()
    .split(',')
    .mapNotNull { encoded ->
        runCatching {
            String(java.util.Base64.getUrlDecoder().decode(encoded), Charsets.UTF_8)
        }.getOrNull()
    }
val dartDefineMap = dartDefineValues.mapNotNull { entry ->
    val separator = entry.indexOf('=')
    if (separator <= 0) null else entry.substring(0, separator) to entry.substring(separator + 1)
}.toMap()
val releaseApiUri = dartDefineMap["API_BASE_URL"]?.let { raw ->
    runCatching { java.net.URI(raw) }.getOrNull()
}
val hasValidReleaseProfile =
    dartDefineMap["APP_ENV"] == "production" &&
        !dartDefineMap["APP_NAME"].isNullOrBlank() &&
        releaseApiUri?.scheme.equals("https", ignoreCase = true) &&
        !releaseApiUri?.host.isNullOrBlank() &&
        releaseApiUri?.rawUserInfo == null &&
        (releaseApiUri?.rawPath.isNullOrEmpty() || releaseApiUri?.rawPath == "/") &&
        releaseApiUri?.rawQuery == null &&
        releaseApiUri?.rawFragment == null

android {
    namespace = "com.cartxis.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
                storeFile = requireNotNull(releaseKeystoreFile)
                storePassword = requireNotNull(releaseStorePassword)
            }
        }
    }

    defaultConfig {
        applicationId = androidApplicationId
        manifestPlaceholders["appDisplayName"] = appDisplayName
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

// Fail closed for release packaging when a customer-owned keystore is absent.
tasks.configureEach {
    if (name.contains("Release") &&
        (name.startsWith("assemble") || name.startsWith("bundle") || name.startsWith("package"))) {
        doFirst {
            if (!hasReleaseSigning) {
                throw GradleException(
                    "Release signing is not configured. Supply an ANDROID_KEYSTORE_PATH " +
                        "outside the repository and ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD, " +
                        "and ANDROID_STORE_PASSWORD from a protected secret store.",
                )
            }
            if (appDisplayName.isBlank() ||
                configuredAndroidApplicationId == null ||
                androidApplicationId.startsWith("com.cartxis.") ||
                androidApplicationId.startsWith("com.example.")) {
                throw GradleException(
                    "Release identity is not configured. Supply the approved " +
                        "APP_DISPLAY_NAME and ANDROID_APPLICATION_ID environment values; " +
                        "the local development ID cannot be used implicitly for release.",
                )
            }
            if (!storeBrandAssetsApproved) {
                throw GradleException(
                    "Release branding is not approved. Replace the upstream launcher/splash " +
                        "assets and set STORE_BRAND_ASSETS_APPROVED=true in the protected release job.",
                )
            }
            if (!hasValidReleaseProfile) {
                throw GradleException(
                    "Release profile is missing or unsafe. Pass --dart-define-from-file with " +
                        "APP_ENV=production and an origin-only HTTPS API_BASE_URL.",
                )
            }
            if (usesUpstreamFirebaseProject) {
                throw GradleException(
                    "Release packaging is blocked while Firebase/Crashlytics configuration " +
                        "still references the upstream Cartxis project. Replace or remove " +
                        "those generated configuration files before release.",
                )
            }
        }
    }
}
