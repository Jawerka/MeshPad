#Requires -Version 5.1
# MeshPad — запуск из корня репозитория.
#   .\dev.ps1          → приложение на Windows (debug)
#   .\dev.ps1 -Test    → тестовый прогон (analyze + tests)
#   .\dev.ps1 -Release → release-сборка + запуск meshpad.exe
& "$PSScriptRoot\scripts\dev.ps1" @args
