plugins {
    id("com.android.application")
}

val keystorePath = providers.environmentVariable("GXR_UPDATE_KEYSTORE").orNull
    ?: error("Run apps/update-control/build.sh to set up the signing key")
val keystorePassword = providers.environmentVariable("GXR_UPDATE_KEYPASS").orNull
    ?: error("Run apps/update-control/build.sh to set up the signing key")

android {
    namespace = "boo.puppy.gxr.updatehold"
    compileSdk = 37
    buildToolsVersion = "37.0.0"

    defaultConfig {
        applicationId = "boo.puppy.gxr.updatehold"
        minSdk = 34
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"
    }

    signingConfigs {
        create("local") {
            storeFile = file(keystorePath)
            storePassword = keystorePassword
            keyAlias = "update-hold"
            keyPassword = keystorePassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("local")
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    lint {
        checkReleaseBuilds = false
    }
}
