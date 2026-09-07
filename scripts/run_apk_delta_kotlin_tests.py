#!/usr/bin/env python3
"""Run Android-free delta decoder checks after an Android Gradle build."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    project = Path(__file__).resolve().parent.parent
    cache = Path(os.environ.get("GRADLE_USER_HOME", str(Path.home() / ".gradle"))) / "caches/modules-2/files-2.1"
    artifacts = [
        "org.jetbrains.kotlin/kotlin-compiler-embeddable",
        "org.jetbrains.kotlin/kotlin-stdlib",
        "org.jetbrains.kotlin/kotlin-reflect",
        "org.jetbrains.kotlin/kotlin-script-runtime",
        "org.jetbrains.kotlin/kotlin-daemon-embeddable",
        "org.jetbrains.intellij.deps/trove4j",
        "org.jetbrains/annotations",
        "org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm",
    ]
    jars = []
    for artifact in artifacts:
        directory = cache / artifact
        if directory.exists():
            # Gradle 빌드가 선택한 최신 캐시 버전만 사용.
            versions = sorted(directory.iterdir(), key=lambda path: tuple(
                int(part) if part.isdigit() else 0 for part in path.name.split(".")
            ))
            if versions:
                jars.extend(versions[-1].rglob("*.jar"))
    if not any("kotlin-compiler-embeddable" in str(jar) for jar in jars):
        raise SystemExit("Run an Android Gradle build first to populate the Kotlin compiler cache.")
    java_home = os.environ.get("JAVA_HOME")
    java = str(Path(java_home) / "bin/java") if java_home else shutil.which("java")
    if not java:
        raise SystemExit("Set JAVA_HOME to JDK 17 or later.")
    classpath = os.pathsep.join(str(jar) for jar in jars)
    with tempfile.TemporaryDirectory(prefix="apk-delta-kotlin-") as temporary:
        output = Path(temporary) / "tests.jar"
        subprocess.run([
            java, "-cp", classpath, "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler",
            "-no-stdlib", "-no-reflect", "-classpath", classpath, "-d", str(output),
            str(project / "android/app/src/main/kotlin/com/example/rune_nexus/ApkDelta.kt"),
            str(project / "android/app/src/test/kotlin/com/example/rune_nexus/ApkDeltaHarness.kt"),
        ], check=True)
        subprocess.run([
            java, "-cp", classpath + os.pathsep + str(output),
            "com.example.rune_nexus.ApkDeltaHarnessKt", *sys.argv[1:],
        ], check=True)


if __name__ == "__main__":
    main()
