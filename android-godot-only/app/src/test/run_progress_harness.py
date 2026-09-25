#!/usr/bin/env python3
"""Run the native downloader regression harness after compileInspectionDebugKotlin."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[4]
cache = Path.home() / '.gradle/caches/modules-2/files-2.1'
jars = []
for artifact in ('org.jetbrains.kotlin/kotlin-compiler-embeddable', 'org.jetbrains.kotlin/kotlin-stdlib',
                 'org.jetbrains.kotlin/kotlin-reflect', 'org.jetbrains.kotlin/kotlin-script-runtime',
                 'org.jetbrains.kotlin/kotlin-daemon-embeddable', 'org.jetbrains.intellij.deps/trove4j',
                 'org.jetbrains/annotations', 'org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm'):
    versions = sorted((cache / artifact).glob('*'), key=lambda p: tuple(int(n) if n.isdigit() else 0 for n in p.name.split('.')))
    if versions:
        jars.extend(versions[-1].rglob('*.jar'))
sdk = Path(os.environ.get('ANDROID_HOME', str(Path.home() / 'Library/Android/sdk')))
java = Path(os.environ.get('JAVA_HOME', str(Path.home() / 'development/jdk-17-temurin/Contents/Home'))) / 'bin/java'
classpath = os.pathsep.join(map(str, jars + [sdk / 'platforms/android-36/android.jar',
    root / 'build/godot-only/app/tmp/kotlin-classes/inspectionDebug']))
with tempfile.TemporaryDirectory(prefix='update-progress-') as temp:
    output = Path(temp) / 'tests.jar'
    subprocess.run([str(java), '-cp', classpath, 'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler',
        '-no-stdlib', '-no-reflect', '-classpath', classpath, '-d', str(output),
        str(Path(__file__).parent / 'kotlin/com/example/rune_nexus/AppUpdaterProgressHarness.kt')], check=True)
    subprocess.run([str(java), '-cp', classpath + os.pathsep + str(output),
        'com.example.rune_nexus.AppUpdaterProgressHarnessKt'], check=True)
