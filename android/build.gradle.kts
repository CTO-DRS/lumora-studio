allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Align the JVM target of every plugin's Java and Kotlin compilation (Flutter
// 3.50 jvm-target validation). Plugins that apply their own Kotlin Gradle
// Plugin (e.g. tflite_flutter) otherwise compile Java at the AGP default (11)
// and Kotlin at the toolchain default (21) and fail the consistency check.
subprojects {
    val alignJvm: Project.() -> Unit = {
        try {
            (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        } catch (e: Exception) {
            logger.info("compileOptions already finalized for $name")
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
    if (state.executed) {
        alignJvm()
    } else {
        afterEvaluate { alignJvm() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
