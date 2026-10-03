plugins { id("com.android.application"); id("org.jetbrains.kotlin.android") }
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}
android {
    namespace = "com.pocketkin.game"
    compileSdk = 36
    signingConfigs {
        create("release") {
            val ks = file("../pocket-kin-upload.keystore")
            if (ks.exists()) {
                storeFile = ks
                storePassword = providers.environmentVariable("KIN_STORE_PASSWORD").getOrElse(providers.gradleProperty("KIN_STORE_PASSWORD").getOrElse("changeit-SEE-RELEASE-NOTES"))
                keyAlias = providers.environmentVariable("KIN_KEY_ALIAS").getOrElse(providers.gradleProperty("KIN_KEY_ALIAS").getOrElse("pocketkin"))
                keyPassword = providers.environmentVariable("KIN_KEY_PASSWORD").getOrElse(providers.gradleProperty("KIN_KEY_PASSWORD").getOrElse("changeit-SEE-RELEASE-NOTES"))
            }
        }
    }
    defaultConfig {
        applicationId = "com.pocketkin.game"
        minSdk = 28
        targetSdk = 36
        versionCode = 10006
        versionName = "0.2.0"
        val admobApp = providers.environmentVariable("ADMOB_APP_ID")
            .orElse(providers.gradleProperty("admobAppId"))
            .getOrElse("ca-app-pub-3940256099942544~3347511713")
        val rewardedUnit = providers.environmentVariable("REWARDED_AD_UNIT")
            .orElse(providers.gradleProperty("rewardedAdUnit"))
            .orElse(providers.environmentVariable("REWARDED_INTERSTITIAL_AD_UNIT"))
            .orElse(providers.gradleProperty("rewardedInterstitialAdUnit"))
            .getOrElse("ca-app-pub-3940256099942544/5224354917")
        val interstitialUnit = providers.environmentVariable("INTERSTITIAL_AD_UNIT")
            .orElse(providers.gradleProperty("interstitialAdUnit"))
            .getOrElse("ca-app-pub-3940256099942544/1033173712")
        val bannerUnit = providers.environmentVariable("BANNER_AD_UNIT")
            .orElse(providers.gradleProperty("bannerAdUnit"))
            .getOrElse("ca-app-pub-3940256099942544/6300978111")
        val rewardedInterstitialUnit = providers.environmentVariable("REWARDED_INTERSTITIAL_AD_UNIT")
            .orElse(providers.gradleProperty("rewardedInterstitialAdUnit"))
            .getOrElse("ca-app-pub-3940256099942544/5354046379")

        manifestPlaceholders["admobAppId"] = admobApp
        buildConfigField("String", "REWARDED_AD_UNIT", "\"$rewardedUnit\"")
        buildConfigField("String", "INTERSTITIAL_AD_UNIT", "\"$interstitialUnit\"")
        buildConfigField("String", "BANNER_AD_UNIT", "\"$bannerUnit\"")
        buildConfigField("String", "REWARDED_INTERSTITIAL_AD_UNIT", "\"$rewardedInterstitialUnit\"")
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
    }
    buildFeatures { buildConfig = true }
    buildTypes {
        getByName("release") {
            val ks = file("../pocket-kin-upload.keystore")
            if (ks.exists()) signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    packaging { jniLibs { useLegacyPackaging = false }; resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}
dependencies {
    implementation("org.godotengine:godot:4.7.2.stable")
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.0")
    implementation("androidx.health.connect:connect-client:1.1.0")
    implementation("androidx.work:work-runtime-ktx:2.10.1")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("com.google.android.gms:play-services-auth:21.3.0")
    implementation("com.google.android.gms:play-services-ads:24.9.0")
    implementation("com.google.android.ump:user-messaging-platform:3.2.0")
    implementation("com.google.mlkit:translate:17.0.3")
    implementation("com.android.billingclient:billing-ktx:8.0.0")
    implementation(platform("com.google.firebase:firebase-bom:33.13.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-functions")
    implementation("com.google.firebase:firebase-config")
    implementation("com.google.firebase:firebase-crashlytics")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
