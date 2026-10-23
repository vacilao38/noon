$ErrorActionPreference = 'Stop'
$appRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
$checked = 0
$sourceRoots = @('lib', 'test', 'integration_test', 'tool', 'docs', 'android/app/src', 'windows/runner')
foreach ($sourceRoot in $sourceRoots) {
    Get-ChildItem -LiteralPath (Join-Path $appRoot $sourceRoot) -File -Recurse | Where-Object {
        $_.Extension -in @('.dart', '.kt', '.xml', '.md', '.ps1', '.cpp', '.h', '.rc', '.txt', '.manifest')
    } | ForEach-Object {
        $null = $strictUtf8.GetString([System.IO.File]::ReadAllBytes($_.FullName))
        $checked++
    }
}
Write-Output "UTF-8 estrito: $checked arquivos aprovados."
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $appRoot 'dist/Noon-0.1.0-Windows-x64.zip'
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $names = $archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') }
    foreach ($required in @('noon.exe', 'flutter_windows.dll', 'audioplayers_windows_plugin.dll', 'file_selector_windows_plugin.dll',
        'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll',
        'data/app.so', 'data/flutter_assets/assets/fonts/Lato-Regular.ttf', 'data/flutter_assets/assets/fonts/BitcountGridSingleInk.ttf', 'LEIA-ME.txt')) {
        if ($required -notin $names) { throw "Arquivo ausente no ZIP: $required" }
    }
    Write-Output 'ZIP Windows: executável, motor, plugins, AOT, fontes e instruções presentes.'
} finally { $archive.Dispose() }
$sdkBuildTools = 'C:\Users\Adm\AppData\Local\Android\Sdk\build-tools\36.1.0'
$apk = Join-Path $appRoot 'dist/Noon-0.1.0-arm64.apk'
& (Join-Path $sdkBuildTools 'aapt.exe') dump badging $apk | Select-String 'package:|sdkVersion:|targetSdkVersion:|uses-permission:|native-code:'
if ($LASTEXITCODE -ne 0) { throw 'aapt falhou.' }
foreach ($apkFile in (Get-ChildItem -LiteralPath (Join-Path $appRoot 'dist') -Filter '*.apk' -File | Sort-Object Name)) {
    Write-Output "Assinatura: $($apkFile.Name)"
    & 'C:\Program Files\Android\Android Studio\jbr\bin\java.exe' -jar (Join-Path $sdkBuildTools 'lib/apksigner.jar') verify --verbose --print-certs $apkFile.FullName
    if ($LASTEXITCODE -ne 0) { throw "Verificação de assinatura falhou: $($apkFile.Name)" }
}
