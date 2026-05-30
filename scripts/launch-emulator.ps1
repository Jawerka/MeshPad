#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$AvdId = "MeshPad_API36"
$javaHome = "C:\Program Files\Android\Android Studio\jbr"
$sdkRoot = "$env:LOCALAPPDATA\Android\Sdk"

$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:Path = "$javaHome\bin;$sdkRoot\emulator;$sdkRoot\platform-tools;$env:LOCALAPPDATA\flutter\bin;" + $env:Path

Write-Host "Launching emulator: $AvdId"
flutter emulators --launch $AvdId

Write-Host "Waiting for device..."
flutter devices
