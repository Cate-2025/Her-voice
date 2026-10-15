plugins {
    // AGP 8.10 is deliberately used for broad Android Studio compatibility.
    // Keep this version paired with the Gradle Wrapper in gradle-wrapper.properties.
    id("com.android.application") version "8.10.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
