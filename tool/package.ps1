$ErrorActionPreference = 'Stop'
$appRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$dist = Join-Path $appRoot 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$windows = Join-Path $appRoot 'build/windows/x64/runner/Release'
if (-not (Test-Path -LiteralPath (Join-Path $windows 'noon.exe'))) { throw 'Compile o Windows antes de empacotar.' }
$runtimeDirectory = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Redist\MSVC\14.51.36231\x64\Microsoft.VC145.CRT'
foreach ($runtime in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    Copy-Item -LiteralPath (Join-Path $runtimeDirectory $runtime) -Destination (Join-Path $windows $runtime) -Force
}
$notes = @'
Noon 0.1.0 · Clustter cores

Extraia todo o ZIP e abra noon.exe. Windows 10/11 x64.
Android: instale o APK da arquitetura do aparelho, geralmente arm64. Android 7/API 24 ou superior. APK de uso pessoal, assinado com chave de desenvolvimento.

Primeira versão: síntese em camadas, efeitos, guias de acordes/seções e exportação WAV/.noon. O projeto é um script editável; Copiar para LLM permite trabalhar com uma LLM externa. Não há integração de rede no app.

Use Ouvir para escutar o exemplo, Timbre para transformar o som, Compor para acordes/seções e Script para editar texto. Exporte .noon como backup. Dados locais não são sincronizados.

Limites: 8 camadas, 16 compassos, 60 segundos de arranjo e 4 s de cauda. Sem importação de áudio, MIDI, VST ou motor em tempo real. O teclado toca uma nota por vez, sem gravar no arranjo.

Fontes Lato/Bitcount sob OFL; licenças em data/flutter_assets/assets/fonts. Demais avisos de bibliotecas em data/flutter_assets/NOTICES.Z ou Licenças do Flutter.
Runtime Visual C++ da Microsoft acompanha o executável, conforme a distribuição local recomendada pela documentação Flutter. Os respectivos avisos de copyright permanecem nos binários da Microsoft.
'@
$notes | Set-Content -LiteralPath (Join-Path $windows 'LEIA-ME.txt') -Encoding utf8
Compress-Archive -Path (Join-Path $windows '*') -DestinationPath (Join-Path $dist 'Noon-0.1.0-Windows-x64.zip') -Force
foreach ($abi in @('arm64-v8a', 'armeabi-v7a', 'x86_64')) {
    $source = Join-Path $appRoot "build/app/outputs/flutter-apk/app-$abi-release.apk"
    if (-not (Test-Path -LiteralPath $source)) { throw "APK ausente: $abi" }
    $label = switch ($abi) { 'arm64-v8a' { 'arm64' } 'armeabi-v7a' { 'arm32' } 'x86_64' { 'x64' } }
    Copy-Item -LiteralPath $source -Destination (Join-Path $dist "Noon-0.1.0-$label.apk") -Force
}
$hashes = Get-ChildItem -LiteralPath $dist -File | Where-Object { $_.Extension -in @('.apk', '.zip') } | Sort-Object Name | ForEach-Object {
    $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $($_.Name)"
}
$hashes | Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt') -Encoding utf8
Get-ChildItem -LiteralPath $dist -File | Select-Object Name, Length
