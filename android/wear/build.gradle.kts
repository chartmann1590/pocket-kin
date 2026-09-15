plugins { id("com.android.application"); id("org.jetbrains.kotlin.android"); id("org.jetbrains.kotlin.plugin.compose") }
android {
    namespace="com.pocketkin.game"
    compileSdk=36
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
    defaultConfig { applicationId="com.pocketkin.game"; minSdk=30; targetSdk=36; versionCode=2; versionName="0.2.0" }
    buildTypes {
        getByName("release") {
            val ks = file("../pocket-kin-upload.keystore")
            if (ks.exists()) signingConfig = signingConfigs.getByName("release")
        }
    }
    buildFeatures { compose=true }
    compileOptions { sourceCompatibility=JavaVersion.VERSION_17; targetCompatibility=JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget="17" }
}
dependencies {
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.wear.compose:compose-material:1.4.1")
    implementation("androidx.wear.compose:compose-foundation:1.4.1")
    implementation("androidx.compose.ui:ui:1.7.8")
    implementation("androidx.wear.tiles:tiles:1.6.2")
    implementation("androidx.wear.protolayout:protolayout:1.2.1")
    implementation("androidx.wear.watchface:watchface-complications-data-source-ktx:1.2.1")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
    implementation("com.google.guava:guava:33.4.0-android")
}
